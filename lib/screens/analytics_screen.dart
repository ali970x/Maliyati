import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../widgets/app_states.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_card.dart';
import 'budget_plan_screen.dart';
import 'transaction_detail_screen.dart';

class _WalletAnalyticsCard extends StatelessWidget {
  const _WalletAnalyticsCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final wallets = controller.walletSummary;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WalletAnalyticValue(
                    label: 'My Wallet',
                    usd: wallets.cash.balanceUsd,
                    lbp: wallets.cash.balanceLbp,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletAnalyticValue(
                    label: 'Whish Money',
                    usd: wallets.wish.balanceUsd,
                    lbp: wallets.wish.balanceLbp,
                    color: const Color(0xFF6D28D9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletAnalyticValue extends StatelessWidget {
  const _WalletAnalyticValue({
    required this.label,
    required this.usd,
    required this.lbp,
    required this.color,
  });
  final String label;
  final double usd;
  final double lbp;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          FinanceFormatters.usd(usd),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          FinanceFormatters.lbp(lbp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final transactions = controller.periodTransactions;
    final summary = controller.summary;
    final strings = controller.strings;

    if (controller.isLoading && !controller.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: AppResponsive.pagePadding(context),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.analytics,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _CategoryReportsScreen(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.summarize_rounded),
                label: const Text('More reports'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PeriodFilterBar(controller: controller),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BudgetPlanScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.donut_large_rounded),
            label: const Text('Open 33/33/34 budget plan'),
          ),
          const SizedBox(height: 12),
          _WalletAnalyticsCard(controller: controller),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            SizedBox(
              height: 360,
              child: AppEmptyState(
                icon: Icons.insights_rounded,
                title: strings.noAnalyticsYet,
                message: strings.loadTransactionsForCharts,
              ),
            )
          else ...[
            ResponsivePair(
              gap: 16,
              first: _AnalyticsSummaryCard(summary: summary, strings: strings),
              second: _KeyInsightsCard(
                transactions: transactions,
                summary: summary,
                strings: strings,
              ),
            ),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _CategoryRankingCard(
                controller: controller,
                title: strings.expenseCategoryRanking,
                emptyLabel: strings.noCategoryData,
                data: summary.categoryExpenseTotals,
                color: const Color(0xFFC74949),
                icon: Icons.payments_rounded,
                transactionsForKey: (category) => _transactionsForCategory(
                  controller,
                  category,
                  type: TransactionType.expense,
                ),
              ),
              second: _CategoryRankingCard(
                controller: controller,
                title: strings.incomeCategoryRanking,
                emptyLabel: strings.noCategoryData,
                data: summary.categoryIncomeTotals,
                color: const Color(0xFF168A5B),
                icon: Icons.savings_rounded,
                transactionsForKey: (category) => _transactionsForCategory(
                  controller,
                  category,
                  type: TransactionType.income,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _CategoryRankingCard(
                controller: controller,
                title: strings.incomePaymentMethodRanking,
                emptyLabel: strings.noPaymentMethodData,
                data: _paymentMethodTotals(
                  transactions,
                  controller.exchangeRate,
                  strings,
                  type: TransactionType.income,
                ),
                color: const Color(0xFF168A5B),
                icon: Icons.credit_card_rounded,
                transactionsForKey: (paymentMethod) =>
                    _transactionsForPaymentMethod(
                      controller,
                      paymentMethod,
                      strings,
                      type: TransactionType.income,
                    ),
              ),
              second: _CategoryRankingCard(
                controller: controller,
                title: strings.expensePaymentMethodRanking,
                emptyLabel: strings.noPaymentMethodData,
                data: _paymentMethodTotals(
                  transactions,
                  controller.exchangeRate,
                  strings,
                  type: TransactionType.expense,
                ),
                color: const Color(0xFFC74949),
                icon: Icons.account_balance_wallet_rounded,
                transactionsForKey: (paymentMethod) =>
                    _transactionsForPaymentMethod(
                      controller,
                      paymentMethod,
                      strings,
                      type: TransactionType.expense,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _CategoryRankingCard(
                controller: controller,
                title: 'Credit payment method ranking',
                emptyLabel: strings.noPaymentMethodData,
                data: _paymentMethodTotals(
                  transactions,
                  controller.exchangeRate,
                  strings,
                  type: TransactionType.reserveable,
                ),
                color: const Color(0xFFD97706),
                icon: Icons.pending_actions_rounded,
                transactionsForKey: (paymentMethod) =>
                    _transactionsForPaymentMethod(
                      controller,
                      paymentMethod,
                      strings,
                      type: TransactionType.reserveable,
                    ),
              ),
              second: _CategoryRankingCard(
                controller: controller,
                title: 'Debt payment method ranking',
                emptyLabel: strings.noPaymentMethodData,
                data: _paymentMethodTotals(
                  transactions,
                  controller.exchangeRate,
                  strings,
                  type: TransactionType.debt,
                ),
                color: const Color(0xFF395EE9),
                icon: Icons.account_balance_rounded,
                transactionsForKey: (paymentMethod) =>
                    _transactionsForPaymentMethod(
                      controller,
                      paymentMethod,
                      strings,
                      type: TransactionType.debt,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _BestWorstDays(summary: summary, strings: strings),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _TrendChart(summary: summary, strings: strings),
              second: _DailyTrendBreakdown(summary: summary, strings: strings),
              firstFlex: 3,
              secondFlex: 2,
            ),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _CategoryChart(
                title: strings.expensesByCategory,
                noDataLabel: strings.noData,
                data: summary.categoryExpenseTotals,
                palette: _expensePalette,
              ),
              second: _CategoryChart(
                title: strings.incomeByCategory,
                noDataLabel: strings.noData,
                data: summary.categoryIncomeTotals,
                palette: _incomePalette,
              ),
            ),
            const SizedBox(height: 12),
            ResponsivePair(
              gap: 16,
              first: _GroupedSummary(
                title: strings.weeklySummary,
                values: _groupTransactions(
                  transactions,
                  controller.exchangeRate,
                  (date) => _weekKey(date, strings),
                ),
              ),
              second: _GroupedSummary(
                title: strings.monthlySummary,
                values: _groupTransactions(
                  transactions,
                  controller.exchangeRate,
                  _monthKey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _expensePalette = [
    Color(0xFFC74949),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  static const _incomePalette = [
    Color(0xFF168A5B),
    Color(0xFF2563EB),
    Color(0xFF14B8A6),
    Color(0xFF9333EA),
    Color(0xFF84CC16),
  ];

  static String _weekKey(DateTime date, dynamic strings) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    return strings.weekOf(DateFormat('MMM d').format(start));
  }

  static String _monthKey(DateTime date) => DateFormat('MMM yyyy').format(date);

  static Map<String, double> _groupTransactions(
    List<FinancialTransaction> transactions,
    double exchangeRate,
    String Function(DateTime date) keyForDate,
  ) {
    final values = <String, double>{};
    for (final transaction in transactions) {
      final isIncome = transaction.affectsIncomeStats;
      final isExpense = transaction.affectsExpenseStats;
      if (!isIncome && !isExpense) {
        continue;
      }
      final signed = isIncome
          ? transaction.amountInUsd(exchangeRate)
          : -transaction.amountInUsd(exchangeRate);
      values.update(
        keyForDate(transaction.date),
        (value) => value + signed,
        ifAbsent: () => signed,
      );
    }
    return values;
  }

  static Map<String, double> _paymentMethodTotals(
    List<FinancialTransaction> transactions,
    double exchangeRate,
    AppStrings strings, {
    required TransactionType type,
  }) {
    final values = <String, double>{};
    for (final transaction in transactions) {
      if (!_matchesAccountingType(transaction, type)) {
        continue;
      }
      final key = transaction.paymentMethod.trim().isEmpty
          ? strings.unspecifiedPaymentMethod
          : transaction.paymentMethod.trim();
      values.update(
        key,
        (value) => value + transaction.amountInUsd(exchangeRate),
        ifAbsent: () => transaction.amountInUsd(exchangeRate),
      );
    }
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  static List<FinancialTransaction> _transactionsForCategory(
    DashboardController controller,
    String category, {
    required TransactionType type,
  }) {
    return controller.periodTransactions.where((transaction) {
      return transaction.category == category &&
          _matchesAccountingType(transaction, type);
    }).toList()..sort(
      (a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date),
    );
  }

  static List<FinancialTransaction> _transactionsForPaymentMethod(
    DashboardController controller,
    String paymentMethod,
    AppStrings strings, {
    required TransactionType type,
  }) {
    return controller.periodTransactions.where((transaction) {
      if (!_matchesAccountingType(transaction, type)) {
        return false;
      }
      final key = transaction.paymentMethod.trim().isEmpty
          ? strings.unspecifiedPaymentMethod
          : transaction.paymentMethod.trim();
      return key == paymentMethod;
    }).toList()..sort(
      (a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date),
    );
  }

  static bool _matchesAccountingType(
    FinancialTransaction transaction,
    TransactionType type,
  ) => switch (type) {
    TransactionType.income => transaction.affectsIncomeStats,
    TransactionType.expense => transaction.affectsExpenseStats,
    TransactionType.reserveable =>
      transaction.isCredit && !transaction.isSettlementEntry,
    TransactionType.debt =>
      transaction.isDebt && !transaction.isSettlementEntry,
    TransactionType.transfer => transaction.isTransfer,
    TransactionType.unknown => transaction.type == TransactionType.unknown,
  };
}

class _CategoryReportsScreen extends StatelessWidget {
  const _CategoryReportsScreen({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final strings = controller.strings;
    return Scaffold(
      appBar: AppBar(title: const Text('Category reports')),
      body: ListView(
        padding: AppResponsive.pagePadding(context),
        children: [
          Text(
            'Reports by category',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('For ${periodFilterLabel(controller)}'),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BudgetPlanScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.donut_large_rounded),
            label: const Text('33/33/34 budget plan'),
          ),
          const SizedBox(height: 12),
          _CategoryRankingCard(
            controller: controller,
            title: strings.expenseCategoryRanking,
            emptyLabel: strings.noCategoryData,
            data: summary.categoryExpenseTotals,
            color: const Color(0xFFC74949),
            icon: Icons.payments_rounded,
            transactionsForKey: (category) =>
                AnalyticsScreen._transactionsForCategory(
                  controller,
                  category,
                  type: TransactionType.expense,
                ),
          ),
          const SizedBox(height: 12),
          _CategoryRankingCard(
            controller: controller,
            title: strings.incomeCategoryRanking,
            emptyLabel: strings.noCategoryData,
            data: summary.categoryIncomeTotals,
            color: const Color(0xFF168A5B),
            icon: Icons.savings_rounded,
            transactionsForKey: (category) =>
                AnalyticsScreen._transactionsForCategory(
                  controller,
                  category,
                  type: TransactionType.income,
                ),
          ),
          const SizedBox(height: 12),
          _CategoryChart(
            title: strings.expensesByCategory,
            noDataLabel: strings.noData,
            data: summary.categoryExpenseTotals,
            palette: AnalyticsScreen._expensePalette,
          ),
          const SizedBox(height: 12),
          _CategoryChart(
            title: strings.incomeByCategory,
            noDataLabel: strings.noData,
            data: summary.categoryIncomeTotals,
            palette: AnalyticsScreen._incomePalette,
          ),
        ],
      ),
    );
  }
}

class _KeyInsightsCard extends StatelessWidget {
  const _KeyInsightsCard({
    required this.transactions,
    required this.summary,
    required this.strings,
  });

  final List<FinancialTransaction> transactions;
  final FinancialSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final notesCount = transactions
        .where((transaction) => transaction.notes.trim().isNotEmpty)
        .length;
    final topExpenseValue = summary.categoryExpenseTotals.isEmpty
        ? 0.0
        : summary.categoryExpenseTotals.values.first;
    final topExpenseShare = summary.totalExpense <= 0
        ? 0.0
        : topExpenseValue / summary.totalExpense;

    return _ChartPanel(
      title: strings.keyInsights,
      height: null,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.category_rounded,
                  label: strings.topExpenseCategory,
                  value: summary.topExpenseCategory == 'No data'
                      ? strings.noData
                      : summary.topExpenseCategory,
                  color: const Color(0xFFC74949),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightTile(
                  icon: Icons.percent_rounded,
                  label: strings.topCategoryShare,
                  value: FinanceFormatters.percent(topExpenseShare),
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.sticky_note_2_rounded,
                  label: strings.notesCoverage,
                  value: strings.notesCount(notesCount, transactions.length),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightTile(
                  icon: Icons.calendar_today_rounded,
                  label: strings.averageDailyExpense,
                  value: FinanceFormatters.usd(summary.averageDailyExpense),
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRankingCard extends StatelessWidget {
  const _CategoryRankingCard({
    required this.controller,
    required this.title,
    required this.emptyLabel,
    required this.data,
    required this.color,
    required this.icon,
    required this.transactionsForKey,
  });

  final DashboardController controller;
  final String title;
  final String emptyLabel;
  final Map<String, double> data;
  final Color color;
  final IconData icon;
  final List<FinancialTransaction> Function(String key) transactionsForKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.take(7).toList();
    final maxValue = entries.isEmpty ? 1.0 : entries.first.value;

    return _ChartPanel(
      title: title,
      height: null,
      child: entries.isEmpty
          ? Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final entry in entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showRankingTransactions(context, entry.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, size: 18, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                FinanceFormatters.usd(entry.value),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: maxValue <= 0 ? 0 : entry.value / maxValue,
                              minHeight: 8,
                              color: color,
                              backgroundColor: color.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showRankingTransactions(BuildContext context, String title) {
    final strings = controller.strings;
    final transactions = transactionsForKey(title);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            strings.rowsLoaded(transactions.length),
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: transactions.length,
                  itemBuilder: (itemContext, index) {
                    final transaction = transactions[index];
                    return TransactionCard(
                      transaction: transaction,
                      exchangeRate: controller.exchangeRate,
                      strings: strings,
                      categoryColor: controller.categoryColorFor(
                        transaction.category,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                transaction.isCredit || transaction.isDebt
                                ? SettlementWorkspaceScreen(
                                    controller: controller,
                                    transaction: transaction,
                                  )
                                : TransactionDetailScreen(
                                    controller: controller,
                                    transaction: transaction,
                                  ),
                          ),
                        );
                      },
                      onLongPress: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                transaction.isCredit || transaction.isDebt
                                ? SettlementWorkspaceScreen(
                                    controller: controller,
                                    transaction: transaction,
                                    showAccountDetails: true,
                                  )
                                : TransactionDetailScreen(
                                    controller: controller,
                                    transaction: transaction,
                                    startEditing: true,
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsSummaryCard extends StatelessWidget {
  const _AnalyticsSummaryCard({required this.summary, required this.strings});

  final FinancialSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netColor = summary.totalNet >= 0
        ? const Color(0xFF168A5B)
        : const Color(0xFFC74949);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.selectedPeriod,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: strings.income,
                    value: FinanceFormatters.usd(summary.totalIncome),
                    color: const Color(0xFF168A5B),
                    icon: Icons.south_west_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetric(
                    label: strings.expenses,
                    value: FinanceFormatters.usd(summary.totalExpense),
                    color: const Color(0xFFC74949),
                    icon: Icons.north_east_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetric(
                    label: strings.reserveables,
                    value: FinanceFormatters.usd(summary.totalReserveable),
                    color: const Color(0xFFD97706),
                    icon: Icons.request_quote_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryMetric(
              label: strings.netBalance,
              value: FinanceFormatters.usd(summary.totalNet),
              color: netColor,
              icon: summary.totalNet >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              wide: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style:
                        (wide
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BestWorstDays extends StatelessWidget {
  const _BestWorstDays({required this.summary, required this.strings});

  final FinancialSummary summary;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = summary.dailyNetTotals.entries.toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final best = entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = entries.reduce((a, b) => a.value <= b.value ? a : b);

    return Row(
      children: [
        Expanded(
          child: _SmallPanel(
            title: strings.bestDay,
            value: FinanceFormatters.usd(best.value),
            subtitle: FinanceFormatters.date(best.key),
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFF168A5B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallPanel(
            title: strings.worstDay,
            value: FinanceFormatters.usd(worst.value),
            subtitle: FinanceFormatters.date(worst.key),
            icon: Icons.warning_rounded,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _SmallPanel extends StatelessWidget {
  const _SmallPanel({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.summary, required this.strings});

  final FinancialSummary summary;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = summary.dailyNetTotals.keys.toList();
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    final netSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final incomeSpots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      netSpots.add(FlSpot(i.toDouble(), summary.dailyNetTotals[day] ?? 0));
      expenseSpots.add(
        FlSpot(i.toDouble(), summary.dailyExpenseTotals[day] ?? 0),
      );
      incomeSpots.add(
        FlSpot(i.toDouble(), summary.dailyIncomeTotals[day] ?? 0),
      );
    }

    final maxY = [
      ...netSpots.map((spot) => spot.y.abs()),
      ...expenseSpots.map((spot) => spot.y.abs()),
      ...incomeSpots.map((spot) => spot.y.abs()),
    ].fold<double>(1, math.max);

    return _ChartPanel(
      title: strings.dailyTrend,
      height: 250,
      child: LineChart(
        LineChartData(
          minY: -maxY,
          maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(1, days.length / 4).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    FinanceFormatters.shortDate(days[index]),
                    style: theme.textTheme.labelSmall,
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) => Text(
                  FinanceFormatters.compactUsd(value),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
          lineBarsData: [
            _line(netSpots, const Color(0xFF2563EB)),
            _line(incomeSpots, const Color(0xFF168A5B)),
            _line(expenseSpots, const Color(0xFFC74949)),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 3,
      isCurved: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _DailyTrendBreakdown extends StatelessWidget {
  const _DailyTrendBreakdown({required this.summary, required this.strings});

  final FinancialSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = summary.dailyNetTotals.keys
        .toList()
        .reversed
        .take(10)
        .toList();

    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    return _ChartPanel(
      title: strings.dailyBreakdown,
      height: null,
      child: Column(
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      FinanceFormatters.shortDate(day),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _DailyAmountPill(
                      label: strings.income,
                      value: summary.dailyIncomeTotals[day] ?? 0,
                      color: const Color(0xFF168A5B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _DailyAmountPill(
                      label: strings.expenses,
                      value: summary.dailyExpenseTotals[day] ?? 0,
                      color: const Color(0xFFC74949),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _DailyAmountPill(
                      label: strings.netBalance,
                      value: summary.dailyNetTotals[day] ?? 0,
                      color: (summary.dailyNetTotals[day] ?? 0) >= 0
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFC74949),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyAmountPill extends StatelessWidget {
  const _DailyAmountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              FinanceFormatters.compactUsd(value),
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

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({
    required this.title,
    required this.noDataLabel,
    required this.data,
    required this.palette,
  });

  final String title;
  final String noDataLabel;
  final Map<String, double> data;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.take(6).toList();

    if (entries.isEmpty) {
      return _ChartPanel(
        title: title,
        height: 120,
        child: Center(
          child: Text(noDataLabel, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return _ChartPanel(
      title: title,
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: palette[i % palette.length],
                      radius: 58,
                      title: FinanceFormatters.compactUsd(entries[i].value),
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (var i = 0; i < entries.length; i++)
                _LegendItem(
                  color: palette[i % palette.length],
                  label: entries[i].key,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _GroupedSummary extends StatelessWidget {
  const _GroupedSummary({required this.title, required this.values});

  final String title;
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList().reversed.take(6).toList();

    return _ChartPanel(
      title: title,
      height: null,
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    FinanceFormatters.usd(entry.value),
                    style: TextStyle(
                      color: entry.value >= 0
                          ? const Color(0xFF168A5B)
                          : const Color(0xFFC74949),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.child,
    required this.height,
  });

  final String title;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}
