class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final double currentBalance; // Payables
  final String createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.currentBalance = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gst_number': gstNumber,
      'current_balance': currentBalance,
      'created_at': createdAt,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      gstNumber: map['gst_number']?.toString(),
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
