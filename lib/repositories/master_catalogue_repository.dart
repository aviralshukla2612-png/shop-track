import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/master_product.dart';

class MasterCatalogueRepository {
  Future<List<MasterProduct>> getProducts({
    String? searchQuery,
    String? category,
    String? brand,
    String? packSize,
    String? sourceName,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR brand LIKE ? OR barcode LIKE ? OR flavour LIKE ?)');
      final pattern = '%${searchQuery.trim()}%';
      whereArgs.addAll([pattern, pattern, pattern, pattern]);
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (brand != null && brand.isNotEmpty && brand != 'All') {
      whereClauses.add('brand = ?');
      whereArgs.add(brand);
    }

    if (packSize != null && packSize.isNotEmpty && packSize != 'All') {
      whereClauses.add('pack_size = ?');
      whereArgs.add(packSize);
    }

    if (sourceName != null && sourceName.isNotEmpty && sourceName != 'All') {
      whereClauses.add('source_name = ?');
      whereArgs.add(sourceName);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'master_products',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'brand ASC, name ASC',
      limit: limit,
      offset: offset,
    );

    return results.map((e) => MasterProduct.fromDbMap(e)).toList();
  }

  Future<int> getProductsCount({
    String? searchQuery,
    String? category,
    String? brand,
    String? packSize,
    String? sourceName,
  }) async {
    final db = await AppDatabase.instance.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR brand LIKE ? OR barcode LIKE ? OR flavour LIKE ?)');
      final pattern = '%${searchQuery.trim()}%';
      whereArgs.addAll([pattern, pattern, pattern, pattern]);
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (brand != null && brand.isNotEmpty && brand != 'All') {
      whereClauses.add('brand = ?');
      whereArgs.add(brand);
    }

    if (packSize != null && packSize.isNotEmpty && packSize != 'All') {
      whereClauses.add('pack_size = ?');
      whereArgs.add(packSize);
    }

    if (sourceName != null && sourceName.isNotEmpty && sourceName != 'All') {
      whereClauses.add('source_name = ?');
      whereArgs.add(sourceName);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await db.rawQuery(
      'SELECT count(*) as count FROM master_products ${whereString != null ? 'WHERE $whereString' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<MasterProduct?> getProductById(String id) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query('master_products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return MasterProduct.fromDbMap(results.first);
  }

  Future<MasterProduct?> getProductByBarcode(String barcode) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query('master_products', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (results.isEmpty) return null;
    return MasterProduct.fromDbMap(results.first);
  }

  Future<List<String>> getDistinctCategories() async {
    final db = await AppDatabase.instance.database;
    final results = await db.rawQuery('SELECT DISTINCT category FROM master_products ORDER BY category ASC');
    return results.map((r) => r['category'].toString()).where((c) => c.isNotEmpty).toList();
  }

  Future<List<String>> getDistinctBrands({String? category}) async {
    final db = await AppDatabase.instance.database;
    String sql = 'SELECT DISTINCT brand FROM master_products ';
    List<dynamic> args = [];
    if (category != null && category.isNotEmpty && category != 'All') {
      sql += 'WHERE category = ? ';
      args.add(category);
    }
    sql += 'ORDER BY brand ASC';
    final results = await db.rawQuery(sql, args.isNotEmpty ? args : null);
    return results.map((r) => r['brand'].toString()).where((b) => b.isNotEmpty).toList();
  }

  Future<List<String>> getDistinctPackSizes() async {
    final db = await AppDatabase.instance.database;
    final results = await db.rawQuery('SELECT DISTINCT pack_size FROM master_products WHERE pack_size IS NOT NULL ORDER BY pack_size ASC LIMIT 40');
    return results.map((r) => r['pack_size'].toString()).where((p) => p.isNotEmpty).toList();
  }

  Future<List<String>> getDistinctSources() async {
    final db = await AppDatabase.instance.database;
    final results = await db.rawQuery('SELECT DISTINCT source_name FROM master_products ORDER BY source_name ASC');
    return results.map((r) => r['source_name'].toString()).where((s) => s.isNotEmpty).toList();
  }
}
