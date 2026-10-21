import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/sale_transaction.dart';

class DashboardMetrics {
  final double todaySales;
  final double todayGrossProfit;
  final int todayTransactionsCount;
  final double monthSales;
  final double monthGrossProfit;
  final double activeInventoryValue;
  final int lowStockCount;
  final int activeProductsCount;
  final double totalEstimatedNetProfit; // gross profit minus operating expenses

  DashboardMetrics({
    required this.todaySales,
    required this.todayGrossProfit,
    required this.todayTransactionsCount,
    required this.monthSales,
    required this.monthGrossProfit,
    required this.activeInventoryValue,
    required this.lowStockCount,
    required this.activeProductsCount,
    required this.totalEstimatedNetProfit,
  });
}

class TopProductMetric {
  final String productName;
  final double totalQuantity;
  final double totalRevenue;
  final double totalProfit;
  final String? inventoryItemId;
  final String? imageUrl;
  final String? localImagePath;
  final String? category;
  final double? currentStock;
  final double? sellingPrice;

  TopProductMetric({
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.totalProfit,
    this.inventoryItemId,
    this.imageUrl,
    this.localImagePath,
    this.category,
    this.currentStock,
    this.sellingPrice,
  });

  double get marginPercentage => totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
}

class SalesRepository {
  Future<void> recordSale(SaleTransaction sale, List<SaleItem> items) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // 1. Insert parent sale
      await txn.insert('sales', sale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert line items & update inventory
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

        // Fetch current stock
        final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [item.inventoryItemId], limit: 1);
        if (invRows.isNotEmpty) {
          final cur = (invRows.first['current_stock'] as num).toDouble();
          // If loose stick, check unitsPerPack
          double qtyDeduct = item.quantity;
          if (item.isLooseStick) {
            final unitsPerPack = (invRows.first['units_per_pack'] as int?) ?? 1;
            qtyDeduct = unitsPerPack > 0 ? (item.quantity / unitsPerPack) : item.quantity;
          }
          final newStock = (cur - qtyDeduct).clamp(0.0, 999999.0);
          await txn.update(
            'inventory',
            {
              'current_stock': newStock,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [item.inventoryItemId],
          );
        }
      }
    });
  }

  Future<void> voidSale(String saleId, String reason) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // Fetch items to restore stock
      final items = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (final item in items) {
        final invId = item['inventory_item_id'].toString();
        final qty = (item['quantity'] as num).toDouble();
        final isLoose = item['is_loose_stick'] == 1;

        final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [invId], limit: 1);
        if (invRows.isNotEmpty) {
          final cur = (invRows.first['current_stock'] as num).toDouble();
          double qtyAdd = qty;
          if (isLoose) {
            final unitsPerPack = (invRows.first['units_per_pack'] as int?) ?? 1;
            qtyAdd = unitsPerPack > 0 ? (qty / unitsPerPack) : qty;
          }
          await txn.update(
            'inventory',
            {
              'current_stock': cur + qtyAdd,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [invId],
          );
        }
      }

      await txn.update(
        'sales',
        {
          'status': 'voided',
          'notes': reason,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<List<SaleTransaction>> getRecentSales({int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final list = <SaleTransaction>[];
    for (final r in rows) {
      final itemsRows = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [r['id']]);
      final items = itemsRows.map((m) => SaleItem.fromMap(m)).toList();
      list.add(SaleTransaction.fromMap(r, items: items));
    }
    return list;
  }

  Future<DashboardMetrics> getDashboardMetrics() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    // 1. Today sales & gross profit
    final todayRows = await db.rawQuery('''
      SELECT 
        coalesce(sum(grand_total), 0) as total_sales,
        coalesce(sum(gross_profit), 0) as total_profit,
        count(*) as count
      FROM sales
      WHERE created_at >= ? AND status = 'completed'
    ''', [todayStart]);

    final todaySales = (todayRows.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final todayProfit = (todayRows.first['total_profit'] as num?)?.toDouble() ?? 0.0;
    final todayTxnCount = (todayRows.first['count'] as num?)?.toInt() ?? 0;

    // 2. Month sales & gross profit
    final monthRows = await db.rawQuery('''
      SELECT 
        coalesce(sum(grand_total), 0) as total_sales,
        coalesce(sum(gross_profit), 0) as total_profit
      FROM sales
      WHERE created_at >= ? AND status = 'completed'
    ''', [monthStart]);

    final monthSales = (monthRows.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final monthProfit = (monthRows.first['total_profit'] as num?)?.toDouble() ?? 0.0;

    // 3. Month Expenses
    final expRows = await db.rawQuery('''
      SELECT coalesce(sum(amount), 0) as total_exp
      FROM expenses
      WHERE expense_date >= ?
    ''', [monthStart]);
    final monthExpenses = (expRows.first['total_exp'] as num?)?.toDouble() ?? 0.0;

    // 4. Inventory metrics
    final invRows = await db.rawQuery('''
      SELECT 
        count(*) as active_count,
        coalesce(sum(current_stock * purchase_price), 0) as val,
        coalesce(sum(CASE WHEN current_stock <= min_stock_level THEN 1 ELSE 0 END), 0) as low_count
      FROM inventory
    ''');

    final activeCount = (invRows.first['active_count'] as num?)?.toInt() ?? 0;
    final inventoryVal = (invRows.first['val'] as num?)?.toDouble() ?? 0.0;
    final lowStock = (invRows.first['low_count'] as num?)?.toInt() ?? 0;

    return DashboardMetrics(
      todaySales: todaySales,
      todayGrossProfit: todayProfit,
      todayTransactionsCount: todayTxnCount,
      monthSales: monthSales,
      monthGrossProfit: monthProfit,
      activeInventoryValue: inventoryVal,
      lowStockCount: lowStock,
      activeProductsCount: activeCount,
      totalEstimatedNetProfit: monthProfit - monthExpenses,
    );
  }

  Future<List<TopProductMetric>> getTopSellingProducts({
    int limit = 5,
    String period = '7 Days',
    String sortBy = 'revenue',
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    DateTime? startDate;

    if (period == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (period == '7 Days') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (period == '30 Days') {
      startDate = now.subtract(const Duration(days: 30));
    }

    String orderClause;
    if (sortBy == 'quantity') {
      orderClause = 'total_qty DESC';
    } else if (sortBy == 'profit') {
      orderClause = 'total_prof DESC';
    } else {
      orderClause = 'total_rev DESC';
    }

    final List<dynamic> args = [];
    String dateFilter = '';
    if (startDate != null) {
      dateFilter = 'AND s.created_at >= ?';
      args.add(startDate.toIso8601String());
    }
    args.add(limit);

    final rows = await db.rawQuery('''
      SELECT 
        si.product_name,
        max(si.inventory_item_id) as inventory_item_id,
        coalesce(sum(si.quantity), 0) as total_qty,
        coalesce(sum(si.line_total), 0) as total_rev,
        coalesce(sum(si.line_profit), 0) as total_prof,
        max(inv.image_url) as image_url,
        max(inv.local_image_path) as local_image_path,
        max(inv.category) as category,
        max(inv.current_stock) as current_stock,
        max(inv.selling_price) as selling_price
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN inventory inv ON (
        si.inventory_item_id = inv.id 
        OR LOWER(si.product_name) LIKE '%' || LOWER(inv.name) || '%' 
        OR LOWER(inv.name) LIKE '%' || LOWER(si.product_name) || '%'
      )
      WHERE s.status = 'completed' $dateFilter
      GROUP BY si.product_name
      ORDER BY $orderClause
      LIMIT ?
    ''', args);

    return rows.map((r) => TopProductMetric(
      productName: r['product_name'].toString(),
      inventoryItemId: r['inventory_item_id']?.toString(),
      totalQuantity: (r['total_qty'] as num).toDouble(),
      totalRevenue: (r['total_rev'] as num).toDouble(),
      totalProfit: (r['total_prof'] as num).toDouble(),
      imageUrl: r['image_url']?.toString(),
      localImagePath: r['local_image_path']?.toString(),
      category: r['category']?.toString(),
      currentStock: (r['current_stock'] as num?)?.toDouble(),
      sellingPrice: (r['selling_price'] as num?)?.toDouble(),
    )).toList();
  }

  Future<List<Map<String, dynamic>>> getDailySalesChartData({int days = 7}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final list = <Map<String, dynamic>>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
      final nextDateStr = DateTime(date.year, date.month, date.day + 1).toIso8601String();

      final res = await db.rawQuery('''
        SELECT coalesce(sum(grand_total), 0) as total, coalesce(sum(gross_profit), 0) as profit
        FROM sales
        WHERE created_at >= ? AND created_at < ? AND status = 'completed'
      ''', [dateStr, nextDateStr]);

      final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
      final profit = (res.first['profit'] as num?)?.toDouble() ?? 0.0;

      list.add({
        'day': '${date.day}/${date.month}',
        'sales': total,
        'profit': profit,
      });
    }

    return list;
  }
}
