class SaleItem {
  final String id;
  final String saleId;
  final String inventoryItemId;
  final String productName;
  final String? variant;
  final double quantity;
  final double unitSellingPrice;
  final double unitCostBasis; // Exact cost basis for accurate COGS
  final double discount;
  final double lineTotal;
  final double lineProfit;
  final bool isLooseStick;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.inventoryItemId,
    required this.productName,
    this.variant,
    required this.quantity,
    required this.unitSellingPrice,
    required this.unitCostBasis,
    this.discount = 0.0,
    required this.lineTotal,
    required this.lineProfit,
    this.isLooseStick = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'inventory_item_id': inventoryItemId,
      'product_name': productName,
      'variant': variant,
      'quantity': quantity,
      'unit_selling_price': unitSellingPrice,
      'unit_cost_basis': unitCostBasis,
      'discount': discount,
      'line_total': lineTotal,
      'line_profit': lineProfit,
      'is_loose_stick': isLooseStick ? 1 : 0,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'].toString(),
      saleId: map['sale_id'].toString(),
      inventoryItemId: map['inventory_item_id'].toString(),
      productName: map['product_name']?.toString() ?? '',
      variant: map['variant']?.toString(),
      quantity: (map['quantity'] as num).toDouble(),
      unitSellingPrice: (map['unit_selling_price'] as num).toDouble(),
      unitCostBasis: (map['unit_cost_basis'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (map['line_total'] as num).toDouble(),
      lineProfit: (map['line_profit'] as num).toDouble(),
      isLooseStick: map['is_loose_stick'] == 1,
    );
  }
}

class SaleTransaction {
  final String id;
  final String invoiceNumber;
  final String createdAt;
  final String? customerName;
  final String? customerPhone;
  final String paymentMethod; // Cash, UPI, Credit, Card
  final double subtotal;
  final double discount;
  final double grandTotal;
  final double totalCostBasis; // COGS
  final double grossProfit;    // grandTotal - totalCostBasis
  final String status;         // completed, returned, voided
  final String? notes;
  final List<SaleItem> items;

  SaleTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    required this.paymentMethod,
    required this.subtotal,
    this.discount = 0.0,
    required this.grandTotal,
    required this.totalCostBasis,
    required this.grossProfit,
    this.status = 'completed',
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'created_at': createdAt,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'discount': discount,
      'grand_total': grandTotal,
      'total_cost_basis': totalCostBasis,
      'gross_profit': grossProfit,
      'status': status,
      'notes': notes,
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) {
    return SaleTransaction(
      id: map['id'].toString(),
      invoiceNumber: map['invoice_number'].toString(),
      createdAt: map['created_at'].toString(),
      customerName: map['customer_name']?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      paymentMethod: map['payment_method']?.toString() ?? 'Cash',
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num).toDouble(),
      totalCostBasis: (map['total_cost_basis'] as num).toDouble(),
      grossProfit: (map['gross_profit'] as num).toDouble(),
      status: map['status']?.toString() ?? 'completed',
      notes: map['notes']?.toString(),
      items: items,
    );
  }
}
