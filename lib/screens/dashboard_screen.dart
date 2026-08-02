import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/dashboard_controller.dart';
import '../l10n/app_strings.dart';
import '../models/budget_plan.dart';
import '../models/dashboard_comparison.dart';
import '../models/dashboard_pin.dart';
import '../models/transaction.dart';
import '../services/label_normalizer.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/period_filter_bar.dart';
import '../widgets/responsive_layout.dart';
import 'add_transaction_screen.dart';
import 'budget_plan_screen.dart';
import 'transaction_detail_screen.dart';
import 'wallet_screen.dart';

enum _DashboardMetricKind { income, expense, reserveable, debit, transfer }

enum _ComparisonScope { day, week, month, selectedPeriod }

enum _MetricFocusSort {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
  mostTransactions,
  categoryName,
}

enum _CreditListMode { open, completed }

enum _DebtListMode { open, paid }

enum _WalletTimeScope { today, thisWeek, thisMonth, allTime }

enum _WalletDisplayMode { split, totalUsd, totalLbp }

String _dashboardComparisonPresetLabel(DashboardComparisonPreset preset) =>
    switch (preset) {
      DashboardComparisonPreset.previousPeriod => 'Previous selected period',
      DashboardComparisonPreset.yesterday => 'Yesterday',
      DashboardComparisonPreset.previousWeek => 'Previous week',
      DashboardComparisonPreset.previousMonth => 'Previous month',
      DashboardComparisonPreset.custom => 'Custom dates',
    };

IconData _dashboardComparisonPresetIcon(DashboardComparisonPreset preset) =>
    switch (preset) {
      DashboardComparisonPreset.previousPeriod => Icons.history_rounded,
      DashboardComparisonPreset.yesterday => Icons.today_outlined,
      DashboardComparisonPreset.previousWeek => Icons.view_week_outlined,
      DashboardComparisonPreset.previousMonth => Icons.calendar_month_outlined,
      DashboardComparisonPreset.custom => Icons.date_range_rounded,
    };

Future<void> _showDashboardComparisonPicker(
  BuildContext context,
  DashboardController controller,
) async {
  final selected = await showModalBottomSheet<DashboardComparisonPreset>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare all sections with',
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'This comparison is shared by the dashboard and every category view.',
          ),
          const SizedBox(height: 10),
          for (final preset in DashboardComparisonPreset.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_dashboardComparisonPresetIcon(preset)),
              title: Text(_dashboardComparisonPresetLabel(preset)),
              trailing: controller.dashboardComparison.preset == preset
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(sheetContext, preset),
            ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  DashboardComparisonSettings settings;
  if (selected == DashboardComparisonPreset.custom) {
    final saved = controller.dashboardComparison;
    final now = DateTime.now();
    final initialStart =
        saved.customStart ?? now.subtract(const Duration(days: 30));
    final initialEnd = saved.customEnd ?? now;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Choose comparison period',
      saveText: 'Use period',
    );
    if (range == null) {
      return;
    }
    settings = DashboardComparisonSettings(
      preset: selected,
      customStart: range.start,
      customEnd: range.end,
    );
  } else {
    settings = DashboardComparisonSettings(preset: selected);
  }
  await controller.saveDashboardComparison(settings);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Comparison updated: ${controller.dashboardComparisonLabel}',
        ),
      ),
    );
}

class _DashboardComparisonControl extends StatelessWidget {
  const _DashboardComparisonControl({
    required this.controller,
    this.light = false,
  });

  final DashboardController controller;
  final bool light;

  @override
  Widget build(BuildContext context) => Material(
    color: light
        ? Colors.white.withValues(alpha: .96)
        : const Color(0xFF0A1D2D).withValues(alpha: .88),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _showDashboardComparisonPicker(context, controller),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compare all sections',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    controller.dashboardComparisonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

double _transferTotalUsd(
  Iterable<FinancialTransaction> transactions,
  double exchangeRate,
) => transactions
    .where((transaction) => transaction.isTransfer)
    .fold<double>(
      0,
      (total, transaction) => total + transaction.amountInUsd(exchangeRate),
    );

double _transferTotalLbp(Iterable<FinancialTransaction> transactions) =>
    transactions
        .where((transaction) => transaction.isTransfer)
        .fold<double>(0, (total, transaction) => total + transaction.amountLbp);

double _percentageChange(double current, double previous) {
  if (previous == 0) {
    return current == 0 ? 0 : 1;
  }
  return (current - previous) / previous.abs();
}

DashboardPinMetric _pinMetricForKind(_DashboardMetricKind kind) =>
    switch (kind) {
      _DashboardMetricKind.income => DashboardPinMetric.income,
      _DashboardMetricKind.expense => DashboardPinMetric.expense,
      _DashboardMetricKind.reserveable => DashboardPinMetric.receivable,
      _DashboardMetricKind.debit => DashboardPinMetric.payable,
      _DashboardMetricKind.transfer => DashboardPinMetric.transfer,
    };

_DashboardMetricKind _kindForPin(DashboardPinnedItem pin) =>
    switch (pin.metric) {
      DashboardPinMetric.income => _DashboardMetricKind.income,
      DashboardPinMetric.expense => _DashboardMetricKind.expense,
      DashboardPinMetric.receivable => _DashboardMetricKind.reserveable,
      DashboardPinMetric.payable => _DashboardMetricKind.debit,
      DashboardPinMetric.transfer => _DashboardMetricKind.transfer,
    };

DashboardPinnedItem _dashboardPinFor({
  required _DashboardMetricKind kind,
  required DashboardPinComparison comparison,
  String? category,
  _CreditListMode creditMode = _CreditListMode.open,
  _DebtListMode debtMode = _DebtListMode.open,
}) {
  return DashboardPinnedItem(
    metric: _pinMetricForKind(kind),
    comparison: comparison,
    category: category,
    mode: switch (kind) {
      _DashboardMetricKind.reserveable => creditMode.name,
      _DashboardMetricKind.debit => debtMode.name,
      _ => 'all',
    },
  );
}

String _dashboardPinTitle(
  DashboardController controller,
  DashboardPinnedItem pin,
) {
  final category = pin.category?.trim();
  if (category != null && category.isNotEmpty) {
    return category;
  }
  return switch (pin.metric) {
    DashboardPinMetric.income => controller.strings.income,
    DashboardPinMetric.expense => controller.strings.expenses,
    DashboardPinMetric.receivable =>
      pin.mode == _CreditListMode.completed.name
          ? controller.strings.collectedReceivables
          : controller.strings.outstandingReceivables,
    DashboardPinMetric.payable =>
      pin.mode == _DebtListMode.paid.name
          ? controller.strings.settledPayables
          : controller.strings.outstandingPayables,
    DashboardPinMetric.transfer => 'Transfers',
  };
}

String _dashboardPinComparisonLabel(DashboardPinComparison comparison) =>
    switch (comparison) {
      DashboardPinComparison.day => 'Yesterday',
      DashboardPinComparison.week => 'Previous week',
      DashboardPinComparison.month => 'Previous month',
      DashboardPinComparison.selectedPeriod => 'Previous selected period',
    };

_ComparisonScope _comparisonScopeForPin(DashboardPinComparison comparison) =>
    switch (comparison) {
      DashboardPinComparison.day => _ComparisonScope.day,
      DashboardPinComparison.week => _ComparisonScope.week,
      DashboardPinComparison.month => _ComparisonScope.month,
      DashboardPinComparison.selectedPeriod => _ComparisonScope.selectedPeriod,
    };

extension on _WalletTimeScope {
  String get label => switch (this) {
    _WalletTimeScope.today => 'Today',
    _WalletTimeScope.thisWeek => 'This week',
    _WalletTimeScope.thisMonth => 'This month',
    _WalletTimeScope.allTime => 'All time',
  };
}

void _openMetricFocus(
  BuildContext context,
  DashboardController controller,
  _DashboardMetricKind kind, {
  required bool showCategories,
  _CreditListMode creditMode = _CreditListMode.open,
  _DebtListMode debtMode = _DebtListMode.open,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _DashboardMetricFocusScreen(
        controller: controller,
        kind: kind,
        showCategories: showCategories,
        creditMode: creditMode,
        debtMode: debtMode,
      ),
    ),
  );
}

class _PinEditorResult {
  const _PinEditorResult.save(this.comparison) : remove = false;

  const _PinEditorResult.remove()
    : comparison = DashboardPinComparison.month,
      remove = true;

  final DashboardPinComparison comparison;
  final bool remove;
}

DashboardPinnedItem? _matchingDashboardPin(
  DashboardController controller, {
  required _DashboardMetricKind kind,
  String? category,
  _CreditListMode creditMode = _CreditListMode.open,
  _DebtListMode debtMode = _DebtListMode.open,
}) {
  final draft = _dashboardPinFor(
    kind: kind,
    comparison: DashboardPinComparison.month,
    category: category,
    creditMode: creditMode,
    debtMode: debtMode,
  );
  for (final item in controller.dashboardPins) {
    if (item.identity == draft.identity) {
      return item;
    }
  }
  return null;
}

Future<void> _showDashboardPinEditor(
  BuildContext context,
  DashboardController controller, {
  required _DashboardMetricKind kind,
  String? category,
  _CreditListMode creditMode = _CreditListMode.open,
  _DebtListMode debtMode = _DebtListMode.open,
}) async {
  final draft = _dashboardPinFor(
    kind: kind,
    comparison: DashboardPinComparison.month,
    category: category,
    creditMode: creditMode,
    debtMode: debtMode,
  );
  final existing = _matchingDashboardPin(
    controller,
    kind: kind,
    category: category,
    creditMode: creditMode,
    debtMode: debtMode,
  );
  var selected = existing?.comparison ?? DashboardPinComparison.month;
  final result = await showModalBottomSheet<_PinEditorResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _kindColor(kind).withValues(alpha: .13),
                  foregroundColor: _kindColor(kind),
                  child: Icon(_kindIcon(kind)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null
                            ? 'Show on dashboard'
                            : 'Dashboard comparison',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _dashboardPinTitle(controller, draft),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${controller.dashboardPins.length}/3',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Compare with',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'The dashboard card will show this item against the period you choose.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in DashboardPinComparison.values)
                  ChoiceChip(
                    selected: selected == option,
                    label: Text(_dashboardPinComparisonLabel(option)),
                    onSelected: (_) => setSheetState(() => selected = option),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (existing != null) ...[
                  IconButton.filledTonal(
                    tooltip: 'Remove from dashboard',
                    onPressed: () =>
                        Navigator.pop(context, const _PinEditorResult.remove()),
                    icon: const Icon(Icons.push_pin_outlined),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _PinEditorResult.save(selected)),
                    icon: Icon(
                      existing == null
                          ? Icons.push_pin_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      existing == null
                          ? 'Show on dashboard'
                          : 'Save comparison',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null || !context.mounted) {
    return;
  }
  try {
    if (result.remove && existing != null) {
      await controller.removeDashboardPin(existing);
    } else {
      await controller.addOrUpdateDashboardPin(
        draft.copyWith(comparison: result.comparison),
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.remove
                ? 'Removed from dashboard.'
                : 'Dashboard comparison saved.',
          ),
        ),
      );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _DashboardPinButton extends StatelessWidget {
  const _DashboardPinButton({
    required this.controller,
    required this.kind,
    this.category,
    this.creditMode = _CreditListMode.open,
    this.debtMode = _DebtListMode.open,
    this.iconSize,
    this.compact = false,
  });

  final DashboardController controller;
  final _DashboardMetricKind kind;
  final String? category;
  final _CreditListMode creditMode;
  final _DebtListMode debtMode;
  final double? iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final pinned =
          _matchingDashboardPin(
            controller,
            kind: kind,
            category: category,
            creditMode: creditMode,
            debtMode: debtMode,
          ) !=
          null;
      return IconButton(
        tooltip: pinned ? 'Pinned on dashboard' : 'Show on dashboard',
        padding: compact ? EdgeInsets.zero : null,
        visualDensity: compact ? VisualDensity.compact : null,
        onPressed: () => _showDashboardPinEditor(
          context,
          controller,
          kind: kind,
          category: category,
          creditMode: creditMode,
          debtMode: debtMode,
        ),
        icon: Icon(
          pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          size: iconSize,
          color: pinned ? _kindColor(kind) : null,
        ),
      );
    },
  );
}

Future<void> _openContextualAdd(
  BuildContext context,
  DashboardController controller, {
  TransactionType? type,
  String? category,
  String? walletId,
  required String title,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AddTransactionScreen(
          controller: controller,
          initialType: type,
          initialCategory: category,
          initialWalletId: walletId,
        ),
      ),
    ),
  );
}

void _openDashboardTransaction(
  BuildContext context,
  DashboardController controller,
  FinancialTransaction transaction, {
  bool startEditing = false,
}) {
  final route = transaction.isCredit || transaction.isDebt
      ? SettlementWorkspaceScreen(
          controller: controller,
          transaction: transaction,
          showAccountDetails: startEditing,
        )
      : TransactionDetailScreen(
          controller: controller,
          transaction: transaction,
          startEditing: startEditing,
        );
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => route));
}

