import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/widgets/finance_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FinanceFormatters.localeCode = 'en');

  test('converts a USD transaction to LBP for the secondary amount', () {
    final converted = FinanceFormatters.convertedAmount(
      _transaction(currency: CurrencyCode.usd, amount: 8.5),
      89000,
    );

    expect(converted, contains('LBP'));
    expect(converted, contains('756,500'));
  });

  test('converts an LBP transaction to USD for the secondary amount', () {
    final converted = FinanceFormatters.convertedAmount(
      _transaction(currency: CurrencyCode.lbp, amount: 800000),
      89000,
    );

    expect(converted, contains(r'$8.99'));
  });
}

FinancialTransaction _transaction({
  required CurrencyCode currency,
  required double amount,
}) {
  return FinancialTransaction(
    date: DateTime(2026, 7, 14),
    hasDate: true,
    type: TransactionType.expense,
    category: 'Subscriptions',
    description: 'CapCut',
    currency: currency,
    amount: amount,
    paymentMethod: 'Card',
    notes: '',
    raw: const {},
  );
}
