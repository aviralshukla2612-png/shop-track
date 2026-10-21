import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory_item.dart';

class CsvImportResult {
  final int totalRows;
  final int successfullyImported;
  final List<String> errors;
  final List<InventoryItem> importedItems;

  CsvImportResult({
    required this.totalRows,
    required this.successfullyImported,
    required this.errors,
    required this.importedItems,
  });
}

class CsvService {
  static const _uuid = Uuid();

  static CsvImportResult parseSupplierCsv(String csvContent) {
    final rows = csv.decode(csvContent);
    if (rows.isEmpty) {
      return CsvImportResult(totalRows: 0, successfullyImported: 0, errors: ['CSV file is empty'], importedItems: []);
    }

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final nameIdx = headers.indexOf('name');
    final brandIdx = headers.indexOf('brand');
    final categoryIdx = headers.indexOf('category');
    final subcategoryIdx = headers.indexOf('subcategory');
    final packSizeIdx = headers.indexOf('pack_size');
    final barcodeIdx = headers.indexOf('barcode');
    final mrpIdx = headers.indexOf('mrp');
    final purchasePriceIdx = headers.indexOf('purchase_price');
    final sellingPriceIdx = headers.indexOf('selling_price');
    final openingStockIdx = headers.indexOf('opening_stock');
    final minStockIdx = headers.indexOf('min_stock_level');
    final supplierNameIdx = headers.indexOf('supplier_name');

    if (nameIdx == -1) {
      return CsvImportResult(
        totalRows: rows.length - 1,
        successfullyImported: 0,
        errors: ['Mandatory header "name" is missing from CSV.'],
        importedItems: [],
      );
    }

    final imported = <InventoryItem>[];
    final errors = <String>[];
    final now = DateTime.now().toIso8601String();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;

      try {
        final name = row[nameIdx].toString().trim();
        if (name.isEmpty) {
          errors.add('Row $i: Product name is required.');
          continue;
        }

        final brand = (brandIdx != -1 && brandIdx < row.length) ? row[brandIdx].toString().trim() : 'Generic';
        final category = (categoryIdx != -1 && categoryIdx < row.length) ? row[categoryIdx].toString().trim() : 'General';
        final subcategory = (subcategoryIdx != -1 && subcategoryIdx < row.length) ? row[subcategoryIdx].toString().trim() : null;
        final packSize = (packSizeIdx != -1 && packSizeIdx < row.length) ? row[packSizeIdx].toString().trim() : null;
        final barcode = (barcodeIdx != -1 && barcodeIdx < row.length) ? row[barcodeIdx].toString().trim() : null;
        final mrp = (mrpIdx != -1 && mrpIdx < row.length) ? double.tryParse(row[mrpIdx].toString()) : null;
        final purchasePrice = (purchasePriceIdx != -1 && purchasePriceIdx < row.length) ? (double.tryParse(row[purchasePriceIdx].toString()) ?? 0.0) : 0.0;
        final sellingPrice = (sellingPriceIdx != -1 && sellingPriceIdx < row.length) ? (double.tryParse(row[sellingPriceIdx].toString()) ?? (mrp ?? purchasePrice * 1.2)) : (mrp ?? purchasePrice * 1.2);
        final openingStock = (openingStockIdx != -1 && openingStockIdx < row.length) ? (double.tryParse(row[openingStockIdx].toString()) ?? 0.0) : 0.0;
        final minStock = (minStockIdx != -1 && minStockIdx < row.length) ? (double.tryParse(row[minStockIdx].toString()) ?? 5.0) : 5.0;
        final supplierName = (supplierNameIdx != -1 && supplierNameIdx < row.length) ? row[supplierNameIdx].toString().trim() : null;

        final isTobacco = category.toLowerCase().contains('tobacco') || category.toLowerCase().contains('cigarette') || category.toLowerCase().contains('pan masala');

        final item = InventoryItem(
          id: _uuid.v4(),
          name: name,
          brand: brand.isNotEmpty ? brand : 'Generic',
          category: category.isNotEmpty ? category : 'General',
          subcategory: subcategory,
          packSize: packSize,
          barcode: (barcode != null && barcode.isNotEmpty) ? barcode : null,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          currentStock: openingStock,
          minStockLevel: minStock,
          preferredSupplierName: supplierName,
          isTobacco: isTobacco,
          updatedAt: now,
        );

        imported.add(item);
      } catch (e) {
        errors.add('Row $i: Failed to parse - $e');
      }
    }

    return CsvImportResult(
      totalRows: rows.length - 1,
      successfullyImported: imported.length,
      errors: errors,
      importedItems: imported,
    );
  }

  static String exportInventoryToCsv(List<InventoryItem> items) {
    final headers = [
      'Name',
      'Brand',
      'Category',
      'Pack Size',
      'Barcode',
      'Purchase Price (Cost)',
      'Selling Price (Retail)',
      'Current Stock',
      'Min Stock Level',
      'Inventory Value (Cost)',
      'Supplier'
    ];

    final rows = <List<dynamic>>[headers];
    for (final it in items) {
      rows.add([
        it.name,
        it.brand,
        it.category,
        it.packSize ?? '',
        it.barcode ?? '',
        it.purchasePrice,
        it.sellingPrice,
        it.currentStock,
        it.minStockLevel,
        it.totalInventoryValue,
        it.preferredSupplierName ?? '',
      ]);
    }

    return csv.encode(rows);
  }
}
