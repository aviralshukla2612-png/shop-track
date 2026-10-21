import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/inventory_item.dart';
import '../models/purchase_list_item.dart';
import '../models/purchase_order.dart';

class PurchasesRepository {
  final _uuid = const Uuid();

  // ================= PURCHASE LIST (SHOPPING/PROCUREMENT LIST) =================

  Future<List<PurchaseListItem>> getPurchaseList({String? status}) async {
    final db = await AppDatabase.instance.database;
    final where = status != null && status != 'All' ? 'status = ?' : null;
    final whereArgs = status != null && status != 'All' ? [status] : null;

    final rows = await db.query(
      'purchase_list',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'added_at DESC',
    );
    return rows.map((m) => PurchaseListItem.fromMap(m)).toList();
  }

  Future<void> addToPurchaseList(PurchaseListItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert('purchase_list', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePurchaseListItem(PurchaseListItem item) async {
    final db = await AppDatabase.instance.database;
    await db.update('purchase_list', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> removePurchaseListItem(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('purchase_list', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPurchaseList() async {
    final db = await AppDatabase.instance.database;
    await db.delete('purchase_list');
  }

  // Convert received items into actual purchase order transaction and increment inventory!
  Future<void> convertReceivedToInventory({
    required List<PurchaseListItem> itemsToReceive,
    required String supplierName,
    String? invoiceRef,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final purchaseId = _uuid.v4();
      final now = DateTime.now().toIso8601String();
      double totalAmount = 0.0;

      for (final item in itemsToReceive) {
        final lineTotal = item.requestedQuantity * item.estimatedUnitCost;
        totalAmount += lineTotal;

        // 1. Insert purchase item
        final pItem = PurchaseItem(
          id: _uuid.v4(),
          purchaseId: purchaseId,
          inventoryItemId: item.inventoryItemId,
          productName: item.productName,
          variant: item.variant,
          quantity: item.requestedQuantity,
          unitCost: item.estimatedUnitCost,
          lineTotal: lineTotal,
        );
        await txn.insert('purchase_items', pItem.toMap());

        // 2. Update or create inventory item
        if (item.inventoryItemId != null) {
          final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [item.inventoryItemId], limit: 1);
          if (invRows.isNotEmpty) {
            final cur = (invRows.first['current_stock'] as num).toDouble();
            await txn.update(
              'inventory',
              {
                'current_stock': cur + item.requestedQuantity,
                'purchase_price': item.estimatedUnitCost,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [item.inventoryItemId],
            );
          }
        } else {
          // Check if product exists by name & variant in inventory
          final existing = await txn.query('inventory', where: 'name = ?', whereArgs: [item.productName], limit: 1);
          if (existing.isNotEmpty) {
            final cur = (existing.first['current_stock'] as num).toDouble();
            await txn.update(
              'inventory',
              {
                'current_stock': cur + item.requestedQuantity,
                'purchase_price': item.estimatedUnitCost,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          } else {
            // Create new inventory item
            final newItem = InventoryItem(
              id: _uuid.v4(),
              masterProductId: item.masterProductId,
              name: item.productName,
              brand: item.brand,
              category: 'General',
              packSize: item.packSize,
              purchasePrice: item.estimatedUnitCost,
              sellingPrice: item.estimatedUnitCost * 1.25, // default 25% margin
              currentStock: item.requestedQuantity,
              preferredSupplierName: supplierName,
              imageUrl: item.imageUrl,
              localImagePath: item.localImagePath,
              updatedAt: now,
            );
            await txn.insert('inventory', newItem.toMap());
          }
        }

        // 3. Update status in purchase list
        await txn.update('purchase_list', {'status': 'received'}, where: 'id = ?', whereArgs: [item.id]);
      }

      // 4. Insert purchase order
      final po = PurchaseOrder(
        id: purchaseId,
        orderNumber: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        supplierName: supplierName,
        createdAt: now,
        receivedAt: now,
        totalAmount: totalAmount,
        status: 'received',
        invoiceRef: invoiceRef,
        notes: 'Inward receipt converted from purchase list',
      );
      await txn.insert('purchases', po.toMap());
    });
  }

  // ================= PURCHASE ORDERS =================

  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('purchases', orderBy: 'created_at DESC');
    final list = <PurchaseOrder>[];

    for (final r in rows) {
      final itemRows = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [r['id']]);
      final items = itemRows.map((m) => PurchaseItem.fromMap(m)).toList();
      list.add(PurchaseOrder.fromMap(r, items: items));
    }
    return list;
  }
}
