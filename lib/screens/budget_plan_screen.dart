import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/budget_plan.dart';
import '../models/transaction.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';

class BudgetPlanScreen extends StatefulWidget {
  const BudgetPlanScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<BudgetPlanScreen> createState() => _BudgetPlanScreenState();
}

class _BudgetPlanScreenState extends State<BudgetPlanScreen> {
  final Set<BudgetBucket> _expanded = {BudgetBucket.investment};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Budget Builder'),
      actions: [
        IconButton(
          tooltip: 'Customize plan',
          onPressed: _openEditor,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final summary = widget.controller.budgetPlanSummary;
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
              'Build your own income plan. Tap a section to explore it, or use Customize to rename groups and move categories.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 14),
            PeriodFilterBar(controller: widget.controller),
            const SizedBox(height: 14),
            _AllocationOverview(summary: summary, onCustomize: _openEditor),
            const SizedBox(height: 14),
            for (final bucket in BudgetBucket.values) ...[
              _BudgetBucketPanel(
                summary: summary.forBucket(bucket),
                categoryNames: widget.controller.categoryRules
                    .where(
                      (rule) =>
                          !rule.budgetExcluded &&
                          rule.effectiveBudgetBucket == bucket,
                    )
                    .map((rule) => rule.name)
                    .toList(growable: false),
                expanded: _expanded.contains(bucket),
                onToggle: () => setState(() {
                  if (!_expanded.add(bucket)) {
                    _expanded.remove(bucket);
                  }
                }),
                onManage: _openEditor,
              ),
              const SizedBox(height: 12),
            ],
            if (summary.unassignedCategorySpending.isNotEmpty)
              _UnassignedPanel(summary: summary, onManage: _openEditor),
          ],
        );
      },
    ),
  );

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetPlanEditorScreen(controller: widget.controller),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }
}

class _AllocationOverview extends StatelessWidget {
  const _AllocationOverview({required this.summary, required this.onCustomize});

  final BudgetPlanSummary summary;
  final VoidCallback onCustomize;

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
        Row(
          children: [
            const Icon(Icons.donut_large_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Income available to plan',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Customize',
              onPressed: onCustomize,
              icon: const Icon(Icons.edit_outlined),
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
                    flex: summary.settings.percentageFor(bucket) == 0
                        ? 1
                        : summary.settings.percentageFor(bucket),
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
                    '${summary.settings.nameFor(bucket)} ${summary.settings.percentageFor(bucket)}%',
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
    required this.expanded,
    required this.onToggle,
    required this.onManage,
  });

  final BudgetBucketSummary summary;
  final List<String> categoryNames;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onManage;

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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Row(
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
                        summary.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${summary.percentage}% of included income',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                Text(
                  FinanceFormatters.usd(summary.allocatedUsd),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: expanded ? .5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
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
          if (expanded) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Categories in this group',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
        ],
      ),
    );
  }
}

class _UnassignedPanel extends StatelessWidget {
  const _UnassignedPanel({required this.summary, required this.onManage});

  final BudgetPlanSummary summary;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Unassigned spending',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              FinanceFormatters.usd(summary.unassignedSpendingUsd),
              style: const TextStyle(
                color: Color(0xFFD97706),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${summary.unassignedTransactionCount} transactions are outside the plan.',
          style: const TextStyle(color: Color(0xFF7C5A19)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final entry in summary.unassignedCategorySpending.entries)
              Chip(
                label: Text(
                  '${entry.key} | ${FinanceFormatters.usd(entry.value)}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onManage,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Assign categories'),
          ),
        ),
      ],
    ),
  );
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

class BudgetPlanEditorScreen extends StatefulWidget {
  const BudgetPlanEditorScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<BudgetPlanEditorScreen> createState() => _BudgetPlanEditorScreenState();
}

