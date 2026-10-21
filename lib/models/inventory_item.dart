class InventoryItem {
  final String id;
  final String? masterProductId;
  final String name;
  final String brand;
  final String category;
  final String? subcategory;
  final String? packSize;
  final String? barcode;
  final double purchasePrice; // Shop acquisition cost
  final double sellingPrice;  // Shop selling price
  final double currentStock;
  final double minStockLevel;
  final String? preferredSupplierId;
  final String? preferredSupplierName;
  final bool isTobacco;
  final int unitsPerPack;     // For loose stick sale calculations (e.g. 10 or 20 for cigarettes)
  final double? looseSellingPrice;
  final String? imageUrl;
  final String? localImagePath;
  final String updatedAt;

  InventoryItem({
    required this.id,
    this.masterProductId,
    required this.name,
    required this.brand,
    required this.category,
    this.subcategory,
    this.packSize,
    this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    this.minStockLevel = 5.0,
    this.preferredSupplierId,
    this.preferredSupplierName,
    this.isTobacco = false,
    this.unitsPerPack = 1,
    this.looseSellingPrice,
    this.imageUrl,
    this.localImagePath,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minStockLevel;
  double get totalInventoryValue => currentStock * purchasePrice;
  double get potentialSalesValue => currentStock * sellingPrice;
  double get unitMargin => sellingPrice - purchasePrice;
  double get marginPercentage => purchasePrice > 0 ? ((sellingPrice - purchasePrice) / purchasePrice) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_product_id': masterProductId,
      'name': name,
      'brand': brand,
      'category': category,
      'subcategory': subcategory,
      'pack_size': packSize,
      'barcode': barcode,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'current_stock': currentStock,
      'min_stock_level': minStockLevel,
      'preferred_supplier_id': preferredSupplierId,
      'preferred_supplier_name': preferredSupplierName,
      'is_tobacco': isTobacco ? 1 : 0,
      'units_per_pack': unitsPerPack,
      'loose_selling_price': looseSellingPrice,
      'image_url': imageUrl,
      'local_image_path': localImagePath,
      'updated_at': updatedAt,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'].toString(),
      masterProductId: map['master_product_id']?.toString(),
      name: map['name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      subcategory: map['subcategory']?.toString(),
      packSize: map['pack_size']?.toString(),
      barcode: map['barcode']?.toString(),
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      minStockLevel: (map['min_stock_level'] as num?)?.toDouble() ?? 5.0,
      preferredSupplierId: map['preferred_supplier_id']?.toString(),
      preferredSupplierName: map['preferred_supplier_name']?.toString(),
      isTobacco: map['is_tobacco'] == 1,
      unitsPerPack: (map['units_per_pack'] as int?) ?? 1,
      looseSellingPrice: (map['loose_selling_price'] as num?)?.toDouble(),
      imageUrl: map['image_url']?.toString(),
      localImagePath: map['local_image_path']?.toString(),
      updatedAt: map['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  InventoryItem copyWith({
    double? currentStock,
    double? purchasePrice,
    double? sellingPrice,
    double? minStockLevel,
    String? preferredSupplierId,
    String? preferredSupplierName,
    bool? isTobacco,
    int? unitsPerPack,
    double? looseSellingPrice,
    String? updatedAt,
  }) {
    return InventoryItem(
      id: id,
      masterProductId: masterProductId,
      name: name,
      brand: brand,
      category: category,
      subcategory: subcategory,
      packSize: packSize,
      barcode: barcode,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      preferredSupplierId: preferredSupplierId ?? this.preferredSupplierId,
      preferredSupplierName: preferredSupplierName ?? this.preferredSupplierName,
      isTobacco: isTobacco ?? this.isTobacco,
      unitsPerPack: unitsPerPack ?? this.unitsPerPack,
      looseSellingPrice: looseSellingPrice ?? this.looseSellingPrice,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
