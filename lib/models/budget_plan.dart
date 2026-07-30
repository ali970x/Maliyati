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

class BudgetPlanSettings {
  const BudgetPlanSettings({required this.names, required this.percentages});

  factory BudgetPlanSettings.defaults() => const BudgetPlanSettings(
    names: {
      BudgetBucket.investment: 'Investment',
      BudgetBucket.commitments: 'Commitments',
      BudgetBucket.expenses: 'Expenses',
    },
    percentages: {
      BudgetBucket.investment: 33,
      BudgetBucket.commitments: 33,
      BudgetBucket.expenses: 34,
    },
  );

  final Map<BudgetBucket, String> names;
  final Map<BudgetBucket, int> percentages;

  String nameFor(BudgetBucket bucket) {
    final value = names[bucket]?.trim() ?? '';
    return value.isEmpty ? bucket.label : value;
  }

  int percentageFor(BudgetBucket bucket) =>
      (percentages[bucket] ?? bucket.percentage).clamp(0, 100).toInt();

  int get totalPercentage => BudgetBucket.values.fold(
    0,
    (total, bucket) => total + percentageFor(bucket),
  );

  Map<String, dynamic> toJson() => {
    'names': {
      for (final bucket in BudgetBucket.values) bucket.name: nameFor(bucket),
    },
    'percentages': {
      for (final bucket in BudgetBucket.values)
        bucket.name: percentageFor(bucket),
    },
  };

  factory BudgetPlanSettings.fromJson(Map<String, dynamic> json) {
    final defaults = BudgetPlanSettings.defaults();
    final rawNames = json['names'];
    final rawPercentages = json['percentages'];
    final names = <BudgetBucket, String>{};
    final percentages = <BudgetBucket, int>{};
    for (final bucket in BudgetBucket.values) {
      final name = rawNames is Map
          ? '${rawNames[bucket.name] ?? ''}'.trim()
          : '';
      final rawPercentage = rawPercentages is Map
          ? rawPercentages[bucket.name]
          : null;
      names[bucket] = name.isEmpty ? defaults.nameFor(bucket) : name;
      percentages[bucket] = rawPercentage is num
          ? rawPercentage.toInt()
          : int.tryParse('$rawPercentage') ?? defaults.percentageFor(bucket);
    }
    final settings = BudgetPlanSettings(names: names, percentages: percentages);
    return settings.totalPercentage == 100 ? settings : defaults;
  }
}

class BudgetBucketSummary {
  const BudgetBucketSummary({
    required this.bucket,
    required this.displayName,
    required this.percentage,
    required this.allocatedUsd,
    required this.spentUsd,
    required this.transactionCount,
    required this.categorySpending,
  });

  final BudgetBucket bucket;
  final String displayName;
  final int percentage;
  final double allocatedUsd;
  final double spentUsd;
  final int transactionCount;
  final Map<String, double> categorySpending;

  double get targetUsd => allocatedUsd;

  double get coveredUsd => spentUsd;

  double get remainingUsd => allocatedUsd - spentUsd;

  double get remainingRequiredUsd =>
      allocatedUsd > spentUsd ? allocatedUsd - spentUsd : 0;

  double get overUsd => spentUsd > allocatedUsd ? spentUsd - allocatedUsd : 0;

  double get coverageRatio {
    if (allocatedUsd <= 0) {
      return spentUsd > 0 ? 1 : 0;
    }
    return spentUsd / allocatedUsd;
  }

  double get progress => coverageRatio.clamp(0, 1).toDouble();

  bool get isOverBudget => spentUsd > allocatedUsd;
}

class BudgetPlanSummary {
  const BudgetPlanSummary({
    required this.settings,
    required this.totalAllocatedIncomeUsd,
    required this.buckets,
    required this.unassignedSpendingUsd,
    required this.unassignedTransactionCount,
    required this.unassignedCategorySpending,
  });

  final BudgetPlanSettings settings;
  final double totalAllocatedIncomeUsd;
  final Map<BudgetBucket, BudgetBucketSummary> buckets;
  final double unassignedSpendingUsd;
  final int unassignedTransactionCount;
  final Map<String, double> unassignedCategorySpending;

  BudgetBucketSummary forBucket(BudgetBucket bucket) => buckets[bucket]!;
}

class BudgetPlanCalculator {
  const BudgetPlanCalculator._();

  static BudgetPlanSummary calculate({
    required Iterable<FinancialTransaction> transactions,
    required double exchangeRate,
    required BudgetPlanSettings settings,
    required BudgetBucket? Function(FinancialTransaction transaction)
    bucketForTransaction,
  }) {
    var incomeUsd = 0.0;
    final spending = {for (final bucket in BudgetBucket.values) bucket: 0.0};
    final counts = {for (final bucket in BudgetBucket.values) bucket: 0};
    final categorySpending = {
      for (final bucket in BudgetBucket.values) bucket: <String, double>{},
    };
    var unassignedSpendingUsd = 0.0;
    var unassignedTransactionCount = 0;
    final unassignedCategorySpending = <String, double>{};

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
      final category = transaction.category.trim().isEmpty
          ? 'Uncategorized'
          : transaction.category.trim();
      if (bucket == null) {
        unassignedSpendingUsd += valueUsd;
        unassignedTransactionCount += 1;
        unassignedCategorySpending.update(
          category,
          (current) => current + valueUsd,
          ifAbsent: () => valueUsd,
        );
        continue;
      }
      spending[bucket] = spending[bucket]! + valueUsd;
      counts[bucket] = counts[bucket]! + 1;
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
        displayName: settings.nameFor(bucket),
        percentage: settings.percentageFor(bucket),
        allocatedUsd: incomeUsd * settings.percentageFor(bucket) / 100,
        spentUsd: spending[bucket]!,
        transactionCount: counts[bucket]!,
        categorySpending: Map.fromEntries(sortedCategories),
      );
    }
    final sortedUnassigned = unassignedCategorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return BudgetPlanSummary(
      settings: settings,
      totalAllocatedIncomeUsd: incomeUsd,
      buckets: summaries,
      unassignedSpendingUsd: unassignedSpendingUsd,
      unassignedTransactionCount: unassignedTransactionCount,
      unassignedCategorySpending: Map.fromEntries(sortedUnassigned),
    );
  }
}
