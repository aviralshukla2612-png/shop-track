import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/inventory_item.dart';
import '../models/purchase_list_item.dart';
import '../repositories/expenses_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/master_catalogue_repository.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/reports_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/suppliers_repository.dart';

export '../repositories/settings_repository.dart' show ShopProfile;

// Repositories
final masterCatalogueRepoProvider = Provider((ref) => MasterCatalogueRepository());
final inventoryRepoProvider = Provider((ref) => InventoryRepository());
final salesRepoProvider = Provider((ref) => SalesRepository());
final purchasesRepoProvider = Provider((ref) => PurchasesRepository());
final suppliersRepoProvider = Provider((ref) => SuppliersRepository());
final expensesRepoProvider = Provider((ref) => ExpensesRepository());
final reportsRepoProvider = Provider((ref) => ReportsRepository());
final settingsRepoProvider = Provider((ref) => SettingsRepository());

// Dashboard Metrics Provider
final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final repo = ref.watch(salesRepoProvider);
  return repo.getDashboardMetrics();
});

// Daily Sales Chart Provider
final dailySalesChartProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(salesRepoProvider);
  return repo.getDailySalesChartData(days: 7);
});

// Top Products Filter State & Provider
class TopProductsFilter {
  final String period; // 'Today', '7 Days', '30 Days', 'All Time'
  final String sortBy; // 'revenue', 'quantity', 'profit'

  const TopProductsFilter({
    this.period = '7 Days',
    this.sortBy = 'revenue',
  });

