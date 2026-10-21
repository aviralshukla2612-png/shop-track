import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/app_providers.dart';
import '../../repositories/reports_repository.dart';
import '../../repositories/sales_repository.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedRange = 'This Month';
  ProfitLossReport? _plReport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedRange == 'Today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'This Week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_selectedRange == 'This Month') {
      start = DateTime(now.year, now.month, 1);
    } else {
      // This Year
      start = DateTime(now.year, 1, 1);
    }

    final report = await ref.read(reportsRepoProvider).generateProfitLossReport(start, end);
    if (mounted) {
      setState(() {
        _plReport = report;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topProductsAsync = ref.watch(topSellingProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics & Profit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Time Range Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Reporting Period:  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Today', label: Text('Today')),
                      ButtonSegment(value: 'This Week', label: Text('Week')),
                      ButtonSegment(value: 'This Month', label: Text('Month')),
                      ButtonSegment(value: 'This Year', label: Text('Year')),
                    ],
                    selected: {_selectedRange},
                    onSelectionChanged: (val) {
                      setState(() => _selectedRange = val.first);
                      _loadReport();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Profit & Loss Card
            _isLoading || _plReport == null
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                : _buildProfitLossCard(_plReport!),

            const SizedBox(height: 20),

            // 3. Payment Methods Breakdown
            if (_plReport != null && _plReport!.salesByPaymentMethod.isNotEmpty)
              _buildPaymentMethodSection(_plReport!),

            const SizedBox(height: 20),

            // 4. Best Selling Products Ranking
            _buildTopProductsCard(topProductsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossCard(ProfitLossReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('P&L Profitability Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_selectedRange, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 14),

            _metricRow('Gross Sales Revenue', CurrencyFormatter.format(report.grossSales), isHeader: true),
            if (report.totalDiscounts > 0)
              _metricRow('Less Customer Discounts', '-${CurrencyFormatter.format(report.totalDiscounts)}', isNegative: true),
            _metricRow('Net Sales Revenue', CurrencyFormatter.format(report.netRevenue), isBold: true),
            const Divider(height: 16),

            _metricRow('Cost of Goods Sold (COGS)', '-${CurrencyFormatter.format(report.costOfGoodsSold)}', isNegative: true, subtitle: 'Unit acquisition cost basis'),
            const Divider(height: 16),

            _metricRow(
              'Gross Profit Margin',
              '+${CurrencyFormatter.format(report.grossProfit)} (${report.grossProfitMargin.toStringAsFixed(1)}%)',
              isBold: true,
              color: AppTheme.successColor,
            ),
            const Divider(height: 16),

            _metricRow('Operating Expenses (Shop bills, rent, etc.)', '-${CurrencyFormatter.format(report.totalOperatingExpenses)}', isNegative: true),
            const Divider(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: report.netProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: report.netProfit >= 0 ? Colors.green.shade600 : Colors.red.shade600),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ESTIMATED NET PROFIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('${report.netProfitMargin.toStringAsFixed(1)}% net margin', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(report.netProfit),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: report.netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String title, String value, {bool isHeader = false, bool isBold = false, bool isNegative = false, Color? color, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isHeader || isBold ? 13 : 12,
                    fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
                    color: isHeader ? Colors.black87 : Colors.grey.shade800,
                  ),
                ),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isNegative ? Colors.red.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(ProfitLossReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue by Payment Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...report.salesByPaymentMethod.entries.map((e) {
              final pct = report.netRevenue > 0 ? (e.value / report.netRevenue) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${CurrencyFormatter.format(e.value)} (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: (pct / 100).clamp(0.0, 1.0), minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(AsyncValue<List<TopProductMetric>> topProductsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Best-Selling Products by Revenue & Profit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            topProductsAsync.when(
              data: (list) {
                if (list.isEmpty) return const Text('No sales records available.');
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = list[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                      title: Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.totalQuantity.toStringAsFixed(0)} sold', style: const TextStyle(fontSize: 11)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyFormatter.format(item.totalRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('+${CurrencyFormatter.format(item.totalProfit)} profit', style: const TextStyle(fontSize: 10, color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
