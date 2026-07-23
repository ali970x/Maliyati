import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reserveables are tracked separately and do not change net balance', () {
    final date = DateTime(2026, 7, 13);
    final transactions = [
      _transaction(date, TransactionType.income, 200),
      _transaction(date, TransactionType.expense, 50),
      _transaction(date, TransactionType.reserveable, 75),
    ];

    final summary = FinancialSummary.fromTransactions(
      transactions,
      exchangeRate: 89000,
    );

    expect(summary.totalIncome, 200);
    expect(summary.totalExpense, 50);
    expect(summary.totalReserveable, 75);
    expect(summary.totalNet, 150);
    expect(summary.categoryReserveableTotals['Test'], 75);
  });

  test(
    'partial debt and credit settlements count only the remaining balance',
    () {
      final date = DateTime(2026, 7, 13);
      final credit = _transaction(date, TransactionType.reserveable, 100)
          .copyWith(
            raw: const {
              'affects_receivables': 'true',
              'settlement_status': 'partial',
              'settled_amount_usd': '35',
            },
          );
      final debt = _transaction(date, TransactionType.debt, 80).copyWith(
        raw: const {
          'affects_payables': 'true',
          'settlement_status': 'partial',
          'settled_amount_usd': '20',
        },
      );

      final summary = FinancialSummary.fromTransactions([
        credit,
        debt,
      ], exchangeRate: 89000);

      expect(summary.totalReserveable, 65);
      expect(summary.totalDebt, 60);
    },
  );
}

FinancialTransaction _transaction(
  DateTime date,
  TransactionType type,
  double amount,
) {
  return FinancialTransaction(
    date: date,
    hasDate: true,
    type: type,
    category: 'Test',
    description: 'Test transaction',
    currency: CurrencyCode.usd,
    amount: amount,
    paymentMethod: 'Cash',
    notes: '',
    raw: const {},
  );
}