  TopProductsFilter copyWith({String? period, String? sortBy}) {
    return TopProductsFilter(
      period: period ?? this.period,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

final topProductsFilterProvider = StateProvider<TopProductsFilter>((ref) => const TopProductsFilter());

// Top Selling Products Provider
final topSellingProductsProvider = FutureProvider.autoDispose<List<TopProductMetric>>((ref) async {
  final repo = ref.watch(salesRepoProvider);
  final filter = ref.watch(topProductsFilterProvider);
  return repo.getTopSellingProducts(
    limit: 5,
    period: filter.period,
    sortBy: filter.sortBy,
  );
});

// Dynamic SQLite-Persistent Shop Profile State & Provider
class ShopProfileNotifier extends StateNotifier<ShopProfile> {
  final SettingsRepository _repo;

  ShopProfileNotifier(this._repo) : super(const ShopProfile()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final profile = await _repo.getShopProfile();
    state = profile;
  }

  Future<void> updateProfile(ShopProfile profile) async {
    await _repo.saveShopProfile(profile);
    state = profile;
  }

  Future<void> clearProfile() async {
    await _repo.clearProfile();
    state = const ShopProfile();
  }
}

final shopProfileProvider = StateNotifierProvider<ShopProfileNotifier, ShopProfile>((ref) {
  final repo = ref.watch(settingsRepoProvider);
  return ShopProfileNotifier(repo);
});

// Inventory List Filter State
class InventoryFilterState {
  final String query;
  final String category;
  final bool lowStockOnly;

  const InventoryFilterState({
    this.query = '',
    this.category = 'All',
    this.lowStockOnly = false,
  });

  InventoryFilterState copyWith({
    String? query,
    String? category,
    bool? lowStockOnly,
  }) {
    return InventoryFilterState(
      query: query ?? this.query,
      category: category ?? this.category,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }
}

final inventoryFilterProvider = StateProvider<InventoryFilterState>((ref) => const InventoryFilterState());

final inventoryListProvider = FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final repo = ref.watch(inventoryRepoProvider);
  final filter = ref.watch(inventoryFilterProvider);
  return repo.getItems(
    query: filter.query,
    category: filter.category,
    lowStockOnly: filter.lowStockOnly,
  );
});

final inventoryValuationProvider = FutureProvider.autoDispose<InventoryValuationSummary>((ref) async {
  final repo = ref.watch(inventoryRepoProvider);
  return repo.getInventoryValuation();
});

// POS Cart Management
class CartItem {
  final InventoryItem item;
  final double quantity;
  final double customPrice;
  final double discount;
  final bool isLooseStick;

  CartItem({
    required this.item,
    required this.quantity,
    required this.customPrice,
    this.discount = 0.0,
    this.isLooseStick = false,
  });

  double get unitSellingPrice => isLooseStick ? (item.looseSellingPrice ?? (item.sellingPrice / item.unitsPerPack)) : customPrice;
  double get lineTotal => (unitSellingPrice * quantity) - discount;
  double get unitCostBasis => isLooseStick ? (item.purchasePrice / item.unitsPerPack) : item.purchasePrice;
  double get lineCost => unitCostBasis * quantity;
  double get lineProfit => lineTotal - lineCost;

  CartItem copyWith({
    double? quantity,
    double? customPrice,
    double? discount,
    bool? isLooseStick,
  }) {
    return CartItem(
      item: item,
      quantity: quantity ?? this.quantity,
      customPrice: customPrice ?? this.customPrice,
      discount: discount ?? this.discount,
      isLooseStick: isLooseStick ?? this.isLooseStick,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(InventoryItem item, {bool isLooseStick = false}) {
    final idx = state.indexWhere((c) => c.item.id == item.id && c.isLooseStick == isLooseStick);
    if (idx >= 0) {
      final existing = state[idx];
      final updated = existing.copyWith(quantity: existing.quantity + 1);
      final list = [...state];
      list[idx] = updated;
      state = list;
    } else {
      final initialPrice = isLooseStick ? (item.looseSellingPrice ?? (item.sellingPrice / item.unitsPerPack)) : item.sellingPrice;
      state = [
        ...state,
        CartItem(
          item: item,
          quantity: 1,
          customPrice: initialPrice,
          isLooseStick: isLooseStick,
        ),
      ];
    }
  }

  void updateQuantity(int index, double quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final list = [...state];
    list[index] = list[index].copyWith(quantity: quantity);
    state = list;
  }

  void updateDiscount(int index, double discount) {
    final list = [...state];
    list[index] = list[index].copyWith(discount: discount.clamp(0.0, list[index].lineTotal));
    state = list;
  }

  void updateCustomPrice(int index, double price) {
    final list = [...state];
    list[index] = list[index].copyWith(customPrice: price);
    state = list;
  }

  void removeItem(int index) {
    final list = [...state];
    list.removeAt(index);
    state = list;
  }

  void clear() {
    state = [];
  }

  double get subtotal => state.fold(0.0, (acc, c) => acc + (c.unitSellingPrice * c.quantity));
  double get totalDiscount => state.fold(0.0, (acc, c) => acc + c.discount);
  double get grandTotal => subtotal - totalDiscount;
  double get totalCostBasis => state.fold(0.0, (acc, c) => acc + c.lineCost);
  double get grossProfit => grandTotal - totalCostBasis;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

// Purchase List Provider
class PurchaseListNotifier extends StateNotifier<AsyncValue<List<PurchaseListItem>>> {
  final PurchasesRepository _repo;
  PurchaseListNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final items = await _repo.getPurchaseList();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(PurchaseListItem item) async {
    await _repo.addToPurchaseList(item);
    await load();
  }

  Future<void> updateItem(PurchaseListItem item) async {
    await _repo.updatePurchaseListItem(item);
    await load();
  }

  Future<void> removeItem(String id) async {
    await _repo.removePurchaseListItem(id);
    await load();
  }

  Future<void> clearAll() async {
    await _repo.clearPurchaseList();
    await load();
  }

  Future<void> convertReceived({required List<PurchaseListItem> items, required String supplierName}) async {
    await _repo.convertReceivedToInventory(itemsToReceive: items, supplierName: supplierName);
    await load();
  }
}

final purchaseListProvider = StateNotifierProvider<PurchaseListNotifier, AsyncValue<List<PurchaseListItem>>>((ref) {
  final repo = ref.watch(purchasesRepoProvider);
  return PurchaseListNotifier(repo);
});
