import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../models/inventory_item.dart';
import '../../providers/app_providers.dart';
import '../../repositories/inventory_repository.dart';
import '../../services/csv_service.dart';
import '../../services/pdf_service.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryListProvider);
    final valuationAsync = ref.watch(inventoryValuationProvider);
    final filter = ref.watch(inventoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Inventory & Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Valuation PDF',
            onPressed: () async {
              final items = await ref.read(inventoryRepoProvider).getItems();
              final pdfBytes = await PdfService.generateInventoryReportPdf(items);
              await PdfService.printOrSharePdf(pdfBytes, 'inventory_valuation_report.pdf');
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () async {
              final items = await ref.read(inventoryRepoProvider).getItems();
              final csvStr = CsvService.exportInventoryToCsv(items);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Exported ${items.length} inventory records to CSV (${csvStr.length} bytes).'),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Valuation Summary Banner
          valuationAsync.when(
            data: (val) => _buildValuationBanner(context, val),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2. Search & Low Stock Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search stocked items...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        suffixIcon: filter.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  ref.read(inventoryFilterProvider.notifier).state = filter.copyWith(query: '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        ref.read(inventoryFilterProvider.notifier).state = filter.copyWith(query: val.trim());
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ref.read(inventoryFilterProvider.notifier).state = filter.copyWith(lowStockOnly: !filter.lowStockOnly);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: filter.lowStockOnly ? const Color(0xFFFEF2F2) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: filter.lowStockOnly ? const Color(0xFFF87171) : const Color(0xFFE2E8F0),
                        width: filter.lowStockOnly ? 1.4 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: filter.lowStockOnly ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Low Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: filter.lowStockOnly ? const Color(0xFFDC2626) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // 3. Inventory List
          Expanded(
            child: inventoryAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        const Text('No inventory items found.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Text(
                          filter.lowStockOnly ? 'All products are currently well-stocked!' : 'Add items from Master Catalogue to start tracking.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    return _buildInventoryCard(context, ref, item);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading inventory: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuationBanner(BuildContext context, InventoryValuationSummary val) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399)),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'STORE VALUATION & ASSETS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFFA7F3D0),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${val.totalItemsCount} Active SKUs',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Cost Basis', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(val.totalCostValuation),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: Colors.white12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Potential Retail Value', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(val.totalRetailValuation),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFDE047),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.all_inbox_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      '${val.totalUnitsCount.toStringAsFixed(0)} Total Units in Stock',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, size: 15, color: Color(0xFF6EE7B7)),
                    const SizedBox(width: 4),
                    Text(
                      'Margin: +${CurrencyFormatter.format(val.potentialGrossMargin)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, WidgetRef ref, InventoryItem item) {
    final isLow = item.isLowStock;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
          width: isLow ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isLow
                ? const Color(0xFFDC2626).withOpacity(0.04)
                : const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: ProductImageWidget(
                    localImagePath: item.localImagePath,
                    imageUrl: item.imageUrl,
                    category: item.category,
                    width: 58,
                    height: 58,
                    borderRadius: 10,
                  ),
                ),
                const SizedBox(width: 12),

                // Main Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Low / In Stock Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLow ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLow ? 'Low Stock' : 'In Stock',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.brand} • ${item.category} • ${item.packSize ?? "-"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      // Pricing Row
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Retail: ',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                TextSpan(
                                  text: CurrencyFormatter.format(item.sellingPrice),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Cost: ${CurrencyFormatter.format(item.purchasePrice)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.marginPercentage.toStringAsFixed(0)}% Margin',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          // Bottom Stock & Actions Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AVAILABLE STOCK',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.currentStock.toStringAsFixed(0)} units',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isLow ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                          ),
                        ),
                        if (isLow) ...[
                          const SizedBox(width: 5),
                          const Text(
                            '(Reorder)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    InkWell(
                      onTap: () => _openStockAdjustmentDialog(context, ref, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, size: 14, color: Color(0xFF475569)),
                            SizedBox(width: 5),
                            Text(
                              'Adjust',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _quickStockInDialog(context, ref, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D5C46),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D5C46).withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Inward Stock',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openStockAdjustmentDialog(BuildContext context, WidgetRef ref, InventoryItem item) {
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String reason = 'Damaged Stock';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Stock Adjustment',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current On-Hand Stock:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(
                            '${item.currentStock.toStringAsFixed(0)} units',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: reason,
                      decoration: InputDecoration(
                        labelText: 'Reason for Adjustment',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Damaged Stock',
                          child: Text('Damaged Stock (write-off)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Expired Stock',
                          child: Text('Expired Stock (write-off)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Inventory Audit Count Correction',
                          child: Text('Physical Count Audit Correction', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'Return to Supplier',
                          child: Text('Return to Supplier', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) => setDialogState(() => reason = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity Change*',
                        hintText: 'e.g. -2 for damage, +5 for found stock',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notes / Remarks',
                        hintText: 'Optional audit explanation',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final delta = double.tryParse(qtyCtrl.text.trim());
                    if (delta == null || delta == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a non-zero quantity change.')));
                      return;
                    }

                    await ref.read(inventoryRepoProvider).adjustStock(
                          itemId: item.id,
                          quantityChange: delta,
                          reason: reason,
                          notes: notesCtrl.text.trim(),
                        );

                    ref.invalidate(inventoryListProvider);
                    ref.invalidate(inventoryValuationProvider);
                    ref.invalidate(dashboardMetricsProvider);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock adjustment logged successfully.')));
                    }
                  },
                  child: const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _quickStockInDialog(BuildContext context, WidgetRef ref, InventoryItem item) {
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: item.purchasePrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_business_rounded, size: 20, color: Color(0xFF0D5C46)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Inward New Stock',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to Add*',
                        hintText: '10',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick Preset Buttons
                    Row(
                      children: [5, 10, 25, 50].map((preset) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                backgroundColor: const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  qtyCtrl.text = preset.toString();
                                });
                              },
                              child: Text('+$preset', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Unit Purchase Cost (₹)*',
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                    final cost = double.tryParse(costCtrl.text.trim()) ?? item.purchasePrice;

                    if (qty <= 0) return;

                    await ref.read(inventoryRepoProvider).upsertItem(
                          item.copyWith(
                            currentStock: item.currentStock + qty,
                            purchasePrice: cost,
                            updatedAt: DateTime.now().toIso8601String(),
                          ),
                        );

                    ref.invalidate(inventoryListProvider);
                    ref.invalidate(inventoryValuationProvider);
                    ref.invalidate(dashboardMetricsProvider);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $qty units to ${item.name}.')));
                    }
                  },
                  child: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
