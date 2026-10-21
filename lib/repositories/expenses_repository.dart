import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/expense.dart';

class ExpensesRepository {
  Future<List<Expense>> getExpenses({String? category, DateTime? startDate, DateTime? endDate}) async {
    final db = await AppDatabase.instance.database;

    final where = <String>[];
    final args = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      where.add('category = ?');
      args.add(category);
    }

    if (startDate != null) {
      where.add('expense_date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.add('expense_date <= ?');
      args.add(endDate.toIso8601String());
    }

    final rows = await db.query(
      'expenses',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'expense_date DESC',
    );

    return rows.map((m) => Expense.fromMap(m)).toList();
  }

  Future<void> addExpense(Expense expense) async {
    final db = await AppDatabase.instance.database;
    await db.insert('expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExpense(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getExpensesByCategory({DateTime? since}) async {
    final db = await AppDatabase.instance.database;
    String sql = 'SELECT category, coalesce(sum(amount), 0) as total FROM expenses ';
    List<dynamic> args = [];
    if (since != null) {
      sql += 'WHERE expense_date >= ? ';
      args.add(since.toIso8601String());
    }
    sql += 'GROUP BY category ORDER BY total DESC';

    final rows = await db.rawQuery(sql, args.isNotEmpty ? args : null);
    final map = <String, double>{};
    for (final r in rows) {
      map[r['category'].toString()] = (r['total'] as num).toDouble();
    }
    return map;
  }
}
