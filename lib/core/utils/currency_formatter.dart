import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String format(num? value, {bool showDecimals = true}) {
    if (value == null) return '₹0.00';
    if (!showDecimals || value % 1 == 0) {
      return _inrNoDecimals.format(value);
    }
    return _inrFormatter.format(value);
  }

  static String formatCompact(num? value) {
    if (value == null) return '₹0';
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)} k';
    }
    return format(value);
  }

  static String formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static String formatDateOnly(DateTime dt) {
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String formatTimeOnly(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }
}
