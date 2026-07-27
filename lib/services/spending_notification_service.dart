import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

class SpendingNotificationService {
  SpendingNotificationService._();

  static final instance = SpendingNotificationService._();

  static const dailyLimitKey = 'spending_limit_daily';
  static const weeklyLimitKey = 'spending_limit_weekly';
  static const monthlyLimitKey = 'spending_limit_monthly';
  static const enabledKey = 'spending_notifications_enabled';

  static const _channel = MethodChannel('maliyati/notifications');
  static const _dailyNotificationKey = 'spending_notification_daily';
  static const _weeklyNotificationKey = 'spending_notification_weekly';
  static const _monthlyNotificationKey = 'spending_notification_monthly';

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? false;
  }

  Future<bool> enable() async {
    if (!isSupported) {
      return false;
    }
    final granted =
        await _channel.invokeMethod<bool>('requestPermission') ?? false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, granted);
    return granted;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, false);
  }

  Future<void> resetSentMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dailyNotificationKey);
    await prefs.remove(_weeklyNotificationKey);
    await prefs.remove(_monthlyNotificationKey);
  }

  Future<void> evaluateAndNotify({
    required List<FinancialTransaction> transactions,
    required double exchangeRate,
  }) async {
    if (!isSupported || !await isEnabled()) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday % 7));
    final monthStart = DateTime(now.year, now.month);
    final end = today.add(const Duration(days: 1));

    await _notifyLimit(
      prefs: prefs,
      markerKey: _dailyNotificationKey,
      periodId: _dayId(today),
      notificationId: 5101,
      title: 'Daily spending limit reached',
      periodLabel: 'today',
      spent: _spentBetween(transactions, today, end, exchangeRate),
      limit: prefs.getDouble(dailyLimitKey) ?? 0,
    );
    await _notifyLimit(
      prefs: prefs,
      markerKey: _weeklyNotificationKey,
      periodId: _dayId(weekStart),
      notificationId: 5102,
      title: 'Weekly spending limit reached',
      periodLabel: 'this week',
      spent: _spentBetween(transactions, weekStart, end, exchangeRate),
      limit: prefs.getDouble(weeklyLimitKey) ?? 0,
    );
    await _notifyLimit(
      prefs: prefs,
      markerKey: _monthlyNotificationKey,
      periodId: '${monthStart.year}-${monthStart.month}',
      notificationId: 5103,
      title: 'Monthly spending limit reached',
      periodLabel: 'this month',
      spent: _spentBetween(transactions, monthStart, end, exchangeRate),
      limit: prefs.getDouble(monthlyLimitKey) ?? 0,
    );
  }

  Future<void> _notifyLimit({
    required SharedPreferences prefs,
    required String markerKey,
    required String periodId,
    required int notificationId,
    required String title,
    required String periodLabel,
    required double spent,
    required double limit,
  }) async {
    if (limit <= 0 || spent < limit || prefs.getString(markerKey) == periodId) {
      return;
    }
    await _channel.invokeMethod<void>('show', {
      'id': notificationId,
      'title': title,
      'body':
          'You spent \$${spent.toStringAsFixed(2)} $periodLabel. '
          'Your limit is \$${limit.toStringAsFixed(2)}.',
    });
    await prefs.setString(markerKey, periodId);
  }

  double _spentBetween(
    List<FinancialTransaction> transactions,
    DateTime start,
    DateTime end,
    double exchangeRate,
  ) {
    return transactions
        .where(
          (transaction) =>
              transaction.affectsExpenseStats &&
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end),
        )
        .fold<double>(
          0,
          (total, transaction) => total + transaction.amountInUsd(exchangeRate),
        );
  }

  String _dayId(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
