import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../models/purchase_list_item.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_service.dart';

class PurchaseListScreen extends ConsumerWidget {
  final VoidCallback onBrowseCatalogue;

  const PurchaseListScreen({super.key, required this.onBrowseCatalogue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(purchaseListProvider);
    final notifier = ref.read(purchaseListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase & Procurement List', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Purchase List PDF',
            onPressed: () async {
              final items = listAsync.value ?? [];
              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items in purchase list to export.')));
                return;
              }
              final pdfBytes = await PdfService.generatePurchaseListPdf(items);
              await PdfService.printOrSharePdf(pdfBytes, 'purchase_procurement_list.pdf');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Items from Catalogue',
            onPressed: onBrowseCatalogue,
          ),
        ],
      ),
      body: listAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_checkout, size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Your purchase list is currently empty.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Browse master catalogue and tap "Procure" to add items to buy.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Browse Master Catalogue'),
                    onPressed: onBrowseCatalogue,
                  ),
                ],
              ),
            );
          }

          double estimatedGrandTotal = 0.0;
          int confirmedCount = 0;
          for (final it in items) {
            estimatedGrandTotal += it.lineTotal;
            if (it.isCostConfirmed) confirmedCount++;
          }

          final receivedItems = items.where((it) => it.status == 'received').toList();

          return Column(
            children: [
              // 1. Procurement Summary Banner
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Procurement Grand Total', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                            Text(
                              CurrencyFormatter.format(estimatedGrandTotal),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        if (receivedItems.isNotEmpty)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.inventory_2, size: 16),
                            label: Text('Inward Received (${receivedItems.length})'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                            onPressed: () => _convertReceivedDialog(context, ref, receivedItems),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('${items.length} SKUs to purchase ($confirmedCount confirmed costs)', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                        const Text('*Totals are estimates until bill confirmation', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.amber)),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Items List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final it = items[idx];
                    return _buildPurchaseCard(context, ref, notifier, it);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPurchaseCard(BuildContext context, WidgetRef ref, PurchaseListNotifier notifier, PurchaseListItem it) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ProductImageWidget(
                  localImagePath: it.localImagePath,
                  imageUrl: it.imageUrl,
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${it.brand} • ${it.packSize ?? it.variant ?? "-"}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: it.status == 'received' ? Colors.green.shade50 : (it.status == 'ordered' ? Colors.blue.shade50 : Colors.orange.shade50),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              it.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: it.status == 'received' ? Colors.green.shade800 : (it.status == 'ordered' ? Colors.blue.shade800 : Colors.orange.shade800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            it.isCostConfirmed ? 'Confirmed Cost' : 'Estimated Cost',
                            style: TextStyle(fontSize: 10, color: it.isCostConfirmed ? Colors.green : Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyFormatter.format(it.lineTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    Text('${it.requestedQuantity.toStringAsFixed(0)} pkts @ ${CurrencyFormatter.format(it.estimatedUnitCost)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Pending', style: TextStyle(fontSize: 10)),
                      selected: it.status == 'pending',
                      onSelected: (val) {
                        if (val) notifier.updateItem(it.copyWith(status: 'pending'));
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Ordered', style: TextStyle(fontSize: 10)),
                      selected: it.status == 'ordered',
                      onSelected: (val) {
                        if (val) notifier.updateItem(it.copyWith(status: 'ordered'));
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Received', style: TextStyle(fontSize: 10)),
                      selected: it.status == 'received',
                      onSelected: (val) {
                        if (val) notifier.updateItem(it.copyWith(status: 'received'));
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit Quantity / Cost',
                      onPressed: () => _openEditDialog(context, notifier, it),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Remove',
                      onPressed: () => notifier.removeItem(it.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context, PurchaseListNotifier notifier, PurchaseListItem it) {
    final qtyCtrl = TextEditingController(text: it.requestedQuantity.toStringAsFixed(0));
    final costCtrl = TextEditingController(text: it.estimatedUnitCost.toStringAsFixed(2));
    bool confirmed = it.isCostConfirmed;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${it.productName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity to Procure*')),
                  const SizedBox(height: 12),
                  TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Estimated Unit Cost (₹)*')),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Cost confirmed by wholesale supplier', style: TextStyle(fontSize: 12)),
                    value: confirmed,
                    onChanged: (val) => setDialogState(() => confirmed = val ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? it.requestedQuantity;
                    final cost = double.tryParse(costCtrl.text.trim()) ?? it.estimatedUnitCost;
                    notifier.updateItem(it.copyWith(
                      requestedQuantity: qty,
                      estimatedUnitCost: cost,
                      isCostConfirmed: confirmed,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _convertReceivedDialog(BuildContext context, WidgetRef ref, List<PurchaseListItem> receivedItems) {
    final supplierCtrl = TextEditingController(text: 'Metro Wholesale Depot');
    final invoiceCtrl = TextEditingController(text: 'BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Inward Received Stock (${receivedItems.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will convert all marked "Received" goods into an official inward purchase receipt and increment your shop inventory stock levels.'),
              const SizedBox(height: 12),
              TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Supplier Name*')),
              const SizedBox(height: 8),
              TextField(controller: invoiceCtrl, decoration: const InputDecoration(labelText: 'Supplier Invoice / Bill Ref#')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(purchaseListProvider.notifier).convertReceived(
                      items: receivedItems,
                      supplierName: supplierCtrl.text.trim(),
                    );
                ref.invalidate(inventoryListProvider);
                ref.invalidate(inventoryValuationProvider);
                ref.invalidate(dashboardMetricsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Received goods converted to inward purchase and stock incremented!')));
                }
              },
              child: const Text('Confirm Inward Stock'),
            ),
          ],
        );
      },
    );
  }
}
