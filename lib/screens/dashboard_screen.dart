import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';
import '../widgets/app_states.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/metric_card.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/transaction_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TransactionType? _selectedTransactionType;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final strings = controller.strings;
    if (controller.isLoading && !controller.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && !controller.hasData) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: strings.couldNotLoadSheet,
        message: controller.errorMessage!,
        action: FilledButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.tryAgain),
        ),
      );
    }

    if (!controller.hasData) {
      return AppEmptyState(
        icon: Icons.table_chart_rounded,
        title: strings.noTransactionsYet,
        message: strings.noValidRows,
        action: FilledButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.refresh),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: AppResponsive.pagePadding(context),
        children: [
          _Header(controller: controller),
          const SizedBox(height: 14),
          PeriodFilterBar(controller: controller),
          const SizedBox(height: 16),
          ResponsivePair(
            firstFlex: 3,
            secondFlex: 2,
            first: _NetBalance(controller: controller),
            second: _SummaryGrid(
              controller: controller,
              selectedType: _selectedTransactionType,
              onTypeSelected: (type) {
                setState(() {
                  _selectedTransactionType = _selectedTransactionType == type
                      ? null
                      : type;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          _SelectedTransactionsSection(
            controller: controller,
            selectedType: _selectedTransactionType,
          ),
          const SizedBox(height: 12),
          if (AppResponsive.isWideWeb(context))
            ResponsivePair(
              first: _ExpenseFocusCard(controller: controller),
              second: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _QuickStats(controller: controller),
                ),
              ),
              firstFlex: 3,
              secondFlex: 2,
            )
          else
            _ExpenseFocusCard(controller: controller),
          if (controller.transactions.any(
            (transaction) => !transaction.hasDate,
          )) ...[
            const SizedBox(height: 12),
            _UndatedNotice(controller: controller),
          ],
          if (!AppResponsive.isWideWeb(context)) ...[
            const SizedBox(height: 12),
            _QuickStats(controller: controller),
          ],
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 14),
            _InlineWarning(message: controller.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _SelectedTransactionsSection extends StatelessWidget {
  const _SelectedTransactionsSection({
    required this.controller,
    required this.selectedType,
  });

  final DashboardController controller;
  final TransactionType? selectedType;

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    final theme = Theme.of(context);

    if (selectedType == null) {
      return const SizedBox.shrink();
    }

    final transactions =
        controller.periodTransactions
            .where((transaction) => transaction.type == selectedType)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final (color, icon, title, emptyMessage) = switch (selectedType!) {
      TransactionType.income => (
        const Color(0xFF168A5B),
        Icons.south_west_rounded,
        strings.showIncomeTransactions,
        strings.noIncomeInPeriod,
      ),
      TransactionType.expense => (
        const Color(0xFFC74949),
        Icons.north_east_rounded,
        strings.showExpenseTransactions,
        strings.noExpensesInPeriod,
      ),
      TransactionType.reserveable => (
        const Color(0xFFD97706),
        Icons.request_quote_rounded,
        strings.showReserveableTransactions,
        strings.noReserveablesInPeriod,
      ),
      TransactionType.unknown => (
        theme.colorScheme.onSurfaceVariant,
        Icons.help_outline_rounded,
        strings.transactions,
        strings.noTransactionsYet,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${transactions.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.58,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              emptyMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = AppResponsive.isWideWeb(context);
              final columns = isWide && constraints.maxWidth >= 1400 ? 3 : 2;
              final cardWidth = isWide
                  ? (constraints.maxWidth - 16 * (columns - 1)) / columns
                  : constraints.maxWidth;
              return Wrap(
                spacing: isWide ? 16 : 0,
                runSpacing: 0,
                children: [
                  for (final transaction in transactions)
                    SizedBox(
                      width: cardWidth,
                      child: TransactionCard(
                        transaction: transaction,
                        exchangeRate: controller.exchangeRate,
                        strings: strings,
                        margin: const EdgeInsets.symmetric(vertical: 6),
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
              );
            },
          ),
      ],
    );
  }
}

class _ExpenseFocusCard extends StatelessWidget {
  const _ExpenseFocusCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = controller.strings;
    final summary = controller.summary;
    final rows = _dailyExpenseRows(
      controller.periodTransactions,
      controller.exchangeRate,
    );
    final totalExpenseInLbp = summary.totalExpense * controller.exchangeRate;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC74949).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFFC74949),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.expensesFocus,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        periodFilterLabel(controller),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ExpensePill(
                  label: strings.expenseUsd,
                  value: FinanceFormatters.usd(summary.totalExpenseUsd),
                  color: const Color(0xFFC74949),
                ),
                _ExpensePill(
                  label: strings.expenseLbp,
                  value: FinanceFormatters.lbp(summary.totalExpenseLbp),
                  color: const Color(0xFFF97316),
                ),
                _ExpensePill(
                  label: strings.totalAsUsd,
                  value: FinanceFormatters.usd(summary.totalExpense),
                  color: const Color(0xFF2563EB),
                ),
                _ExpensePill(
                  label: strings.totalAsLbp,
                  value: FinanceFormatters.lbp(totalExpenseInLbp),
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatRow(
              icon: Icons.today_rounded,
              title: strings.averageDailyExpense,
              value:
                  '${FinanceFormatters.usd(summary.averageDailyExpense)} / ${FinanceFormatters.lbp(summary.averageDailyExpense * controller.exchangeRate)}',
            ),
            const SizedBox(height: 12),
            Text(
              strings.dailyExpenses,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                strings.noExpensesInPeriod,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...rows.map((row) => _DailyExpenseRow(row: row)),
          ],
        ),
      ),
    );
  }

  List<_DailyExpenseTotal> _dailyExpenseRows(
    List<FinancialTransaction> transactions,
    double exchangeRate,
  ) {
    final totals = <DateTime, _DailyExpenseTotal>{};
    for (final transaction in transactions) {
      if (!transaction.isExpense || !transaction.hasDate) {
        continue;
      }
      final day = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final current = totals[day] ?? _DailyExpenseTotal(day: day);
      totals[day] = current.add(transaction, exchangeRate);
    }

    final rows = totals.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    return rows;
  }
}

class _UndatedNotice extends StatelessWidget {
  const _UndatedNotice({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = controller.strings;
    final count = controller.transactions
        .where((transaction) => !transaction.hasDate)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.undatedRows(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensePill extends StatelessWidget {
  const _ExpensePill({
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
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
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

class _DailyExpenseRow extends StatelessWidget {
  const _DailyExpenseRow({required this.row});

  final _DailyExpenseTotal row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FinanceFormatters.date(row.day),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${FinanceFormatters.usd(row.usd)} + ${FinanceFormatters.lbp(row.lbp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            FinanceFormatters.usd(row.totalUsd),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC74949),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyExpenseTotal {
  const _DailyExpenseTotal({
    required this.day,
    this.usd = 0,
    this.lbp = 0,
    this.totalUsd = 0,
  });

  final DateTime day;
  final double usd;
  final double lbp;
  final double totalUsd;

  _DailyExpenseTotal add(
    FinancialTransaction transaction,
    double exchangeRate,
  ) {
    final amountUsd = transaction.amountInUsd(exchangeRate);
    return _DailyExpenseTotal(
      day: day,
      usd: transaction.currency == CurrencyCode.usd
          ? usd + transaction.amount
          : usd,
      lbp: transaction.currency == CurrencyCode.lbp
          ? lbp + transaction.amount
          : lbp,
      totalUsd: totalUsd + amountUsd,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = controller.strings;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.dashboard,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.lastUpdated == null
                    ? strings.readyToSync
                    : strings.updated(
                        FinanceFormatters.dateTime(controller.lastUpdated!),
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
    );
  }
}

class _NetBalance extends StatelessWidget {
  const _NetBalance({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = controller.summary;
    final comparison = controller.comparison;
    final strings = controller.strings;
    final isPositive = summary.totalNet >= 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF0F766E), const Color(0xFF2563EB)]
              : [const Color(0xFFB91C1C), const Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                strings.netBalance,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              FinanceFormatters.usd(summary.totalNet),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MiniFigure(
                label: strings.usdNet,
                value: FinanceFormatters.usd(summary.totalNetUsd),
              ),
              _MiniFigure(
                label: strings.lbpNet,
                value: FinanceFormatters.lbp(summary.totalNetLbp),
              ),
              if (comparison != null)
                _MiniFigure(
                  label: strings.vsPrevious,
                  value:
                      '${comparison.netChange >= 0 ? '+' : ''}${FinanceFormatters.percent(comparison.netChange)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniFigure extends StatelessWidget {
  const _MiniFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.controller,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final DashboardController controller;
  final TransactionType? selectedType;
  final ValueChanged<TransactionType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final strings = controller.strings;
    final incomeColor = selectedType == TransactionType.income
        ? const Color(0xFF0F766E)
        : const Color(0xFF168A5B);
    final expenseColor = selectedType == TransactionType.expense
        ? const Color(0xFFB91C1C)
        : const Color(0xFFC74949);
    final reserveableColor = selectedType == TransactionType.reserveable
        ? const Color(0xFFB45309)
        : const Color(0xFFD97706);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppResponsive.isWideWeb(context) ? 3 : 2;
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        final height = AppResponsive.isWideWeb(context) ? 190.0 : 150.0;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              height: height,
              child: MetricCard(
                title: strings.income,
                value: FinanceFormatters.usd(summary.totalIncome),
                subtitle:
                    '${FinanceFormatters.compactUsd(summary.totalIncomeUsd)} + ${FinanceFormatters.lbp(summary.totalIncomeLbp)}',
                icon: Icons.south_west_rounded,
                color: incomeColor,
                onTap: () => onTypeSelected(TransactionType.income),
              ),
            ),
            SizedBox(
              width: width,
              height: height,
              child: MetricCard(
                title: strings.expenses,
                value: FinanceFormatters.usd(summary.totalExpense),
                subtitle:
                    '${FinanceFormatters.compactUsd(summary.totalExpenseUsd)} + ${FinanceFormatters.lbp(summary.totalExpenseLbp)}',
                icon: Icons.north_east_rounded,
                color: expenseColor,
                onTap: () => onTypeSelected(TransactionType.expense),
              ),
            ),
            SizedBox(
              width: width,
              height: height,
              child: MetricCard(
                title: strings.reserveables,
                value: FinanceFormatters.usd(summary.totalReserveable),
                subtitle:
                    '${FinanceFormatters.compactUsd(summary.totalReserveableUsd)} + ${FinanceFormatters.lbp(summary.totalReserveableLbp)}',
                icon: Icons.request_quote_rounded,
                color: reserveableColor,
                onTap: () => onTypeSelected(TransactionType.reserveable),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final largestExpense = summary.largestExpense;
    final largestIncome = summary.largestIncome;
    final largestReserveable = summary.largestReserveable;
    final strings = controller.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.quickStats,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _StatRow(
          icon: Icons.percent_rounded,
          title: strings.expenseRatio,
          value: FinanceFormatters.percent(summary.expenseRatio),
        ),
        _StatRow(
          icon: Icons.category_rounded,
          title: strings.topExpenseCategory,
          value: summary.topExpenseCategory == 'No data'
              ? strings.noData
              : summary.topExpenseCategory,
        ),
        _StatRow(
          icon: Icons.savings_rounded,
          title: strings.topIncomeCategory,
          value: summary.topIncomeCategory == 'No data'
              ? strings.noData
              : summary.topIncomeCategory,
        ),
        _StatRow(
          icon: Icons.request_quote_rounded,
          title: strings.topReserveableCategory,
          value: summary.topReserveableCategory == 'No data'
              ? strings.noData
              : summary.topReserveableCategory,
        ),
        _StatRow(
          icon: Icons.calendar_today_rounded,
          title: strings.averageDailySpend,
          value: FinanceFormatters.usd(summary.averageDailyExpense),
        ),
        _StatRow(
          icon: Icons.receipt_long_rounded,
          title: strings.transactionCount,
          value: '${summary.transactionCount}',
        ),
        _StatRow(
          icon: Icons.arrow_upward_rounded,
          title: strings.largestExpense,
          value: largestExpense == null
              ? strings.noData
              : FinanceFormatters.amount(largestExpense),
        ),
        _StatRow(
          icon: Icons.arrow_downward_rounded,
          title: strings.largestIncome,
          value: largestIncome == null
              ? strings.noData
              : FinanceFormatters.amount(largestIncome),
        ),
        _StatRow(
          icon: Icons.schedule_send_rounded,
          title: strings.largestReserveable,
          value: largestReserveable == null
              ? strings.noData
              : FinanceFormatters.amount(largestReserveable),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
