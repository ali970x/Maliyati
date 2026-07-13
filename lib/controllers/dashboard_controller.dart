import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../services/google_sheet_service.dart';

enum TimeFilter { today, last3Days, thisWeek, thisMonth, custom, allTime }

extension TimeFilterLabel on TimeFilter {
  String get label {
    switch (this) {
      case TimeFilter.today:
        return 'Today';
      case TimeFilter.last3Days:
        return 'Last 3 days';
      case TimeFilter.thisWeek:
        return 'This week';
      case TimeFilter.thisMonth:
        return 'This month';
      case TimeFilter.custom:
        return 'Custom';
      case TimeFilter.allTime:
        return 'All time';
    }
  }
}

class DashboardController extends ChangeNotifier {
  DashboardController({GoogleSheetService? service})
    : _service = service ?? GoogleSheetService();

  static const _sheetUrlKey = 'sheet_url';
  static const _exchangeRateKey = 'exchange_rate';
  static const _languageKey = 'language';

  final GoogleSheetService _service;

  List<FinancialTransaction> _transactions = [];
  String _sheetUrl = AppConfig.defaultGoogleSheetUrl;
  double _exchangeRate = AppConfig.defaultExchangeRate;
  AppLanguage _language = AppLanguage.english;
  TimeFilter _timeFilter = TimeFilter.thisMonth;
  DateTime? _selectedRecentDay;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime? _lastUpdated;
  String? _errorMessage;
  bool _isLoading = false;

  List<FinancialTransaction> get transactions =>
      List.unmodifiable(_transactions);

  String get sheetUrl => _sheetUrl;

  double get exchangeRate => _exchangeRate;

  AppLanguage get language => _language;

  AppStrings get strings => AppStrings(_language);

  TimeFilter get timeFilter => _timeFilter;

  DateTime? get selectedRecentDay => _selectedRecentDay;

  DateTime? get customStart => _customStart;

  DateTime? get customEnd => _customEnd;

  DateTime? get lastUpdated => _lastUpdated;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  bool get hasData => _transactions.isNotEmpty;

  List<FinancialTransaction> get periodTransactions {
    return _applyWindow(_transactions, currentWindow);
  }

  List<FinancialTransaction> get previousPeriodTransactions {
    final previous = previousWindow;
    if (previous == null) {
      return const [];
    }
    return _applyWindow(_transactions, previous);
  }

  DateWindow get currentWindow {
    if (_timeFilter == TimeFilter.last3Days && _selectedRecentDay != null) {
      final day = DateTime(
        _selectedRecentDay!.year,
        _selectedRecentDay!.month,
        _selectedRecentDay!.day,
      );
      return DateWindow(
        start: day,
        endExclusive: day.add(const Duration(days: 1)),
      );
    }
    return DateWindow.forFilter(
      _timeFilter,
      customStart: _customStart,
      customEnd: _customEnd,
    );
  }

  DateWindow? get previousWindow => currentWindow.previous;

  FinancialSummary get summary => FinancialSummary.fromTransactions(
    periodTransactions,
    exchangeRate: _exchangeRate,
    window: currentWindow,
  );

  FinancialSummary get previousSummary => FinancialSummary.fromTransactions(
    previousPeriodTransactions,
    exchangeRate: _exchangeRate,
    window: previousWindow,
  );

