import '../database/app_database.dart';

class ProfitLossReport {
  final DateTime startDate;
  final DateTime endDate;
  final double grossSales;
  final double totalDiscounts;
  final double netRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossProfitMargin;
  final double totalOperatingExpenses;
  final double netProfit;
  final double netProfitMargin;
  final Map<String, double> expensesByCategory;
  final Map<String, double> salesByPaymentMethod;

  ProfitLossReport({
    required this.startDate,
    required this.endDate,
    required this.grossSales,
    required this.totalDiscounts,
    required this.netRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.grossProfitMargin,
    required this.totalOperatingExpenses,
    required this.netProfit,
    required this.netProfitMargin,
    required this.expensesByCategory,
    required this.salesByPaymentMethod,
  });
}

class ReportsRepository {
  Future<ProfitLossReport> generateProfitLossReport(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    // 1. Sales query
    final salesRes = await db.rawQuery('''
      SELECT 
        coalesce(sum(subtotal), 0) as gross_sales,
        coalesce(sum(discount), 0) as total_discount,
        coalesce(sum(grand_total), 0) as net_rev,
        coalesce(sum(total_cost_basis), 0) as cogs,
        coalesce(sum(gross_profit), 0) as gross_prof
      FROM sales
      WHERE created_at >= ? AND created_at <= ? AND status = 'completed'
    ''', [startStr, endStr]);

    final grossSales = (salesRes.first['gross_sales'] as num?)?.toDouble() ?? 0.0;
    final totalDiscounts = (salesRes.first['total_discount'] as num?)?.toDouble() ?? 0.0;
    final netRevenue = (salesRes.first['net_rev'] as num?)?.toDouble() ?? 0.0;
    final cogs = (salesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = (salesRes.first['gross_prof'] as num?)?.toDouble() ?? 0.0;
    final grossMargin = netRevenue > 0 ? (grossProfit / netRevenue) * 100 : 0.0;

    // 2. Expenses query
    final expRes = await db.rawQuery('''
      SELECT category, coalesce(sum(amount), 0) as total
      FROM expenses
      WHERE expense_date >= ? AND expense_date <= ?
      GROUP BY category
    ''', [startStr, endStr]);

    final expensesByCategory = <String, double>{};
    double totalExpenses = 0.0;
    for (final r in expRes) {
      final amt = (r['total'] as num).toDouble();
      expensesByCategory[r['category'].toString()] = amt;
      totalExpenses += amt;
    }

    // 3. Payment methods query
    final payRes = await db.rawQuery('''
      SELECT payment_method, coalesce(sum(grand_total), 0) as total
      FROM sales
      WHERE created_at >= ? AND created_at <= ? AND status = 'completed'
      GROUP BY payment_method
    ''', [startStr, endStr]);

    final salesByPaymentMethod = <String, double>{};
    for (final r in payRes) {
      salesByPaymentMethod[r['payment_method'].toString()] = (r['total'] as num).toDouble();
    }

    final netProfit = grossProfit - totalExpenses;
    final netMargin = netRevenue > 0 ? (netProfit / netRevenue) * 100 : 0.0;

    return ProfitLossReport(
      startDate: start,
      endDate: end,
      grossSales: grossSales,
      totalDiscounts: totalDiscounts,
      netRevenue: netRevenue,
      costOfGoodsSold: cogs,
      grossProfit: grossProfit,
      grossProfitMargin: grossMargin,
      totalOperatingExpenses: totalExpenses,
      netProfit: netProfit,
      netProfitMargin: netMargin,
      expensesByCategory: expensesByCategory,
      salesByPaymentMethod: salesByPaymentMethod,
    );
  }
}
