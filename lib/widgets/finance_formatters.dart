import 'package:intl/intl.dart';

import '../models/transaction.dart';

class FinanceFormatters {
  FinanceFormatters._();

  static final _usd = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
  static final _lbp = NumberFormat.currency(symbol: 'LBP ', decimalDigits: 0);
  static final _compactUsd = NumberFormat.compactCurrency(
    symbol: r'$',
    decimalDigits: 1,
  );
  static String localeCode = 'en';

  static String usd(double value) => _usd.format(value);

  static String compactUsd(double value) => _compactUsd.format(value);

  static String lbp(double value) => _lbp.format(value);

  static String percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  static String date(DateTime value) =>
      DateFormat('MMM d, yyyy', localeCode).format(value);

  static String shortDate(DateTime value) =>
      DateFormat('MMM d', localeCode).format(value);

  static String monthYear(DateTime value) =>
      DateFormat('MMM yyyy', localeCode).format(value);

  static String dateTime(DateTime value) =>
      DateFormat('MMM d, yyyy - h:mm a', localeCode).format(value);

  static String amount(FinancialTransaction transaction) {
    if (transaction.currency == CurrencyCode.lbp) {
      return lbp(transaction.amount);
    }
    return usd(transaction.amount);
  }

  static String convertedAmount(
    FinancialTransaction transaction,
    double exchangeRate,
  ) {
    if (transaction.currency == CurrencyCode.usd) {
      return lbp(transaction.amount * exchangeRate);
    }
    if (transaction.currency == CurrencyCode.lbp) {
      return usd(transaction.amount / exchangeRate);
    }
    return '';
  }
}
