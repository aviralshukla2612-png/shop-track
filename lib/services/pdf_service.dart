import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/inventory_item.dart';
import '../models/purchase_list_item.dart';
import '../models/sale_transaction.dart';
import '../repositories/reports_repository.dart';

import '../repositories/settings_repository.dart';

class PdfService {
  static final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static pw.Widget _buildHeader(String title, {String? subtitle, ShopProfile? profile}) {
    final shopTitle = (profile != null && profile.shopName.isNotEmpty)
        ? profile.shopName.toUpperCase()
        : 'SHOP TRACK — RETAIL STORE';
    final shopSubtitle = (profile != null && profile.shopOwner.isNotEmpty)
        ? 'Proprietor: ${profile.shopOwner}'
        : 'Inventory & Business Management System';
    final shopContact = (profile != null && (profile.address.isNotEmpty || profile.phone.isNotEmpty))
        ? '${profile.address}${profile.address.isNotEmpty && profile.phone.isNotEmpty ? " | " : ""}Phone: ${profile.phone}'
        : 'Offline Retail Billing & Inventory';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                pw.Text(shopSubtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text(shopContact, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('OFFICIAL REPORT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.Text('Generated: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.teal700, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
              if (subtitle != null)
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  // 1. Purchase List PDF
  static Future<Uint8List> generatePurchaseListPdf(List<PurchaseListItem> items) async {
    final pdf = pw.Document();
    double grandTotal = 0.0;
    for (var it in items) {
      grandTotal += it.lineTotal;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('PURCHASE & PROCUREMENT ORDER LIST', subtitle: '${items.length} Items Listed'),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Product Name', 'Brand', 'Pack Size', 'Req Qty', 'Est. Unit Cost', 'Line Total', 'Cost Status'],
            data: items.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final it = entry.value;
              return [
                '$i',
                it.productName,
                it.brand,
                it.packSize ?? '-',
                '${it.requestedQuantity.toStringAsFixed(0)} pkts',
                _inrFormat.format(it.estimatedUnitCost),
                _inrFormat.format(it.lineTotal),
                it.isCostConfirmed ? 'Confirmed' : 'Estimated',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Estimated Procurement Total: ${_inrFormat.format(grandTotal)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('*Unit costs are estimates until confirmed on supplier bill.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // 2. Inventory Valuation & Stock Report PDF
  static Future<Uint8List> generateInventoryReportPdf(List<InventoryItem> items) async {
    final pdf = pw.Document();
    double totalCostVal = 0.0;
    double totalRetailVal = 0.0;
    for (var it in items) {
      totalCostVal += it.totalInventoryValue;
      totalRetailVal += it.potentialSalesValue;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('INVENTORY VALUATION & STOCK AUDIT REPORT', subtitle: 'Total Products: ${items.length}'),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Product Name', 'Category', 'Stock Qty', 'Cost Price', 'Retail Price', 'Cost Valuation', 'Retail Valuation', 'Status'],
            data: items.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final it = entry.value;
              return [
                '$i',
                '${it.name} (${it.packSize ?? '-'})',
                it.category,
                it.currentStock.toStringAsFixed(0),
                _inrFormat.format(it.purchasePrice),
                _inrFormat.format(it.sellingPrice),
                _inrFormat.format(it.totalInventoryValue),
                _inrFormat.format(it.potentialSalesValue),
                it.isLowStock ? 'LOW STOCK' : 'Healthy',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Method: Weighted Average Acquisition Cost Basis', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Cost Valuation: ${_inrFormat.format(totalCostVal)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  pw.Text('Potential Retail Value: ${_inrFormat.format(totalRetailVal)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.Text('Projected Margin: ${_inrFormat.format(totalRetailVal - totalCostVal)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // 3. Profit and Loss Financial Statement PDF
  static Future<Uint8List> generateProfitLossPdf(ProfitLossReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('PROFIT & LOSS FINANCIAL STATEMENT', subtitle: '${DateFormat('dd MMM yyyy').format(report.startDate)} to ${DateFormat('dd MMM yyyy').format(report.endDate)}'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('REVENUE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                pw.Divider(color: PdfColors.grey300),
                _financialRow('Gross Retail Sales', report.grossSales),
                _financialRow('Less: Customer Discounts Allowed', -report.totalDiscounts, isDeduction: true),
                _financialRow('Net Sales Revenue', report.netRevenue, isTotal: true),
                pw.SizedBox(height: 12),

                pw.Text('COST OF GOODS SOLD (COGS)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                pw.Divider(color: PdfColors.grey300),
                _financialRow('Historical Acquisition Cost Basis of Sold Units', report.costOfGoodsSold),
                pw.SizedBox(height: 6),
                _financialRow('GROSS PROFIT', report.grossProfit, isTotal: true, extra: '${report.grossProfitMargin.toStringAsFixed(1)}% margin'),
                pw.SizedBox(height: 14),

                pw.Text('OPERATING EXPENSES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                pw.Divider(color: PdfColors.grey300),
                if (report.expensesByCategory.isEmpty)
                  pw.Text('No operating expenses recorded in this period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
                else
                  ...report.expensesByCategory.entries.map((e) => _financialRow(e.key, e.value)),
                _financialRow('Total Operating Expenses', report.totalOperatingExpenses, isTotal: true),
                pw.SizedBox(height: 14),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: report.netProfit >= 0 ? PdfColors.green50 : PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: report.netProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('ESTIMATED NET PROFIT (EBITDA)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: report.netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
                      pw.Text(
                        '${_inrFormat.format(report.netProfit)} (${report.netProfitMargin.toStringAsFixed(1)}%)',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: report.netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // 4. Daily Sales Transactions Report PDF
  static Future<Uint8List> generateSalesTransactionsPdf(List<SaleTransaction> sales, String periodLabel) async {
    final pdf = pw.Document();
    double totalRevenue = 0.0;
    double totalProfit = 0.0;
    for (var s in sales) {
      if (s.status == 'completed') {
        totalRevenue += s.grandTotal;
        totalProfit += s.grossProfit;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('SALES TRANSACTIONS & CASH REGISTER AUDIT', subtitle: periodLabel),
          pw.TableHelper.fromTextArray(
            headers: ['Invoice #', 'Date & Time', 'Customer', 'Payment Mode', 'Items Count', 'Net Amount', 'Gross Margin', 'Status'],
            data: sales.map((s) {
              return [
                s.invoiceNumber,
                DateFormat('dd/MM hh:mm a').format(DateTime.parse(s.createdAt)),
                s.customerName ?? 'Walk-in',
                s.paymentMethod,
                '${s.items.length}',
                _inrFormat.format(s.grandTotal),
                _inrFormat.format(s.grossProfit),
                s.status.toUpperCase(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Sales Realized: ${_inrFormat.format(totalRevenue)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  pw.Text('Total Gross Profit: ${_inrFormat.format(totalProfit)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _financialRow(String title, double amount, {bool isTotal = false, bool isDeduction = false, String? extra}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: isTotal ? 11 : 9.5, fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: isTotal ? PdfColors.black : PdfColors.grey800),
          ),
          pw.Row(
            children: [
              if (extra != null)
                pw.Text('($extra)   ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(
                _inrFormat.format(amount),
                style: pw.TextStyle(fontSize: isTotal ? 11 : 9.5, fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: isDeduction ? PdfColors.red800 : (isTotal ? PdfColors.teal900 : PdfColors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> printOrSharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