class _BudgetPlanEditorScreenState extends State<BudgetPlanEditorScreen> {
  late List<CategoryRule> _rules;
  late final Map<BudgetBucket, TextEditingController> _nameControllers;
  late final Map<BudgetBucket, TextEditingController> _percentageControllers;
  late final Map<String, BudgetBucket?> _assignments;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.budgetPlanSettings;
    _rules = widget.controller.categoryRules.toList();
    _nameControllers = {
      for (final bucket in BudgetBucket.values)
        bucket: TextEditingController(text: settings.nameFor(bucket)),
    };
    _percentageControllers = {
      for (final bucket in BudgetBucket.values)
        bucket: TextEditingController(
          text: settings.percentageFor(bucket).toString(),
        ),
    };
    _assignments = {
      for (final rule in _rules)
        rule.name: rule.budgetExcluded ? null : rule.effectiveBudgetBucket,
    };
  }

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentages = {
      for (final bucket in BudgetBucket.values) bucket: _percentageFor(bucket),
    };
    final total = percentages.values.fold<int>(0, (sum, value) => sum + value);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize budget'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: AppResponsive.pagePadding(context),
        children: [
          _EditorTotalBar(total: total, percentages: percentages),
          const SizedBox(height: 14),
          for (final bucket in BudgetBucket.values) ...[
            _buildGroupEditor(bucket),
            const SizedBox(height: 12),
          ],
          _buildUnassigned(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save budget plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupEditor(BudgetBucket bucket) {
    final color = Color(bucket.colorValue);
    final assigned = _rules
        .where((rule) => _assignments[rule.name] == bucket)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .45), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_bucketIcon(bucket), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameControllers[bucket],
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _percentageControllers[bucket],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Percent',
                    suffixText: '%',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${assigned.length} categories',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addCategory(bucket),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New category'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a category to add it here. Tap it again to remove it.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF667085)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final rule in _rules)
                FilterChip(
                  label: Text(rule.name),
                  selected: _assignments[rule.name] == bucket,
                  selectedColor: color.withValues(alpha: .14),
                  checkmarkColor: color,
                  side: BorderSide(
                    color: _assignments[rule.name] == bucket
                        ? color
                        : const Color(0xFFD7DCE3),
                  ),
                  onSelected: (selected) => setState(
                    () => _assignments[rule.name] = selected ? bucket : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnassigned() {
    final unassigned = _rules
        .where((rule) => _assignments[rule.name] == null)
        .toList(growable: false);
    if (unassigned.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not in plan',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'These categories stay available for transactions but are not counted inside a budget group.',
            style: TextStyle(color: Color(0xFF7C5A19), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final rule in unassigned) Chip(label: Text(rule.name)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory(BudgetBucket bucket) async {
    final nameController = TextEditingController();
    var type = TransactionType.expense;
    final result = await showDialog<(String, TransactionType)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TransactionType>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Transaction type',
                ),
                items: [
                  for (final value in const [
                    TransactionType.income,
                    TransactionType.expense,
                    TransactionType.reserveable,
                    TransactionType.debt,
                    TransactionType.transfer,
                  ])
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => type = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop((name, type));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) {
      return;
    }
    final name = result.$1;
    final existing = _rules.any(
      (rule) => rule.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (existing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This category already exists.')),
      );
      return;
    }
    setState(() {
      _rules = [
        ..._rules,
        CategoryRule(name: name, statuses: {result.$2}, budgetBucket: bucket),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _assignments[name] = bucket;
    });
  }

  int _percentageFor(BudgetBucket bucket) {
    final value = int.tryParse(
      _percentageControllers[bucket]!.text.replaceAll('%', '').trim(),
    );
    return value?.clamp(0, 100).toInt() ?? 0;
  }

  Future<void> _save() async {
    final names = <BudgetBucket, String>{};
    final percentages = <BudgetBucket, int>{};
    for (final bucket in BudgetBucket.values) {
      final name = _nameControllers[bucket]!.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Every group needs a name.')),
        );
        return;
      }
      names[bucket] = name;
      percentages[bucket] = _percentageFor(bucket);
    }
    final settings = BudgetPlanSettings(names: names, percentages: percentages);
    if (settings.totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Percentages must equal 100%. Current total: ${settings.totalPercentage}%.',
          ),
        ),
      );
      return;
    }
    final updatedRules = _rules
        .map((rule) {
          final assignment = _assignments[rule.name];
          return CategoryRule(
            name: rule.name,
            statuses: rule.statuses,
            colorValue: rule.effectiveColorValue,
            budgetBucket: assignment ?? rule.effectiveBudgetBucket,
            budgetExcluded: assignment == null,
          );
        })
        .toList(growable: false);
    setState(() => _saving = true);
    try {
      await widget.controller.saveCategoryRules(updatedRules);
      await widget.controller.saveBudgetPlanSettings(settings);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _EditorTotalBar extends StatelessWidget {
  const _EditorTotalBar({required this.total, required this.percentages});

  final int total;
  final Map<BudgetBucket, int> percentages;

  @override
  Widget build(BuildContext context) {
    final valid = total == 100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valid ? const Color(0xFFECFDF3) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: valid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                valid ? Icons.check_circle_rounded : Icons.error_rounded,
                color: valid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  valid
                      ? 'Your plan is balanced at 100%'
                      : 'Current total: $total% — it must equal 100%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final bucket in BudgetBucket.values)
                    Expanded(
                      flex: percentages[bucket] == 0 ? 1 : percentages[bucket]!,
                      child: ColoredBox(color: Color(bucket.colorValue)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _bucketIcon(BudgetBucket bucket) => switch (bucket) {
  BudgetBucket.investment => Icons.trending_up_rounded,
  BudgetBucket.commitments => Icons.event_repeat_rounded,
  BudgetBucket.expenses => Icons.shopping_bag_outlined,
};
