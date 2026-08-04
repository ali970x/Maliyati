import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';

class CategoryOverviewScreen extends StatefulWidget {
  const CategoryOverviewScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<CategoryOverviewScreen> createState() => _CategoryOverviewScreenState();
}

class _CategoryOverviewScreenState extends State<CategoryOverviewScreen> {
  late DateTime _month;
  String? _account;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  List<FinancialTransaction> get _transactions => widget.controller.transactions
      .where(
        (item) =>
            item.isExpense &&
            item.date.year == _month.year &&
            item.date.month == _month.month &&
            (_account == null ||
                item.walletId.trim().toLowerCase() == _account!.toLowerCase()),
      )
      .toList();

  Map<String, double> get _totals {
    final values = <String, double>{};
    for (final item in _transactions) {
      values.update(
        item.category,
        (value) => value + item.amountInUsd(widget.controller.exchangeRate),
        ifAbsent: () => item.amountInUsd(widget.controller.exchangeRate),
      );
    }
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = _totals;
    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    return Scaffold(
      appBar: AppBar(title: const Text('Category overview')),
      body: ListView(
        padding: AppResponsive.pagePadding(context).copyWith(bottom: 28),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Center(
                  child: TextButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _account,
            decoration: const InputDecoration(
              labelText: 'Account',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All accounts'),
              ),
              ...widget.controller.financeAccounts.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.name,
                  child: Text(item.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _account = value),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox.square(
              dimension: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 78,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      sections: totals.isEmpty
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                showTitle: false,
                                radius: 28,
                              ),
                            ]
                          : totals.entries.map((entry) {
                              return PieChartSectionData(
                                value: entry.value,
                                color: widget.controller.categoryColorFor(
                                  entry.key,
                                ),
                                showTitle: false,
                                radius: 28,
                              );
                            }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Expenses', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(
                        FinanceFormatters.usd(total),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${_transactions.length} transactions'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (totals.isEmpty)
            const _EmptyMonth()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.12,
                  children: totals.entries.map((entry) {
                    final color = widget.controller.categoryColorFor(entry.key);
                    final percent = total <= 0 ? 0 : entry.value / total * 100;
                    return Material(
                      color: color.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: color.withValues(alpha: 0.24)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showCategory(entry.key),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  widget.controller.categoryIconFor(entry.key),
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(FinanceFormatters.usd(entry.value)),
                              Text('${percent.toStringAsFixed(1)}%'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose any day in the month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  void _showCategory(String category) {
    final items =
        _transactions.where((item) => item.category == category).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .62,
          minChildSize: .35,
          maxChildSize: .92,
          builder: (context, scrollController) => ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    widget.controller.categoryIconFor(category),
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    category,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text('${items.length} transactions'),
                );
              }
              final item = items[index - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.description),
                subtitle: Text(
                  '${DateFormat('MMM d').format(item.date)}  •  ${item.walletId}',
                ),
                trailing: Text(
                  FinanceFormatters.usd(
                    item.amountInUsd(widget.controller.exchangeRate),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(
          Icons.donut_large_rounded,
          size: 52,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 10),
        const Text('No expenses in this month.'),
      ],
    ),
  );
}
