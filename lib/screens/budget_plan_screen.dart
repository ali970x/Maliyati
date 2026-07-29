import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/budget_plan.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';

class BudgetPlanScreen extends StatelessWidget {
  const BudgetPlanScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('33/33/34 Budget plan')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final summary = controller.budgetPlanSummary;
        return ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text(
              'Income allocation',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Every included income is planned across investment, commitments, and expenses. Wallet balances remain unchanged.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 14),
            PeriodFilterBar(controller: controller),
            const SizedBox(height: 14),
            _AllocationOverview(summary: summary),
            const SizedBox(height: 14),
            for (final bucket in BudgetBucket.values) ...[
              _BudgetBucketPanel(
                summary: summary.forBucket(bucket),
                categoryNames: controller.categoryRules
                    .where((rule) => rule.effectiveBudgetBucket == bucket)
                    .map((rule) => rule.name)
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );
}

class _AllocationOverview extends StatelessWidget {
  const _AllocationOverview({required this.summary});

  final BudgetPlanSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.donut_large_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'Income available to plan',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          FinanceFormatters.usd(summary.totalAllocatedIncomeUsd),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (final bucket in BudgetBucket.values)
                  Expanded(
                    flex: bucket.percentage,
                    child: ColoredBox(color: Color(bucket.colorValue)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final bucket in BudgetBucket.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(bucket.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${bucket.label} ${bucket.percentage}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}

class _BudgetBucketPanel extends StatelessWidget {
  const _BudgetBucketPanel({
    required this.summary,
    required this.categoryNames,
  });

  final BudgetBucketSummary summary;
  final List<String> categoryNames;

  @override
  Widget build(BuildContext context) {
    final bucket = summary.bucket;
    final color = Color(bucket.colorValue);
    final remaining = summary.remainingUsd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_bucketIcon(bucket), color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bucket.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${bucket.percentage}% of included income',
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              Text(
                FinanceFormatters.usd(summary.allocatedUsd),
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BudgetValue(
                  label: 'Allocated',
                  value: summary.allocatedUsd,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BudgetValue(
                  label: 'Used',
                  value: summary.spentUsd,
                  color: const Color(0xFF475467),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BudgetValue(
                  label: summary.isOverBudget ? 'Over' : 'Remaining',
                  value: remaining.abs(),
                  color: summary.isOverBudget
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF168A5B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 9,
              color: summary.isOverBudget ? const Color(0xFFDC2626) : color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${summary.transactionCount} expense ${summary.transactionCount == 1 ? 'transaction' : 'transactions'} in this period',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text(
            'Categories in this group',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (categoryNames.isEmpty)
            const Text(
              'No categories assigned yet.',
              style: TextStyle(color: Color(0xFF667085)),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final category in categoryNames)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: .20)),
                    ),
                    child: Text(
                      summary.categorySpending.containsKey(category)
                          ? '$category · ${FinanceFormatters.usd(summary.categorySpending[category]!)}'
                          : category,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            FinanceFormatters.usd(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

IconData _bucketIcon(BudgetBucket bucket) => switch (bucket) {
  BudgetBucket.investment => Icons.trending_up_rounded,
  BudgetBucket.commitments => Icons.event_repeat_rounded,
  BudgetBucket.expenses => Icons.shopping_bag_outlined,
};
