import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class ShopProfile {
  final String shopName;
  final String shopOwner;
  final String address;
  final String gstin;
  final String phone;
  final bool isConfigured;

  const ShopProfile({
    this.shopName = '',
    this.shopOwner = '',
    this.address = '',
    this.gstin = '',
    this.phone = '',
    this.isConfigured = false,
  });

  ShopProfile copyWith({
    String? shopName,
    String? shopOwner,
    String? address,
    String? gstin,
    String? phone,
    bool? isConfigured,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      shopOwner: shopOwner ?? this.shopOwner,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      phone: phone ?? this.phone,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<ShopProfile> getShopProfile() async {
    final db = await _db.database;
    final results = await db.query('app_settings');
    final map = <String, String>{};
    for (final row in results) {
      final k = row['key'] as String?;
      final v = row['value'] as String?;
      if (k != null && v != null) {
        map[k] = v;
      }
    }

    final shopName = map['shop_name'] ?? '';
    final shopOwner = map['shop_owner'] ?? '';
    final address = map['address'] ?? '';
    final gstin = map['gstin'] ?? '';
    final phone = map['phone'] ?? '';
    final isOnboarded = map['is_onboarded'] == 'true' || shopName.isNotEmpty;

    return ShopProfile(
      shopName: shopName,
      shopOwner: shopOwner,
      address: address,
      gstin: gstin,
      phone: phone,
      isConfigured: isOnboarded && shopName.isNotEmpty,
    );
  }

  Future<void> saveShopProfile(ShopProfile profile) async {
    final db = await _db.database;
    final batch = db.batch();

    void put(String key, String value) {
      batch.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    put('shop_name', profile.shopName);
    put('shop_owner', profile.shopOwner);
    put('address', profile.address);
    put('gstin', profile.gstin);
    put('phone', profile.phone);
    put('is_onboarded', 'true');

    await batch.commit(noResult: true);
  }

  Future<bool> isOnboarded() async {
    final profile = await getShopProfile();
    return profile.isConfigured;
  }

  Future<void> clearProfile() async {
    final db = await _db.database;
    await db.delete('app_settings');
  }
}
