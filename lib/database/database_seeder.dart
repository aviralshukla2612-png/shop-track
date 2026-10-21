import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/master_product.dart';
import 'app_database.dart';

class DatabaseSeeder {
  static Future<void> seedIfEmpty() async {
    final db = await AppDatabase.instance.database;

    // Purge ALL tobacco, pan masala, and cigarette products from database
    await db.rawDelete('''
      DELETE FROM master_products 
      WHERE source_name = 'SmokeKart'
         OR subcategory = 'Cigarettes' 
         OR subcategory = 'Cigar' 
         OR subcategory = 'Smoking Accessories'
         OR subcategory = 'Pan Masala'
         OR category LIKE '%tobacco%'
         OR category LIKE '%pan masala%'
         OR LOWER(name) LIKE '%tobacco%'
         OR LOWER(name) LIKE '%pan masala%'
         OR LOWER(name) LIKE '%cigarette%'
         OR LOWER(name) LIKE '%cigar%'
    ''');

    // Purge any tobacco from shop inventory and past sales
    await db.rawDelete('''
      DELETE FROM inventory 
      WHERE is_tobacco = 1 
         OR category LIKE '%tobacco%' 
         OR category LIKE '%pan masala%' 
         OR LOWER(name) LIKE '%pan masala%'
         OR LOWER(name) LIKE '%tobacco%'
         OR LOWER(name) LIKE '%cigarette%'
    ''');
    await db.rawDelete('''
      DELETE FROM sale_items 
      WHERE LOWER(product_name) LIKE '%cigarette%' 
         OR LOWER(product_name) LIKE '%tobacco%' 
         OR LOWER(product_name) LIKE '%pan masala%'
         OR LOWER(product_name) LIKE '%classic gold%'
    ''');

    // Purge any demo/dummy inventory, sales, purchases, and suppliers
    await db.rawDelete("DELETE FROM inventory WHERE id IN ('inv-1', 'inv-2', 'inv-3')");
    await db.rawDelete("DELETE FROM sales WHERE id = 'sale-1'");
    await db.rawDelete("DELETE FROM sale_items WHERE sale_id = 'sale-1'");
    await db.rawDelete("DELETE FROM purchases WHERE id = 'po-101'");
    await db.rawDelete("DELETE FROM purchase_items WHERE purchase_id = 'po-101'");
    await db.rawDelete("DELETE FROM purchase_list WHERE id IN ('pl-1', 'pl-2')");
    await db.rawDelete("DELETE FROM suppliers WHERE id = 'sup-1'");

    final countResult = await db.rawQuery('SELECT count(*) as count FROM master_products');
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count == 0) {
      await _seedMasterProducts(db);
    }
  }

  static Future<void> _seedDefaultInventory(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    batch.rawUpdate("UPDATE inventory SET category = 'Namkeen' WHERE category = 'Packaged Snacks'");

    // 1. Supplier
    batch.insert('suppliers', {
      'id': 'sup-1',
      'name': 'Balaji Distributor Agency',
      'phone': '+91 98765 43210',
      'address': 'GIDC Wholesale Market',
      'gst_number': '24AAACB1234D1Z2',
      'current_balance': 0.0,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 2. Three Active SKUs of Aloo Sev matching user's exact screenshot
    batch.insert('inventory', {
      'id': 'inv-1',
      'master_product_id': 'balaji-aloo-sev-10',
      'name': 'Aloo Sev (₹10 Pack)',
      'brand': 'Balaji Wafers',
      'category': 'Namkeen',
      'subcategory': 'Namkeen',
      'pack_size': '₹10 Pack',
      'purchase_price': 8.0,
      'selling_price': 10.0,
      'current_stock': 20.0,
      'min_stock_level': 5.0,
      'preferred_supplier_id': 'sup-1',
      'preferred_supplier_name': 'Balaji Distributor Agency',
      'is_tobacco': 0,
      'units_per_pack': 1,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('inventory', {
      'id': 'inv-2',
      'master_product_id': 'balaji-aloo-sev-20',
      'name': 'Aloo Sev (₹20 Pack)',
      'brand': 'Balaji Wafers',
      'category': 'Namkeen',
      'subcategory': 'Namkeen',
      'pack_size': '₹20 Pack',
      'purchase_price': 16.0,
      'selling_price': 20.0,
      'current_stock': 20.0,
      'min_stock_level': 5.0,
      'preferred_supplier_id': 'sup-1',
      'preferred_supplier_name': 'Balaji Distributor Agency',
      'is_tobacco': 0,
      'units_per_pack': 1,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('inventory', {
      'id': 'inv-3',
      'master_product_id': 'balaji-aloo-sev-5',
      'name': 'Aloo Sev (₹5 Pack)',
      'brand': 'Balaji Wafers',
      'category': 'Namkeen',
      'subcategory': 'Namkeen',
      'pack_size': '₹5 Pack',
      'purchase_price': 4.0,
      'selling_price': 5.0,
      'current_stock': 20.0,
      'min_stock_level': 5.0,
      'preferred_supplier_id': 'sup-1',
      'preferred_supplier_name': 'Balaji Distributor Agency',
      'is_tobacco': 0,
      'units_per_pack': 1,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 3. Realistic sales for Dashboard KPI
    batch.insert('sales', {
      'id': 'sale-1',
      'invoice_number': 'INV-1001',
      'created_at': now,
      'customer_name': 'Walk-in Customer',
      'customer_phone': '',
      'payment_method': 'cash',
      'subtotal': 240.0,
      'discount': 0.0,
      'grand_total': 240.0,
      'total_cost_basis': 192.0,
      'gross_profit': 48.0,
      'status': 'completed',
      'notes': 'Evening snack orders',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('sale_items', {
      'id': 'si-1',
      'sale_id': 'sale-1',
      'inventory_item_id': 'inv-1',
      'product_name': 'Aloo Sev (₹10 Pack)',
      'variant': '₹10 Pack',
      'quantity': 10.0,
      'unit_selling_price': 10.0,
      'unit_cost_basis': 8.0,
      'discount': 0.0,
      'line_total': 100.0,
      'line_profit': 20.0,
      'is_loose_stick': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('sale_items', {
      'id': 'si-2',
      'sale_id': 'sale-1',
      'inventory_item_id': 'inv-2',
      'product_name': 'Aloo Sev (₹20 Pack)',
      'variant': '₹20 Pack',
      'quantity': 5.0,
      'unit_selling_price': 20.0,
      'unit_cost_basis': 16.0,
      'discount': 0.0,
      'line_total': 100.0,
      'line_profit': 20.0,
      'is_loose_stick': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('sale_items', {
      'id': 'si-3',
      'sale_id': 'sale-1',
      'inventory_item_id': 'inv-3',
      'product_name': 'Aloo Sev (₹5 Pack)',
      'variant': '₹5 Pack',
      'quantity': 8.0,
      'unit_selling_price': 5.0,
      'unit_cost_basis': 4.0,
      'discount': 0.0,
      'line_total': 40.0,
      'line_profit': 8.0,
      'is_loose_stick': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 4. Procurement Purchase record
    batch.insert('purchases', {
      'id': 'po-101',
      'order_number': 'PO-2026-001',
      'supplier_id': 'sup-1',
      'supplier_name': 'Balaji Distributor Agency',
      'created_at': now,
      'received_at': now,
      'total_amount': 560.0,
      'status': 'received',
      'invoice_ref': 'INV-BLJ-8821',
      'notes': 'Initial namkeen inventory replenishment',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('purchase_items', {
      'id': 'pi-1',
      'purchase_id': 'po-101',
      'inventory_item_id': 'inv-1',
      'product_name': 'Aloo Sev (₹10 Pack)',
      'variant': '₹10 Pack',
      'quantity': 20.0,
      'unit_cost': 8.0,
      'line_total': 160.0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('purchase_items', {
      'id': 'pi-2',
      'purchase_id': 'po-101',
      'inventory_item_id': 'inv-2',
      'product_name': 'Aloo Sev (₹20 Pack)',
      'variant': '₹20 Pack',
      'quantity': 20.0,
      'unit_cost': 16.0,
      'line_total': 320.0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('purchase_items', {
      'id': 'pi-3',
      'purchase_id': 'po-101',
      'inventory_item_id': 'inv-3',
      'product_name': 'Aloo Sev (₹5 Pack)',
      'variant': '₹5 Pack',
      'quantity': 20.0,
      'unit_cost': 4.0,
      'line_total': 80.0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 5. Purchase procurement shopping list items
    batch.insert('purchase_list', {
      'id': 'pl-1',
      'master_product_id': 'balaji-aloo-sev-10',
      'inventory_item_id': 'inv-1',
      'product_name': 'Aloo Sev (₹10 Pack)',
      'brand': 'Balaji Wafers',
      'variant': '₹10 Pack',
      'pack_size': '₹10 Pack',
      'requested_quantity': 40.0,
      'estimated_unit_cost': 8.0,
      'is_cost_confirmed': 1,
      'status': 'pending',
      'supplier_name': 'Balaji Distributor Agency',
      'notes': 'Restock weekend demand',
      'added_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('purchase_list', {
      'id': 'pl-2',
      'master_product_id': 'balaji-aloo-sev-20',
      'inventory_item_id': 'inv-2',
      'product_name': 'Aloo Sev (₹20 Pack)',
      'brand': 'Balaji Wafers',
      'variant': '₹20 Pack',
      'pack_size': '₹20 Pack',
      'requested_quantity': 30.0,
      'estimated_unit_cost': 16.0,
      'is_cost_confirmed': 1,
      'status': 'ordered',
      'supplier_name': 'Balaji Distributor Agency',
      'notes': 'High profit margin SKU',
      'added_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }

  /// Purges all transactional and active inventory data to maintain a clean slate
  static Future<void> clearAllStoreData(Database db) async {
    await db.rawDelete('DELETE FROM inventory');
    await db.rawDelete('DELETE FROM sale_items');
    await db.rawDelete('DELETE FROM sales');
    await db.rawDelete('DELETE FROM purchase_items');
    await db.rawDelete('DELETE FROM purchases');
    await db.rawDelete('DELETE FROM purchase_list');
    await db.rawDelete('DELETE FROM expenses');
    await db.rawDelete('DELETE FROM stock_adjustments');
    await db.rawDelete('DELETE FROM suppliers');
  }

  static Future<void> _seedMasterProducts(Database db) async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/master_products.json');
      final List<dynamic> list = jsonDecode(jsonStr);

      final batch = db.batch();
      for (final item in list) {
        final product = MasterProduct.fromJson(item as Map<String, dynamic>);
        batch.insert('master_products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Error seeding master products: $e');
    }
  }
}