  PeriodComparison? get comparison {
    final previous = previousSummary;
    if (previous.transactionCount == 0) {
      return null;
    }
    return PeriodComparison(current: summary, previous: previous);
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _sheetUrl =
        prefs.getString(_sheetUrlKey) ?? AppConfig.defaultGoogleSheetUrl;
    _exchangeRate =
        prefs.getDouble(_exchangeRateKey) ?? AppConfig.defaultExchangeRate;
    _language = AppLanguage.fromCode(prefs.getString(_languageKey));
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _service.fetchTransactions(_sheetUrl);
      _lastUpdated = DateTime.now();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    required String sheetUrl,
    required double exchangeRate,
  }) async {
    _sheetUrl = sheetUrl.trim();
    _exchangeRate = exchangeRate <= 0
        ? AppConfig.defaultExchangeRate
        : exchangeRate;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetUrlKey, _sheetUrl);
    await prefs.setDouble(_exchangeRateKey, _exchangeRate);

    notifyListeners();
  }

  Future<void> updateLanguage(AppLanguage language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    notifyListeners();
  }

  void selectTimeFilter(TimeFilter filter) {
    _selectedRecentDay = null;
    _timeFilter = filter;
    notifyListeners();
  }

  void selectRecentDay(DateTime day) {
    _selectedRecentDay = DateTime(day.year, day.month, day.day);
    _timeFilter = TimeFilter.last3Days;
    notifyListeners();
  }

  void setCustomRange(DateTimeRange range) {
    _selectedRecentDay = null;
    _customStart = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    _customEnd = DateTime(range.end.year, range.end.month, range.end.day);
    _timeFilter = TimeFilter.custom;
    notifyListeners();
  }

  void updateTransactionLocally(
    FinancialTransaction current,
    FinancialTransaction updated,
  ) {
    final index = _transactions.indexOf(current);
    if (index == -1) {
      return;
    }
    _transactions = [
      ..._transactions.take(index),
      updated,
      ..._transactions.skip(index + 1),
    ];
    notifyListeners();
  }

  List<FinancialTransaction> _applyWindow(
    List<FinancialTransaction> source,
    DateWindow? window,
  ) {
    if (window == null ||
        (window.start == null && window.endExclusive == null)) {
      return List.unmodifiable(source);
    }

    return source
        .where(
          (transaction) =>
              transaction.hasDate && window.contains(transaction.date),
        )
        .toList();
  }
}

class DateWindow {
  const DateWindow({this.start, this.endExclusive});

  final DateTime? start;
  final DateTime? endExclusive;

  static DateWindow forFilter(
    TimeFilter filter, {
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);

    switch (filter) {
      case TimeFilter.today:
        return DateWindow(
          start: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case TimeFilter.last3Days:
        return DateWindow(
          start: today.subtract(const Duration(days: 2)),
          endExclusive: today.add(const Duration(days: 1)),
        );
      case TimeFilter.thisWeek:
        return DateWindow(
          start: today.subtract(const Duration(days: 6)),
          endExclusive: today.add(const Duration(days: 1)),
        );
      case TimeFilter.thisMonth:
        final start = DateTime(today.year, today.month);
        return DateWindow(
          start: start,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case TimeFilter.custom:
        if (customStart == null || customEnd == null) {
          return const DateWindow();
        }
        final start = DateTime(
          customStart.year,
          customStart.month,
          customStart.day,
        );
        final end = DateTime(
          customEnd.year,
          customEnd.month,
          customEnd.day,
        ).add(const Duration(days: 1));
        return DateWindow(start: start, endExclusive: end);
      case TimeFilter.allTime:
        return const DateWindow();
    }
  }

  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (start != null && normalized.isBefore(start!)) {
      return false;
    }
    if (endExclusive != null && !normalized.isBefore(endExclusive!)) {
      return false;
    }
    return true;
  }

  DateWindow? get previous {
    if (start == null || endExclusive == null) {
      return null;
    }
    final duration = endExclusive!.difference(start!);
    return DateWindow(start: start!.subtract(duration), endExclusive: start);
  }

  int get dayCount {
    if (start == null || endExclusive == null) {
      return 1;
    }
    return endExclusive!.difference(start!).inDays.clamp(1, 100000);
  }
}

class FinancialSummary {
  const FinancialSummary({
    required this.totalExpenseUsd,
    required this.totalExpenseLbp,
    required this.totalExpense,
    required this.totalIncomeUsd,
    required this.totalIncomeLbp,
    required this.totalIncome,
    required this.totalReserveableUsd,
    required this.totalReserveableLbp,
    required this.totalReserveable,
    required this.totalNetUsd,
    required this.totalNetLbp,
    required this.totalNet,
    required this.expenseRatio,
    required this.topExpenseCategory,
    required this.topIncomeCategory,
    required this.topReserveableCategory,
    required this.averageDailyExpense,
    required this.transactionCount,
    required this.largestExpense,
    required this.largestIncome,
    required this.largestReserveable,
    required this.categoryExpenseTotals,
    required this.categoryIncomeTotals,
    required this.categoryReserveableTotals,
    required this.dailyNetTotals,
    required this.dailyExpenseTotals,
    required this.dailyIncomeTotals,
    required this.dailyReserveableTotals,
  });

