import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../database/app_database.dart';
import '../../models/purchase_list_item.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_service.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  final VoidCallback onBrowseCatalogue;

  const ShoppingListScreen({super.key, required this.onBrowseCatalogue});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  String _currentMonthKey = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(purchaseListProvider);
    final notifier = ref.read(purchaseListProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Wholesale Order List', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Order with Wholesaler',
            onPressed: () {
              final items = listAsync.value ?? [];
              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your list is empty. Add items from catalogue first.')),
                );
                return;
              }
              _shareListWithWholesaler(items);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Bill',
            onPressed: () async {
              final items = listAsync.value ?? [];
              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No items to export to PDF.')),
                );
                return;
              }
              final pdfBytes = await PdfService.generatePurchaseListPdf(items);
              await PdfService.printOrSharePdf(pdfBytes, 'wholesale_order_list.pdf');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            tooltip: 'Clear Entire List',
            onPressed: () => _confirmClearAll(context),
          ),
        ],
      ),
      body: listAsync.when(
        data: (items) {
          double grandTotal = 0.0;
          double totalQuantity = 0.0;
          for (final it in items) {
            grandTotal += it.lineTotal;
            totalQuantity += it.requestedQuantity;
          }

          return Column(
            children: [
              // 1. Month Bar & "Copy From Last Month" helper
              _buildMonthToolbar(context, items),

              // 2. Table Column Header
              _buildTableHeader(),

              // 3. The List Items (No images, clean tabular row)
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 20),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, idx) {
                          final item = items[idx];
                          return _buildTableRow(context, notifier, item, idx + 1);
                        },
                      ),
              ),

              // 4. Sticky Bottom Bar: Total Wholesaler Bill
              _buildBottomSummaryBar(context, items, grandTotal, totalQuantity),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading list: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Products', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: widget.onBrowseCatalogue,
      ),
    );
  }

  // Month toolbar allowing saving snapshot and copying previous month's items
  Widget _buildMonthToolbar(BuildContext context, List<PurchaseListItem> currentItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF047857)),
                const SizedBox(width: 5),
                Text(
                  _currentMonthKey,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: const Color(0xFF4338CA),
            ),
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy Last Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _copyFromPreviousMonth(context),
          ),
          IconButton(
            icon: const Icon(Icons.save_as_outlined, size: 18, color: Color(0xFF475569)),
            tooltip: 'Save This Month as Template',
            onPressed: () => _saveCurrentMonthSnapshot(context, currentItems),
          ),
        ],
      ),
    );
  }

  // Clean Table Header
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFF1F5F9),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'ITEM',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'QUANTITY',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'PRICE (₹)',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'TOTAL (₹)',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
            ),
          ),
          SizedBox(width: 32), // Spacer for red delete button
        ],
      ),
    );
  }

  // Each table row: NO images, text table format as requested
  Widget _buildTableRow(BuildContext context, PurchaseListNotifier notifier, PurchaseListItem item, int indexNumber) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // 1. Item number & name
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$indexNumber. ${item.productName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.brand.isNotEmpty && !item.productName.toLowerCase().contains(item.brand.toLowerCase()))
                  Text(
                    item.brand,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),

          // 2. Quantity stepper & editable tap
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    final current = item.requestedQuantity;
                    if (current > 1) {
                      notifier.updateItem(item.copyWith(requestedQuantity: current - 1));
                    } else {
                      notifier.removeItem(item.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.remove, size: 14, color: Color(0xFF334155)),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openEditQuantityDialog(context, notifier, item),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFFFAFAFA),
                    ),
                    child: Text(
                      item.requestedQuantity.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    notifier.updateItem(item.copyWith(requestedQuantity: item.requestedQuantity + 1));
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),

          // 3. Wholesale Unit Price (Tap to edit)
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _openEditPriceDialog(context, notifier, item),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  '₹${item.estimatedUnitCost.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0369A1),
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ),
          ),

          // 4. Line Total
          Expanded(
            flex: 3,
            child: Text(
              '₹${item.lineTotal.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF065F46),
              ),
            ),
          ),

          // 5. Red Delete Icon Only Button
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete Item',
              onPressed: () => notifier.removeItem(item.id),
            ),
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Summary Bar
  Widget _buildBottomSummaryBar(BuildContext context, List<PurchaseListItem> items, double grandTotal, double totalQuantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL CASH TO PAY WHOLESALER',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length} Products • ${totalQuantity.toStringAsFixed(0)} Total Units',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(grandTotal),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text(
                      'Share Order with Wholesaler',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: items.isEmpty ? null : () => _shareListWithWholesaler(items),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Wholesale List is Empty',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse the catalogue and tap "+ Add to List" on any product.\nYou can edit quantities, rates, and calculate the exact wholesale bill.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Browse Master Catalogue', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: widget.onBrowseCatalogue,
            ),
          ],
        ),
      ),
    );
  }

  // Edit Quantity Dialog
  void _openEditQuantityDialog(BuildContext context, PurchaseListNotifier notifier, PurchaseListItem item) {
    final controller = TextEditingController(text: item.requestedQuantity.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Quantity for ${item.productName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Units / Packets to Buy',
              border: OutlineInputBorder(),
              suffixText: 'units',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                final qty = double.tryParse(controller.text.trim()) ?? item.requestedQuantity;
                if (qty > 0) {
                  notifier.updateItem(item.copyWith(requestedQuantity: qty));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // Edit Wholesale Price Dialog
  void _openEditPriceDialog(BuildContext context, PurchaseListNotifier notifier, PurchaseListItem item) {
    final controller = TextEditingController(text: item.estimatedUnitCost.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Wholesale Rate for ${item.productName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cost Rate from Wholesaler (₹)',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                final price = double.tryParse(controller.text.trim()) ?? item.estimatedUnitCost;
                if (price >= 0) {
                  notifier.updateItem(item.copyWith(estimatedUnitCost: price));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Update Rate'),
            ),
          ],
        );
      },
    );
  }

  // Share formatted text on WhatsApp or SMS
  void _shareListWithWholesaler(List<PurchaseListItem> items) {
    double totalBill = 0.0;
    final buffer = StringBuffer();
    buffer.writeln('🛒 *WHOLESALE ORDER LIST - $_currentMonthKey*');
    buffer.writeln('------------------------------------------');
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      totalBill += it.lineTotal;
      buffer.writeln('${i + 1}. ${it.productName}');
      buffer.writeln('   Qty: ${it.requestedQuantity.toStringAsFixed(0)} pcs  |  Rate: ₹${it.estimatedUnitCost.toStringAsFixed(2)}  |  Total: ₹${it.lineTotal.toStringAsFixed(0)}');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('💰 *TOTAL TO PAY WHOLESALER: ${CurrencyFormatter.format(totalBill)}*');
    buffer.writeln('📦 Total Products: ${items.length}');

    Share.share(buffer.toString(), subject: 'Wholesale Order List');
  }

  // Premium Centered "Clear All" Modal
  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.delete_forever_rounded, size: 36, color: Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Clear Entire Buying List?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Are you sure you want to remove all items from your wholesale order list?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          foregroundColor: const Color(0xFF475569),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Yes, Clear All', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(purchaseListProvider.notifier).clearAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wholesale list cleared successfully.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Save current month template to SQLite app_settings
  Future<void> _saveCurrentMonthSnapshot(BuildContext context, List<PurchaseListItem> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty list as monthly template.')),
      );
      return;
    }

    final db = await AppDatabase.instance.database;
    final jsonList = items.map((it) => it.toMap()).toList();
    await db.insert('app_settings', {'key': 'monthly_template_last', 'value': jsonEncode(jsonList)}, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_settings', {'key': 'monthly_template_month_name', 'value': _currentMonthKey}, conflictAlgorithm: ConflictAlgorithm.replace);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${items.length} items as template for $_currentMonthKey!'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }

  // Copy previous month's items into current list from SQLite app_settings
  Future<void> _copyFromPreviousMonth(BuildContext context) async {
    final db = await AppDatabase.instance.database;
    final rowTemplate = await db.query('app_settings', where: 'key = ?', whereArgs: ['monthly_template_last'], limit: 1);
    final rowName = await db.query('app_settings', where: 'key = ?', whereArgs: ['monthly_template_month_name'], limit: 1);

    final raw = rowTemplate.isNotEmpty ? rowTemplate.first['value'] as String? : null;
    final lastMonthName = rowName.isNotEmpty ? rowName.first['value'] as String? : 'previous month';

    if (raw == null || raw.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous month template found. Save this month first!')),
        );
      }
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final notifier = ref.read(purchaseListProvider.notifier);
    final uuid = const Uuid();

    for (final map in decoded) {
      final it = PurchaseListItem.fromMap(map as Map<String, dynamic>);
      final freshItem = PurchaseListItem(
        id: uuid.v4(),
        masterProductId: it.masterProductId,
        productName: it.productName,
        brand: it.brand,
        variant: it.variant,
        packSize: it.packSize,
        requestedQuantity: it.requestedQuantity,
        estimatedUnitCost: it.estimatedUnitCost,
        status: 'pending',
        addedAt: DateTime.now().toIso8601String(),
      );
      await notifier.addItem(freshItem);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${decoded.length} items from $lastMonthName into your current list!'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }
}
