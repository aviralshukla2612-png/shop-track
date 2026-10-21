class MasterProduct {
  final String id;
  final String? sourceId;
  final String name;
  final String brand;
  final String? manufacturer;
  final String category;
  final String? subcategory;
  final String? variant;
  final String? flavour;
  final String? netWeight;
  final String? netVolume;
  final String? packSize;
  final int? unitsPerCarton;
  final String? barcode;
  final double? mrp;
  final double? displayedPrice;
  final String currency;
  final String priceType;
  final String? productUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? localImagePath;
  final String sourceName;
  final String? sourceDocument;
  final int? sourcePage;
  final String? attribution;
  final String verificationStatus;
  final String? lastVerifiedAt;

  MasterProduct({
    required this.id,
    this.sourceId,
    required this.name,
    required this.brand,
    this.manufacturer,
    required this.category,
    this.subcategory,
    this.variant,
    this.flavour,
    this.netWeight,
    this.netVolume,
    this.packSize,
    this.unitsPerCarton,
    this.barcode,
    this.mrp,
    this.displayedPrice,
    this.currency = 'INR',
    this.priceType = 'standard',
    this.productUrl,
    this.imageUrl,
    this.imageUrls = const [],
    this.localImagePath,
    required this.sourceName,
    this.sourceDocument,
    this.sourcePage,
    this.attribution,
    this.verificationStatus = 'verified',
    this.lastVerifiedAt,
  });

  factory MasterProduct.fromJson(Map<String, dynamic> json) {
    List<String> imgs = [];
    if (json['image_urls'] is List) {
      imgs = (json['image_urls'] as List).map((e) => e.toString()).toList();
    }
    return MasterProduct(
      id: json['id']?.toString() ?? '',
      sourceId: json['source_id']?.toString(),
      name: json['name']?.toString() ?? 'Unnamed Product',
      brand: json['brand']?.toString() ?? 'Unknown Brand',
      manufacturer: json['manufacturer']?.toString(),
      category: json['category']?.toString() ?? 'General',
      subcategory: json['subcategory']?.toString(),
      variant: json['variant']?.toString(),
      flavour: json['flavour']?.toString(),
      netWeight: json['net_weight']?.toString(),
      netVolume: json['net_volume']?.toString(),
      packSize: json['pack_size']?.toString(),
      unitsPerCarton: json['units_per_carton'] is int ? json['units_per_carton'] : null,
      barcode: json['barcode']?.toString(),
      mrp: json['mrp'] != null ? double.tryParse(json['mrp'].toString()) : null,
      displayedPrice: json['displayed_price'] != null ? double.tryParse(json['displayed_price'].toString()) : null,
      currency: json['currency']?.toString() ?? 'INR',
      priceType: json['price_type']?.toString() ?? 'standard',
      productUrl: json['product_url']?.toString(),
      imageUrl: json['image_url']?.toString(),
      imageUrls: imgs,
      localImagePath: json['local_image_path']?.toString(),
      sourceName: json['source_name']?.toString() ?? 'Unknown',
      sourceDocument: json['source_document']?.toString(),
      sourcePage: json['source_page'] is int ? json['source_page'] : int.tryParse(json['source_page']?.toString() ?? ''),
      attribution: json['attribution']?.toString(),
      verificationStatus: json['verification_status']?.toString() ?? 'verified',
      lastVerifiedAt: json['last_verified_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'brand': brand,
      'manufacturer': manufacturer,
      'category': category,
      'subcategory': subcategory,
      'variant': variant,
      'flavour': flavour,
      'net_weight': netWeight,
      'net_volume': netVolume,
      'pack_size': packSize,
      'units_per_carton': unitsPerCarton,
      'barcode': barcode,
      'mrp': mrp,
      'displayed_price': displayedPrice,
      'currency': currency,
      'price_type': priceType,
      'product_url': productUrl,
      'image_url': imageUrl,
      'image_urls': imageUrls.join(','),
      'local_image_path': localImagePath,
      'source_name': sourceName,
      'source_document': sourceDocument,
      'source_page': sourcePage,
      'attribution': attribution,
      'verification_status': verificationStatus,
      'last_verified_at': lastVerifiedAt,
    };
  }

  factory MasterProduct.fromDbMap(Map<String, dynamic> map) {
    List<String> imgs = [];
    if (map['image_urls'] != null && map['image_urls'].toString().isNotEmpty) {
      imgs = map['image_urls'].toString().split(',');
    }
    return MasterProduct(
      id: map['id'].toString(),
      sourceId: map['source_id']?.toString(),
      name: map['name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      manufacturer: map['manufacturer']?.toString(),
      category: map['category']?.toString() ?? '',
      subcategory: map['subcategory']?.toString(),
      variant: map['variant']?.toString(),
      flavour: map['flavour']?.toString(),
      netWeight: map['net_weight']?.toString(),
      netVolume: map['net_volume']?.toString(),
      packSize: map['pack_size']?.toString(),
      unitsPerCarton: map['units_per_carton'] as int?,
      barcode: map['barcode']?.toString(),
      mrp: map['mrp'] != null ? (map['mrp'] as num).toDouble() : null,
      displayedPrice: map['displayed_price'] != null ? (map['displayed_price'] as num).toDouble() : null,
      currency: map['currency']?.toString() ?? 'INR',
      priceType: map['price_type']?.toString() ?? 'standard',
      productUrl: map['product_url']?.toString(),
      imageUrl: map['image_url']?.toString(),
      imageUrls: imgs,
      localImagePath: map['local_image_path']?.toString(),
      sourceName: map['source_name']?.toString() ?? '',
      sourceDocument: map['source_document']?.toString(),
      sourcePage: map['source_page'] as int?,
      attribution: map['attribution']?.toString(),
      verificationStatus: map['verification_status']?.toString() ?? 'verified',
      lastVerifiedAt: map['last_verified_at']?.toString(),
    );
  }
}