  final double totalExpenseUsd;
  final double totalExpenseLbp;
  final double totalExpense;
  final double totalIncomeUsd;
  final double totalIncomeLbp;
  final double totalIncome;
  final double totalReserveableUsd;
  final double totalReserveableLbp;
  final double totalReserveable;
  final double totalNetUsd;
  final double totalNetLbp;
  final double totalNet;
  final double expenseRatio;
  final String topExpenseCategory;
  final String topIncomeCategory;
  final String topReserveableCategory;
  final double averageDailyExpense;
  final int transactionCount;
  final FinancialTransaction? largestExpense;
  final FinancialTransaction? largestIncome;
  final FinancialTransaction? largestReserveable;
  final Map<String, double> categoryExpenseTotals;
  final Map<String, double> categoryIncomeTotals;
  final Map<String, double> categoryReserveableTotals;
  final Map<DateTime, double> dailyNetTotals;
  final Map<DateTime, double> dailyExpenseTotals;
  final Map<DateTime, double> dailyIncomeTotals;
  final Map<DateTime, double> dailyReserveableTotals;

  factory FinancialSummary.fromTransactions(
    List<FinancialTransaction> transactions, {
    required double exchangeRate,
    DateWindow? window,
  }) {
    var expenseUsd = 0.0;
    var expenseLbp = 0.0;
    var incomeUsd = 0.0;
    var incomeLbp = 0.0;
    var reserveableUsd = 0.0;
    var reserveableLbp = 0.0;
    FinancialTransaction? largestExpense;
    FinancialTransaction? largestIncome;
    FinancialTransaction? largestReserveable;
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};
    final reserveableByCategory = <String, double>{};
    final dailyNet = <DateTime, double>{};
    final dailyExpense = <DateTime, double>{};
    final dailyIncome = <DateTime, double>{};
    final dailyReserveable = <DateTime, double>{};

    for (final transaction in transactions) {
      final amountUsd = transaction.amountInUsd(exchangeRate);
      final day = transaction.hasDate
          ? DateTime(
              transaction.date.year,
              transaction.date.month,
              transaction.date.day,
            )
          : null;

      if (transaction.isExpense) {
        if (transaction.currency == CurrencyCode.usd) {
          expenseUsd += transaction.amount;
        } else if (transaction.currency == CurrencyCode.lbp) {
          expenseLbp += transaction.amount;
        }

        expenseByCategory.update(
          transaction.category,
          (value) => value + amountUsd,
          ifAbsent: () => amountUsd,
        );
        if (day != null) {
          dailyExpense.update(
            day,
            (value) => value + amountUsd,
            ifAbsent: () => amountUsd,
          );
          dailyNet.update(
            day,
            (value) => value - amountUsd,
            ifAbsent: () => -amountUsd,
          );
        }

        if (largestExpense == null ||
            amountUsd > largestExpense.amountInUsd(exchangeRate)) {
          largestExpense = transaction;
        }
      }

      if (transaction.isIncome) {
        if (transaction.currency == CurrencyCode.usd) {
          incomeUsd += transaction.amount;
        } else if (transaction.currency == CurrencyCode.lbp) {
          incomeLbp += transaction.amount;
        }

        incomeByCategory.update(
          transaction.category,
          (value) => value + amountUsd,
          ifAbsent: () => amountUsd,
        );
        if (day != null) {
          dailyIncome.update(
            day,
            (value) => value + amountUsd,
            ifAbsent: () => amountUsd,
          );
          dailyNet.update(
            day,
            (value) => value + amountUsd,
            ifAbsent: () => amountUsd,
          );
        }

        if (largestIncome == null ||
            amountUsd > largestIncome.amountInUsd(exchangeRate)) {
          largestIncome = transaction;
        }
      }

      if (transaction.isReserveable) {
        if (transaction.currency == CurrencyCode.usd) {
          reserveableUsd += transaction.amount;
        } else if (transaction.currency == CurrencyCode.lbp) {
          reserveableLbp += transaction.amount;
        }

        reserveableByCategory.update(
          transaction.category,
          (value) => value + amountUsd,
          ifAbsent: () => amountUsd,
        );
        if (day != null) {
          dailyReserveable.update(
            day,
            (value) => value + amountUsd,
            ifAbsent: () => amountUsd,
          );
        }

        if (largestReserveable == null ||
            amountUsd > largestReserveable.amountInUsd(exchangeRate)) {
          largestReserveable = transaction;
        }
      }
    }

