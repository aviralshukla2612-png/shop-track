import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/inventory_item.dart';
import '../models/stock_adjustment.dart';

class InventoryValuationSummary {
  final int totalItemsCount;
  final double totalUnitsCount;
  final double totalCostValuation;
  final double totalRetailValuation;
  final double potentialGrossMargin;
  final int lowStockCount;

  InventoryValuationSummary({
    required this.totalItemsCount,
    required this.totalUnitsCount,
    required this.totalCostValuation,
    required this.totalRetailValuation,
    required this.potentialGrossMargin,
    required this.lowStockCount,
  });
}

class InventoryRepository {
  final _uuid = const Uuid();

  Future<List<InventoryItem>> getItems({
    String? query,
    String? category,
    bool? lowStockOnly,
  }) async {
    final db = await AppDatabase.instance.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR brand LIKE ? OR barcode LIKE ?)');
      final p = '%${query.trim()}%';
      whereArgs.addAll([p, p, p]);
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (lowStockOnly == true) {
      whereClauses.add('current_stock <= min_stock_level');
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'inventory',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'current_stock <= min_stock_level DESC, name ASC',
    );

    return results.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<InventoryItem?> getItemById(String id) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query('inventory', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return InventoryItem.fromMap(res.first);
  }

  Future<InventoryItem?> getItemByBarcode(String barcode) async {
    final db = await AppDatabase.instance.database;
    final res = await db.query('inventory', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (res.isEmpty) return null;
    return InventoryItem.fromMap(res.first);
  }

  Future<void> upsertItem(InventoryItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert('inventory', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> adjustStock({
    required String itemId,
    required double quantityChange,
    required String reason,
    String? notes,
  }) async {
    final db = await AppDatabase.instance.database;
    final item = await getItemById(itemId);
    if (item == null) return;

    final newStock = (item.currentStock + quantityChange).clamp(0.0, 999999.0);
    final costLoss = (quantityChange.abs()) * item.purchasePrice;

    await db.transaction((txn) async {
      await txn.update(
        'inventory',
        {
          'current_stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      final adjustment = StockAdjustment(
        id: _uuid.v4(),
        inventoryItemId: itemId,
        productName: item.name,
        quantityChange: quantityChange,
        reason: reason,
        costLoss: costLoss,
        adjustedAt: DateTime.now().toIso8601String(),
        notes: notes,
      );
      await txn.insert('stock_adjustments', adjustment.toMap());
    });
  }

  Future<void> deleteItem(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllItems() async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('inventory');
      await txn.delete('stock_adjustments');
    });
  }

  Future<InventoryValuationSummary> getInventoryValuation() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT 
        count(*) as total_items,
        coalesce(sum(current_stock), 0) as total_units,
        coalesce(sum(current_stock * purchase_price), 0) as total_cost,
        coalesce(sum(current_stock * selling_price), 0) as total_retail,
        coalesce(sum(CASE WHEN current_stock <= min_stock_level THEN 1 ELSE 0 END), 0) as low_stock_count
      FROM inventory
    ''');

    final r = rows.first;
    final totalItems = Sqflite.firstIntValue([{'val': r['total_items']}]) ?? 0;
    final totalUnits = (r['total_units'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (r['total_cost'] as num?)?.toDouble() ?? 0.0;
    final totalRetail = (r['total_retail'] as num?)?.toDouble() ?? 0.0;
    final lowStock = (r['low_stock_count'] as num?)?.toInt() ?? 0;

    return InventoryValuationSummary(
      totalItemsCount: totalItems,
      totalUnitsCount: totalUnits,
      totalCostValuation: totalCost,
      totalRetailValuation: totalRetail,
      potentialGrossMargin: totalRetail - totalCost,
      lowStockCount: lowStock,
    );
  }

  Future<List<StockAdjustment>> getRecentAdjustments({int limit = 30}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'stock_adjustments',
      orderBy: 'adjusted_at DESC',
      limit: limit,
    );
    return rows.map((m) => StockAdjustment.fromMap(m)).toList();
  }
}