void _showBalancePeriodSettings(
  BuildContext context,
  DashboardController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Net balance period',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 5),
            const Text(
              'Tap a period. Long-press a day, week, or month to choose the exact date.',
            ),
            const SizedBox(height: 14),
            PeriodFilterBar(controller: controller),
          ],
        ),
      ),
    ),
  );
}

/// The primary product surface. Its visual language is deliberately shared by
/// the rest of the app through the global dark theme: deep navy, glass panels,
/// cyan focus and violet analytics.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller, this.onOpenMenu});

  final DashboardController controller;
  final VoidCallback? onOpenMenu;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _balanceVisible = true;
  bool _showRealBalance = true;
  bool _netCashFlowInLbp = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => _buildDashboard(context),
  );

  Widget _buildDashboard(BuildContext context) {
    final controller = widget.controller;
    if (controller.isLoading && !controller.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (Theme.of(context).brightness == Brightness.light) {
      return _LightDashboard(
        controller: controller,
        onOpenMenu: widget.onOpenMenu,
        balanceVisible: _balanceVisible,
        onToggleBalance: () =>
            setState(() => _balanceVisible = !_balanceVisible),
        showRealBalance: _showRealBalance,
        onToggleRealBalance: () =>
            setState(() => _showRealBalance = !_showRealBalance),
        netCashFlowInLbp: _netCashFlowInLbp,
        onToggleNetCashFlowCurrency: () =>
            setState(() => _netCashFlowInLbp = !_netCashFlowInLbp),
      );
    }

    final content = _DashboardContent(
      controller: controller,
      balanceVisible: _balanceVisible,
      onToggleBalance: () => setState(() => _balanceVisible = !_balanceVisible),
      onOpenMenu: widget.onOpenMenu,
    );
    return _CyberBackground(
      child: RefreshIndicator(
        color: const Color(0xFF12D9F4),
        backgroundColor: const Color(0xFF071827),
        onRefresh: controller.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = AppResponsive.isWideWeb(context) ? 28.0 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: content,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The light presentation follows the compact reference layout: information is
/// grouped in a calm white surface and ordered from balance, to accounts, to
/// metrics, to the daily detail and quick stats.
class _LightDashboard extends StatelessWidget {
  const _LightDashboard({
    required this.controller,
    required this.balanceVisible,
    required this.onToggleBalance,
    required this.showRealBalance,
    required this.onToggleRealBalance,
    required this.netCashFlowInLbp,
    required this.onToggleNetCashFlowCurrency,
    this.onOpenMenu,
  });

  final DashboardController controller;
  final VoidCallback? onOpenMenu;
  final bool balanceVisible;
  final VoidCallback onToggleBalance;
  final bool showRealBalance;
  final VoidCallback onToggleRealBalance;
  final bool netCashFlowInLbp;
  final VoidCallback onToggleNetCashFlowCurrency;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final comparison = controller.comparison;
    final wallets = controller.walletSummary;
    final walletUsd = wallets.cash.balanceUsd + wallets.wish.balanceUsd;
    final walletLbp = wallets.cash.balanceLbp + wallets.wish.balanceLbp;
    final shownBalance = showRealBalance
        ? walletUsd + walletLbp / controller.exchangeRate
        : summary.totalNet;
    final wide = AppResponsive.isWideWeb(context);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 18, wide ? 28 : 16, 28),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.language == AppLanguage.arabic
                                ? 'لوحة التحكم'
                                : 'Dashboard',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF20242C),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controller.lastUpdated == null
                                ? 'Ready to sync'
                                : 'Updated ${FinanceFormatters.dateTime(controller.lastUpdated!)}',
                            style: const TextStyle(
                              color: Color(0xFF69707D),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                          'Compare all sections: ${controller.dashboardComparisonLabel}',
                      onPressed: () =>
                          _showDashboardComparisonPicker(context, controller),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF0B5CAD,
                        ).withValues(alpha: .08),
                        foregroundColor: const Color(0xFF0B5CAD),
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 20),
                    ),
                    const SizedBox(width: 3),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: onOpenMenu,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF39333E),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LightCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: PeriodFilterBar(controller: controller),
                ),
                const SizedBox(height: 12),
                _LightBalanceCard(
                  total: shownBalance,
                  change: comparison?.netChange ?? 0,
                  trend: _chartSeries(summary.dailyNetTotals, 14),
                  visible: balanceVisible,
                  onToggle: onToggleBalance,
                  label: showRealBalance
                      ? controller.strings.totalWalletBalance
                      : controller.strings.netCashFlow,
                  onDoubleTap: onToggleRealBalance,
                  onLongPress: () =>
                      _showBalancePeriodSettings(context, controller),
                ),
                const SizedBox(height: 8),
                _LightAccounts(controller: controller, wallets: wallets),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _LightMetric(
                            title: controller.strings.income,
                            value: FinanceFormatters.usd(summary.totalIncome),
                            subtitle: FinanceFormatters.lbp(
                              summary.totalIncomeLbp,
                            ),
                            icon: Icons.south_west_rounded,
                            color: const Color(0xFF168A5B),
                            change: _percentageChange(
                              summary.totalIncome,
                              controller.previousSummary.totalIncome,
                            ),
                            onTap: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.income,
                              showCategories: true,
                            ),
                            onLongPress: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.income,
                              showCategories: false,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _LightMetric(
                            title: controller.strings.expenses,
                            value: FinanceFormatters.usd(summary.totalExpense),
                            subtitle: FinanceFormatters.lbp(
                              summary.totalExpenseLbp,
                            ),
                            icon: Icons.north_east_rounded,
                            color: const Color(0xFFC74949),
                            change: _percentageChange(
                              summary.totalExpense,
                              controller.previousSummary.totalExpense,
                            ),
                            onTap: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.expense,
                              showCategories: true,
                            ),
                            onLongPress: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.expense,
                              showCategories: false,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _LightMetric(
                            title: controller.strings.reserveables,
                            value: FinanceFormatters.usd(
                              summary.totalReserveable,
                            ),
                            subtitle: FinanceFormatters.lbp(
                              summary.totalReserveableLbp,
                            ),
                            icon: Icons.account_balance_outlined,
                            color: const Color(0xFFD97706),
                            change: _percentageChange(
                              summary.totalReserveable,
                              controller.previousSummary.totalReserveable,
                            ),
                            onTap: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.reserveable,
                              showCategories: false,
                              creditMode: _CreditListMode.open,
                            ),
                            onLongPress: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.reserveable,
                              showCategories: false,
                              creditMode: _CreditListMode.completed,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _LightMetric(
                            title: controller.strings.debts,
                            value: FinanceFormatters.usd(summary.totalDebt),
                            subtitle: FinanceFormatters.lbp(
                              summary.totalDebtLbp,
                            ),
                            icon: Icons.account_balance_rounded,
                            color: const Color(0xFF2563EB),
                            change: _percentageChange(
                              summary.totalDebt,
                              controller.previousSummary.totalDebt,
                            ),
                            onTap: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.debit,
                              showCategories: false,
                              debtMode: _DebtListMode.open,
                            ),
                            onLongPress: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.debit,
                              showCategories: false,
                              debtMode: _DebtListMode.paid,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _LightMetric(
                            title: 'Transfers',
                            value: FinanceFormatters.usd(
                              _transferTotalUsd(
                                controller.periodTransactions,
                                controller.exchangeRate,
                              ),
                            ),
                            subtitle: FinanceFormatters.lbp(
                              _transferTotalLbp(controller.periodTransactions),
                            ),
                            icon: Icons.swap_horiz_rounded,
                            color: const Color(0xFF0F6CBD),
                            change: _percentageChange(
                              _transferTotalUsd(
                                controller.periodTransactions,
                                controller.exchangeRate,
                              ),
                              _transferTotalUsd(
                                controller.previousPeriodTransactions,
                                controller.exchangeRate,
                              ),
                            ),
                            onTap: () => _openMetricFocus(
                              context,
                              controller,
                              _DashboardMetricKind.transfer,
                              showCategories: false,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _LightMetric(
                  title: controller.strings.netCashFlow,
                  value: netCashFlowInLbp
                      ? FinanceFormatters.lbp(summary.totalNetLbp)
                      : FinanceFormatters.usd(summary.totalNet),
                  subtitle: netCashFlowInLbp
                      ? FinanceFormatters.usd(summary.totalNet)
                      : FinanceFormatters.lbp(summary.totalNetLbp),
                  icon: Icons.account_balance_rounded,
                  color: summary.totalNet >= 0
                      ? const Color(0xFF168A5B)
                      : const Color(0xFFC74949),
                  change: _percentageChange(
                    summary.totalNet,
                    controller.previousSummary.totalNet,
                  ),
                  onLongPress: onToggleNetCashFlowCurrency,
                ),
                const SizedBox(height: 8),
                _IncomeAllocationPanel(controller: controller, light: true),
                const SizedBox(height: 8),
                _PinnedDashboardSection(controller: controller, light: true),
                if (controller.dashboardPins.isNotEmpty)
                  const SizedBox(height: 8),
                _LightExpenseFocus(controller: controller),
                const SizedBox(height: 8),
                _LightQuickStats(controller: controller),
                const SizedBox(height: 8),
                _LightRecentTransactions(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE1E2E8)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF073B66).withValues(alpha: .10),
          blurRadius: 13,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _LightBalanceCard extends StatelessWidget {
  const _LightBalanceCard({
    required this.total,
    required this.change,
    required this.trend,
    required this.visible,
    required this.onToggle,
    required this.onLongPress,
    required this.label,
    required this.onDoubleTap,
  });
  final double total;
  final double change;
  final List<double> trend;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final String label;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: onLongPress,
    onDoubleTap: onDoubleTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1478D4), Color(0xFF073B66)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B5CAD).withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: .86),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              visible ? FinanceFormatters.usd(total) : '••••••',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 31,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            visible
                ? '${change >= 0 ? '+' : ''}${FinanceFormatters.percent(change)} vs last period'
                : 'Balance hidden',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 35,
            width: double.infinity,
            child: CustomPaint(painter: _HeroTrendPainter(values: trend)),
          ),
        ],
      ),
    ),
  );
}

class _LightAccounts extends StatefulWidget {
  const _LightAccounts({required this.controller, required this.wallets});
  final DashboardController controller;
  final WalletSummary wallets;

  @override
  State<_LightAccounts> createState() => _LightAccountsState();
}

class _LightAccountsState extends State<_LightAccounts> {
  bool _cashVisible = true;
  bool _wishVisible = true;
  _WalletDisplayMode _cashDisplay = _WalletDisplayMode.split;
  _WalletDisplayMode _wishDisplay = _WalletDisplayMode.split;
  _WalletDisplayMode? _combinedDisplay;

