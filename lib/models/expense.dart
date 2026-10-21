class Expense {
  final String id;
  final String category; // 'Shop Rent', 'Electricity & Utilities', 'Staff Wages', 'Tea & Refreshments', 'Packaging & Bags', 'Transport & Freight', 'Miscellaneous'
  final String title;
  final double amount;
  final String paymentMode; // 'Cash', 'UPI', 'Bank Transfer'
  final String expenseDate;
  final String? notes;

  Expense({
    required this.id,
    required this.category,
    required this.title,
    required this.amount,
    this.paymentMode = 'Cash',
    required this.expenseDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'amount': amount,
      'payment_mode': paymentMode,
      'expense_date': expenseDate,
      'notes': notes,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'].toString(),
      category: map['category']?.toString() ?? 'Miscellaneous',
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] as num).toDouble(),
      paymentMode: map['payment_mode']?.toString() ?? 'Cash',
      expenseDate: map['expense_date']?.toString() ?? DateTime.now().toIso8601String(),
      notes: map['notes']?.toString(),
    );
  }
}

class StockAdjustment {
  final String id;
  final String inventoryItemId;
  final String productName;
  final double quantityChange; // negative for damages/loss, positive for audit recovery
  final String reason;         // 'Damaged Stock', 'Expired Stock', 'Theft / Missing', 'Inventory Audit Count Correction', 'Return to Supplier'
  final double costLoss;       // quantityChange * purchasePrice
  final String adjustedAt;
  final String? notes;

  StockAdjustment({
    required this.id,
    required this.inventoryItemId,
    required this.productName,
    required this.quantityChange,
    required this.reason,
    required this.costLoss,
    required this.adjustedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventory_item_id': inventoryItemId,
      'product_name': productName,
      'quantity_change': quantityChange,
      'reason': reason,
      'cost_loss': costLoss,
      'adjusted_at': adjustedAt,
      'notes': notes,
    };
  }

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'].toString(),
      inventoryItemId: map['inventory_item_id'].toString(),
      productName: map['product_name']?.toString() ?? '',
      quantityChange: (map['quantity_change'] as num).toDouble(),
      reason: map['reason']?.toString() ?? 'Stock Correction',
      costLoss: (map['cost_loss'] as num).toDouble(),
      adjustedAt: map['adjusted_at']?.toString() ?? DateTime.now().toIso8601String(),
      notes: map['notes']?.toString(),
    );
  }
}
