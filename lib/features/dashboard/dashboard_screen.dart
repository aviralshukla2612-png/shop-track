import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../providers/app_providers.dart';
import '../../repositories/sales_repository.dart';

class DashboardScreen extends ConsumerWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final chartAsync = ref.watch(dailySalesChartProvider);
    final topProductsAsync = ref.watch(topSellingProductsProvider);
    final shopProfile = ref.watch(shopProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Shop Track',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    shopProfile.shopName.isNotEmpty
                        ? (shopProfile.shopOwner.isNotEmpty ? '${shopProfile.shopName} • ${shopProfile.shopOwner}' : shopProfile.shopName)
                        : 'Retail Store & Business Manager',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () {
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(dailySalesChartProvider);
              ref.invalidate(topSellingProductsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Reports & Financial Statements',
            onPressed: () => onNavigate(5), // Reports
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(dailySalesChartProvider);
          ref.invalidate(topSellingProductsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Cards Grid
              metricsAsync.when(
                data: (metrics) => _buildKpiGrid(context, metrics, ref),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading dashboard: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Quick Action Shortcuts
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // 3. Weekly Sales & Gross Profit Chart
              _buildChartSection(context, chartAsync),
              const SizedBox(height: 24),

              // 4. Best Selling Products & Inventory Overview
              _buildTopProductsSection(context, ref, topProductsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, DashboardMetrics metrics, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 800 ? 1.6 : 1.35,
          children: [
            _kpiCard(
              title: "Today's Sales",
              value: CurrencyFormatter.format(metrics.todaySales),
              subtitle: "${metrics.todayTransactionsCount} transactions today",
              icon: Icons.payments,
              color: AppTheme.primaryColor,
              onTap: () => onNavigate(4), // Analytics
            ),
            _kpiCard(
              title: "Today's Gross Profit",
              value: CurrencyFormatter.format(metrics.todayGrossProfit),
              subtitle: "Net profit after COGS",
              icon: Icons.trending_up,
              color: AppTheme.successColor,
              onTap: () => onNavigate(4), // Analytics
            ),
            _kpiCard(
              title: "Month's Sales",
              value: CurrencyFormatter.format(metrics.monthSales),
              subtitle: "Gross: ${CurrencyFormatter.format(metrics.monthGrossProfit)} margin",
              icon: Icons.calendar_month,
              color: AppTheme.secondaryColor,
              onTap: () => onNavigate(4),
            ),
            _kpiCard(
              title: "Estimated Net Profit",
              value: CurrencyFormatter.format(metrics.totalEstimatedNetProfit),
              subtitle: "Gross margin minus expenses",
              icon: Icons.account_balance_wallet,
              color: metrics.totalEstimatedNetProfit >= 0 ? const Color(0xFF047857) : Colors.red,
              onTap: () => onNavigate(5),
            ),
            _kpiCard(
              title: "Shop Inventory Value",
              value: CurrencyFormatter.format(metrics.activeInventoryValue),
              subtitle: "${metrics.activeProductsCount} active SKUs stocked",
              icon: Icons.inventory_2,
              color: const Color(0xFF4338CA),
              onTap: () => onNavigate(2), // Inventory
            ),
            _kpiCard(
              title: "Low Stock Alerts",
              value: "${metrics.lowStockCount} Items",
              subtitle: metrics.lowStockCount > 0 ? "Requires purchase reorder" : "Stock levels healthy",
              icon: Icons.warning_amber_rounded,
              color: metrics.lowStockCount > 0 ? AppTheme.accentColor : Colors.green,
              isAlert: metrics.lowStockCount > 0,
              onTap: () {
                ref.read(inventoryFilterProvider.notifier).state = const InventoryFilterState(lowStockOnly: true);
                onNavigate(2); // Go to inventory with filter
              },
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: isAlert ? Colors.orange.shade50 : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isAlert ? Colors.orange.shade900 : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'title': 'Stock Inventory', 'icon': Icons.inventory_2_rounded, 'color': AppTheme.primaryColor, 'page': 2},
      {'title': 'Browse Catalogue', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF0284C7), 'page': 1},
      {'title': 'Purchase List', 'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFF7C3AED), 'page': 3},
      {'title': 'Record Expense', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFFD97706), 'page': 6},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        Row(
          children: actions.map((act) {
            final color = act['color'] as Color;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onNavigate(act['page'] as int),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 94,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(act['icon'] as IconData, color: color, size: 20),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 28,
                            child: Center(
                              child: Text(
                                act['title'] as String,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChartSection(BuildContext context, AsyncValue<List<Map<String, dynamic>>> chartAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales & Profit Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Last 7 Days (Revenue vs Gross Profit)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem('Revenue', AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    _legendItem('Gross Profit', AppTheme.accentColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: chartAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(child: Text('No transaction history yet'));
                  }

                  double maxY = 100.0;
                  for (final d in data) {
                    if ((d['sales'] as double) > maxY) maxY = (d['sales'] as double);
                  }
                  maxY = maxY * 1.25;

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = data[groupIndex];
                            final isSales = rodIndex == 0;
                            return BarTooltipItem(
                              '${isSales ? 'Sales' : 'Profit'}: ${CurrencyFormatter.format(isSales ? item['sales'] : item['profit'])}',
                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(data[idx]['day'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (val, meta) {
                              return Text(CurrencyFormatter.formatCompact(val), style: const TextStyle(fontSize: 9, color: Colors.grey));
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return BarChartGroupData(
                          x: idx,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: (item['sales'] as double),
                              color: const Color(0xFF0D5C46),
                              width: 9,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                            BarChartRodData(
                              toY: (item['profit'] as double),
                              color: const Color(0xFFD97706),
                              width: 9,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Chart error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  Widget _buildTopProductsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TopProductMetric>> topProductsAsync,
  ) {
    final filter = ref.watch(topProductsFilterProvider);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, size: 20, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Performing Products',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Dynamic sales contribution & gross margin',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => onNavigate(4), // Analytics
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Analytics', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF334155)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Dynamic Period & Metric Filter Controls
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...['Today', '7 Days', '30 Days', 'All Time'].map((p) {
                  final isSelected = filter.period == p;
                  return InkWell(
                    onTap: () => ref.read(topProductsFilterProvider.notifier).state = filter.copyWith(period: p),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0D5C46) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0D5C46) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                // Sort Toggle
                PopupMenuButton<String>(
                  tooltip: 'Change Sort Metric',
                  onSelected: (val) => ref.read(topProductsFilterProvider.notifier).state = filter.copyWith(sortBy: val),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 14, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          filter.sortBy == 'revenue' ? 'Sort: Revenue' : (filter.sortBy == 'quantity' ? 'Sort: Volume' : 'Sort: Margin'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF475569)),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'revenue', child: Text('By Total Revenue (₹)', style: TextStyle(fontSize: 12))),
                    PopupMenuItem(value: 'quantity', child: Text('By Volume Sold (Units)', style: TextStyle(fontSize: 12))),
                    PopupMenuItem(value: 'profit', child: Text('By Gross Profit Margin (₹)', style: TextStyle(fontSize: 12))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Dynamic Products List
            topProductsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.bar_chart_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No sales recorded for ${filter.period}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'New transactions from POS will dynamically update here instantly.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 14, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, idx) {
                    final item = list[idx];
                    return InkWell(
                      onTap: () => _showTopProductDetail(context, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Rank Badge
                            _buildRankBadge(idx),
                            const SizedBox(width: 8),

                            // Real Product Thumbnail
                            ProductImageWidget(
                              localImagePath: item.localImagePath,
                              imageUrl: item.imageUrl,
                              productName: item.productName,
                              category: item.category ?? 'General',
                              width: 44,
                              height: 44,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 10),

                            // Product Title & Metadata (Supports 2 Lines - No more ugly cutoff!)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${item.totalQuantity.toStringAsFixed(0)} units sold',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                      ),
                                      if (item.currentStock != null) ...[
                                        const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                                        if (item.currentStock! <= 5)
                                          Text(
                                            'Low: ${item.currentStock!.toStringAsFixed(0)} left',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                          )
                                        else
                                          Text(
                                            '${item.currentStock!.toStringAsFixed(0)} in stock',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF10B981)),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Revenue & Gross Margin Pill
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(item.totalRevenue),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${CurrencyFormatter.format(item.totalProfit)} (${item.marginPercentage.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D5C46),
                                    ),
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
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error loading top products: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int idx) {
    if (idx == 0) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Center(
          child: Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
        ),
      );
    } else if (idx == 1) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF94A3B8)),
        ),
        child: const Center(
          child: Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF475569))),
        ),
      );
    } else if (idx == 2) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFFB923C)),
        ),
        child: const Center(
          child: Text('3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFC2410C))),
        ),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      ),
    );
  }

  void _showTopProductDetail(BuildContext context, TopProductMetric item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductImageWidget(
                    localImagePath: item.localImagePath,
                    imageUrl: item.imageUrl,
                    productName: item.productName,
                    category: item.category ?? 'General',
                    width: 52,
                    height: 52,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        if (item.category != null)
                          Text(item.category!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol('Revenue', CurrencyFormatter.format(item.totalRevenue)),
                    _metricCol('Volume', '${item.totalQuantity.toStringAsFixed(0)} units'),
                    _metricCol('Gross Profit', CurrencyFormatter.format(item.totalProfit)),
                    _metricCol('Margin', '${item.marginPercentage.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C46),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onNavigate(2); // Go to Inventory
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('View in Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricCol(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