    final totalExpense = expenseUsd + expenseLbp / exchangeRate;
    final totalIncome = incomeUsd + incomeLbp / exchangeRate;
    final totalReserveable = reserveableUsd + reserveableLbp / exchangeRate;
    final totalNetUsd = incomeUsd - expenseUsd;
    final totalNetLbp = incomeLbp - expenseLbp;
    final totalNet = totalIncome - totalExpense;
    final dayCount = window?.dayCount ?? _activeDayCount(transactions);

    return FinancialSummary(
      totalExpenseUsd: expenseUsd,
      totalExpenseLbp: expenseLbp,
      totalExpense: totalExpense,
      totalIncomeUsd: incomeUsd,
      totalIncomeLbp: incomeLbp,
      totalIncome: totalIncome,
      totalReserveableUsd: reserveableUsd,
      totalReserveableLbp: reserveableLbp,
      totalReserveable: totalReserveable,
      totalNetUsd: totalNetUsd,
      totalNetLbp: totalNetLbp,
      totalNet: totalNet,
      expenseRatio: totalIncome <= 0 ? 0 : totalExpense / totalIncome,
      topExpenseCategory: _topCategory(expenseByCategory),
      topIncomeCategory: _topCategory(incomeByCategory),
      topReserveableCategory: _topCategory(reserveableByCategory),
      averageDailyExpense: totalExpense / dayCount,
      transactionCount: transactions.length,
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      largestReserveable: largestReserveable,
      categoryExpenseTotals: _sortMap(expenseByCategory),
      categoryIncomeTotals: _sortMap(incomeByCategory),
      categoryReserveableTotals: _sortMap(reserveableByCategory),
      dailyNetTotals: _sortDateMap(dailyNet),
      dailyExpenseTotals: _sortDateMap(dailyExpense),
      dailyIncomeTotals: _sortDateMap(dailyIncome),
      dailyReserveableTotals: _sortDateMap(dailyReserveable),
    );
  }

  static int _activeDayCount(List<FinancialTransaction> transactions) {
    if (transactions.isEmpty) {
      return 1;
    }
    final days = transactions
        .where((transaction) => transaction.hasDate)
        .map(
          (transaction) => DateTime(
            transaction.date.year,
            transaction.date.month,
            transaction.date.day,
          ),
        )
        .toSet()
        .length;
    return days.clamp(1, 100000);
  }

  static String _topCategory(Map<String, double> values) {
    if (values.isEmpty) {
      return 'No data';
    }
    return values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static Map<String, double> _sortMap(Map<String, double> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  static Map<DateTime, double> _sortDateMap(Map<DateTime, double> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(entries);
  }
}

class PeriodComparison {
  const PeriodComparison({required this.current, required this.previous});

  final FinancialSummary current;
  final FinancialSummary previous;

  double get incomeChange => _change(current.totalIncome, previous.totalIncome);

  double get expenseChange =>
      _change(current.totalExpense, previous.totalExpense);

  double get netChange => _change(current.totalNet, previous.totalNet);

  double _change(double currentValue, double previousValue) {
    if (previousValue == 0) {
      return currentValue == 0 ? 0 : 1;
    }
    return (currentValue - previousValue) / previousValue.abs();
  }
}