  @override
  Widget build(BuildContext context) {
    if (_combinedDisplay != null) {
      return _MergedWalletCard(
        cashUsd: widget.wallets.cash.balanceUsd,
        cashLbp: widget.wallets.cash.balanceLbp,
        wishUsd: widget.wallets.wish.balanceUsd,
        wishLbp: widget.wallets.wish.balanceLbp,
        exchangeRate: widget.controller.exchangeRate,
        mode: _combinedDisplay!,
        onLongPress: _cycleCombinedBalance,
      );
    }
    return Row(
      children: [
        Expanded(
          child: _ActiveWalletCard(
            title: 'My Wallet',
            usd: widget.wallets.cash.balanceUsd,
            lbp: widget.wallets.cash.balanceLbp,
            imageAsset: 'assets/branding/maliyati_wallet_icon_v2.png',
            color: const Color(0xFF0B5CAD),
            visible: _cashVisible,
            onToggleVisibility: () =>
                setState(() => _cashVisible = !_cashVisible),
            onTap: () => _handleTap(context, isWishMoney: false),
            onDoubleTap: () =>
                setState(() => _cashDisplay = _nextDisplay(_cashDisplay)),
            onLongPress: _cycleCombinedBalance,
            displayMode: _cashDisplay,
            exchangeRate: widget.controller.exchangeRate,
            comparison: widget.controller.walletBalanceComparison(
              isWishMoney: false,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActiveWalletCard(
            title: 'Whish Money',
            usd: widget.wallets.wish.balanceUsd,
            lbp: widget.wallets.wish.balanceLbp,
            color: const Color(0xFF087F8C),
            imageAsset: 'assets/branding/wish_money_logo.jpg',
            visible: _wishVisible,
            onToggleVisibility: () =>
                setState(() => _wishVisible = !_wishVisible),
            onTap: () => _handleTap(context, isWishMoney: true),
            onDoubleTap: () =>
                setState(() => _wishDisplay = _nextDisplay(_wishDisplay)),
            onLongPress: _cycleCombinedBalance,
            displayMode: _wishDisplay,
            exchangeRate: widget.controller.exchangeRate,
            comparison: widget.controller.walletBalanceComparison(
              isWishMoney: true,
            ),
          ),
        ),
      ],
    );
  }

  void _cycleCombinedBalance() => setState(() {
    _combinedDisplay = switch (_combinedDisplay) {
      null => _WalletDisplayMode.totalUsd,
      _WalletDisplayMode.totalUsd => _WalletDisplayMode.totalLbp,
      _WalletDisplayMode.totalLbp => null,
      _WalletDisplayMode.split => _WalletDisplayMode.totalUsd,
    };
  });

  _WalletDisplayMode _nextDisplay(_WalletDisplayMode current) =>
      switch (current) {
        _WalletDisplayMode.split => _WalletDisplayMode.totalUsd,
        _WalletDisplayMode.totalUsd => _WalletDisplayMode.totalLbp,
        _WalletDisplayMode.totalLbp => _WalletDisplayMode.split,
      };

  void _handleTap(BuildContext context, {required bool isWishMoney}) {
    final mode = isWishMoney ? _wishDisplay : _cashDisplay;
    if (mode != _WalletDisplayMode.split) {
      setState(() {
        if (isWishMoney) {
          _wishDisplay = _WalletDisplayMode.split;
        } else {
          _cashDisplay = _WalletDisplayMode.split;
        }
      });
      return;
    }
    _open(context, isWishMoney: isWishMoney);
  }

  void _open(
    BuildContext context, {
    required bool isWishMoney,
    _WalletTimeScope scope = _WalletTimeScope.thisWeek,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _WalletActivityScreen(
        controller: widget.controller,
        isWishMoney: isWishMoney,
        initialScope: scope,
      ),
    ),
  );

  Future<void> _chooseTime(
    BuildContext context, {
    required bool isWishMoney,
  }) async {
    final selected = await showModalBottomSheet<_WalletTimeScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Set time',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('This week is the default for each wallet.'),
            ),
            for (final scope in _WalletTimeScope.values)
              ListTile(
                leading: Icon(
                  scope == _WalletTimeScope.today
                      ? Icons.today_rounded
                      : Icons.date_range_rounded,
                ),
                title: Text(scope.label),
                onTap: () => Navigator.of(context).pop(scope),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      _open(context, isWishMoney: isWishMoney, scope: selected);
    }
  }
}

class _ActiveWalletCard extends StatelessWidget {
  const _ActiveWalletCard({
    required this.title,
    required this.usd,
    required this.lbp,
    required this.color,
    required this.onTap,
    required this.visible,
    required this.onToggleVisibility,
    required this.comparison,
    required this.displayMode,
    required this.exchangeRate,
    this.onLongPress,
    this.onDoubleTap,
    this.icon,
    this.imageAsset,
  });

  final String title;
  final double usd;
  final double lbp;
  final Color color;
  final VoidCallback onTap;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final WalletBalanceComparison comparison;
  final _WalletDisplayMode displayMode;
  final double exchangeRate;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final IconData? icon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: .75)],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .19),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .30),
                    ),
                  ),
                  child: imageAsset == null
                      ? Icon(icon, color: Colors.white, size: 21)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(imageAsset!, fit: BoxFit.cover),
                        ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: visible ? 'Hide balance' : 'Show balance',
                  onPressed: onToggleVisibility,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  icon: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white70,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            _balanceDisplay(),
            const SizedBox(height: 5),
            Text(
              visible
                  ? '${comparison.usdChange >= 0 ? '+' : ''}${FinanceFormatters.usd(comparison.usdChange)} vs ${comparison.range.label}'
                  : 'Balance hidden',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _balanceDisplay() {
    if (displayMode == _WalletDisplayMode.split) {
      return Row(
        children: [
          Expanded(
            child: _WalletCurrencyLine(
              label: 'USD',
              value: visible ? FinanceFormatters.usd(usd) : '••••••',
            ),
          ),
          Expanded(
            child: _WalletCurrencyLine(
              label: 'LBP',
              value: visible ? FinanceFormatters.lbp(lbp) : '••••••',
            ),
          ),
        ],
      );
    }
    final totalUsd = usd + lbp / exchangeRate;
    final totalLbp = lbp + usd * exchangeRate;
    final isUsd = displayMode == _WalletDisplayMode.totalUsd;
    return _WalletCurrencyLine(
      label: isUsd ? 'TOTAL · USD' : 'TOTAL · LBP',
      value: visible
          ? (isUsd
                ? FinanceFormatters.usd(totalUsd)
                : FinanceFormatters.lbp(totalLbp))
          : '••••••',
    );
  }
}

class _WalletCurrencyLine extends StatelessWidget {
  const _WalletCurrencyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 8)),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

class _LightAccountRow extends StatelessWidget {
  const _LightAccountRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.isWishMoney = false,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool isWishMoney;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: const Color(0xFFEFDFF7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: isWishMoney
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/branding/wish_money_logo.jpg',
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(icon, color: const Color(0xFF6A2F9B), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF25212B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF5A5462),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF737078)),
        ],
      ),
    ),
  );
}

