import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/budget_plan.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing categories receive practical default budget groups', () {
    expect(
      BudgetBucketDetails.infer('Inventory & Supplies', {
        TransactionType.expense,
      }),
      BudgetBucket.investment,
    );
    expect(
      BudgetBucketDetails.infer('Utilities & Bills', {TransactionType.expense}),
      BudgetBucket.commitments,
    );
    expect(
      BudgetBucketDetails.infer('Home & Groceries', {TransactionType.expense}),
      BudgetBucket.expenses,
    );
    expect(
      BudgetBucketDetails.infer('Wallet Transfers', {TransactionType.transfer}),
      BudgetBucket.commitments,
    );
  });

  test('category rules persist a manually selected budget group', () {
    const rule = CategoryRule(
      name: 'Custom',
      statuses: {TransactionType.expense},
      budgetBucket: BudgetBucket.investment,
      budgetExcluded: true,
    );

    final restored = CategoryRule.fromJson(rule.toJson());

    expect(restored.effectiveBudgetBucket, BudgetBucket.investment);
    expect(restored.budgetExcluded, isTrue);
  });

  test('budget plan allocates income 33 33 34 and tracks actual spending', () {
    final transactions = [
      _transaction(TransactionType.income, 'Salary & Other Income', 1000),
      _transaction(TransactionType.expense, 'Inventory & Supplies', 100),
      _transaction(TransactionType.expense, 'Utilities & Bills', 200),
      _transaction(TransactionType.expense, 'Home & Groceries', 50),
    ];

    final summary = BudgetPlanCalculator.calculate(
      transactions: transactions,
      exchangeRate: 89000,
      settings: BudgetPlanSettings.defaults(),
      bucketForTransaction: (transaction) =>
          BudgetBucketDetails.infer(transaction.category, {transaction.type}),
    );

    expect(summary.totalAllocatedIncomeUsd, 1000);
    expect(summary.forBucket(BudgetBucket.investment).allocatedUsd, 330);
    expect(summary.forBucket(BudgetBucket.investment).spentUsd, 100);
    expect(summary.forBucket(BudgetBucket.commitments).allocatedUsd, 330);
    expect(summary.forBucket(BudgetBucket.commitments).spentUsd, 200);
    expect(summary.forBucket(BudgetBucket.expenses).allocatedUsd, 340);
    expect(summary.forBucket(BudgetBucket.expenses).spentUsd, 50);
  });

  test('income can be excluded from automatic budget allocation', () {
    final excludedIncome = _transaction(
      TransactionType.income,
      'Other Income',
      100,
    ).copyWith(raw: const {'budget_split_333334': 'false'});

    final summary = BudgetPlanCalculator.calculate(
      transactions: [excludedIncome],
      exchangeRate: 89000,
      settings: BudgetPlanSettings.defaults(),
      bucketForTransaction: (_) => BudgetBucket.expenses,
    );

    expect(summary.totalAllocatedIncomeUsd, 0);
  });

  test('custom group names and percentages survive serialization', () {
    final settings = BudgetPlanSettings(
      names: const {
        BudgetBucket.investment: 'Growth',
        BudgetBucket.commitments: 'Bills',
        BudgetBucket.expenses: 'Daily life',
      },
      percentages: const {
        BudgetBucket.investment: 40,
        BudgetBucket.commitments: 35,
        BudgetBucket.expenses: 25,
      },
    );

    final restored = BudgetPlanSettings.fromJson(settings.toJson());

    expect(restored.nameFor(BudgetBucket.investment), 'Growth');
    expect(restored.percentageFor(BudgetBucket.commitments), 35);
    expect(restored.totalPercentage, 100);
  });

  test(
    'unassigned category spending stays visible outside the three groups',
    () {
      final expense = _transaction(
        TransactionType.expense,
        'Special expense',
        75,
      );

      final summary = BudgetPlanCalculator.calculate(
        transactions: [expense],
        exchangeRate: 89000,
        settings: BudgetPlanSettings.defaults(),
        bucketForTransaction: (_) => null,
      );

      expect(summary.unassignedSpendingUsd, 75);
      expect(summary.unassignedTransactionCount, 1);
      expect(summary.unassignedCategorySpending['Special expense'], 75);
    },
  );
}

FinancialTransaction _transaction(
  TransactionType type,
  String category,
  double amount,
) => FinancialTransaction(
  date: DateTime(2026, 7, 29),
  hasDate: true,
  type: type,
  category: category,
  description: category,
  currency: CurrencyCode.usd,
  amount: amount,
  paymentMethod: 'My Wallet',
  notes: '',
  raw: const {},
);
