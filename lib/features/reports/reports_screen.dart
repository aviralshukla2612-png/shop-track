import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReport = 'Profit & Loss Statement';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports & PDF Generator', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Report Selector Tabs / Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                'Profit & Loss Statement',
                'Inventory Valuation',
                'Sales Audit Log',
                'Purchase Procurement List',
              ].map((rep) {
                final isSelected = _selectedReport == rep;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(rep),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedReport = rep);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Interactive PDF Preview Area
          Expanded(
            child: PdfPreview(
              build: (format) => _generatePdfDoc(),
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowPrinting: true,
              allowSharing: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdfDoc() async {
    final now = DateTime.now();

    if (_selectedReport == 'Profit & Loss Statement') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final pl = await ref.read(reportsRepoProvider).generateProfitLossReport(start, end);
      return await PdfService.generateProfitLossPdf(pl);
    } else if (_selectedReport == 'Inventory Valuation') {
      final items = await ref.read(inventoryRepoProvider).getItems();
      return await PdfService.generateInventoryReportPdf(items);
    } else if (_selectedReport == 'Purchase Procurement List') {
      final items = await ref.read(purchasesRepoProvider).getPurchaseList();
      return await PdfService.generatePurchaseListPdf(items);
    } else {
      // Sales Audit Log
      final sales = await ref.read(salesRepoProvider).getRecentSales(limit: 50);
      return await PdfService.generateSalesTransactionsPdf(sales, 'Sales Audit Report');
    }
  }
}
