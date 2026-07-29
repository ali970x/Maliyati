import 'transaction.dart';

enum BudgetBucket { investment, commitments, expenses }

extension BudgetBucketDetails on BudgetBucket {
  String get label => switch (this) {
    BudgetBucket.investment => 'Investment',
    BudgetBucket.commitments => 'Commitments',
    BudgetBucket.expenses => 'Expenses',
  };

  int get percentage => switch (this) {
    BudgetBucket.investment => 33,
    BudgetBucket.commitments => 33,
    BudgetBucket.expenses => 34,
  };

  int get colorValue => switch (this) {
    BudgetBucket.investment => 0xFF2563EB,
    BudgetBucket.commitments => 0xFFDC2626,
    BudgetBucket.expenses => 0xFF16A34A,
  };

  static BudgetBucket fromName(String value) {
    final normalized = value.trim().toLowerCase();
    return BudgetBucket.values.firstWhere(
      (bucket) =>
          bucket.name == normalized || bucket.label.toLowerCase() == normalized,
      orElse: () => BudgetBucket.expenses,
    );
  }

  static BudgetBucket infer(String category, Set<TransactionType> statuses) {
    final normalized = category.trim().toLowerCase();
    if (_containsAny(normalized, const [
      'inventory',
      'supplies',
      'shop maintenance',
      'product',
      'recharge',
      'telecom',
      'repair',
      'perfume',
      'service income',
      'wallet funding',
      'sales',
      'salary',
      'other income',
      'investment',
    ])) {
      return BudgetBucket.investment;
    }
    if (_containsAny(normalized, const [
      'utilities',
      'bills',
      'subscription',
      'fees',
      'commission',
      'debt',
      'payable',
      'receivable',
      'transfer',
      'transaction',
      'commitment',
    ])) {
      return BudgetBucket.commitments;
    }
    if (statuses.contains(TransactionType.transfer) ||
        statuses.contains(TransactionType.debt) ||
        statuses.contains(TransactionType.reserveable)) {
      return BudgetBucket.commitments;
    }
    return BudgetBucket.expenses;
  }

  static bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);
}

class BudgetBucketSummary {
  const BudgetBucketSummary({
    required this.bucket,
    required this.allocatedUsd,
    required this.spentUsd,
    required this.transactionCount,
    required this.categorySpending,
  });

  final BudgetBucket bucket;
  final double allocatedUsd;
  final double spentUsd;
  final int transactionCount;
  final Map<String, double> categorySpending;

  double get remainingUsd => allocatedUsd - spentUsd;

  double get progress =>
      allocatedUsd <= 0 ? 0 : (spentUsd / allocatedUsd).clamp(0, 1);

  bool get isOverBudget => spentUsd > allocatedUsd;
}

class BudgetPlanSummary {
  const BudgetPlanSummary({
    required this.totalAllocatedIncomeUsd,
    required this.buckets,
  });

  final double totalAllocatedIncomeUsd;
  final Map<BudgetBucket, BudgetBucketSummary> buckets;

  BudgetBucketSummary forBucket(BudgetBucket bucket) => buckets[bucket]!;
}

class BudgetPlanCalculator {
  const BudgetPlanCalculator._();

  static BudgetPlanSummary calculate({
    required Iterable<FinancialTransaction> transactions,
    required double exchangeRate,
    required BudgetBucket Function(FinancialTransaction transaction)
    bucketForTransaction,
  }) {
    var incomeUsd = 0.0;
    final spending = {for (final bucket in BudgetBucket.values) bucket: 0.0};
    final counts = {for (final bucket in BudgetBucket.values) bucket: 0};
    final categorySpending = {
      for (final bucket in BudgetBucket.values) bucket: <String, double>{},
    };

    for (final transaction in transactions) {
      if (transaction.isDeleted || transaction.isArchived) {
        continue;
      }
      final valueUsd = transaction.amountInUsd(exchangeRate);
      final allocationEnabled =
          transaction.raw['budget_split_333334']?.trim().toLowerCase() !=
          'false';
      if (transaction.affectsIncomeStats && allocationEnabled) {
        incomeUsd += valueUsd;
      }
      if (!transaction.affectsExpenseStats) {
        continue;
      }
      final bucket = bucketForTransaction(transaction);
      spending[bucket] = spending[bucket]! + valueUsd;
      counts[bucket] = counts[bucket]! + 1;
      final category = transaction.category.trim().isEmpty
          ? 'Uncategorized'
          : transaction.category.trim();
      categorySpending[bucket]!.update(
        category,
        (current) => current + valueUsd,
        ifAbsent: () => valueUsd,
      );
    }

    final summaries = <BudgetBucket, BudgetBucketSummary>{};
    for (final bucket in BudgetBucket.values) {
      final sortedCategories = categorySpending[bucket]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      summaries[bucket] = BudgetBucketSummary(
        bucket: bucket,
        allocatedUsd: incomeUsd * bucket.percentage / 100,
        spentUsd: spending[bucket]!,
        transactionCount: counts[bucket]!,
        categorySpending: Map.fromEntries(sortedCategories),
      );
    }
    return BudgetPlanSummary(
      totalAllocatedIncomeUsd: incomeUsd,
      buckets: summaries,
    );
  }
}
