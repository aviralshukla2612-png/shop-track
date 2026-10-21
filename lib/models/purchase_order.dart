class PurchaseItem {
  final String id;
  final String purchaseId;
  final String? inventoryItemId;
  final String productName;
  final String? variant;
  final double quantity;
  final double unitCost;
  final double lineTotal;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    this.inventoryItemId,
    required this.productName,
    this.variant,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'inventory_item_id': inventoryItemId,
      'product_name': productName,
      'variant': variant,
      'quantity': quantity,
      'unit_cost': unitCost,
      'line_total': lineTotal,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'].toString(),
      purchaseId: map['purchase_id'].toString(),
      inventoryItemId: map['inventory_item_id']?.toString(),
      productName: map['product_name']?.toString() ?? '',
      variant: map['variant']?.toString(),
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      lineTotal: (map['line_total'] as num).toDouble(),
    );
  }
}

class PurchaseOrder {
  final String id;
  final String orderNumber;
  final String? supplierId;
  final String supplierName;
  final String createdAt;
  final String? receivedAt;
  final double totalAmount;
  final String status; // 'draft', 'ordered', 'received', 'cancelled'
  final String? invoiceRef;
  final String? notes;
  final List<PurchaseItem> items;

  PurchaseOrder({
    required this.id,
    required this.orderNumber,
    this.supplierId,
    required this.supplierName,
    required this.createdAt,
    this.receivedAt,
    required this.totalAmount,
    this.status = 'received',
    this.invoiceRef,
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'created_at': createdAt,
      'received_at': receivedAt,
      'total_amount': totalAmount,
      'status': status,
      'invoice_ref': invoiceRef,
      'notes': notes,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return PurchaseOrder(
      id: map['id'].toString(),
      orderNumber: map['order_number'].toString(),
      supplierId: map['supplier_id']?.toString(),
      supplierName: map['supplier_name']?.toString() ?? 'Wholesale Vendor',
      createdAt: map['created_at'].toString(),
      receivedAt: map['received_at']?.toString(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status']?.toString() ?? 'received',
      invoiceRef: map['invoice_ref']?.toString(),
      notes: map['notes']?.toString(),
      items: items,
    );
  }
}