class _LightMetric extends StatelessWidget {
  const _LightMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.change,
    this.onTap,
    this.onLongPress,
  });
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? change;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: _LightCard(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF34313A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1D1C20),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF77717D),
                    fontSize: 10,
                  ),
                ),
                if (change != null)
                  Text(
                    _signedPercent(change!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: change == 0 ? const Color(0xFF77717D) : color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MergedWalletCard extends StatelessWidget {
  const _MergedWalletCard({
    required this.cashUsd,
    required this.cashLbp,
    required this.wishUsd,
    required this.wishLbp,
    required this.exchangeRate,
    required this.mode,
    required this.onLongPress,
  });

  final double cashUsd;
  final double cashLbp;
  final double wishUsd;
  final double wishLbp;
  final double exchangeRate;
  final _WalletDisplayMode mode;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final usd = cashUsd + wishUsd;
    final lbp = cashLbp + wishLbp;
    final amount = mode == _WalletDisplayMode.totalLbp
        ? FinanceFormatters.lbp(lbp + usd * exchangeRate)
        : FinanceFormatters.usd(usd + lbp / exchangeRate);
    return GestureDetector(
      onLongPress: onLongPress,
      child: _LightCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0B5CAD).withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF0B5CAD),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Combined balance',
                    style: TextStyle(
                      color: Color(0xFF5C5561),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    amount,
                    style: const TextStyle(
                      color: Color(0xFF29232E),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombinedWalletBalance extends StatefulWidget {
  const _CombinedWalletBalance({
    required this.cashUsd,
    required this.cashLbp,
    required this.wishUsd,
    required this.wishLbp,
    required this.exchangeRate,
  });

  final double cashUsd;
  final double cashLbp;
  final double wishUsd;
  final double wishLbp;
  final double exchangeRate;

  @override
  State<_CombinedWalletBalance> createState() => _CombinedWalletBalanceState();
}

class _CombinedWalletBalanceState extends State<_CombinedWalletBalance> {
  _WalletDisplayMode _mode = _WalletDisplayMode.split;

  @override
  Widget build(BuildContext context) {
    final usd = widget.cashUsd + widget.wishUsd;
    final lbp = widget.cashLbp + widget.wishLbp;
    final totalUsd = usd + lbp / widget.exchangeRate;
    final totalLbp = lbp + usd * widget.exchangeRate;
    final label = switch (_mode) {
      _WalletDisplayMode.split => 'Total funds · My Wallet + Whish Money',
      _WalletDisplayMode.totalUsd => 'Total funds in USD',
      _WalletDisplayMode.totalLbp => 'Total funds in LBP',
    };
    final value = switch (_mode) {
      _WalletDisplayMode.split =>
        '${FinanceFormatters.usd(usd)}  ·  ${FinanceFormatters.lbp(lbp)}',
      _WalletDisplayMode.totalUsd => FinanceFormatters.usd(totalUsd),
      _WalletDisplayMode.totalLbp => FinanceFormatters.lbp(totalLbp),
    };
    return GestureDetector(
      onLongPress: () => setState(() {
        _mode = _mode == _WalletDisplayMode.totalUsd
            ? _WalletDisplayMode.totalLbp
            : _WalletDisplayMode.totalUsd;
      }),
      onDoubleTap: () => setState(() => _mode = _WalletDisplayMode.split),
      child: _LightCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0B5CAD).withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF0B5CAD),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF5C5561),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF29232E),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightExpenseFocus extends StatelessWidget {
  const _LightExpenseFocus({required this.controller});
  final DashboardController controller;
  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.strings.expenseOverview,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF27232C),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            periodFilterLabel(controller),
            style: const TextStyle(color: Color(0xFF76707D), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CurrencyTile(
                  label: 'USD',
                  value: FinanceFormatters.usd(summary.totalExpenseUsd),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CurrencyTile(
                  label: 'LBP',
                  value: FinanceFormatters.lbp(summary.totalExpenseLbp),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CurrencyTile(
                  label: 'Total USD',
                  value: FinanceFormatters.usd(summary.totalExpense),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Average daily expense: ${FinanceFormatters.usd(summary.averageDailyExpense)} / ${FinanceFormatters.lbp(summary.averageDailyExpense * controller.exchangeRate)}',
            style: const TextStyle(color: Color(0xFF343039), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Transactions: ${summary.transactionCount}',
            style: const TextStyle(color: Color(0xFF343039), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F7FA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E1E8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B6570),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF25222A),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _LightQuickStats extends StatelessWidget {
  const _LightQuickStats({required this.controller});
  final DashboardController controller;
  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF27232C),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          _QuickStatLine(
            icon: Icons.percent_rounded,
            title: 'Expense ratio',
            value: FinanceFormatters.percent(summary.expenseRatio),
          ),
          _QuickStatLine(
            icon: Icons.category_outlined,
            title: 'Categories',
            value: summary.topExpenseCategory,
          ),
          _QuickStatLine(
            icon: Icons.receipt_long_rounded,
            title: 'Transactions',
            value: '${summary.transactionCount}',
          ),
          _QuickStatLine(
            icon: Icons.arrow_downward_rounded,
            title: 'Largest expense',
            value: summary.largestExpense == null
                ? '—'
                : FinanceFormatters.amount(summary.largestExpense!),
          ),
        ],
      ),
    );
  }
}

class _QuickStatLine extends StatelessWidget {
  const _QuickStatLine({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF6C319E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Color(0xFF37323D), fontSize: 12),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF39333E),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _LightRecentTransactions extends StatelessWidget {
  const _LightRecentTransactions({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final transactions = controller.periodTransactions.toList()
      ..sort(
        (a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date),
      );
    final visible = transactions.take(4).toList();
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF27232C),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                periodFilterLabel(controller),
                style: const TextStyle(
                  color: Color(0xFF6C319E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No transactions in this period.'),
            )
          else
            for (final transaction in visible)
              _RecentDashboardRow(
                controller: controller,
                transaction: transaction,
              ),
        ],
      ),
    );
  }
}

class _RecentDashboardRow extends StatelessWidget {
  const _RecentDashboardRow({
    required this.controller,
    required this.transaction,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isTransfer
        ? const Color(0xFF0F6CBD)
        : transaction.isIncome
        ? const Color(0xFF168A5B)
        : transaction.isReserveable
        ? const Color(0xFFD97706)
        : const Color(0xFFC74949);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openDashboardTransaction(context, controller, transaction),
      onLongPress: () => _openDashboardTransaction(
        context,
        controller,
        transaction,
        startEditing: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(
                transaction.isTransfer
                    ? Icons.swap_horiz_rounded
                    : transaction.isIncome
                    ? Icons.south_west_rounded
                    : transaction.isReserveable
                    ? Icons.request_quote_rounded
                    : Icons.north_east_rounded,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? transaction.category
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${transaction.category} · ${FinanceFormatters.shortDate(transaction.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF706A75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              FinanceFormatters.amount(transaction),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricFocusScreen extends StatefulWidget {
  const _DashboardMetricFocusScreen({
    required this.controller,
    required this.kind,
    required this.showCategories,
    this.creditMode = _CreditListMode.open,
    this.debtMode = _DebtListMode.open,
    this.category,
  });

  final DashboardController controller;
  final _DashboardMetricKind kind;
  final bool showCategories;
  final _CreditListMode creditMode;
  final _DebtListMode debtMode;
  final String? category;

  @override
  State<_DashboardMetricFocusScreen> createState() =>
      _DashboardMetricFocusScreenState();
}

class _DashboardMetricFocusScreenState
    extends State<_DashboardMetricFocusScreen> {
  late bool _showCategories;
  _MetricFocusSort _sort = _MetricFocusSort.newest;

  @override
  void initState() {
    super.initState();
    _showCategories = widget.showCategories;
    if (_showCategories) {
      _sort = _MetricFocusSort.highestAmount;
    }
  }

  void _openComparison() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MetricComparisonScreen(
          controller: widget.controller,
          kind: widget.kind,
          creditMode: widget.creditMode,
          debtMode: widget.debtMode,
          category: widget.category,
        ),
      ),
    );
  }

  Future<void> _selectComparisonPeriod() async {
    await _showDashboardComparisonPicker(context, widget.controller);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final kind = widget.kind;
    final category = widget.category;
    final creditMode = widget.creditMode;
    final debtMode = widget.debtMode;
    final usesAllTimeByDefault =
        kind == _DashboardMetricKind.reserveable ||
        kind == _DashboardMetricKind.debit;
    final sourceTransactions = usesAllTimeByDefault
        ? controller.calculationTransactions
        : controller.periodTransactions;
    final matchedTransactions = sourceTransactions
        .where(_matches)
        .where(
          (transaction) => category == null || transaction.category == category,
        )
        .toList();
    final filteredTransactions =
        kind == _DashboardMetricKind.debit && category == null
        ? matchedTransactions
              .where(
                (transaction) => debtMode == _DebtListMode.open
                    ? !transaction.isSettled
                    : transaction.isSettled,
              )
              .toList()
        : matchedTransactions;
    final matchedComparisonTransactions = controller.previousPeriodTransactions
        .where(_matches)
        .where(
          (transaction) => category == null || transaction.category == category,
        )
        .toList();
    final comparisonTransactions =
        kind == _DashboardMetricKind.debit && category == null
        ? matchedComparisonTransactions
              .where(
                (transaction) => debtMode == _DebtListMode.open
                    ? !transaction.isSettled
                    : transaction.isSettled,
              )
              .toList()
        : matchedComparisonTransactions;
    final transactions = _sortTransactions(filteredTransactions);
    final title = switch (kind) {
      _DashboardMetricKind.income => controller.strings.income,
      _DashboardMetricKind.expense => controller.strings.expenses,
      _DashboardMetricKind.reserveable =>
        creditMode == _CreditListMode.open
            ? controller.strings.outstandingReceivables
            : controller.strings.collectedReceivables,
      _DashboardMetricKind.debit =>
        debtMode == _DebtListMode.open
            ? controller.strings.outstandingPayables
            : controller.strings.settledPayables,
      _DashboardMetricKind.transfer => 'Transfers',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(category ?? title),
        actions: [
          _DashboardPinButton(
            controller: controller,
            kind: kind,
            category: category,
            creditMode: creditMode,
            debtMode: debtMode,
          ),
          GestureDetector(
            onLongPress: _openComparison,
            child: IconButton(
              tooltip: 'Choose comparison period',
              onPressed: _selectComparisonPeriod,
              icon: const Icon(Icons.compare_arrows_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _MetricFocusControls(
            showCategories: _showCategories,
            supportsCategories:
                category == null &&
                (kind == _DashboardMetricKind.income ||
                    kind == _DashboardMetricKind.expense ||
                    kind == _DashboardMetricKind.transfer),
            sort: _sort,
            onViewChanged: (showCategories) => setState(() {
              _showCategories = showCategories;
              if (showCategories && _sort == _MetricFocusSort.newest) {
                _sort = _MetricFocusSort.highestAmount;
              }
            }),
            onSortChanged: (sort) => setState(() => _sort = sort),
          ),
          Expanded(
            child:
                (kind == _DashboardMetricKind.reserveable ||
                        kind == _DashboardMetricKind.debit) &&
                    category == null
                ? _SettlementFocusBody(
                    controller: controller,
                    transactions: transactions,
                    isDebt: kind == _DashboardMetricKind.debit,
                    showCompleted: kind == _DashboardMetricKind.debit
                        ? debtMode == _DebtListMode.paid
                        : creditMode == _CreditListMode.completed,
                  )
                : _showCategories && category == null
                ? _CategoryFocusList(
                    controller: controller,
                    kind: kind,
                    title: title,
                    transactions: transactions,
                    comparisonTransactions: comparisonTransactions,
                    sort: _sort,
                  )
                : transactions.isEmpty
                ? Center(
                    child: Text(
                      'No $title transactions for ${usesAllTimeByDefault ? 'all time' : periodFilterLabel(controller)}.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      if (kind == _DashboardMetricKind.reserveable ||
                          kind == _DashboardMetricKind.debit) {
                        return _CreditOverviewTile(
                          controller: controller,
                          transaction: transaction,
                          onTap: () => _openTransaction(context, transaction),
                          onLongPress: () => _openTransaction(
                            context,
                            transaction,
                            startEditing: true,
                          ),
                        );
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kindColor(
                            kind,
                          ).withValues(alpha: .15),
                          foregroundColor: _kindColor(kind),
                          child: Icon(_kindIcon(kind)),
                        ),
                        title: Text(
                          transaction.description.isEmpty
                              ? transaction.category
                              : transaction.description,
                        ),
                        subtitle: Text(
                          kind == _DashboardMetricKind.reserveable ||
                                  kind == _DashboardMetricKind.debit
                              ? '${transaction.walletId} · ${FinanceFormatters.shortDate(transaction.date)}'
                              : '${transaction.category} · ${FinanceFormatters.shortDate(transaction.date)}',
                        ),
                        trailing: Text(
                          FinanceFormatters.amount(transaction),
                          style: TextStyle(
                            color: _kindColor(kind),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onTap: () => _openTransaction(
                          context,
                          transaction,
                          openSettlement:
                              (transaction.isDebt || transaction.isCredit) &&
                              !transaction.isSettled,
                        ),
                        onLongPress: () => _openTransaction(
                          context,
                          transaction,
                          startEditing: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContextualAdd(
          context,
          controller,
          type: switch (kind) {
            _DashboardMetricKind.income => TransactionType.income,
            _DashboardMetricKind.expense => TransactionType.expense,
            _DashboardMetricKind.reserveable => TransactionType.reserveable,
            _DashboardMetricKind.debit => TransactionType.debt,
            _DashboardMetricKind.transfer => TransactionType.transfer,
          },
          category: category,
          title: switch (kind) {
            _DashboardMetricKind.income => 'Add income',
            _DashboardMetricKind.expense => 'Add expense',
            _DashboardMetricKind.reserveable => 'Add credit',
            _DashboardMetricKind.debit => 'Add debt',
            _DashboardMetricKind.transfer => 'Add transfer',
          },
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(switch (kind) {
          _DashboardMetricKind.income => 'Add income',
          _DashboardMetricKind.expense => 'Add expense',
          _DashboardMetricKind.reserveable => 'Add credit',
          _DashboardMetricKind.debit => 'Add debt',
          _DashboardMetricKind.transfer => 'Add transfer',
        }),
      ),
    );
  }

  List<FinancialTransaction> _sortTransactions(
    List<FinancialTransaction> source,
  ) {
    final categoryCounts = <String, int>{};
    for (final transaction in source) {
      categoryCounts.update(
        transaction.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final sorted = [...source];
    sorted.sort((a, b) {
      final createdA = a.createdAt ?? a.date;
      final createdB = b.createdAt ?? b.date;
      final amountA = a.amountInUsd(widget.controller.exchangeRate);
      final amountB = b.amountInUsd(widget.controller.exchangeRate);
      return switch (_sort) {
        _MetricFocusSort.newest => createdB.compareTo(createdA),
        _MetricFocusSort.oldest => createdA.compareTo(createdB),
        _MetricFocusSort.highestAmount => amountB.compareTo(amountA),
        _MetricFocusSort.lowestAmount => amountA.compareTo(amountB),
        _MetricFocusSort.mostTransactions =>
          (categoryCounts[b.category] ?? 0).compareTo(
            categoryCounts[a.category] ?? 0,
          ),
        _MetricFocusSort.categoryName => a.category.toLowerCase().compareTo(
          b.category.toLowerCase(),
        ),
      };
    });
    return sorted;
  }

  bool _matches(FinancialTransaction transaction) => switch (widget.kind) {
    _DashboardMetricKind.income => transaction.affectsIncomeStats,
    _DashboardMetricKind.expense => transaction.affectsExpenseStats,
    _DashboardMetricKind.reserveable =>
      transaction.isReserveable && !transaction.isSettlementEntry,
    _DashboardMetricKind.debit =>
      transaction.isDebt && !transaction.isSettlementEntry,
    _DashboardMetricKind.transfer => transaction.isTransfer,
  };

  void _openTransaction(
    BuildContext context,
    FinancialTransaction transaction, {
    bool openSettlement = false,
    bool startEditing = false,
  }) => _openDashboardTransaction(
    context,
    widget.controller,
    transaction,
    startEditing: startEditing,
  );
}

class _MetricFocusControls extends StatelessWidget {
  const _MetricFocusControls({
    required this.showCategories,
    required this.supportsCategories,
    required this.sort,
    required this.onViewChanged,
    required this.onSortChanged,
  });

  final bool showCategories;
  final bool supportsCategories;
  final _MetricFocusSort sort;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<_MetricFocusSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (supportsCategories) ...[
                ChoiceChip(
                  selected: !showCategories,
                  avatar: const Icon(Icons.view_list_rounded, size: 18),
                  label: const Text('Transactions'),
                  onSelected: (_) => onViewChanged(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: showCategories,
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Categories'),
                  onSelected: (_) => onViewChanged(true),
                ),
                const SizedBox(width: 10),
              ],
              PopupMenuButton<_MetricFocusSort>(
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (context) => [
                  for (final option in _MetricFocusSort.values)
                    PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          Icon(_metricSortIcon(option), size: 19),
                          const SizedBox(width: 10),
                          Text(_metricSortLabel(option)),
                        ],
                      ),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort_rounded, size: 18),
                  label: Text(_metricSortLabel(sort)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _metricSortLabel(_MetricFocusSort sort) => switch (sort) {
  _MetricFocusSort.newest => 'Newest',
  _MetricFocusSort.oldest => 'Oldest',
  _MetricFocusSort.highestAmount => 'Highest amount',
  _MetricFocusSort.lowestAmount => 'Lowest amount',
  _MetricFocusSort.mostTransactions => 'Most transactions',
  _MetricFocusSort.categoryName => 'Category A-Z',
};

IconData _metricSortIcon(_MetricFocusSort sort) => switch (sort) {
  _MetricFocusSort.newest => Icons.schedule_rounded,
  _MetricFocusSort.oldest => Icons.history_rounded,
  _MetricFocusSort.highestAmount => Icons.arrow_downward_rounded,
  _MetricFocusSort.lowestAmount => Icons.arrow_upward_rounded,
  _MetricFocusSort.mostTransactions => Icons.format_list_numbered_rounded,
  _MetricFocusSort.categoryName => Icons.sort_by_alpha_rounded,
};

class _MetricComparisonScreen extends StatefulWidget {
  const _MetricComparisonScreen({
    required this.controller,
    required this.kind,
    required this.creditMode,
    required this.debtMode,
    this.category,
  });

  final DashboardController controller;
  final _DashboardMetricKind kind;
  final _CreditListMode creditMode;
  final _DebtListMode debtMode;
  final String? category;

  @override
  State<_MetricComparisonScreen> createState() =>
      _MetricComparisonScreenState();
}

class _MetricComparisonScreenState extends State<_MetricComparisonScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final comparisonWindow =
        controller.previousWindow ??
        controller.currentWindow.previous ??
        controller.currentWindow;
    final windows = (controller.currentWindow, comparisonWindow);
    final currentTransactions = _transactionsForWindow(windows.$1);
    final previousTransactions = _transactionsForWindow(windows.$2);
    final current = _total(currentTransactions);
    final previous = _total(previousTransactions);
    final change = _percentageChange(current, previous);
    final title = _title(controller);
    final color = _kindColor(widget.kind);
    final lowerIsBetter =
        widget.kind == _DashboardMetricKind.expense ||
        widget.kind == _DashboardMetricKind.debit;

    return Scaffold(
      appBar: AppBar(title: Text('$title comparison')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'Compare with',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'The same comparison period is used on the dashboard and in every category.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          _DashboardComparisonControl(
            controller: controller,
            light: Theme.of(context).brightness == Brightness.light,
          ),
          const SizedBox(height: 16),
          _ComparisonPeriodHeader(current: windows.$1, previous: windows.$2),
          const SizedBox(height: 12),
          _ComparisonMetricCard(
            title: title,
            icon: _kindIcon(widget.kind),
            color: color,
            current: current,
            previous: previous,
            change: change,
            lowerIsBetter: lowerIsBetter,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ComparisonCount(
                      label: 'Current transactions',
                      count: currentTransactions.length,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ComparisonCount(
                      label: 'Previous transactions',
                      count: previousTransactions.length,
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

  List<FinancialTransaction> _transactionsForWindow(DateWindow window) {
    final category = widget.category?.trim().toLowerCase();
    return widget.controller.calculationTransactions
        .where((transaction) => window.contains(transaction.date))
        .where(_matches)
        .where(
          (transaction) =>
              category == null ||
              transaction.category.trim().toLowerCase() == category,
        )
        .toList(growable: false);
  }

  bool _matches(FinancialTransaction transaction) => switch (widget.kind) {
    _DashboardMetricKind.income => transaction.affectsIncomeStats,
    _DashboardMetricKind.expense => transaction.affectsExpenseStats,
    _DashboardMetricKind.reserveable =>
      transaction.isReserveable &&
          !transaction.isSettlementEntry &&
          (widget.creditMode == _CreditListMode.open
              ? !transaction.isSettled
              : transaction.isSettled),
    _DashboardMetricKind.debit =>
      transaction.isDebt &&
          !transaction.isSettlementEntry &&
          (widget.debtMode == _DebtListMode.open
              ? !transaction.isSettled
              : transaction.isSettled),
    _DashboardMetricKind.transfer => transaction.isTransfer,
  };

  double _total(List<FinancialTransaction> transactions) => transactions.fold(
    0,
    (sum, transaction) =>
        sum + transaction.amountInUsd(widget.controller.exchangeRate),
  );

  String _title(DashboardController controller) {
    final category = widget.category?.trim();
    if (category != null && category.isNotEmpty) {
      return category;
    }
    return switch (widget.kind) {
      _DashboardMetricKind.income => controller.strings.income,
      _DashboardMetricKind.expense => controller.strings.expenses,
      _DashboardMetricKind.reserveable =>
        widget.creditMode == _CreditListMode.open
            ? controller.strings.outstandingReceivables
            : controller.strings.collectedReceivables,
      _DashboardMetricKind.debit =>
        widget.debtMode == _DebtListMode.open
            ? controller.strings.outstandingPayables
            : controller.strings.settledPayables,
      _DashboardMetricKind.transfer => 'Transfers',
    };
  }
}

class _ComparisonCount extends StatelessWidget {
  const _ComparisonCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ComparisonPeriodHeader extends StatelessWidget {
  const _ComparisonPeriodHeader({
    required this.current,
    required this.previous,
  });

  final DateWindow current;
  final DateWindow previous;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _ComparisonPeriodColumn(label: 'Current', window: current),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.compare_arrows_rounded),
          ),
          Expanded(
            child: _ComparisonPeriodColumn(label: 'Previous', window: previous),
          ),
        ],
      ),
    ),
  );
}

class _ComparisonPeriodColumn extends StatelessWidget {
  const _ComparisonPeriodColumn({required this.label, required this.window});

  final String label;
  final DateWindow window;

  @override
  Widget build(BuildContext context) {
    final start = window.start;
    final end = window.endExclusive?.subtract(const Duration(days: 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          start == null || end == null
              ? 'All available data'
              : start == end
              ? FinanceFormatters.shortDate(start)
              : '${FinanceFormatters.shortDate(start)} - '
                    '${FinanceFormatters.shortDate(end)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ComparisonMetricCard extends StatelessWidget {
  const _ComparisonMetricCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.current,
    required this.previous,
    required this.change,
    required this.lowerIsBetter,
  });

  final String title;
  final IconData icon;
  final Color color;
  final double current;
  final double previous;
  final double change;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final favourable = lowerIsBetter ? change <= 0 : change >= 0;
    final changeColor = favourable
        ? const Color(0xFF168A5B)
        : const Color(0xFFC74949);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Previous ${FinanceFormatters.usd(previous)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FinanceFormatters.usd(current),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${change >= 0 ? '+' : ''}${FinanceFormatters.percent(change)}',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w900,
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

(DateWindow, DateWindow) _comparisonWindows(
  DashboardController controller,
  _ComparisonScope scope,
) {
  final now = DateTime.now();
  final reference = controller.referenceDate;
  final today = DateTime(reference.year, reference.month, reference.day);
  switch (scope) {
    case _ComparisonScope.day:
      return (
        DateWindow(
          start: today,
          endExclusive: today.add(const Duration(days: 1)),
        ),
        DateWindow(
          start: today.subtract(const Duration(days: 1)),
          endExclusive: today,
        ),
      );
    case _ComparisonScope.week:
      final start = today.subtract(Duration(days: today.weekday % 7));
      final end = today.add(const Duration(days: 1));
      final duration = end.difference(start);
      final previousStart = start.subtract(const Duration(days: 7));
      return (
        DateWindow(start: start, endExclusive: end),
        DateWindow(
          start: previousStart,
          endExclusive: previousStart.add(duration),
        ),
      );
    case _ComparisonScope.month:
      final referenceMonth = controller.referenceMonth;
      if (referenceMonth != null) {
        return (
          DateWindow.forMonth(referenceMonth),
          DateWindow.forMonth(
            DateTime(referenceMonth.year, referenceMonth.month - 1),
          ),
        );
      }
      final start = DateTime(now.year, now.month);
      final end = today.add(const Duration(days: 1));
      final previousStart = DateTime(now.year, now.month - 1);
      final previousMonthEnd = DateTime(now.year, now.month);
      final candidateEnd = previousStart.add(end.difference(start));
      return (
        DateWindow(start: start, endExclusive: end),
        DateWindow(
          start: previousStart,
          endExclusive: candidateEnd.isAfter(previousMonthEnd)
              ? previousMonthEnd
              : candidateEnd,
        ),
      );
    case _ComparisonScope.selectedPeriod:
      final previous = controller.previousWindow;
      if (previous != null) {
        return (controller.currentWindow, previous);
      }
      return (
        DateWindow.forMonth(today),
        DateWindow.forMonth(DateTime(now.year, now.month - 1)),
      );
  }
}

class _SettlementFocusBody extends StatefulWidget {
  const _SettlementFocusBody({
    required this.controller,
    required this.transactions,
    required this.isDebt,
    required this.showCompleted,
  });

  final DashboardController controller;
  final List<FinancialTransaction> transactions;
  final bool isDebt;
  final bool showCompleted;

  @override
  State<_SettlementFocusBody> createState() => _SettlementFocusBodyState();
}

class _SettlementFocusBodyState extends State<_SettlementFocusBody> {
  @override
  Widget build(BuildContext context) {
    final open = widget.transactions
        .where((transaction) => !transaction.isSettled)
        .toList();
    final completed = widget.transactions
        .where((transaction) => transaction.isSettled)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if ((widget.showCompleted ? completed : open).isEmpty)
          _CreditEmptyState(
            message: widget.isDebt
                ? (widget.showCompleted
                      ? 'No paid payable yet.'
                      : 'No payable waiting for payment.')
                : (widget.showCompleted
                      ? 'No collected receivable yet.'
                      : 'No receivable waiting for collection.'),
          )
        else
          for (final transaction
              in widget.showCompleted ? completed : open) ...[
            _CompactCreditRow(
              controller: widget.controller,
              transaction: transaction,
              onTap: () => _openDashboardTransaction(
                context,
                widget.controller,
                transaction,
              ),
              onLongPress: () => _openDashboardTransaction(
                context,
                widget.controller,
                transaction,
                startEditing: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CreditSectionHeader extends StatelessWidget {
  const _CreditSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.expanded,
    this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const Spacer(),
          if (expanded != null)
            Icon(
              expanded! ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    ),
  );
}

class _CreditEmptyState extends StatelessWidget {
  const _CreditEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _CompactCreditRow extends StatelessWidget {
  const _CompactCreditRow({
    required this.controller,
    required this.transaction,
    required this.onTap,
    required this.onLongPress,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDebt = transaction.isDebt;
    final rate = controller.exchangeRate;
    final total = transaction.amountInUsd(rate);
    final remaining =
        transaction.remainingAmountUsd + transaction.remainingAmountLbp / rate;
    final collected = (total - remaining).clamp(0, total).toDouble();
    final progress = total <= 0
        ? 0.0
        : (collected / total).clamp(0, 1).toDouble();
    final isDone = transaction.isSettled;
    final accent = isDone
        ? const Color(0xFF168A5B)
        : isDebt
        ? const Color(0xFF7C3AED)
        : const Color(0xFFD97706);
    final title = transaction.description.trim().isEmpty
        ? (isDebt ? 'Payable' : 'Receivable')
        : transaction.description.trim();
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: accent.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : isDebt
                      ? Icons.payments_rounded
                      : Icons.request_quote_rounded,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  isDone ? 'Done' : 'Open',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isDone
                        ? '${isDebt ? 'Paid' : 'Collected'} ${FinanceFormatters.usd(collected)}'
                        : '${isDebt ? 'Left to pay' : 'Left to collect'} ${FinanceFormatters.usd(transaction.remainingAmountUsd)}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'of ${FinanceFormatters.usd(total)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: accent,
                backgroundColor: accent.withValues(alpha: .14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditOverviewTile extends StatelessWidget {
  const _CreditOverviewTile({
    required this.controller,
    required this.transaction,
    required this.onTap,
    required this.onLongPress,
  });

  final DashboardController controller;
  final FinancialTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDebt = transaction.isDebt;
    final primaryColor = isDebt
        ? const Color(0xFF7C3AED)
        : const Color(0xFFD97706);
    final rate = controller.exchangeRate;
    final total = transaction.amountInUsd(rate);
    final remaining =
        transaction.remainingAmountUsd + transaction.remainingAmountLbp / rate;
    final collected = (total - remaining).clamp(0, total).toDouble();
    final progress = total <= 0
        ? 0.0
        : (collected / total).clamp(0, 1).toDouble();
    final history = controller.transactions
        .where((item) => item.linkedTransactionId == transaction.id)
        .toList();
    final settlementWallets = history
        .map((item) => item.walletId)
        .where((wallet) => wallet.trim().isNotEmpty)
        .toSet()
        .join(', ');
    final title = transaction.description.trim().isEmpty
        ? (isDebt ? 'Payable' : 'Receivable')
        : transaction.description.trim();
    final sourceLabel = transaction.isServiceSource
        ? (isDebt ? 'Service payable' : 'Service receivable')
        : '${isDebt ? 'Received through' : 'From'} ${transaction.walletId}';
    final statusLabel = transaction.isSettled
        ? (isDebt ? 'Paid in full' : 'Collected in full')
        : (isDebt ? 'Remaining to pay' : 'Remaining to collect');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryColor.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDebt
                        ? Icons.payments_rounded
                        : Icons.request_quote_rounded,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sourceLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  FinanceFormatters.usd(transaction.amountUsd),
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CreditAmountLabel(
                    label: statusLabel,
                    value: FinanceFormatters.usd(
                      transaction.remainingAmountUsd,
                    ),
                    color: transaction.isSettled
                        ? const Color(0xFF168A5B)
                        : primaryColor,
                  ),
                ),
                Expanded(
                  child: _CreditAmountLabel(
                    label: isDebt ? 'Paid' : 'Collected',
                    value: FinanceFormatters.usd(transaction.settledAmountUsd),
                    alignEnd: true,
                    color: const Color(0xFF168A5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: const Color(0xFF168A5B),
                backgroundColor: primaryColor.withValues(alpha: .14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${FinanceFormatters.usd(collected)} ${isDebt ? 'paid' : 'collected'} of ${FinanceFormatters.usd(total)}'
              '${settlementWallets.isEmpty ? '' : ' · ${isDebt ? 'Paid from' : 'Received to'} $settlementWallets'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditAmountLabel extends StatelessWidget {
  const _CreditAmountLabel({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _CategoryFocusList extends StatelessWidget {
  const _CategoryFocusList({
    required this.controller,
    required this.kind,
    required this.title,
    required this.transactions,
    required this.comparisonTransactions,
    required this.sort,
  });

  final DashboardController controller;
  final _DashboardMetricKind kind;
  final String title;
  final List<FinancialTransaction> transactions;
  final List<FinancialTransaction> comparisonTransactions;
  final _MetricFocusSort sort;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<FinancialTransaction>>{};
    for (final transaction in transactions) {
      final label = transaction.category.trim().isEmpty
          ? 'Uncategorized'
          : transaction.category.trim();
      grouped.putIfAbsent(label, () => []).add(transaction);
    }
    final comparisonGrouped = <String, List<FinancialTransaction>>{};
    for (final transaction in comparisonTransactions) {
      final label = transaction.category.trim().isEmpty
          ? 'Uncategorized'
          : transaction.category.trim();
      comparisonGrouped.putIfAbsent(label, () => []).add(transaction);
    }
    final categoryNames = {...grouped.keys, ...comparisonGrouped.keys};
    final entries =
        categoryNames.map((name) {
          final rows = grouped[name] ?? const <FinancialTransaction>[];
          final previousRows =
              comparisonGrouped[name] ?? const <FinancialTransaction>[];
          final datedRows = rows.isEmpty ? previousRows : rows;
          final dates =
              datedRows.map((item) => item.createdAt ?? item.date).toList()
                ..sort();
          return _CategoryFocusStat(
            name: name,
            total: rows.fold<double>(
              0,
              (sum, item) => sum + item.amountInUsd(controller.exchangeRate),
            ),
            previousTotal: previousRows.fold<double>(
              0,
              (sum, item) => sum + item.amountInUsd(controller.exchangeRate),
            ),
            count: rows.length,
            oldest: dates.first,
            newest: dates.last,
          );
        }).toList()..sort((a, b) {
          return switch (sort) {
            _MetricFocusSort.newest => b.newest.compareTo(a.newest),
            _MetricFocusSort.oldest => a.oldest.compareTo(b.oldest),
            _MetricFocusSort.highestAmount => b.total.compareTo(a.total),
            _MetricFocusSort.lowestAmount => a.total.compareTo(b.total),
            _MetricFocusSort.mostTransactions => b.count.compareTo(a.count),
            _MetricFocusSort.categoryName => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
          };
        });
    final total = entries.fold<double>(0, (sum, item) => sum + item.total);
    if (entries.isEmpty) {
      return Center(child: Text('No $title categories for this period.'));
    }
    final largest = entries.fold<double>(
      0,
      (largest, item) => math.max(largest, item.total),
    );
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: ListTile(
            isThreeLine: true,
            leading: CircleAvatar(
              backgroundColor: _kindColor(kind).withValues(alpha: .12),
              foregroundColor: _kindColor(kind),
              child: Icon(_kindIcon(kind)),
            ),
            title: Text(
              entry.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.count == 0
                      ? 'No transactions in the current period'
                      : '${entry.count} transactions | latest ${FinanceFormatters.shortDate(entry.newest)}',
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _comparisonChangeColor(
                        kind,
                        _percentageChange(entry.total, entry.previousTotal),
                      ).withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _signedPercent(
                        _percentageChange(entry.total, entry.previousTotal),
                      ),
                      style: TextStyle(
                        color: _comparisonChangeColor(
                          kind,
                          _percentageChange(entry.total, entry.previousTotal),
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${total == 0 ? 0 : (entry.total / total * 100).round()}% of $title',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    // The largest category fills its track; the remaining
                    // rows are visually ranked against that leading one.
                    value: largest == 0 ? 0 : entry.total / largest,
                    minHeight: 7,
                    color: _kindColor(kind),
                    backgroundColor: _kindColor(kind).withValues(alpha: .13),
                  ),
                ),
              ],
            ),
            trailing: SizedBox(
              width: 92,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FinanceFormatters.usd(entry.total),
                    style: TextStyle(
                      color: _kindColor(kind),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: _DashboardPinButton(
                      controller: controller,
                      kind: kind,
                      category: entry.name,
                      iconSize: 19,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _DashboardMetricFocusScreen(
                  controller: controller,
                  kind: kind,
                  showCategories: false,
                  category: entry.name,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryFocusStat {
  const _CategoryFocusStat({
    required this.name,
    required this.total,
    required this.previousTotal,
    required this.count,
    required this.oldest,
    required this.newest,
  });

  final String name;
  final double total;
  final double previousTotal;
  final int count;
  final DateTime oldest;
  final DateTime newest;
}

String _signedPercent(double value) =>
    '${value >= 0 ? '+' : ''}${FinanceFormatters.percent(value)}';

Color _comparisonChangeColor(_DashboardMetricKind kind, double change) {
  if (change == 0) {
    return const Color(0xFF69707D);
  }
  final lowerIsBetter =
      kind == _DashboardMetricKind.expense ||
      kind == _DashboardMetricKind.debit;
  final favorable = lowerIsBetter ? change < 0 : change > 0;
  return favorable ? const Color(0xFF168A5B) : const Color(0xFFC74949);
}

Color _kindColor(_DashboardMetricKind kind) => switch (kind) {
  _DashboardMetricKind.income => const Color(0xFF168A5B),
  _DashboardMetricKind.expense => const Color(0xFFC74949),
  _DashboardMetricKind.reserveable => const Color(0xFFD97706),
  _DashboardMetricKind.debit => const Color(0xFF395EE9),
  _DashboardMetricKind.transfer => const Color(0xFF0F6CBD),
};

IconData _kindIcon(_DashboardMetricKind kind) => switch (kind) {
  _DashboardMetricKind.income => Icons.south_west_rounded,
  _DashboardMetricKind.expense => Icons.north_east_rounded,
  _DashboardMetricKind.reserveable => Icons.request_quote_rounded,
  _DashboardMetricKind.debit => Icons.account_balance_rounded,
  _DashboardMetricKind.transfer => Icons.swap_horiz_rounded,
};

class _PinnedDashboardSection extends StatelessWidget {
  const _PinnedDashboardSection({
    required this.controller,
    required this.light,
  });

  final DashboardController controller;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final pins = controller.dashboardPins;
    if (pins.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pin in pins)
              SizedBox(
                width: width,
                child: _PinnedComparisonCard(
                  controller: controller,
                  pin: pin,
                  light: light,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PinnedComparisonCard extends StatelessWidget {
  const _PinnedComparisonCard({
    required this.controller,
    required this.pin,
    required this.light,
  });

  final DashboardController controller;
  final DashboardPinnedItem pin;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final kind = _kindForPin(pin);
    final color = _kindColor(kind);
    final windows = _comparisonWindows(
      controller,
      _comparisonScopeForPin(pin.comparison),
    );
    final currentTransactions = _dashboardPinTransactions(
      controller,
      pin,
      windows.$1,
    );
    final previousTransactions = _dashboardPinTransactions(
      controller,
      pin,
      windows.$2,
    );
    final current = _dashboardPinTotal(controller, currentTransactions);
    final previous = _dashboardPinTotal(controller, previousTransactions);
    final change = _percentageChange(current, previous);
    final title = _dashboardPinTitle(controller, pin);
    return Material(
      color: light
          ? Colors.white
          : const Color(0xFF0A1D2D).withValues(alpha: .9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: .32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DashboardMetricFocusScreen(
              controller: controller,
              kind: kind,
              showCategories: false,
              category: pin.category,
              creditMode: pin.mode == _CreditListMode.completed.name
                  ? _CreditListMode.completed
                  : _CreditListMode.open,
              debtMode: pin.mode == _DebtListMode.paid.name
                  ? _DebtListMode.paid
                  : _DebtListMode.open,
            ),
          ),
        ),
        onLongPress: () => _showDashboardPinEditor(
          context,
          controller,
          kind: kind,
          category: pin.category,
          creditMode: pin.mode == _CreditListMode.completed.name
              ? _CreditListMode.completed
              : _CreditListMode.open,
          debtMode: pin.mode == _DebtListMode.paid.name
              ? _DebtListMode.paid
              : _DebtListMode.open,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_kindIcon(kind), color: color, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_dashboardPinComparisonLabel(pin.comparison)} ${FinanceFormatters.usd(previous)} | ${currentTransactions.length} tx',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        FinanceFormatters.usd(current),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          tooltip: 'Pinned on dashboard',
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showDashboardPinEditor(
                            context,
                            controller,
                            kind: kind,
                            category: pin.category,
                            creditMode:
                                pin.mode == _CreditListMode.completed.name
                                ? _CreditListMode.completed
                                : _CreditListMode.open,
                            debtMode: pin.mode == _DebtListMode.paid.name
                                ? _DebtListMode.paid
                                : _DebtListMode.open,
                          ),
                          icon: Icon(
                            Icons.push_pin_rounded,
                            color: color,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${change >= 0 ? '+' : ''}${FinanceFormatters.percent(change)}',
                    style: TextStyle(
                      color: change >= 0
                          ? const Color(0xFF168A5B)
                          : const Color(0xFFC74949),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<FinancialTransaction> _dashboardPinTransactions(
  DashboardController controller,
  DashboardPinnedItem pin,
  DateWindow window,
) {
  final category = pin.category?.trim().toLowerCase();
  return controller.calculationTransactions
      .where((transaction) => window.contains(transaction.date))
      .where((transaction) {
        final matchesMetric = switch (pin.metric) {
          DashboardPinMetric.income => transaction.affectsIncomeStats,
          DashboardPinMetric.expense => transaction.affectsExpenseStats,
          DashboardPinMetric.receivable =>
            transaction.isReserveable &&
                !transaction.isSettlementEntry &&
                (pin.mode == _CreditListMode.completed.name
                    ? transaction.isSettled
                    : !transaction.isSettled),
          DashboardPinMetric.payable =>
            transaction.isDebt &&
                !transaction.isSettlementEntry &&
                (pin.mode == _DebtListMode.paid.name
                    ? transaction.isSettled
                    : !transaction.isSettled),
          DashboardPinMetric.transfer => transaction.isTransfer,
        };
        if (!matchesMetric) {
          return false;
        }
        return category == null ||
            transaction.category.trim().toLowerCase() == category;
      })
      .toList(growable: false);
}

double _dashboardPinTotal(
  DashboardController controller,
  Iterable<FinancialTransaction> transactions,
) => transactions.fold(
  0,
  (total, transaction) =>
      total + transaction.amountInUsd(controller.exchangeRate),
);

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.controller,
    required this.balanceVisible,
    required this.onToggleBalance,
    this.onOpenMenu,
  });

  final DashboardController controller;
  final bool balanceVisible;
  final VoidCallback onToggleBalance;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final comparison = controller.comparison;
    final wide = AppResponsive.isWideWeb(context);
    final change = comparison?.netChange ?? 0;
    final recent = controller.periodTransactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardHeader(controller: controller, onOpenMenu: onOpenMenu),
        const SizedBox(height: 14),
        // One persistent control rail: period controls plus the selected
        // business context remain at the top on every dashboard state.
        _GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: PeriodFilterBar(controller: controller),
        ),
        const SizedBox(height: 16),
        _BalanceHero(
          title: controller.strings.netCashFlow,
          total: summary.totalNet,
          change: change,
          updatedAt: controller.lastUpdated,
          visible: balanceVisible,
          onToggle: onToggleBalance,
          onWalletPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _WalletActivityScreen(
                controller: controller,
                isWishMoney: false,
                initialScope: _WalletTimeScope.thisWeek,
              ),
            ),
          ),
          onWishWalletPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _WalletActivityScreen(
                controller: controller,
                isWishMoney: true,
                initialScope: _WalletTimeScope.thisWeek,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ResponsivePair(
          wide: wide,
          first: _MetricPanel(
            title: controller.strings.income,
            value: FinanceFormatters.usd(summary.totalIncome),
            change: comparison?.incomeChange ?? 0,
            positive: true,
            icon: Icons.south_west_rounded,
            onTap: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.income,
              showCategories: true,
            ),
            onLongPress: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.income,
              showCategories: false,
            ),
          ),
          second: _MetricPanel(
            title: controller.strings.expenses,
            value: FinanceFormatters.usd(summary.totalExpense),
            change: comparison?.expenseChange ?? 0,
            positive: false,
            icon: Icons.north_east_rounded,
            onTap: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.expense,
              showCategories: true,
            ),
            onLongPress: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.expense,
              showCategories: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ResponsivePair(
          wide: wide,
          first: _MetricPanel(
            title: controller.strings.reserveables,
            value: FinanceFormatters.usd(summary.totalReserveable),
            change: _percentageChange(
              summary.totalReserveable,
              controller.previousSummary.totalReserveable,
            ),
            positive: true,
            icon: Icons.request_quote_rounded,
            onTap: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.reserveable,
              showCategories: false,
              creditMode: _CreditListMode.open,
            ),
            onLongPress: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.reserveable,
              showCategories: false,
              creditMode: _CreditListMode.completed,
            ),
          ),
          second: _MetricPanel(
            title: controller.strings.debts,
            value: FinanceFormatters.usd(summary.totalDebt),
            change: _percentageChange(
              summary.totalDebt,
              controller.previousSummary.totalDebt,
            ),
            positive: false,
            icon: Icons.account_balance_rounded,
            onTap: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.debit,
              showCategories: false,
              debtMode: _DebtListMode.open,
            ),
            onLongPress: () => _openMetricFocus(
              context,
              controller,
              _DashboardMetricKind.debit,
              showCategories: false,
              debtMode: _DebtListMode.paid,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MetricPanel(
          title: 'Transfers',
          value: FinanceFormatters.usd(
            _transferTotalUsd(
              controller.periodTransactions,
              controller.exchangeRate,
            ),
          ),
          change: _percentageChange(
            _transferTotalUsd(
              controller.periodTransactions,
              controller.exchangeRate,
            ),
            _transferTotalUsd(
              controller.previousPeriodTransactions,
              controller.exchangeRate,
            ),
          ),
          positive: true,
          icon: Icons.swap_horiz_rounded,
          onTap: () => _openMetricFocus(
            context,
            controller,
            _DashboardMetricKind.transfer,
            showCategories: false,
          ),
        ),
        const SizedBox(height: 12),
        _IncomeAllocationPanel(controller: controller),
        const SizedBox(height: 12),
        _PinnedDashboardSection(controller: controller, light: false),
        if (controller.dashboardPins.isNotEmpty) const SizedBox(height: 12),
        _CashFlowPanel(controller: controller),
        const SizedBox(height: 12),
        _CategoryPanel(controller: controller),
        const SizedBox(height: 12),
        _RecentTransactions(
          controller: controller,
          transactions: recent.take(5).toList(growable: false),
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          _GlassPanel(
            accent: const Color(0xFFFF5D73),
            child: Text(
              controller.errorMessage!,
              style: const TextStyle(color: Color(0xFFFFA9B5)),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.controller, this.onOpenMenu});

  final DashboardController controller;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = controller.user?.displayName?.trim();
    final greetingName = name == null || name.isEmpty ? 'there' : name;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                controller.language == AppLanguage.arabic
                    ? 'لوحة التحكم'
                    : 'Control center',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                controller.language == AppLanguage.arabic
                    ? 'نظرة عامة على وضعك المالي، $greetingName'
                    : 'A clear view of your money, $greetingName',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF93AEC5),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip:
              'Compare all sections: ${controller.dashboardComparisonLabel}',
          onPressed: () => _showDashboardComparisonPicker(context, controller),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0C2031),
            foregroundColor: const Color(0xFFC5EAF3),
          ),
          icon: const Icon(Icons.compare_arrows_rounded, size: 20),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Settings',
          onPressed: onOpenMenu,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0C2031),
            foregroundColor: const Color(0xFFC5EAF3),
          ),
          icon: const Icon(Icons.settings_outlined, size: 20),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    this.badge = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0C2031).withValues(alpha: .88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2B526C)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 12,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(icon, color: const Color(0xFFC5EAF3)),
            ),
          ),
        ),
      ),
      if (badge)
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF12D9F4),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF020B14), width: 2),
            ),
          ),
        ),
    ],
  );
}

/// A wallet is a destination for transactions, so its dashboard card opens
/// a focused history rather than the general balance-settings screen.
class _WalletActivityScreen extends StatefulWidget {
  const _WalletActivityScreen({
    required this.controller,
    required this.isWishMoney,
    required this.initialScope,
  });

  final DashboardController controller;
  final bool isWishMoney;
  final _WalletTimeScope initialScope;

  @override
  State<_WalletActivityScreen> createState() => _WalletActivityScreenState();
}

class _WalletActivityScreenState extends State<_WalletActivityScreen> {
  late _WalletTimeScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
  }

  @override
  Widget build(BuildContext context) {
    final isWish = widget.isWishMoney;
    final title = isWish ? 'Whish Money' : 'My Wallet';
    final wallets = widget.controller.walletSummary;
    final balance = isWish ? wallets.wish : wallets.cash;
    final transactions = widget.controller.transactions.where((transaction) {
      final usesWish = LabelNormalizer.isWishMoney(transaction.walletId);
      final isService = LabelNormalizer.isService(transaction.walletId);
      return (isWish ? usesWish : !usesWish && !isService) &&
          _matchesScope(transaction);
    }).toList()..sort(_newestTransactionFirst);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<_WalletTimeScope>(
            tooltip: 'Set time',
            initialValue: _scope,
            onSelected: (value) => setState(() => _scope = value),
            itemBuilder: (_) => [
              for (final scope in _WalletTimeScope.values)
                PopupMenuItem(value: scope, child: Text(scope.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Chip(
                avatar: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(_scope.label),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Wallet settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WalletScreen(
                  controller: widget.controller,
                  wallet: isWish ? WalletKind.wishMoney : WalletKind.myWallet,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: transactions.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 18) : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _WalletHistoryHeader(
              title: title,
              balance: balance,
              isWishMoney: isWish,
              transactionCount: transactions.length,
              period: _scope.label,
            );
          }
          final transaction = transactions[index - 1];
          final isIncomeFlow = transaction.affectsIncomeStats;
          final isExpenseFlow = transaction.affectsExpenseStats;
          final color = isIncomeFlow
              ? const Color(0xFF168A5B)
              : isExpenseFlow
              ? const Color(0xFFC74949)
              : transaction.isReserveable
              ? const Color(0xFFD97706)
              : const Color(0xFFC74949);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(
                isIncomeFlow
                    ? Icons.south_west_rounded
                    : isExpenseFlow
                    ? Icons.north_east_rounded
                    : transaction.isReserveable
                    ? Icons.request_quote_rounded
                    : Icons.north_east_rounded,
              ),
            ),
            title: Text(
              transaction.description.isEmpty
                  ? transaction.category
                  : transaction.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${transaction.category} · ${FinanceFormatters.shortDate(transaction.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              FinanceFormatters.amount(transaction),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            onTap: () async {
              _openDashboardTransaction(
                context,
                widget.controller,
                transaction,
              );
              if (mounted) setState(() {});
            },
            onLongPress: () async {
              _openDashboardTransaction(
                context,
                widget.controller,
                transaction,
                startEditing: true,
              );
              if (mounted) setState(() {});
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContextualAdd(
          context,
          widget.controller,
          walletId: isWish ? 'Whish Money' : 'My Wallet',
          title: 'Add to $title',
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  bool _matchesScope(FinancialTransaction transaction) {
    final now = DateTime.now();
    final date = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return switch (_scope) {
      _WalletTimeScope.today => date == today,
      _WalletTimeScope.thisWeek =>
        !date.isBefore(today.subtract(Duration(days: today.weekday % 7))) &&
            !date.isAfter(today),
      _WalletTimeScope.thisMonth =>
        date.year == today.year && date.month == today.month,
      _WalletTimeScope.allTime => true,
    };
  }
}

int _newestTransactionFirst(FinancialTransaction a, FinancialTransaction b) {
  final byDate = b.date.compareTo(a.date);
  if (byDate != 0) return byDate;
  final byCreated = (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date);
  if (byCreated != 0) return byCreated;
  return (b.id ?? '').compareTo(a.id ?? '');
}

class _WalletHistoryHeader extends StatelessWidget {
  const _WalletHistoryHeader({
    required this.title,
    required this.balance,
    required this.isWishMoney,
    required this.transactionCount,
    required this.period,
  });

  final String title;
  final WalletAccountSummary balance;
  final bool isWishMoney;
  final int transactionCount;
  final String period;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: isWishMoney
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/branding/wish_money_logo.jpg',
                    fit: BoxFit.cover,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/branding/maliyati_wallet_icon_v2.png',
                    fit: BoxFit.cover,
                  ),
                ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${FinanceFormatters.usd(balance.balanceUsd)}  ·  ${FinanceFormatters.lbp(balance.balanceLbp)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '$transactionCount transactions · $period',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF12D9F4).withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF12D9F4).withValues(alpha: .42)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.business_center_outlined,
          size: 16,
          color: Color(0xFF12D9F4),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: Color(0xFF8DB7C8),
        ),
      ],
    ),
  );
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.title,
    required this.total,
    required this.change,
    required this.updatedAt,
    required this.onWalletPressed,
    required this.onWishWalletPressed,
    required this.visible,
    required this.onToggle,
  });

  final String title;
  final double total;
  final double change;
  final DateTime? updatedAt;
  final VoidCallback onWalletPressed;
  final VoidCallback onWishWalletPressed;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isUp = change >= 0;
    final changeColor = isUp
        ? const Color(0xFF13E0A0)
        : const Color(0xFFFF6A84);
    return _GlassPanel(
      accent: const Color(0xFF12D9F4),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          const Positioned.fill(child: _SignalGrid()),
          Align(
            alignment: const Alignment(.30, 0),
            child: InkWell(
              onTap: onWishWalletPressed,
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF071C2C),
                  border: Border.all(
                    color: const Color(0xFF5ADBE9).withValues(alpha: .5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/wish_money_logo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF8FC6D6),
                          size: 19,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF9FB7C9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: onToggle,
                          borderRadius: BorderRadius.circular(99),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              visible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF9FB7C9),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        visible ? FinanceFormatters.usd(total) : '••••••',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (visible)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: changeColor.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUp
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 17,
                                  color: changeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${isUp ? '+' : ''}${FinanceFormatters.percent(change)}',
                                  style: TextStyle(
                                    color: changeColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          visible ? 'vs last period' : 'Balance hidden',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .62),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      updatedAt == null
                          ? 'Ready to sync'
                          : 'Updated ${FinanceFormatters.dateTime(updatedAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF7294AC),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 116,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        onTap: onWalletPressed,
                        borderRadius: BorderRadius.circular(60),
                        child: const _BalanceOrb(),
                      ),
                    ],
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

class _BalanceOrb extends StatelessWidget {
  const _BalanceOrb();

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [Color(0xFF1CF0FC), Color(0xFF0D6EE8), Color(0xFF092744)],
        stops: [0, .48, 1],
      ),
      border: Border.all(color: const Color(0xFF9CFAFF).withValues(alpha: .65)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF12D9F4).withValues(alpha: .26),
          blurRadius: 28,
          spreadRadius: 3,
        ),
      ],
    ),
    child: const Icon(
      Icons.account_balance_wallet_rounded,
      size: 41,
      color: Colors.white,
    ),
  );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.title,
    required this.value,
    required this.change,
    required this.positive,
    required this.icon,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String value;
  final double change;
  final bool positive;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF12D9F4) : const Color(0xFF9358FF);
    final favourable = positive ? change >= 0 : change <= 0;
    final changeColor = favourable
        ? const Color(0xFF13E0A0)
        : const Color(0xFFFF6A84);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: _GlassPanel(
        accent: color,
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
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFC9D7E5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SparkLine(color: color)),
                const SizedBox(width: 10),
                Text(
                  '${change >= 0 ? '+' : ''}${FinanceFormatters.percent(change)}',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'from last period',
              style: const TextStyle(color: Color(0xFF7091A9), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowPanel extends StatelessWidget {
  const _CashFlowPanel({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final income = _chartSeries(summary.dailyIncomeTotals, 7);
    final expense = _chartSeries(summary.dailyExpenseTotals, 7);
    return _GlassPanel(
      accent: const Color(0xFF12D9F4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Color(0xFF12D9F4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.language == AppLanguage.arabic
                      ? 'التدفق النقدي'
                      : 'Cash flow',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallRangeChip(label: periodFilterLabel(controller)),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _Legend(color: Color(0xFF12D9F4), label: 'Income'),
              SizedBox(width: 16),
              _Legend(color: Color(0xFF9358FF), label: 'Expenses'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _LineChartPainter(income: income, expense: expense),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF9BB2C5), fontSize: 11),
      ),
    ],
  );
}

class _SmallRangeChip extends StatelessWidget {
  const _SmallRangeChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 128),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF0D263A),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF315069)),
    ),
    child: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFBED1E0),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.summary.categoryExpenseTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = entries.take(5).toList();
    final total = shown.fold<double>(0, (sum, item) => sum + item.value);
    final colors = [
      const Color(0xFF12D9F4),
      const Color(0xFF2B9CFF),
      const Color(0xFF9358FF),
      const Color(0xFF5C40C9),
      const Color(0xFF1771CD),
    ];
    return _GlassPanel(
      accent: const Color(0xFF347DF7),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.language == AppLanguage.arabic
                ? 'المصروفات حسب الفئة'
                : 'Spend by category',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: shown.map((item) => item.value).toList(),
                    colors: colors,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      _CategoryRow(
                        color: colors[i],
                        title: shown[i].key,
                        fraction: total == 0 ? 0 : shown[i].value / total,
                      ),
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No expense data',
                          style: TextStyle(color: Color(0xFF93AEC5)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.color,
    required this.title,
    required this.fraction,
  });
  final Color color;
  final String title;
  final double fraction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFFC8D8E5)),
          ),
        ),
        Text(
          FinanceFormatters.percent(fraction),
          style: const TextStyle(fontSize: 11, color: Color(0xFF90A9BF)),
        ),
      ],
    ),
  );
}

class _IncomeAllocationPanel extends StatelessWidget {
  const _IncomeAllocationPanel({required this.controller, this.light = false});

  final DashboardController controller;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final summary = controller.budgetPlanSummary;
    final titleColor = light ? const Color(0xFF171A1F) : Colors.white;
    final secondaryColor = light
        ? const Color(0xFF667085)
        : const Color(0xFF90A9BF);
    final content = InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BudgetPlanScreen(controller: controller),
        ),
      ),
      onLongPress: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BudgetPlanScreen(controller: controller),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF2563EB),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income allocation',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${FinanceFormatters.usd(summary.totalAllocatedIncomeUsd)} planned this period',
                      style: TextStyle(color: secondaryColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: secondaryColor),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final bucket in BudgetBucket.values)
                    Expanded(
                      flex: math.max(1, summary.settings.percentageFor(bucket)),
                      child: ColoredBox(color: Color(bucket.colorValue)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < BudgetBucket.values.length; index++) ...[
            _BudgetDashboardRow(
              summary: summary.forBucket(BudgetBucket.values[index]),
              light: light,
            ),
            if (index != BudgetBucket.values.length - 1)
              Divider(
                height: 18,
                color: light
                    ? const Color(0xFFE4E7EC)
                    : Colors.white.withValues(alpha: .08),
              ),
          ],
        ],
      ),
    );
    return light
        ? _LightCard(child: content)
        : _GlassPanel(
            accent: const Color(0xFF2563EB),
            padding: const EdgeInsets.all(16),
            child: content,
          );
  }
}

class _BudgetDashboardRow extends StatelessWidget {
  const _BudgetDashboardRow({required this.summary, required this.light});

  final BudgetBucketSummary summary;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = Color(summary.bucket.colorValue);
    final isInvestment = summary.bucket == BudgetBucket.investment;
    final exceedsTarget = summary.isOverBudget;
    final isOverLimit = exceedsTarget && !isInvestment;
    final primaryText = light ? const Color(0xFF20242A) : Colors.white;
    final secondaryText = light
        ? const Color(0xFF667085)
        : const Color(0xFF90A9BF);
    final statusColor = isOverLimit ? const Color(0xFFDC2626) : color;
    final progressLabel =
        '${FinanceFormatters.percent(summary.coverageRatio)} '
        '${isInvestment ? 'funded' : 'covered'}';
    final varianceLabel = exceedsTarget
        ? '${FinanceFormatters.percent(summary.overRatio)} '
              '${isInvestment ? 'above' : 'over'} | '
              '${FinanceFormatters.usd(summary.overUsd)}'
        : isInvestment
        ? '${FinanceFormatters.percent(summary.remainingRatio)} short | '
              '${FinanceFormatters.usd(summary.remainingRequiredUsd)} required'
        : '${FinanceFormatters.percent(summary.remainingRatio)} available | '
              '${FinanceFormatters.usd(summary.remainingRequiredUsd)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _budgetDashboardIcon(summary.bucket),
            color: color,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Target ${FinanceFormatters.usd(summary.targetUsd)}',
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .12),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      varianceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _budgetDashboardIcon(BudgetBucket bucket) => switch (bucket) {
  BudgetBucket.investment => Icons.savings_outlined,
  BudgetBucket.commitments => Icons.event_note_rounded,
  BudgetBucket.expenses => Icons.payments_outlined,
};

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.controller,
    required this.transactions,
  });
  final DashboardController controller;
  final List<FinancialTransaction> transactions;
  @override
  Widget build(BuildContext context) => _GlassPanel(
    accent: const Color(0xFF315978),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF12D9F4)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.language == AppLanguage.arabic
                    ? 'أحدث العمليات'
                    : 'Latest transactions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${transactions.length}',
              style: const TextStyle(
                color: Color(0xFF12D9F4),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No transactions in this period',
              style: TextStyle(color: Color(0xFF93AEC5)),
            ),
          )
        else
          for (final transaction in transactions)
            _TransactionRow(controller: controller, transaction: transaction),
      ],
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.controller, required this.transaction});
  final DashboardController controller;
  final FinancialTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final income = transaction.isIncome;
    final color = income ? const Color(0xFF12D9F4) : const Color(0xFF9358FF);
    final icon = transaction.isIncome
        ? Icons.account_balance_wallet_outlined
        : _categoryIcon(transaction.category);
    // Keep gestures physical in both English and Arabic: swipe right deletes,
    // swipe left archives. Dismissible directions are logical in RTL layouts.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final deleteDirection = isRtl
        ? DismissDirection.endToStart
        : DismissDirection.startToEnd;
    const deleteAction = _DashboardSwipeAction(
      color: Color(0xFFC74949),
      icon: Icons.delete_outline_rounded,
      label: 'Recycle',
      alignment: Alignment.centerLeft,
    );
    const archiveAction = _DashboardSwipeAction(
      color: Color(0xFFD97706),
      icon: Icons.archive_outlined,
      label: 'Archive',
      alignment: Alignment.centerRight,
    );
    return Dismissible(
      key: ValueKey('dashboard-${transaction.id ?? transaction.hashCode}'),
      background: isRtl ? archiveAction : deleteAction,
      secondaryBackground: isRtl ? deleteAction : archiveAction,
      confirmDismiss: (direction) => _confirmDashboardAction(
        context,
        isDelete: direction == deleteDirection,
      ),
      onDismissed: (direction) {
        if (direction == deleteDirection) {
          controller.deleteTransaction(transaction);
        } else {
          controller.archiveTransaction(transaction);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _openDashboardTransaction(context, controller, transaction),
          onLongPress: () => _openDashboardTransaction(
            context,
            controller,
            transaction,
            startEditing: true,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: color.withValues(alpha: .34)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description.isEmpty
                            ? transaction.category
                            : transaction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transaction.category} · ${FinanceFormatters.shortDate(transaction.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF88A2B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${income ? '+' : '-'}${FinanceFormatters.amount(transaction)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('food') || value.contains('مطعم'))
      return Icons.restaurant_rounded;
    if (value.contains('transport') || value.contains('car'))
      return Icons.directions_car_rounded;
    if (value.contains('home') || value.contains('rent'))
      return Icons.home_outlined;
    if (value.contains('shop')) return Icons.shopping_bag_outlined;
    return Icons.receipt_long_rounded;
  }
}

Future<bool> _confirmDashboardAction(
  BuildContext context, {
  required bool isDelete,
}) async =>
    (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDelete ? 'Move to Recycle Bin?' : 'Archive transaction?'),
        content: Text(
          isDelete
              ? 'You can restore this transaction later from the Recycle Bin.'
              : 'You can restore this transaction later from Archived transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isDelete ? 'Move to Bin' : 'Archive'),
          ),
        ],
      ),
    )) ??
    false;

