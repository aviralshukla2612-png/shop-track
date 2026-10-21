import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../models/inventory_item.dart';
import '../../models/sale_transaction.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_service.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _posSearchCtrl = TextEditingController();
  String _posSearchQuery = '';

  // Checkout inputs
  String _paymentMethod = 'Cash';
  final TextEditingController _custNameCtrl = TextEditingController();
  final TextEditingController _custPhoneCtrl = TextEditingController();

  List<SaleTransaction> _pastSales = [];
  bool _isLoadingSales = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSalesHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _posSearchCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalesHistory() async {
    setState(() => _isLoadingSales = true);
    final sales = await ref.read(salesRepoProvider).getRecentSales(limit: 50);
    if (mounted) {
      setState(() {
        _pastSales = sales;
        _isLoadingSales = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Register & History', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'POS Counter Register'),
            Tab(icon: Icon(Icons.history), text: 'Sales Transaction History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildPosBillingView(),
          _buildSalesHistoryView(),
        ],
      ),
    );
  }

  // ================= TAB 1: POS COUNTER REGISTER =================

  Widget _buildPosBillingView() {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final inventoryAsync = ref.watch(inventoryListProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return isDesktop
            ? Row(
                children: [
                  Expanded(flex: 3, child: _buildProductPicker(inventoryAsync, cartNotifier)),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 2, child: _buildCartPanel(cart, cartNotifier)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildProductPicker(inventoryAsync, cartNotifier)),
                  const Divider(height: 1),
                  _buildMobileCartSummary(cart, cartNotifier),
                ],
              );
      },
    );
  }

  Widget _buildProductPicker(AsyncValue<List<InventoryItem>> inventoryAsync, CartNotifier cartNotifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _posSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search or scan product to sell...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _posSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _posSearchCtrl.clear();
                        setState(() => _posSearchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _posSearchQuery = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: inventoryAsync.when(
            data: (items) {
              final filtered = items.where((it) {
                if (_posSearchQuery.isEmpty) return true;
                return it.name.toLowerCase().contains(_posSearchQuery) ||
                    it.brand.toLowerCase().contains(_posSearchQuery) ||
                    (it.barcode != null && it.barcode!.contains(_posSearchQuery));
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No matching items in shop inventory.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final it = filtered[idx];
                  return InkWell(
                    onTap: () => cartNotifier.addItem(it),
                    borderRadius: BorderRadius.circular(8),
                    child: Card(
                      color: it.currentStock <= 0 ? Colors.grey.shade100 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                ProductImageWidget(
                                  productName: it.name,
                                  localImagePath: it.localImagePath,
                                  imageUrl: it.imageUrl,
                                  category: it.category,
                                  width: 36,
                                  height: 36,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(it.brand, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentColor), maxLines: 1),
                                      Text(it.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(CurrencyFormatter.format(it.sellingPrice), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                Text('Stock: ${it.currentStock.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: it.currentStock <= 0 ? Colors.red : Colors.grey.shade700)),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel(List<CartItem> cart, CartNotifier cartNotifier) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Sale Cart (${cart.length} items)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () => cartNotifier.clear(),
                  child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
            ],
          ),
          const Divider(height: 16),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Cart is empty. Tap items to add.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final c = cart[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${c.item.name}${c.isLooseStick ? " (Single Stick)" : ""}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${CurrencyFormatter.format(c.unitSellingPrice)} each  •  Cost: ${CurrencyFormatter.format(c.unitCostBasis)}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  onPressed: () => cartNotifier.updateQuantity(idx, c.quantity - 1),
                                ),
                                Text(c.quantity.toStringAsFixed(0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  onPressed: () => cartNotifier.updateQuantity(idx, c.quantity + 1),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 65,
                              child: Text(
                                CurrencyFormatter.format(c.lineTotal),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 16),
          // Checkout Summary
          _buildCheckoutFooter(cart, cartNotifier),
        ],
      ),
    );
  }

  Widget _buildMobileCartSummary(List<CartItem> cart, CartNotifier cartNotifier) {
    if (cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: const Center(child: Text('Cart empty. Tap products above to start sale.', style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${cart.length} items in cart', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(CurrencyFormatter.format(cartNotifier.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Checkout Bill'),
            onPressed: () => _openCheckoutDialog(cart, cartNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutFooter(List<CartItem> cart, CartNotifier cartNotifier) {
    if (cart.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:'),
            Text(CurrencyFormatter.format(cartNotifier.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (cartNotifier.totalDiscount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discounts:', style: TextStyle(color: Colors.red)),
              Text('-${CurrencyFormatter.format(cartNotifier.totalDiscount)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Gross Margin:', style: TextStyle(fontSize: 11, color: AppTheme.successColor)),
            Text('+${CurrencyFormatter.format(cartNotifier.grossProfit)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(CurrencyFormatter.format(cartNotifier.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Complete Sale & Print Bill', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _openCheckoutDialog(cart, cartNotifier),
          ),
        ),
      ],
    );
  }

  void _openCheckoutDialog(List<CartItem> cart, CartNotifier cartNotifier) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Sale & Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount Payable:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(CurrencyFormatter.format(cartNotifier.grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Select Payment Mode:*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['Cash', 'UPI / QR', 'Credit / Udhaar', 'Card'].map((mode) {
                          final isSelected = _paymentMethod == mode;
                          return ChoiceChip(
                            label: Text(mode),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setDialogState(() => _paymentMethod = mode);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _custNameCtrl,
                        decoration: const InputDecoration(labelText: 'Customer Name (Optional)', isDense: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _custPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Customer Mobile (Optional)', isDense: true),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _executeSaleTransaction(cart, cartNotifier);
                  },
                  child: const Text('Confirm & Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeSaleTransaction(List<CartItem> cart, CartNotifier cartNotifier) async {
    final saleId = const Uuid().v4();
    final invoiceNum = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final now = DateTime.now().toIso8601String();

    final saleItems = cart.map((c) {
      return SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        inventoryItemId: c.item.id,
        productName: '${c.item.name}${c.isLooseStick ? " (Loose)" : ""}',
        variant: c.item.packSize,
        quantity: c.quantity,
        unitSellingPrice: c.unitSellingPrice,
        unitCostBasis: c.unitCostBasis,
        discount: c.discount,
        lineTotal: c.lineTotal,
        lineProfit: c.lineProfit,
        isLooseStick: c.isLooseStick,
      );
    }).toList();

    final sale = SaleTransaction(
      id: saleId,
      invoiceNumber: invoiceNum,
      createdAt: now,
      customerName: _custNameCtrl.text.trim().isNotEmpty ? _custNameCtrl.text.trim() : 'Walk-in',
      customerPhone: _custPhoneCtrl.text.trim().isNotEmpty ? _custPhoneCtrl.text.trim() : null,
      paymentMethod: _paymentMethod,
      subtotal: cartNotifier.subtotal,
      discount: cartNotifier.totalDiscount,
      grandTotal: cartNotifier.grandTotal,
      totalCostBasis: cartNotifier.totalCostBasis,
      grossProfit: cartNotifier.grossProfit,
      status: 'completed',
      items: saleItems,
    );

    // Record with atomic transaction
    await ref.read(salesRepoProvider).recordSale(sale, saleItems);

    cartNotifier.clear();
    _custNameCtrl.clear();
    _custPhoneCtrl.clear();

    ref.invalidate(inventoryListProvider);
    ref.invalidate(dashboardMetricsProvider);
    ref.invalidate(dailySalesChartProvider);
    ref.invalidate(topSellingProductsProvider);

    await _loadSalesHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sale $invoiceNum recorded successfully (${CurrencyFormatter.format(sale.grandTotal)})!'),
        action: SnackBarAction(
          label: 'Print PDF',
          onPressed: () async {
            final pdfBytes = await PdfService.generateSalesTransactionsPdf([sale], 'Invoice $invoiceNum');
            await PdfService.printOrSharePdf(pdfBytes, '$invoiceNum.pdf');
          },
        ),
      ));
    }
  }

  // ================= TAB 2: SALES TRANSACTION HISTORY =================

  Widget _buildSalesHistoryView() {
    if (_isLoadingSales) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pastSales.isEmpty) {
      return const Center(child: Text('No past sales transactions yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _pastSales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final s = _pastSales[idx];
        final isVoided = s.status == 'voided';

        return Card(
          color: isVoided ? Colors.grey.shade50 : Colors.white,
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.invoiceNumber, style: TextStyle(fontWeight: FontWeight.bold, decoration: isVoided ? TextDecoration.lineThrough : null)),
                Text(
                  CurrencyFormatter.format(s.grandTotal),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isVoided ? Colors.grey : AppTheme.primaryColor),
                ),
              ],
            ),
            subtitle: Text(
              '${CurrencyFormatter.formatDate(DateTime.parse(s.createdAt))} • ${s.paymentMethod} • ${s.customerName ?? "Walk-in"}${isVoided ? " (VOIDED)" : ""}',
              style: TextStyle(fontSize: 11, color: isVoided ? Colors.red : Colors.grey.shade600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...s.items.map((it) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${it.quantity.toStringAsFixed(0)}x ${it.productName}', style: const TextStyle(fontSize: 12)),
                            Text(CurrencyFormatter.format(it.lineTotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gross Profit (COGS: ${CurrencyFormatter.format(s.totalCostBasis)}):', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('+${CurrencyFormatter.format(s.grossProfit)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!isVoided)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.undo, size: 16, color: Colors.red),
                            label: const Text('Void / Return & Restock', style: TextStyle(fontSize: 11, color: Colors.red)),
                            onPressed: () => _confirmVoidSale(s),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmVoidSale(SaleTransaction s) {
    final reasonCtrl = TextEditingController(text: 'Customer return / Billing mistake');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Void Sale ${s.invoiceNumber}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will void the transaction and automatically return all items to shop inventory stock.'),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Void / Return')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(salesRepoProvider).voidSale(s.id, reasonCtrl.text.trim());
                ref.invalidate(inventoryListProvider);
                ref.invalidate(dashboardMetricsProvider);
                await _loadSalesHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale ${s.invoiceNumber} voided and inventory restored.')));
                }
              },
              child: const Text('Confirm Void'),
            ),
          ],
        );
      },
    );
  }
}
