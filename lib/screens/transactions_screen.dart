import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../widgets/app_states.dart';
import '../widgets/filter_pill.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

enum TransactionSort { newest, oldest, highestAmount, lowestAmount }

enum TransactionTypeFilter { all, income, expense }

enum TransactionCurrencyFilter { all, usd, lbp }

extension TransactionSortLabel on TransactionSort {
  String get label {
    switch (this) {
      case TransactionSort.newest:
        return 'Newest';
      case TransactionSort.oldest:
        return 'Oldest';
      case TransactionSort.highestAmount:
        return 'Highest amount';
      case TransactionSort.lowestAmount:
        return 'Lowest amount';
    }
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  TransactionCurrencyFilter _currencyFilter = TransactionCurrencyFilter.all;
  String? _categoryFilter;
  TransactionSort _sort = TransactionSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final transactions = _filteredTransactions(controller);
    final strings = controller.strings;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: _Filters(
              controller: controller,
              searchController: _searchController,
              typeFilter: _typeFilter,
              currencyFilter: _currencyFilter,
              categoryFilter: _categoryFilter,
              sort: _sort,
              onChanged: () => setState(() {}),
              onTypeChanged: (value) => setState(() => _typeFilter = value),
              onCurrencyChanged: (value) =>
                  setState(() => _currencyFilter = value),
              onCategoryChanged: (value) =>
                  setState(() => _categoryFilter = value),
              onSortChanged: (value) => setState(() => _sort = value),
            ),
          ),
          if (controller.isLoading && !controller.hasData)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (transactions.isEmpty)
            SizedBox(
              height: 360,
              child: AppEmptyState(
                icon: Icons.manage_search_rounded,
                title: strings.noMatchingTransactions,
                message: strings.tryChangingFilters,
              ),
            )
          else ...[
            _ResultsSummary(
              transactions: transactions,
              exchangeRate: controller.exchangeRate,
              strings: strings,
            ),
            const SizedBox(height: 4),
          ],
          if (!controller.isLoading || controller.hasData)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = AppResponsive.isWideWeb(context);
                final outerPadding = isWide ? 24.0 : 0.0;
                final gap = isWide ? 16.0 : 0.0;
                final available = constraints.maxWidth - outerPadding * 2;
                final columns = isWide && available >= 1400 ? 3 : 2;
                final cardWidth = isWide
                    ? (available - gap * (columns - 1)) / columns
                    : constraints.maxWidth;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: outerPadding),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: 0,
                    children: [
                      for (final transaction in transactions)
                        SizedBox(
                          width: cardWidth,
                          child: TransactionCard(
                            transaction: transaction,
                            exchangeRate: controller.exchangeRate,
                            strings: controller.strings,
                            margin: isWide
                                ? const EdgeInsets.symmetric(vertical: 6)
                                : const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TransactionDetailScreen(
                                    controller: controller,
                                    transaction: transaction,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<FinancialTransaction> _filteredTransactions(
    DashboardController controller,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final results = controller.periodTransactions.where((transaction) {
      switch (_typeFilter) {
        case TransactionTypeFilter.income:
          if (!transaction.isIncome) {
            return false;
          }
        case TransactionTypeFilter.expense:
          if (!transaction.isExpense) {
            return false;
          }
        case TransactionTypeFilter.all:
      }

      switch (_currencyFilter) {
        case TransactionCurrencyFilter.usd:
          if (transaction.currency != CurrencyCode.usd) {
            return false;
          }
        case TransactionCurrencyFilter.lbp:
          if (transaction.currency != CurrencyCode.lbp) {
            return false;
          }
        case TransactionCurrencyFilter.all:
      }
      if (_categoryFilter != null && transaction.category != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final searchable = [
        transaction.category,
        transaction.description,
        transaction.paymentMethod,
        transaction.notes,
        transaction.type.label,
        transaction.currency.label,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    results.sort((a, b) {
      switch (_sort) {
        case TransactionSort.newest:
          return b.date.compareTo(a.date);
        case TransactionSort.oldest:
          return a.date.compareTo(b.date);
        case TransactionSort.highestAmount:
          return b
              .amountInUsd(controller.exchangeRate)
              .compareTo(a.amountInUsd(controller.exchangeRate));
        case TransactionSort.lowestAmount:
          return a
              .amountInUsd(controller.exchangeRate)
              .compareTo(b.amountInUsd(controller.exchangeRate));
      }
    });

    return results;
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({
    required this.transactions,
    required this.exchangeRate,
    required this.strings,
  });

  final List<FinancialTransaction> transactions;
  final double exchangeRate;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    var income = 0.0;
    var expenses = 0.0;
    for (final transaction in transactions) {
      final amount = transaction.amountInUsd(exchangeRate);
      if (transaction.isIncome) {
        income += amount;
      } else if (transaction.isExpense) {
        expenses += amount;
      }
    }
    final net = income - expenses;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.isWideWeb(context) ? 24 : 16,
        2,
        AppResponsive.isWideWeb(context) ? 24 : 16,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryPill(
              label: strings.transactionCount,
              value: '${transactions.length}',
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryPill(
              label: strings.income,
              value: FinanceFormatters.compactUsd(income),
              color: const Color(0xFF168A5B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryPill(
              label: strings.expenses,
              value: FinanceFormatters.compactUsd(expenses),
              color: const Color(0xFFC74949),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryPill(
              label: strings.netBalance,
              value: FinanceFormatters.compactUsd(net),
              color: net >= 0
                  ? const Color(0xFF0F766E)
                  : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.controller,
    required this.searchController,
    required this.typeFilter,
    required this.currencyFilter,
    required this.categoryFilter,
    required this.sort,
    required this.onChanged,
    required this.onTypeChanged,
    required this.onCurrencyChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final DashboardController controller;
  final TextEditingController searchController;
  final TransactionTypeFilter typeFilter;
  final TransactionCurrencyFilter currencyFilter;
  final String? categoryFilter;
  final TransactionSort sort;
  final VoidCallback onChanged;
  final ValueChanged<TransactionTypeFilter> onTypeChanged;
  final ValueChanged<TransactionCurrencyFilter> onCurrencyChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<TransactionSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = controller.strings;
    final categories =
        controller.periodTransactions
            .map((transaction) => transaction.category)
            .toSet()
            .toList()
          ..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.isWideWeb(context) ? 24 : 16,
        AppResponsive.isWideWeb(context) ? 20 : 12,
        AppResponsive.isWideWeb(context) ? 24 : 16,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.transactions,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: controller.isLoading ? null : controller.refresh,
                tooltip: strings.refresh,
                icon: controller.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchBar(
            controller: searchController,
            hintText: strings.searchTransactions,
            leading: const Icon(Icons.search_rounded),
            trailing: searchController.text.isEmpty
                ? null
                : [
                    IconButton(
                      tooltip: strings.clear,
                      onPressed: () {
                        searchController.clear();
                        onChanged();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          PeriodFilterBar(controller: controller),
          const SizedBox(height: 12),
          _FilterPanel(
            children: [
              _SegmentedFilter<TransactionTypeFilter>(
                label: strings.type,
                values: TransactionTypeFilter.values,
                selected: typeFilter,
                labelFor: (value) => switch (value) {
                  TransactionTypeFilter.all => strings.allTypes,
                  TransactionTypeFilter.income => strings.income,
                  TransactionTypeFilter.expense => strings.expense,
                },
                iconFor: (value) => switch (value) {
                  TransactionTypeFilter.all => Icons.receipt_long_rounded,
                  TransactionTypeFilter.income => Icons.south_west_rounded,
                  TransactionTypeFilter.expense => Icons.north_east_rounded,
                },
                onSelected: onTypeChanged,
              ),
              _SegmentedFilter<TransactionCurrencyFilter>(
                label: strings.value,
                values: TransactionCurrencyFilter.values,
                selected: currencyFilter,
                labelFor: (value) => switch (value) {
                  TransactionCurrencyFilter.all => strings.allCurrencies,
                  TransactionCurrencyFilter.usd => 'USD',
                  TransactionCurrencyFilter.lbp => 'LBP',
                },
                iconFor: (value) => switch (value) {
                  TransactionCurrencyFilter.all => Icons.payments_rounded,
                  TransactionCurrencyFilter.usd => Icons.attach_money_rounded,
                  TransactionCurrencyFilter.lbp => Icons.money_rounded,
                },
                onSelected: onCurrencyChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: categoryFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.category,
                    prefixIcon: const Icon(Icons.category_rounded),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.allCategories),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<TransactionSort>(
                  initialValue: sort,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.sort,
                    prefixIcon: const Icon(Icons.sort_rounded),
                  ),
                  items: TransactionSort.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            _sortLabel(item, strings),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onSortChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sortLabel(TransactionSort sort, AppStrings strings) {
    switch (sort) {
      case TransactionSort.newest:
        return strings.newest;
      case TransactionSort.oldest:
        return strings.oldest;
      case TransactionSort.highestAmount:
        return strings.highestAmount;
      case TransactionSort.lowestAmount:
        return strings.lowestAmount;
    }
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: AppResponsive.isWideWeb(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(width: 16),
                  Expanded(child: children[index]),
                ],
              ],
            )
          : Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  children[index],
                ],
              ],
            ),
    );
  }
}

class _SegmentedFilter<T> extends StatelessWidget {
  const _SegmentedFilter({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.iconFor,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final IconData Function(T value) iconFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              Expanded(
                child: AppFilterPill(
                  label: labelFor(values[i]),
                  icon: iconFor(values[i]),
                  selected: values[i] == selected,
                  onTap: () => onSelected(values[i]),
                ),
              ),
              if (i != values.length - 1) const SizedBox(width: 7),
            ],
          ],
        ),
      ],
    );
  }
}
