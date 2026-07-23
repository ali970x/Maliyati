import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/accounting_rules.dart';
import 'package:finance_tracker/services/label_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet choices remain distinct for credit and debt settlements', () {
    expect(LabelNormalizer.wallet('Cash'), 'My Wallet');
    expect(LabelNormalizer.wallet('My Wallet'), 'My Wallet');
    expect(LabelNormalizer.wallet('Whish Money'), 'Whish Money');
  });

  test('reserveables are tracked separately and do not change net balance', () {
    final date = DateTime(2026, 7, 13);
    final transactions = [
      _transaction(date, TransactionType.income, 200),
      _transaction(date, TransactionType.expense, 50),
      _transaction(
        date,
        TransactionType.reserveable,
        75,
      ).copyWith(raw: const {'accounting_role': 'split_income_receivable'}),
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

  test('credit and debt settlement preserve Whish Money as the wallet', () {
    final credit =
        _transaction(
          DateTime(2026, 7, 13),
          TransactionType.reserveable,
          50,
        ).copyWith(
          id: 'credit-1',
          paymentMethod: 'Whish Money',
          raw: const {'wallet_id': 'Whish Money', 'wallet_direction': '-1'},
        );
    final normalized = AccountingRules.normalize(credit);
    final settlement = AccountingRules.settlementEntry(
      normalized,
      walletId: 'Whish Money',
      date: DateTime(2026, 7, 14),
      amountUsd: 20,
      amountLbp: 0,
    );

    expect(normalized.walletId, 'Whish Money');
    expect(normalized.walletDirection, -1);
    expect(settlement.walletId, 'Whish Money');
    expect(settlement.walletDirection, 1);
  });

  test('service credit and debt stay outside both wallet balances', () {
    final credit = AccountingRules.moveWallet(
      _transaction(DateTime(2026, 7, 23), TransactionType.reserveable, 30),
      walletId: 'Service',
    );
    final debt = AccountingRules.moveWallet(
      _transaction(DateTime(2026, 7, 23), TransactionType.debt, 20),
      walletId: 'Service',
    );
    final wallets = WalletSummary.fromTransactions(
      [credit, debt],
      cashOpeningUsd: 100,
      cashOpeningLbp: 0,
      wishOpeningUsd: 50,
      wishOpeningLbp: 0,
      ignoredCashTransactionIds: const {},
      ignoredWishTransactionIds: const {},
    );

    expect(LabelNormalizer.wallet('service'), 'Service');
    expect(credit.walletDirection, 0);
    expect(debt.walletDirection, 0);
    expect(wallets.cash.balanceUsd, 100);
    expect(wallets.wish.balanceUsd, 50);
  });

  test(
    'moving a credit transfers its wallet impact without duplicating it',
    () {
      final original =
          _transaction(
            DateTime(2026, 7, 23),
            TransactionType.reserveable,
            36,
          ).copyWith(
            id: 'credit-move',
            paymentMethod: 'My Wallet',
            raw: const {'wallet_id': 'My Wallet', 'wallet_direction': '-1'},
          );
      final moved = AccountingRules.moveWallet(
        original,
        walletId: 'Whish Money',
      );

      expect(moved.paymentMethod, 'Whish Money');
      expect(moved.walletId, 'Whish Money');

      final before = WalletSummary.fromTransactions(
        [original],
        cashOpeningUsd: 100,
        cashOpeningLbp: 0,
        wishOpeningUsd: 40,
        wishOpeningLbp: 0,
        ignoredCashTransactionIds: const {},
        ignoredWishTransactionIds: const {},
      );
      final after = WalletSummary.fromTransactions(
        [moved],
        cashOpeningUsd: 100,
        cashOpeningLbp: 0,
        wishOpeningUsd: 40,
        wishOpeningLbp: 0,
        ignoredCashTransactionIds: const {},
        ignoredWishTransactionIds: const {},
      );

      expect(before.cash.balanceUsd, 64);
      expect(before.wish.balanceUsd, 40);
      expect(after.cash.balanceUsd, 100);
      expect(after.wish.balanceUsd, 4);
    },
  );

  test('a linked collection is never treated as a standalone credit', () {
    final collection =
        _transaction(
          DateTime(2026, 7, 23),
          TransactionType.reserveable,
          10,
        ).copyWith(
          raw: const {
            'linked_transaction_id': 'credit-original',
            // Simulates older Firestore rows without accounting_role.
          },
        );

    expect(collection.isSettlementEntry, isTrue);
  });

  test('an LBP collection reduces a USD credit using the exchange rate', () {
    final credit = _transaction(
      DateTime(2026, 7, 23),
      TransactionType.reserveable,
      25,
    ).copyWith(raw: const {'affects_receivables': 'true'});

    final allocation = AccountingRules.settlementAllocation(
      credit,
      paidUsd: 0,
      paidLbp: 890000,
      exchangeRate: 89000,
    );
    final updated = AccountingRules.applySettlement(
      credit,
      amountUsd: allocation.amountUsd,
      amountLbp: allocation.amountLbp,
    );

    expect(allocation.amountUsd, 10);
    expect(updated.remainingAmountUsd, 15);
    expect(updated.isSettled, isFalse);
  });

  test('credit and debt flows are reflected in income and expense totals', () {
    final date = DateTime(2026, 7, 23);
    final credit = _transaction(
      date,
      TransactionType.reserveable,
      40,
    ).copyWith(id: 'credit-1', raw: const {'wallet_direction': '-1'});
    final collection = AccountingRules.settlementEntry(
      credit,
      walletId: 'My Wallet',
      date: date,
      amountUsd: 40,
      amountLbp: 0,
    );
    final debt = _transaction(
      date,
      TransactionType.debt,
      70,
    ).copyWith(id: 'debt-1', raw: const {'wallet_direction': '1'});
    final repayment = AccountingRules.settlementEntry(
      debt,
      walletId: 'Whish Money',
      date: date,
      amountUsd: 70,
      amountLbp: 0,
    );

    final summary = FinancialSummary.fromTransactions([
      credit,
      collection,
      debt,
      repayment,
    ], exchangeRate: 89000);

    expect(summary.totalExpense, 110);
    expect(summary.totalIncome, 110);
    expect(summary.totalNet, 0);
  });
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
