class PurchaseListItem {
  final String id;
  final String? masterProductId;
  final String? inventoryItemId;
  final String productName;
  final String brand;
  final String? variant;
  final String? packSize;
  final double requestedQuantity;
  final double estimatedUnitCost;
  final bool isCostConfirmed;
  final String status; // 'pending', 'ordered', 'received'
  final String? supplierName;
  final String? notes;
  final String? imageUrl;
  final String? localImagePath;
  final String addedAt;

  PurchaseListItem({
    required this.id,
    this.masterProductId,
    this.inventoryItemId,
    required this.productName,
    required this.brand,
    this.variant,
    this.packSize,
    required this.requestedQuantity,
    required this.estimatedUnitCost,
    this.isCostConfirmed = false,
    this.status = 'pending',
    this.supplierName,
    this.notes,
    this.imageUrl,
    this.localImagePath,
    required this.addedAt,
  });

  double get lineTotal => requestedQuantity * estimatedUnitCost;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_product_id': masterProductId,
      'inventory_item_id': inventoryItemId,
      'product_name': productName,
      'brand': brand,
      'variant': variant,
      'pack_size': packSize,
      'requested_quantity': requestedQuantity,
      'estimated_unit_cost': estimatedUnitCost,
      'is_cost_confirmed': isCostConfirmed ? 1 : 0,
      'status': status,
      'supplier_name': supplierName,
      'notes': notes,
      'image_url': imageUrl,
      'local_image_path': localImagePath,
      'added_at': addedAt,
    };
  }

  factory PurchaseListItem.fromMap(Map<String, dynamic> map) {
    return PurchaseListItem(
      id: map['id'].toString(),
      masterProductId: map['master_product_id']?.toString(),
      inventoryItemId: map['inventory_item_id']?.toString(),
      productName: map['product_name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      variant: map['variant']?.toString(),
      packSize: map['pack_size']?.toString(),
      requestedQuantity: (map['requested_quantity'] as num).toDouble(),
      estimatedUnitCost: (map['estimated_unit_cost'] as num).toDouble(),
      isCostConfirmed: map['is_cost_confirmed'] == 1,
      status: map['status']?.toString() ?? 'pending',
      supplierName: map['supplier_name']?.toString(),
      notes: map['notes']?.toString(),
      imageUrl: map['image_url']?.toString(),
      localImagePath: map['local_image_path']?.toString(),
      addedAt: map['added_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  PurchaseListItem copyWith({
    double? requestedQuantity,
    double? estimatedUnitCost,
    bool? isCostConfirmed,
    String? status,
    String? supplierName,
    String? notes,
  }) {
    return PurchaseListItem(
      id: id,
      masterProductId: masterProductId,
      inventoryItemId: inventoryItemId,
      productName: productName,
      brand: brand,
      variant: variant,
      packSize: packSize,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      estimatedUnitCost: estimatedUnitCost ?? this.estimatedUnitCost,
      isCostConfirmed: isCostConfirmed ?? this.isCostConfirmed,
      status: status ?? this.status,
      supplierName: supplierName ?? this.supplierName,
      notes: notes ?? this.notes,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      addedAt: addedAt,
    );
  }
}