class _DashboardSwipeAction extends StatelessWidget {
  const _DashboardSwipeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    alignment: alignment,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.wide,
    required this.first,
    required this.second,
  });
  final bool wide;
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        )
      : Column(children: [first, const SizedBox(height: 12), second]);
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = const Color(0xFF284962),
  });
  final Widget child;
  final EdgeInsets padding;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(19),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .28),
          blurRadius: 24,
          offset: const Offset(0, 13),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF081B2C).withValues(alpha: .83),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: accent.withValues(alpha: .58)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .055),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _CyberBackground extends StatelessWidget {
  const _CyberBackground({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF020B14))),
      Positioned.fill(child: CustomPaint(painter: _BackgroundGridPainter())),
      Positioned.fill(child: child),
    ],
  );
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: .38,
      child: CustomPaint(painter: _SignalGridPainter()),
    ),
  );
}

class _SparkLine extends StatelessWidget {
  const _SparkLine({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 28, child: CustomPaint(painter: _SparkPainter(color)));
}

List<double> _chartSeries(Map<DateTime, double> values, int size) {
  final entries = values.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final source = entries.map((entry) => entry.value).toList();
  if (source.isEmpty) return List<double>.filled(size, 0);
  if (source.length >= size) return source.sublist(source.length - size);
  return [...List<double>.filled(size - source.length, 0), ...source];
}

class _BackgroundGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CB7E1).withValues(alpha: .055)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x3320E4FF), Color(0x00020B14)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .78, size.height * .08),
              radius: size.width * .7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF12D9F4).withValues(alpha: .19)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i / 5);
      canvas.drawLine(Offset(x, 0), Offset(x - 65, size.height), paint);
    }
    final circle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF12D9F4).withValues(alpha: .32);
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .48),
      math.min(size.width, size.height) * .33,
      circle,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [.7, .42, .66, .3, .54, .22, .45, .18];
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        i * size.width / (values.length - 1),
        values[i] * size.height,
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeroTrendPainter extends CustomPainter {
  const _HeroTrendPainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maximum = math.max(
      1.0,
      values.fold<double>(
        0,
        (previous, value) => math.max(previous, value.abs()),
      ),
    );
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = index * size.width / (values.length - 1);
      final y =
          size.height * .72 - (values[index] / maximum * size.height * .38);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x663CF4FF), Color(0x003CF4FF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE6FAFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.income, required this.expense});
  final List<double> income;
  final List<double> expense;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF8EB0CA).withValues(alpha: .15)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++)
      canvas.drawLine(
        Offset(0, size.height * i / 5),
        Offset(size.width, size.height * i / 5),
        grid,
      );
    final maximum = math.max(
      1.0,
      [
        ...income,
        ...expense,
      ].fold<double>(0, (previous, value) => math.max(previous, value)),
    );
    _drawSeries(canvas, size, income, maximum, const Color(0xFF12D9F4));
    _drawSeries(canvas, size, expense, maximum, const Color(0xFF9358FF));
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y = size.height - (values[i] / maxValue * (size.height - 16)) - 8;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y = size.height - (values[i] / maxValue * (size.height - 16)) - 8;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.income != income || oldDelegate.expense != expense;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: math.min(size.width, size.height) / 2 - 8,
    );
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = const Color(0xFF17334B),
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + .025,
        sweep - .05,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.butt
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}
