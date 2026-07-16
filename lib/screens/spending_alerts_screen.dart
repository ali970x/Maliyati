import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/finance_formatters.dart';
import '../widgets/responsive_layout.dart';

class SpendingAlertsScreen extends StatefulWidget {
  const SpendingAlertsScreen({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<SpendingAlertsScreen> createState() => _SpendingAlertsScreenState();
}

class _SpendingAlertsScreenState extends State<SpendingAlertsScreen> {
  static const _dailyKey = 'spending_limit_daily';
  static const _weeklyKey = 'spending_limit_weekly';
  static const _monthlyKey = 'spending_limit_monthly';

  final _dailyController = TextEditingController();
  final _weeklyController = TextEditingController();
  final _monthlyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    _dailyController.text = (prefs.getDouble(_dailyKey) ?? 0).toStringAsFixed(
      0,
    );
    _weeklyController.text = (prefs.getDouble(_weeklyKey) ?? 0).toStringAsFixed(
      0,
    );
    _monthlyController.text = (prefs.getDouble(_monthlyKey) ?? 0)
        .toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_dailyKey, _amount(_dailyController.text));
      await prefs.setDouble(_weeklyKey, _amount(_weeklyController.text));
      await prefs.setDouble(_monthlyKey, _amount(_monthlyController.text));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert limits saved.')));
      setState(() {});
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daily = _spentSince(DateTime(now.year, now.month, now.day));
    final weekly = _spentSince(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
    );
    final monthly = _spentSince(DateTime(now.year, now.month));

    return ListView(
      padding: AppResponsive.pagePadding(context),
      children: [
        Text(
          'Spending alerts',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set your daily, weekly, and monthly expense limits.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _RiskCard(
          title: 'Today',
          spent: daily,
          limit: _amount(_dailyController.text),
          exchangeRate: widget.controller.exchangeRate,
        ),
        const SizedBox(height: 10),
        _RiskCard(
          title: 'This week',
          spent: weekly,
          limit: _amount(_weeklyController.text),
          exchangeRate: widget.controller.exchangeRate,
        ),
        const SizedBox(height: 10),
        _RiskCard(
          title: 'This month',
          spent: monthly,
          limit: _amount(_monthlyController.text),
          exchangeRate: widget.controller.exchangeRate,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Limits in USD',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _LimitField(controller: _dailyController, label: 'Daily max'),
                const SizedBox(height: 10),
                _LimitField(controller: _weeklyController, label: 'Weekly max'),
                const SizedBox(height: 10),
                _LimitField(
                  controller: _monthlyController,
                  label: 'Monthly max',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save alert limits'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _spentSince(DateTime start) {
    final end = DateTime.now().add(const Duration(days: 1));
    return widget.controller.transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.expense &&
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end),
        )
        .fold<double>(
          0,
          (sum, transaction) =>
              sum + transaction.amountInUsd(widget.controller.exchangeRate),
        );
  }

  double _amount(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.speed_rounded),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.title,
    required this.spent,
    required this.limit,
    required this.exchangeRate,
  });

  final String title;
  final double spent;
  final double limit;
  final double exchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.4);
    final color = limit <= 0
        ? theme.colorScheme.outline
        : ratio >= 1
        ? const Color(0xFFB91C1C)
        : ratio >= 0.75
        ? const Color(0xFFD97706)
        : const Color(0xFF168A5B);
    final label = limit <= 0
        ? 'No limit set'
        : ratio >= 1
        ? 'Danger'
        : ratio >= 0.75
        ? 'Careful'
        : 'Safe';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color),
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
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: limit <= 0 ? 0 : ratio.clamp(0.0, 1.0),
              minHeight: 9,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            if (limit <= 0) ...[
              Text(
                'Add a limit to activate this alert.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '${FinanceFormatters.usd(spent)} spent'
              '${limit > 0 ? ' / ${FinanceFormatters.usd(limit)} limit' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
