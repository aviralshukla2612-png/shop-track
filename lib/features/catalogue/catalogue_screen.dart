import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../models/inventory_item.dart';
import '../../models/master_product.dart';
import '../../models/purchase_list_item.dart';
import '../../models/supplier.dart';
import '../../providers/app_providers.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedBrand = 'All';
  String _selectedSource = 'All';
  bool _isGridView = true;

  List<MasterProduct> _products = [];
  int _totalCount = 0;
  bool _isLoading = false;
  int _currentPage = 1;
  int _pageSize = 24;

  int get _totalPages => (_totalCount <= 0) ? 1 : (_totalCount / _pageSize).ceil();

  List<String> _categories = ['All'];
  List<String> _brands = ['All'];
  List<String> _sources = ['All'];
  List<Supplier> _suppliers = [];

  // Bulk selection
  bool _isBulkMode = false;
  final Set<String> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadFiltersAndSuppliers();
    _loadProducts(resetPage: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() {
      _currentPage = page;
    });
    _loadProducts();
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadFiltersAndSuppliers() async {
    final repo = ref.read(masterCatalogueRepoProvider);
    final suppRepo = ref.read(suppliersRepoProvider);

    final cats = await repo.getDistinctCategories();
    final brs = await repo.getDistinctBrands();
    final srcs = await repo.getDistinctSources();
    final sups = await suppRepo.getSuppliers();

    if (mounted) {
      setState(() {
        _categories = ['All', ...cats];
        _brands = ['All', ...brs];
        _sources = ['All', ...srcs];
        _suppliers = sups;
      });
    }
  }

  Future<void> _loadProducts({bool resetPage = false, bool reset = false}) async {
    if (_isLoading) return;
    if (resetPage || reset) {
      _currentPage = 1;
    }
    setState(() => _isLoading = true);

    final repo = ref.read(masterCatalogueRepoProvider);

    final count = await repo.getProductsCount(
      searchQuery: _searchQuery,
      category: _selectedCategory,
      brand: _selectedBrand,
      sourceName: _selectedSource,
    );

    final maxPages = (count <= 0) ? 1 : (count / _pageSize).ceil();
    if (_currentPage > maxPages) {
      _currentPage = maxPages;
    }

    final offset = (_currentPage - 1) * _pageSize;

    final list = await repo.getProducts(
      searchQuery: _searchQuery,
      category: _selectedCategory,
      brand: _selectedBrand,
      sourceName: _selectedSource,
      limit: _pageSize,
      offset: offset,
    );

    if (mounted) {
      setState(() {
        _totalCount = count;
        _products = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Product Catalogue', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: Icon(_isBulkMode ? Icons.check_box : Icons.check_box_outline_blank),
            tooltip: _isBulkMode ? 'Exit Bulk Mode' : 'Bulk Selection Mode',
            onPressed: () {
              setState(() {
                _isBulkMode = !_isBulkMode;
                if (!_isBulkMode) _selectedProductIds.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create Custom Product',
            onPressed: _openCustomProductDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search items by name or brand...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadProducts(resetPage: true);
                        },
                      )
                    : null,
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val.trim());
                _loadProducts(resetPage: true);
              },
            ),
          ),

          // 2. Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildDropdownFilter(
                  label: 'Source',
                  value: _selectedSource,
                  items: _sources,
                  onChanged: (val) {
                    setState(() => _selectedSource = val!);
                    _loadProducts(resetPage: true);
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (val) {
                    setState(() => _selectedCategory = val!);
                    _loadProducts(resetPage: true);
                  },
                ),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  label: 'Brand',
                  value: _selectedBrand,
                  items: _brands,
                  onChanged: (val) {
                    setState(() => _selectedBrand = val!);
                    _loadProducts(resetPage: true);
                  },
                ),
              ],
            ),
          ),

          // Top Loading Line Indicator
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            )
          else
            const SizedBox(height: 3),

          // 3. Stats & Bulk Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _totalCount == 0
                        ? 'No items found'
                        : 'Showing ${((_currentPage - 1) * _pageSize) + 1}–${(_currentPage * _pageSize).clamp(1, _totalCount)} of $_totalCount verified catalogue items',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isBulkMode && _selectedProductIds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: Text('Stock Selected (${_selectedProductIds.length})'),
                    onPressed: _openBulkAddToInventoryDialog,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. Products List / Grid
          Expanded(
            child: Stack(
              children: [
                if (_products.isEmpty)
                  _isLoading
                      ? _buildSkeletonGrid()
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No products matched your search or filter.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        )
                else
                  _isGridView ? _buildGridView() : _buildListView(),

                if (_isLoading && _products.isNotEmpty)
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Loading products...',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Pagination Bar
          _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    if (_totalCount == 0) return const SizedBox.shrink();

    final totalPages = _totalPages;
    final startItem = ((_currentPage - 1) * _pageSize) + 1;
    final endItem = (_currentPage * _pageSize).clamp(1, _totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;

          final pageSizeWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Items per page: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 12, child: Text('12')),
                      DropdownMenuItem(value: 24, child: Text('24')),
                      DropdownMenuItem(value: 48, child: Text('48')),
                      DropdownMenuItem(value: 96, child: Text('96')),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _pageSize) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                        _loadProducts();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$startItem–$endItem of $_totalCount',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          );

          final navWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'First Page',
                onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous Page',
                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              ),
              ..._buildPageNumbers(totalPages),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next Page',
                onPressed: _currentPage < totalPages ? () => _goToPage(_currentPage + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Last Page',
                onPressed: _currentPage < totalPages ? () => _goToPage(totalPages) : null,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                pageSizeWidget,
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: navWidget,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              pageSizeWidget,
              navWidget,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    if (totalPages <= 1) {
      return [
        _buildPageNumberButton(1, isActive: true),
      ];
    }

    final pages = <int?>[];

    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (_currentPage > 3) {
        pages.add(null); // ellipsis
      }

      final start = (_currentPage - 1).clamp(2, totalPages - 1);
      final end = (_currentPage + 1).clamp(2, totalPages - 1);

      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) {
          pages.add(i);
        }
      }

      if (_currentPage < totalPages - 2) {
        pages.add(null); // ellipsis
      }
      if (!pages.contains(totalPages)) {
        pages.add(totalPages);
      }
    }

    return pages.map((p) {
      if (p == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        );
      }
      return _buildPageNumberButton(p, isActive: p == _currentPage);
    }).toList();
  }

  Widget _buildPageNumberButton(int page, {required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: isActive ? null : () => _goToPage(page),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.borderLight,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          items: items.take(50).map((it) {
            return DropdownMenuItem<String>(
              value: it,
              child: Text(it == 'All' ? '$label: All' : it),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 650 ? 3 : 2);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.68,
          ),
          itemCount: _pageSize.clamp(6, 15),
          itemBuilder: (context, idx) {
            return Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(Icons.image_outlined, size: 38, color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(width: 50, height: 10, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Container(width: double.infinity, height: 32, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 650 ? 3 : 2);
        return GridView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.68,
          ),
          itemCount: _products.length,
          itemBuilder: (context, idx) {
            final p = _products[idx];
            return _buildProductCard(p);
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final p = _products[idx];
        return _buildProductListTile(p);
      },
    );
  }

  Widget _buildProductCard(MasterProduct p) {
    final isSelected = _selectedProductIds.contains(p.id);

    return InkWell(
      onTap: () {
        if (_isBulkMode) {
          setState(() {
            if (isSelected) {
              _selectedProductIds.remove(p.id);
            } else {
              _selectedProductIds.add(p.id);
            }
          });
        } else {
          _openProductDetailsSheet(p);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: isSelected ? Colors.teal.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: ProductImageWidget(
                        localImagePath: p.localImagePath,
                        imageUrl: p.imageUrl,
                        category: p.category,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (_isBulkMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedProductIds.add(p.id);
                              } else {
                                _selectedProductIds.remove(p.id);
                              }
                            });
                          },
                        ),
                      ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.sourceName.split(' ').first,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                p.brand,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                p.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p.packSize ?? (p.variant ?? '-'),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  if (p.displayedPrice != null)
                    Text(
                      CurrencyFormatter.format(p.displayedPrice),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    )
                  else
                    const Text('Catalog item', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _addToPurchaseListQuick(p),
                  child: const Text('+ Add to List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductListTile(MasterProduct p) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ProductImageWidget(
          localImagePath: p.localImagePath,
          imageUrl: p.imageUrl,
          category: p.category,
          width: 52,
          height: 52,
        ),
        title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.brand} • ${p.category} • ${p.packSize ?? p.variant ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (p.displayedPrice != null)
              Text('Reference Price: ${CurrencyFormatter.format(p.displayedPrice)} (${p.priceType})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
          ],
        ),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.add, size: 14),
          onPressed: () => _addToPurchaseListQuick(p),
          label: const Text('Add to List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        onTap: () => _openProductDetailsSheet(p),
      ),
    );
  }

  void _openProductDetailsSheet(MasterProduct p) {
    int? selectedPreset = 10;
    if (p.displayedPrice != null) {
      final pVal = p.displayedPrice!.round();
      if ([5, 10, 20, 30].contains(pVal)) {
        selectedPreset = pVal;
      }
    }
    double activePrice = selectedPreset?.toDouble() ?? (p.displayedPrice ?? 10.0);
    int orderQuantity = 10;
    final customPriceCtrl = TextEditingController(text: activePrice.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (context, scrollCtrl) {
                  return SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: ProductImageWidget(
                              localImagePath: p.localImagePath,
                              imageUrl: p.imageUrl,
                              category: p.category,
                              width: 130,
                              height: 130,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.brand.toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentColor, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.category,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),

                        const SizedBox(height: 18),
                        // ── 5 PRICE SELECTOR BUTTONS (₹5, ₹10, ₹20, ₹30, Custom) ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Select Price Pack:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '₹${activePrice.toStringAsFixed(0)} Pack',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ...[5, 10, 20, 30].map((price) {
                                    final isSelected = selectedPreset == price;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            setSheetState(() {
                                              selectedPreset = price;
                                              activePrice = price.toDouble();
                                              customPriceCtrl.text = price.toString();
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppTheme.primaryColor : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                                width: isSelected ? 2 : 1,
                                              ),
                                              boxShadow: isSelected
                                                  ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                                  : null,
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '₹$price',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  price == 5 ? 'Small' : (price == 10 ? 'Standard' : (price == 20 ? 'Large' : 'Jumbo')),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                    color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  // 5th Button: Custom Price
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          setSheetState(() {
                                            selectedPreset = null;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                          decoration: BoxDecoration(
                                            color: selectedPreset == null ? AppTheme.primaryColor : Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selectedPreset == null ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                              width: selectedPreset == null ? 2 : 1,
                                            ),
                                            boxShadow: selectedPreset == null
                                                ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.edit_note, size: 18, color: selectedPreset == null ? Colors.white : AppTheme.textPrimary),
                                              const SizedBox(height: 1),
                                              Text(
                                                'Custom',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: selectedPreset == null ? Colors.white : AppTheme.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // If Custom is selected, show custom price input
                              if (selectedPreset == null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.accentOrange.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.currency_rupee, size: 18, color: AppTheme.primaryColor),
                                      const SizedBox(width: 6),
                                      const Text('Enter Custom MRP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: customPriceCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            hintText: 'e.g. 15',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onChanged: (val) {
                                            final parsed = double.tryParse(val.trim());
                                            if (parsed != null && parsed > 0) {
                                              setSheetState(() {
                                                activePrice = parsed;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),
                              // Order quantity stepper
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Order / Restock Quantity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 16),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: orderQuantity > 1 ? () => setSheetState(() => orderQuantity--) : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$orderQuantity packs',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 16),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => setSheetState(() => orderQuantity++),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Est. Cost: ₹${(activePrice * 0.8 * orderQuantity).toStringAsFixed(0)} (20% margin)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'Retail Total: ₹${(activePrice * orderQuantity).toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Text('Product Provenance & Specifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _detailRow('Source Catalogue', p.sourceName),
                        if (p.sourceDocument != null) _detailRow('Source Reference', p.sourceDocument!),
                        if (p.sourcePage != null) _detailRow('Catalogue Page', 'Page ${p.sourcePage}'),
                        if (p.barcode != null) _detailRow('Barcode / GTIN', p.barcode!),
                        _detailRow('Selected Pack MRP', CurrencyFormatter.format(activePrice)),
                        _detailRow('Wholesale Cost Est.', CurrencyFormatter.format(activePrice * 0.8)),
                        _detailRow('Verification Status', p.verificationStatus.toUpperCase()),
                        const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.playlist_add_rounded, size: 20),
                          label: Text('Add $orderQuantity x ₹${activePrice.toStringAsFixed(0)} to Wholesale List', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          onPressed: () {
                            Navigator.pop(context);
                            _addToPurchaseListWithPrice(p, activePrice, orderQuantity);
                          },
                        ),
                      ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _openAddToInventoryDialog(MasterProduct p, {double? packPrice, int? initialQty}) {
    int? selectedPreset = (packPrice != null && [5, 10, 20, 30].contains(packPrice.round()))
        ? packPrice.round()
        : (p.displayedPrice != null && [5, 10, 20, 30].contains(p.displayedPrice!.round()) ? p.displayedPrice!.round() : 10);

    double activeSellPrice = packPrice ?? selectedPreset?.toDouble() ?? (p.displayedPrice ?? 10.0);
    double activeCostPrice = activeSellPrice * 0.8;

    final costCtrl = TextEditingController(text: activeCostPrice.toStringAsFixed(2));
    final sellCtrl = TextEditingController(text: activeSellPrice.toStringAsFixed(2));
    final customPriceCtrl = TextEditingController(text: selectedPreset == null ? activeSellPrice.toStringAsFixed(0) : '');
    final stockCtrl = TextEditingController(text: (initialQty ?? 20).toString());
    final minStockCtrl = TextEditingController(text: '5');

    String? selectedSupplier = _suppliers.isNotEmpty ? _suppliers.first.name : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final curSell = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
            final curCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final curStock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
            final curMargin = curSell - curCost;
            final curMarginPct = curSell > 0 ? (curMargin / curSell) * 100 : 0.0;
            final totalBatchProfit = curMargin * curStock;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER WITH PRODUCT THUMBNAIL & CLOSE ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ProductImageWidget(
                              localImagePath: p.localImagePath,
                              imageUrl: p.imageUrl,
                              category: p.category,
                              width: 42,
                              height: 42,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        p.brand.toUpperCase(),
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.accentColor, letterSpacing: 0.4),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 10, color: Color(0xFF059669)),
                                          SizedBox(width: 2),
                                          Text('Verified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Category: ${p.category}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 14),

                      // ── 5 PRICE SELECTOR BUTTONS (₹5, ₹10, ₹20, ₹30, Custom) ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Select Standard Pack Price:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedPreset != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₹$selectedPreset Tier',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...[5, 10, 20, 30].map((pr) {
                            final isSel = selectedPreset == pr;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setDialogState(() {
                                      selectedPreset = pr;
                                      sellCtrl.text = pr.toStringAsFixed(2);
                                      costCtrl.text = (pr * 0.8).toStringAsFixed(2);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isSel ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                        width: isSel ? 1.8 : 1,
                                      ),
                                      boxShadow: isSel
                                          ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.28), blurRadius: 4, offset: const Offset(0, 1))]
                                          : null,
                                    ),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '₹$pr',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          // 5th Button: Custom Price
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setDialogState(() {
                                    selectedPreset = null;
                                    if (customPriceCtrl.text.isNotEmpty) {
                                      final cp = double.tryParse(customPriceCtrl.text) ?? 15.0;
                                      sellCtrl.text = cp.toStringAsFixed(2);
                                      costCtrl.text = (cp * 0.8).toStringAsFixed(2);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedPreset == null ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedPreset == null ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                      width: selectedPreset == null ? 1.8 : 1,
                                    ),
                                    boxShadow: selectedPreset == null
                                        ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.28), blurRadius: 4, offset: const Offset(0, 1))]
                                        : null,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit, size: 11, color: selectedPreset == null ? Colors.white : const Color(0xFF64748B)),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Custom',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: selectedPreset == null ? Colors.white : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // If Custom is selected, show custom price input box
                      if (selectedPreset == null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.currency_rupee, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              const Text('Custom MRP:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: customPriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 15, 25, 45, 50',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    fillColor: Colors.white,
                                    filled: true,
                                  ),
                                  onChanged: (val) {
                                    final s = double.tryParse(val.trim()) ?? 0.0;
                                    if (s > 0) {
                                      sellCtrl.text = s.toStringAsFixed(2);
                                      costCtrl.text = (s * 0.8).toStringAsFixed(2);
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── PURCHASE COST & SELLING PRICE INPUTS ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Purchase Cost (₹)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: costCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selling Price (₹)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: sellCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  onChanged: (val) {
                                    if (selectedPreset == null) {
                                      final s = double.tryParse(val) ?? 0.0;
                                      if (s > 0) {
                                        costCtrl.text = (s * 0.8).toStringAsFixed(2);
                                      }
                                    }
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── LIVE PROFIT MARGIN PILL ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: curMargin >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: curMargin >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    curMargin >= 0 ? Icons.trending_up : Icons.trending_down,
                                    size: 15,
                                    color: curMargin >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Profit: ₹${curMargin.toStringAsFixed(2)} / pack',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: curMargin >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: curMargin >= 0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${curMarginPct.toStringAsFixed(1)}% Margin',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: curMargin >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── OPENING STOCK & MIN ALERT LEVEL ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Opening Stock (Qty)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: stockCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    suffixText: 'packs',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Min Alert Level', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: minStockCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    suffixText: 'units',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── PREFERRED SUPPLIER ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Preferred Supplier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: selectedSupplier,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              prefixIcon: Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF64748B)),
                            ),
                            items: _suppliers
                                .map((s) => DropdownMenuItem(
                                      value: s.name,
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) => setDialogState(() => selectedSupplier = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── ACTION BUTTONS ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Save to Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              onPressed: () async {
                                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                                final sell = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
                                final stock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                                final minStock = double.tryParse(minStockCtrl.text.trim()) ?? 5.0;

                                if (sell <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid selling price.')));
                                  return;
                                }

                                final packLabel = selectedPreset != null ? '₹$selectedPreset Pack' : '₹${sell.toStringAsFixed(0)} Pack';

                                final item = InventoryItem(
                                  id: const Uuid().v4(),
                                  masterProductId: p.id,
                                  name: '${p.name} ($packLabel)',
                                  brand: p.brand,
                                  category: p.category,
                                  subcategory: p.subcategory,
                                  packSize: packLabel,
                                  barcode: p.barcode,
                                  purchasePrice: cost,
                                  sellingPrice: sell,
                                  currentStock: stock,
                                  minStockLevel: minStock,
                                  preferredSupplierName: selectedSupplier,
                                  isTobacco: false,
                                  unitsPerPack: 1,
                                  imageUrl: p.imageUrl,
                                  localImagePath: p.localImagePath,
                                  updatedAt: DateTime.now().toIso8601String(),
                                );

                                await ref.read(inventoryRepoProvider).upsertItem(item);
                                ref.invalidate(inventoryListProvider);
                                ref.invalidate(dashboardMetricsProvider);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${item.name} to shop inventory!')));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addToPurchaseListWithPrice(MasterProduct p, double packPrice, int qty) async {
    final cost = packPrice * 0.8;
    final priceLabel = '₹${packPrice.toStringAsFixed(0)} Pack';
    final fullName = '${p.name} ($priceLabel)';
    
    final currentList = ref.read(purchaseListProvider).value ?? [];
    final existingIdx = currentList.indexWhere((it) => it.productName == fullName || (it.masterProductId == p.id && it.variant == priceLabel));
    
    if (existingIdx >= 0) {
      final existing = currentList[existingIdx];
      await ref.read(purchaseListProvider.notifier).updateItem(
        existing.copyWith(requestedQuantity: existing.requestedQuantity + qty),
      );
    } else {
      final item = PurchaseListItem(
        id: const Uuid().v4(),
        masterProductId: p.id,
        productName: fullName,
        brand: p.brand,
        variant: priceLabel,
        packSize: priceLabel,
        requestedQuantity: qty.toDouble(),
        estimatedUnitCost: cost,
        isCostConfirmed: false,
        status: 'pending',
        imageUrl: p.imageUrl,
        localImagePath: p.localImagePath,
        addedAt: DateTime.now().toIso8601String(),
      );
      await ref.read(purchaseListProvider.notifier).addItem(item);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $qty x ${p.name} ($priceLabel) to Wholesale List!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _addToPurchaseListQuick(MasterProduct p) async {
    final packPrice = (p.displayedPrice != null ? p.displayedPrice!.toDouble() : 10.0);
    _addToPurchaseListWithPrice(p, packPrice, 10);
  }



  void _openBulkAddToInventoryDialog() {
    // Bulk stock selected products
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Stock ${_selectedProductIds.length} Products in Inventory'),
          content: const Text('All selected products will be added to your shop inventory with verified prices and default opening stock of 10 units each.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                for (final id in _selectedProductIds) {
                  final p = await ref.read(masterCatalogueRepoProvider).getProductById(id);
                  if (p != null) {
                    final cost = p.displayedPrice != null ? (p.displayedPrice! * 0.8) : 20.0;
                    final sell = p.displayedPrice ?? (cost * 1.25);
                    final isTobacco = p.category.toLowerCase().contains('tobacco') || p.category.toLowerCase().contains('pan masala');

                    final item = InventoryItem(
                      id: const Uuid().v4(),
                      masterProductId: p.id,
                      name: p.name,
                      brand: p.brand,
                      category: p.category,
                      subcategory: p.subcategory,
                      packSize: p.packSize ?? p.variant,
                      barcode: p.barcode,
                      purchasePrice: cost,
                      sellingPrice: sell,
                      currentStock: 10.0,
                      minStockLevel: 5.0,
                      isTobacco: isTobacco,
                      imageUrl: p.imageUrl,
                      localImagePath: p.localImagePath,
                      updatedAt: DateTime.now().toIso8601String(),
                    );
                    await ref.read(inventoryRepoProvider).upsertItem(item);
                  }
                }
                setState(() {
                  _selectedProductIds.clear();
                  _isBulkMode = false;
                });
                ref.invalidate(inventoryListProvider);
                ref.invalidate(dashboardMetricsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected products added to inventory successfully!')));
                }
              },
              child: const Text('Add All to Inventory'),
            ),
          ],
        );
      },
    );
  }

  void _openCustomProductDialog() {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');
    final packCtrl = TextEditingController(text: 'Standard');
    int? selectedPreset = 10;
    final costCtrl = TextEditingController(text: '8.00');
    final sellCtrl = TextEditingController(text: '10.00');
    final stockCtrl = TextEditingController(text: '10');
    final minStockCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final curSell = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
            final curCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final curMargin = curSell - curCost;
            final curMarginPct = curSell > 0 ? (curMargin / curSell) * 100 : 0.0;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_business_outlined, color: AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create Custom Product',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Add a non-catalogue item to inventory',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 14),

                      // ── PRODUCT NAME ──
                      const Text('Product Name*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Masala Chips, Wheat Bread',
                          prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF64748B)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── BRAND & CATEGORY ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Brand*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: brandCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Local / Store',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: catCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Namkeen, Bakery',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── PACK SIZE ──
                      const Text('Pack Size / Weight', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: packCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 100g, 250g, 1 Packet',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── PRICE PACK PRESETS (5 BUTTONS) ──
                      const Text('Select Standard Pack Price:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...[5, 10, 20, 30].map((pr) {
                            final isSel = selectedPreset == pr;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setDialogState(() {
                                      selectedPreset = pr;
                                      sellCtrl.text = pr.toStringAsFixed(2);
                                      costCtrl.text = (pr * 0.8).toStringAsFixed(2);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSel ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                        width: isSel ? 1.8 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '₹$pr',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setDialogState(() {
                                    selectedPreset = null;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedPreset == null ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedPreset == null ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                      width: selectedPreset == null ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Custom',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: selectedPreset == null ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── COST PRICE & SELLING PRICE ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cost Price (₹)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: costCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selling Price (₹)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: sellCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  onChanged: (val) {
                                    if (selectedPreset == null) {
                                      final s = double.tryParse(val) ?? 0.0;
                                      if (s > 0) {
                                        costCtrl.text = (s * 0.8).toStringAsFixed(2);
                                      }
                                    }
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── PROFIT MARGIN PILL ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: curMargin >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: curMargin >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Profit: ₹${curMargin.toStringAsFixed(2)} / unit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: curMargin >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              ),
                            ),
                            Text(
                              '${curMarginPct.toStringAsFixed(1)}% Margin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: curMargin >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── OPENING STOCK & MIN ALERT ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Opening Stock (Qty)*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: stockCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    suffixText: 'units',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Min Stock Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: minStockCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    suffixText: 'units',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── ACTION BUTTONS ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Save Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                final brand = brandCtrl.text.trim();
                                final sell = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
                                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                                final stock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                                final minStock = double.tryParse(minStockCtrl.text.trim()) ?? 5.0;

                                if (name.isEmpty || brand.isEmpty || sell <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                                  return;
                                }

                                final item = InventoryItem(
                                  id: const Uuid().v4(),
                                  name: name,
                                  brand: brand,
                                  category: catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'General',
                                  packSize: packCtrl.text.trim().isNotEmpty ? packCtrl.text.trim() : 'Standard',
                                  purchasePrice: cost,
                                  sellingPrice: sell,
                                  currentStock: stock,
                                  minStockLevel: minStock,
                                  isTobacco: false,
                                  unitsPerPack: 1,
                                  updatedAt: DateTime.now().toIso8601String(),
                                );

                                await ref.read(inventoryRepoProvider).upsertItem(item);
                                ref.invalidate(inventoryListProvider);
                                ref.invalidate(dashboardMetricsProvider);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created custom product: $name!')));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
