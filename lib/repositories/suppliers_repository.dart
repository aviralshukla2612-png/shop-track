import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/supplier.dart';

class SuppliersRepository {
  Future<List<Supplier>> getSuppliers() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('suppliers', orderBy: 'name ASC');
    return rows.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<void> addSupplier(Supplier supplier) async {
    final db = await AppDatabase.instance.database;
    await db.insert('suppliers', supplier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await AppDatabase.instance.database;
    await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }
}
