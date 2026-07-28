import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/accounting_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleans old transliterated and title-like expense categories', () {
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.expense,
          category: 'Masrouf bayt',
          title: '10 kg tomatoes',
        ),
      ).category,
      'Home & Groceries',
    );
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.expense,
          category: 'Deodorant Nivea',
          title: 'Deodorant Nivea',
        ),
      ).category,
      'Personal Care',
    );
  });

  test('groups mobile shop income into practical English categories', () {
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.income,
          category: 'Income internet',
          title: 'Cable payment',
        ),
      ).category,
      'Recharge & Telecom',
    );
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.income,
          category: 'new category',
          title: 'Phone screen repair',
        ),
      ).category,
      'Repair Services',
    );
  });

  test('uses one clear category for credits, payables, and transfers', () {
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.reserveable,
          category: 'Friend payment',
          title: 'Customer credit',
        ),
      ).category,
      'Customer Receivables',
    );
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.debt,
          category: 'Loan',
          title: 'Supplier balance',
        ),
      ).category,
      'Supplier Payables',
    );
    expect(
      AccountingRules.normalize(
        _transaction(
          type: TransactionType.transfer,
          category: 'Whish transfer',
          title: 'Wallet transfer',
        ),
      ).category,
      'Wallet Transfers',
    );
  });

  test('keeps a category typed explicitly in the manual form', () {
    final transaction = _transaction(
      type: TransactionType.expense,
      category: 'صيانة شاشات',
      title: 'Samsung screen',
    ).copyWith(raw: const {'custom_category': 'true'});

    expect(AccountingRules.normalize(transaction).category, 'صيانة شاشات');
  });
}

FinancialTransaction _transaction({
  required TransactionType type,
  required String category,
  required String title,
}) {
  return FinancialTransaction(
    id: 'test-1',
    date: DateTime(2026, 7, 28),
    hasDate: true,
    type: type,
    category: category,
    description: title,
    currency: CurrencyCode.usd,
    amount: 10,
    paymentMethod: 'My Wallet',
    notes: '',
    raw: const {},
  );
}
