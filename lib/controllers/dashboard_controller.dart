import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../services/accounting_rules.dart';
import '../services/category_taxonomy.dart';
import '../services/firebase_finance_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/gemini_transaction_parser.dart';
import '../services/google_drive_backup_service.dart';
import '../services/google_sheet_service.dart';
import '../services/label_normalizer.dart';
import '../services/sheet_export_service.dart';
import '../services/spending_notification_service.dart';

enum TimeFilter { today, last3Days, thisWeek, thisMonth, custom, allTime }

enum WalletComparisonRange { day, week, month }

extension WalletComparisonRangeLabel on WalletComparisonRange {
  String get label => switch (this) {
    WalletComparisonRange.day => 'Yesterday',
    WalletComparisonRange.week => 'Last week',
    WalletComparisonRange.month => 'Last month',
  };

  Duration get duration => switch (this) {
    WalletComparisonRange.day => const Duration(days: 1),
    WalletComparisonRange.week => const Duration(days: 7),
    WalletComparisonRange.month => const Duration(days: 30),
  };
}

/// Kept as a single value for backwards source compatibility. The old theme
/// gallery has been retired: Cyber Grid is now the product identity.
enum AppThemeStyle { cyberGrid }

enum AppLockMethod { biometric, pin }

class CategoryRule {
  const CategoryRule({required this.name, required this.statuses});

  final String name;
  final Set<TransactionType> statuses;

  bool appliesTo(TransactionType type) => statuses.contains(type);

  Map<String, dynamic> toJson() => {
    'name': name,
    'statuses': statuses.map((status) => status.name).toList(),
  };

  static CategoryRule fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['statuses'];
    return CategoryRule(
      name: '${json['name'] ?? ''}'.trim(),
      statuses: rawStatuses is List
          ? rawStatuses
                .map((value) => _typeFromName('$value'))
                .where((value) => value != TransactionType.unknown)
                .toSet()
          : <TransactionType>{},
    );
  }

  static TransactionType _typeFromName(String value) {
    final normalized = value.trim().toLowerCase();
    for (final type in TransactionType.values) {
      if (type.name.toLowerCase() == normalized ||
          type.label.toLowerCase() == normalized) {
        return type;
      }
    }
    if (normalized == 'credit' || normalized == 'receivable') {
      return TransactionType.reserveable;
    }
    return TransactionType.unknown;
  }
}

extension AppThemeStyleDetails on AppThemeStyle {
  Color get seedColor => switch (this) {
    AppThemeStyle.cyberGrid => const Color(0xFF12D9F4),
  };

  String get label => switch (this) {
    AppThemeStyle.cyberGrid => 'Cyber Grid',
  };

  bool get isDark => true;
}

class SmartActionExecutionSummary {
  const SmartActionExecutionSummary({
    required this.total,
    required this.added,
    required this.edited,
    required this.deleted,
    required this.settled,
    required this.failures,
  });

  final int total;
  final int added;
  final int edited;
  final int deleted;
  final int settled;
  final List<String> failures;

  int get succeeded => added + edited + deleted + settled;

  bool get hasFailures => failures.isNotEmpty;
}

class CategoryCleanupResult {
  const CategoryCleanupResult({
    required this.scanned,
    required this.updated,
    required this.categories,
  });

  final int scanned;
  final int updated;
  final int categories;
}

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
  DashboardController({
    GoogleSheetService? service,
    FirebaseFinanceService? firebaseService,
    SheetExportService? sheetExportService,
    GeminiTransactionParser? geminiParser,
    GoogleDriveBackupService? googleDriveBackupService,
  }) : _usesInjectedSheetService = service != null,
       _service = service ?? GoogleSheetService(),
       _sheetExportService = sheetExportService ?? SheetExportService(),
       _geminiParser = geminiParser ?? GeminiTransactionParser(),
       _googleDriveBackupService =
           googleDriveBackupService ?? GoogleDriveBackupService() {
    _firebaseService = firebaseService;
  }

  static const _sheetUrlKey = 'sheet_url';
  static const _exchangeRateKey = 'exchange_rate';
  static const _languageKey = 'language';
  static const _themeModeKey = 'theme_mode';
  static const _themeStyleKey = 'theme_style';
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _appLockMethodKey = 'app_lock_method';
  static const _autoBackupEnabledKey = 'auto_backup_enabled';
  static const _lastAutoBackupKey = 'last_auto_backup';
  static const _calculationStartMonthKey = 'calculation_start_month';
  static const _firestoreEnabledKey = 'firestore_enabled';
  static const _sheetExportEndpointKey = 'sheet_export_endpoint';
  static const _sheetExportSecretKey = 'sheet_export_secret';
  static const _localBackupsKey = 'local_transaction_backups';
  static const _walletOpeningUsdKey = 'wallet_opening_usd';
  static const _walletOpeningLbpKey = 'wallet_opening_lbp';
  static const _wishWalletOpeningUsdKey = 'wish_wallet_opening_usd';
  static const _wishWalletOpeningLbpKey = 'wish_wallet_opening_lbp';
  static const _walletBaselineTransactionIdsKey =
      'wallet_baseline_transaction_ids';
  static const _cashWalletBaselineTransactionIdsKey =
      'cash_wallet_baseline_transaction_ids';
  static const _wishWalletBaselineTransactionIdsKey =
      'wish_wallet_baseline_transaction_ids';
  static const _cashWalletComparisonRangeKey = 'cash_wallet_comparison_range';
  static const _wishWalletComparisonRangeKey = 'wish_wallet_comparison_range';
  static const _categoryRulesKey = 'category_rules_v1';

  final GoogleSheetService _service;
  final bool _usesInjectedSheetService;
  FirebaseFinanceService? _firebaseService;
  final SheetExportService _sheetExportService;
  final GeminiTransactionParser _geminiParser;
  final GoogleDriveBackupService _googleDriveBackupService;

  List<FinancialTransaction> _transactions = [];
  String _sheetUrl = AppConfig.defaultGoogleSheetUrl;
  String _sheetExportEndpoint = AppConfig.sheetExportEndpoint;
  String _sheetExportSecret = AppConfig.sheetExportSecret;
  double _exchangeRate = AppConfig.defaultExchangeRate;
  AppLanguage _language = AppLanguage.english;
  ThemeMode _themeMode = ThemeMode.light;
  AppThemeStyle _themeStyle = AppThemeStyle.cyberGrid;
  bool _appLockEnabled = false;
  AppLockMethod _appLockMethod = AppLockMethod.biometric;
  bool _autoBackupEnabled = false;
  double _walletOpeningUsd = 0;
  double _walletOpeningLbp = 0;
  double _wishWalletOpeningUsd = 0;
  double _wishWalletOpeningLbp = 0;
  Set<String> _cashWalletBaselineTransactionIds = <String>{};
  Set<String> _wishWalletBaselineTransactionIds = <String>{};
  WalletComparisonRange _cashWalletComparisonRange = WalletComparisonRange.week;
  WalletComparisonRange _wishWalletComparisonRange = WalletComparisonRange.week;
  DateTime? _lastAutoBackup;
  String? _lastAutoBackupError;
  TimeFilter _timeFilter = TimeFilter.thisMonth;
  DateTime? _selectedRecentDay;
  DateTime? _selectedMonth;
  DateTime? _referenceMonth;
  int? _selectedMonthWeek;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime? _calculationStartMonth;
  DateTime? _lastUpdated;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isFirebaseConfigured = false;
  bool _useFirestore = false;
  FinanceUser? _user;
  List<AdminUserSnapshot> _adminUsers = const [];
  bool _isAdminLoading = false;
  List<CategoryRule> _categoryRules = const [];

  List<FinancialTransaction> get transactions => List.unmodifiable(
    _transactions.where((transaction) => !transaction.isArchived),
  );

  List<FinancialTransaction> get archivedTransactions => List.unmodifiable(
    _transactions.where((transaction) => transaction.isArchived),
  );

  double get walletOpeningUsd => _walletOpeningUsd;

  double get walletOpeningLbp => _walletOpeningLbp;

  double get wishWalletOpeningUsd => _wishWalletOpeningUsd;

  double get wishWalletOpeningLbp => _wishWalletOpeningLbp;

  WalletComparisonRange walletComparisonRange({required bool isWishMoney}) =>
      isWishMoney ? _wishWalletComparisonRange : _cashWalletComparisonRange;

  /// Wallet balances begin at the last reset. Categories never decide which
  /// wallet changes; only the selected payment method (My Wallet or Whish
  /// Money)
  /// does.
  WalletSummary get walletSummary => _walletSummaryFor(_transactions);

  WalletSummary _walletSummaryFor(List<FinancialTransaction> transactions) =>
      WalletSummary.fromTransactions(
        transactions,
        cashOpeningUsd: _walletOpeningUsd,
        cashOpeningLbp: _walletOpeningLbp,
        wishOpeningUsd: _wishWalletOpeningUsd,
        wishOpeningLbp: _wishWalletOpeningLbp,
        ignoredCashTransactionIds: _cashWalletBaselineTransactionIds,
        ignoredWishTransactionIds: _wishWalletBaselineTransactionIds,
      );

  /// Wallet balance shown on the dashboard follows the selected time filter.
  /// Today shows the current balance; other periods show the balance at their
  /// starting day, so “Last 3 days” means the balance from three days ago.
  WalletSummary get dashboardWalletSummary {
    if (_timeFilter == TimeFilter.today || _timeFilter == TimeFilter.allTime) {
      return _walletSummaryAsOf(DateTime.now());
    }
    final start = currentWindow.start;
    if (start == null) return walletSummary;
    return _walletSummaryAsOf(start.subtract(const Duration(days: 1)));
  }

  String get dashboardWalletPeriodLabel {
    if (_timeFilter == TimeFilter.today || _timeFilter == TimeFilter.allTime) {
      return 'Current balance';
    }
    final start = currentWindow.start;
    if (start == null) return 'Current balance';
    final date = DateTime(start.year, start.month, start.day);
    return 'Balance on ${date.day}/${date.month}/${date.year}';
  }

  WalletSummary _walletSummaryAsOf(DateTime asOf) {
    final cutoff = DateTime(asOf.year, asOf.month, asOf.day);
    return _walletSummaryFor(
      _transactions
          .where((transaction) => !transaction.date.isAfter(cutoff))
          .toList(),
    );
  }

  WalletBalanceComparison walletBalanceComparison({required bool isWishMoney}) {
    final range = walletComparisonRange(isWishMoney: isWishMoney);
    final current = isWishMoney ? walletSummary.wish : walletSummary.cash;
    final earlierSummary = _walletSummaryAsOf(
      DateTime.now().subtract(range.duration),
    );
    final earlier = isWishMoney ? earlierSummary.wish : earlierSummary.cash;
    return WalletBalanceComparison(
      range: range,
      usdChange: current.balanceUsd - earlier.balanceUsd,
      lbpChange: current.balanceLbp - earlier.balanceLbp,
    );
  }

  String get sheetUrl => _sheetUrl;

  String get sheetExportEndpoint => _sheetExportEndpoint;

  String get sheetExportSecret => _sheetExportSecret;

  double get exchangeRate => _exchangeRate;

  AppLanguage get language => _language;

  ThemeMode get themeMode => _themeMode;

  AppThemeStyle get themeStyle => _themeStyle;

  bool get isAppLockEnabled => _appLockEnabled;

  AppLockMethod get appLockMethod => _appLockMethod;

  bool get isAutoBackupEnabled => _autoBackupEnabled;

  AppStrings get strings => AppStrings(_language);

  TimeFilter get timeFilter => _timeFilter;

  DateTime? get selectedRecentDay => _selectedRecentDay;

  DateTime? get selectedMonth => _selectedMonth;

  DateTime? get referenceMonth => _referenceMonth;

  int? get selectedMonthWeek => _selectedMonthWeek;

  DateTime get referenceDate {
    final now = DateTime.now();
    final month = _referenceMonth;
    if (month == null) {
      return DateTime(now.year, now.month, now.day);
    }
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, now.day.clamp(1, lastDay));
  }

  DateTime? get customStart => _customStart;

  DateTime? get customEnd => _customEnd;

  DateTime? get calculationStartMonth => _calculationStartMonth;

  DateTime? get lastUpdated => _lastUpdated;

  DateTime? get lastAutoBackup => _lastAutoBackup;

  String? get lastAutoBackupError => _lastAutoBackupError;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  bool get hasData => _transactions.isNotEmpty;

  bool get isFirebaseConfigured => _isFirebaseConfigured;

  bool get useFirestore => _useFirestore;

  bool get isSignedIn => _user != null;

  bool get isAdmin => _firebaseService?.isCurrentUserAdmin ?? false;

  List<AdminUserSnapshot> get adminUsers => List.unmodifiable(_adminUsers);

  bool get isAdminLoading => _isAdminLoading;

  String? get firebaseSetupMessage {
    if (_isFirebaseConfigured) {
      return null;
    }
    final error = FirebaseBootstrap.lastError;
    if (error == null) {
      return 'Firebase is starting. Try signing in.';
    }
    return _firebaseBootstrapErrorMessage(error);
  }

  FinanceUser? get user => _user;

  List<String> get categoryOptions {
    final values = {
      for (final rule in _categoryRules) rule.name.trim(),
      for (final transaction in _transactions) transaction.category.trim(),
    }.where((value) => value.isNotEmpty).toList()..sort();
    return values;
  }

  List<CategoryRule> get categoryRules => List.unmodifiable(_categoryRules);

  List<String> categoryOptionsFor(TransactionType type) {
    final values = {
      for (final rule in _categoryRules)
        if (rule.appliesTo(type)) rule.name.trim(),
      for (final transaction in _transactions)
        if (transaction.type == type) transaction.category.trim(),
    }.where((value) => value.isNotEmpty).toList()..sort();
    return values.isEmpty ? ['Uncategorized'] : values;
  }

  List<String> get paymentMethodOptions {
    final values = <String>{
      'My Wallet',
      'Whish Money',
      ..._transactions
          .map((transaction) => transaction.paymentMethod.trim())
          .where((value) => value.isNotEmpty),
    }.toList()..sort();
    return values;
  }

  bool get isSheetExportConfigured => _sheetExportService.isConfigured(
    endpoint: _sheetExportEndpoint,
    secret: _sheetExportSecret,
  );

  FirebaseFinanceService get _firebase =>
      _firebaseService ??= FirebaseFinanceService();

  List<FinancialTransaction> get calculationTransactions {
    final start = _calculationStartMonth;
    if (start == null) {
      return _transactions
          .where((transaction) => !transaction.isArchived)
          .toList();
    }
    return _transactions.where((transaction) {
      if (transaction.isArchived) return false;
      if (!transaction.hasDate) {
        return false;
      }
      final day = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      return !day.isBefore(start);
    }).toList();
  }

  List<FinancialTransaction> get periodTransactions {
    return _applyWindow(calculationTransactions, currentWindow);
  }

  List<FinancialTransaction> get previousPeriodTransactions {
    final previous = previousWindow;
    if (previous == null) {
      return const [];
    }
    return _applyWindow(calculationTransactions, previous);
  }

  DateWindow get currentWindow {
    if (_timeFilter == TimeFilter.last3Days && _selectedRecentDay != null) {
      final day = DateTime(
        _selectedRecentDay!.year,
        _selectedRecentDay!.month,
        _selectedRecentDay!.day,
      );
      final window = DateWindow(
        start: day,
        endExclusive: day.add(const Duration(days: 1)),
      );
      return _referenceMonth == null
          ? window
          : window.intersect(DateWindow.forMonth(_referenceMonth!));
    }
    if (_timeFilter == TimeFilter.thisWeek && _selectedMonthWeek != null) {
      final month = _referenceMonth ?? DateTime.now();
      final monthStart = DateTime(month.year, month.month);
      final monthEnd = DateTime(month.year, month.month + 1);
      final start = monthStart.add(Duration(days: _selectedMonthWeek! * 7));
      final proposedEnd = start.add(const Duration(days: 7));
      return DateWindow(
        start: start,
        endExclusive: proposedEnd.isBefore(monthEnd) ? proposedEnd : monthEnd,
      );
    }
    if (_timeFilter == TimeFilter.thisMonth && _selectedMonth != null) {
      final start = DateTime(_selectedMonth!.year, _selectedMonth!.month);
      final now = DateTime.now();
      final isCurrentMonth = start.year == now.year && start.month == now.month;
      return DateWindow(
        start: start,
        endExclusive: isCurrentMonth
            ? DateTime(
                now.year,
                now.month,
                now.day,
              ).add(const Duration(days: 1))
            : DateTime(start.year, start.month + 1),
      );
    }
    if (_timeFilter == TimeFilter.allTime && _referenceMonth != null) {
      return DateWindow.forMonth(_referenceMonth!);
    }
    var window = DateWindow.forFilter(
      _timeFilter,
      customStart: _customStart,
      customEnd: _customEnd,
      now: referenceDate,
    );
    if (_referenceMonth != null &&
        _timeFilter != TimeFilter.custom &&
        _timeFilter != TimeFilter.allTime) {
      if (_timeFilter == TimeFilter.thisMonth) {
        return DateWindow.forMonth(_referenceMonth!);
      }
      window = window.intersect(DateWindow.forMonth(_referenceMonth!));
    }
    return window;
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
    try {
      _isFirebaseConfigured = await FirebaseBootstrap.initializeIfConfigured();
      // If the first bootstrap attempt failed in a browser but Firebase was
      // already initialized by main(), keep the login flow available.
      _isFirebaseConfigured =
          _isFirebaseConfigured || FirebaseBootstrap.isInitialized;
      final prefs = await SharedPreferences.getInstance();
      _sheetUrl =
          prefs.getString(_sheetUrlKey) ?? AppConfig.defaultGoogleSheetUrl;
      _sheetExportEndpoint =
          prefs.getString(_sheetExportEndpointKey) ??
          AppConfig.sheetExportEndpoint;
      _sheetExportSecret =
          prefs.getString(_sheetExportSecretKey) ?? AppConfig.sheetExportSecret;
      _exchangeRate =
          prefs.getDouble(_exchangeRateKey) ?? AppConfig.defaultExchangeRate;
      _language = AppLanguage.fromCode(prefs.getString(_languageKey));
      // The dashboard opens on the last completed month. Long-pressing a
      // period control can then compare it with any chosen month/year.
      final now = DateTime.now();
      // Dashboard figures should always open on the current calendar month.
      _selectedMonth = DateTime(now.year, now.month);
      _timeFilter = TimeFilter.thisMonth;
      _themeStyle = AppThemeStyle.cyberGrid;
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == prefs.getString(_themeModeKey),
        orElse: () => ThemeMode.light,
      );
      _appLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
      _appLockMethod = AppLockMethod.values.firstWhere(
        (method) => method.name == prefs.getString(_appLockMethodKey),
        orElse: () => AppLockMethod.biometric,
      );
      if (_appLockMethod == AppLockMethod.pin) {
        _appLockMethod = AppLockMethod.biometric;
        await prefs.setString(_appLockMethodKey, AppLockMethod.biometric.name);
      }
      _autoBackupEnabled = prefs.getBool(_autoBackupEnabledKey) ?? false;
      // Wallets are account data. Never hydrate them from device-wide prefs:
      // that would make a second Google account inherit the first account's
      // My Wallet and Whish balances. They are loaded only from this Firebase
      // UID.
      _resetWalletState();
      _categoryRules = _loadCategoryRules(
        prefs,
        key: _categoryRulesStorageKey(),
      );
      _calculationStartMonth = _monthFromStorage(
        prefs.getString(_calculationStartMonthKey),
      );
      _useFirestore = _isFirebaseConfigured;
      if (_isFirebaseConfigured && !_usesInjectedSheetService) {
        try {
          _user = await _firebase.waitForStoredUser();
        } catch (_) {
          // A damaged browser session must never block the sign-in screen.
          _user = null;
          try {
            await _firebase.signOut();
          } catch (_) {}
        }
      }
      _loadAutoBackupState(prefs);
      _categoryRules = _loadCategoryRules(
        prefs,
        key: _categoryRulesStorageKey(),
      );
      await _loadWalletSettings();
      await refresh(silentWhenSignedOut: true);
      await _runDailyAutoBackupIfDue();
    } catch (_) {
      _isFirebaseConfigured = FirebaseBootstrap.isInitialized;
      _useFirestore = false;
      _user = null;
      _transactions = const [];
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  List<FinancialTransaction> _cleanTransactionLabels(
    List<FinancialTransaction> transactions,
  ) => transactions.map(AccountingRules.normalize).toList(growable: false);

  Future<void> refresh({bool silentWhenSignedOut = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_usesInjectedSheetService) {
        _transactions = _cleanTransactionLabels(
          await _service.fetchTransactions(_sheetUrl),
        );
        _lastUpdated = DateTime.now();
        return;
      }
      if (!_isFirebaseConfigured) {
        throw const FirebaseFinanceException(
          'Firebase is not configured. Check firebase_options.dart and google-services.json.',
        );
      }
      final basicUser = _firebase.currentUser;
      if (basicUser == null) {
        _user = null;
        _transactions = const [];
        _lastUpdated = DateTime.now();
        return;
      }
      _user = await _firebase.loadCurrentUser() ?? basicUser;
      final fetchedTransactions = await _firebase.fetchTransactions();
      _transactions = _cleanTransactionLabels(fetchedTransactions);
      try {
        await _persistCategoryCleanup(fetchedTransactions);
      } catch (_) {
        // Category cleanup must never hide otherwise valid account data.
        await saveCategoryRules(_standardCategoryRules(_transactions));
      }
      if (isAdmin) {
        await refreshAdminUsers(silent: true);
      }
      await _saveSequentialIdsIfNeeded();
      _lastUpdated = DateTime.now();
    } catch (error) {
      if (silentWhenSignedOut && _user == null) {
        _transactions = const [];
        _lastUpdated = DateTime.now();
      } else {
        _errorMessage = _friendlyErrorMessage(error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('Null check operator used on a null value')) {
      return 'Could not restore the saved session. Please sign in again.';
    }
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password') ||
        message.contains('user-not-found')) {
      return 'Email or password is not correct. If this is the new Firebase project, create a new account first or use Forgot password.';
    }
    if (message.contains('email-already-in-use')) {
      return 'This email already has an account. Sign in instead, or use Forgot password.';
    }
    if (message.contains('weak-password')) {
      return 'Use a stronger password with at least 6 characters.';
    }
    if (message.contains('operation-not-allowed')) {
      return 'Email and password login is not enabled in Firebase. Enable Authentication > Sign-in method > Email/Password.';
    }
    return message;
  }

  String _firebaseBootstrapErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('api-key-not-valid')) {
      return 'Firebase web API key is not valid for this project.';
    }
    if (message.contains('auth/invalid-api-key')) {
      return 'Firebase Auth rejected the web API key.';
    }
    if (message.contains('duplicate-app')) {
      return 'Firebase is already open. Try signing in again.';
    }
    return 'Firebase setup error: $message';
  }

  Future<bool> _ensureFirebaseReady() async {
    if (_isFirebaseConfigured || FirebaseBootstrap.isInitialized) {
      _isFirebaseConfigured = true;
      return true;
    }

    _isFirebaseConfigured = await FirebaseBootstrap.initializeIfConfigured();
    _isFirebaseConfigured =
        _isFirebaseConfigured || FirebaseBootstrap.isInitialized;
    if (!_isFirebaseConfigured) {
      final error = FirebaseBootstrap.lastError;
      _errorMessage = error == null
          ? 'Firebase is not ready yet. Try again.'
          : _firebaseBootstrapErrorMessage(error);
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> updateSettings({
    String? sheetUrl,
    required String sheetExportEndpoint,
    required String sheetExportSecret,
    required double exchangeRate,
  }) async {
    _sheetUrl = sheetUrl?.trim().isNotEmpty == true
        ? sheetUrl!.trim()
        : _sheetUrl;
    _sheetExportEndpoint = sheetExportEndpoint.trim();
    _sheetExportSecret = sheetExportSecret.trim();
    _exchangeRate = exchangeRate <= 0
        ? AppConfig.defaultExchangeRate
        : exchangeRate;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetUrlKey, _sheetUrl);
    await prefs.setString(_sheetExportEndpointKey, _sheetExportEndpoint);
    await prefs.setString(_sheetExportSecretKey, _sheetExportSecret);
    await prefs.setDouble(_exchangeRateKey, _exchangeRate);
    await _saveSheetIntegrationSettings();

    notifyListeners();
  }

  Future<void> updateExchangeRate(double exchangeRate) async {
    if (exchangeRate <= 0) return;
    _exchangeRate = exchangeRate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_exchangeRateKey, _exchangeRate);
    notifyListeners();
  }

  Future<int> exportCurrentTransactionsToSheet({
    void Function(int completed, int total, String label)? onProgress,
  }) async {
    if (!isSheetExportConfigured) {
      throw const FirebaseFinanceException(
        'Google Sheet export is not configured yet. Firestore remains the only live database.',
      );
    }
    onProgress?.call(0, 0, 'Checking IDs');
    final normalized = await _saveSequentialIdsIfNeeded();
    final total = normalized.length;
    onProgress?.call(0, total, 'Preparing smart sync');
    await _sheetExportService.syncTransactions(
      normalized,
      endpoint: _sheetExportEndpoint,
      secret: _sheetExportSecret,
      onProgress: onProgress,
    );
    onProgress?.call(total, total, 'Google Sheet synced');
    notifyListeners();
    return total;
  }

  Future<int> repairTransactionIds({
    void Function(int completed, int total, String label)? onProgress,
  }) async {
    final normalized = await _saveSequentialIdsIfNeeded(onProgress: onProgress);
    return normalized.length;
  }

  Future<int> importGoogleSheetToFirestore({
    void Function(int completed, int total, String label)? onProgress,
  }) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      onProgress?.call(0, 0, 'Reading Google Sheet');
      final sheetTransactions = await _service.fetchTransactions(_sheetUrl);
      onProgress?.call(0, sheetTransactions.length, 'Saving to database');
      final preparedTransactions = _assignMissingSequentialIds(
        sheetTransactions
            .map(
              (transaction) =>
                  transaction.copyWith(source: TransactionSource.googleSheet),
            )
            .toList(growable: false),
      );
      final imported = await _firebase.replaceTransactions(
        preparedTransactions,
      );
      _transactions = _cleanTransactionLabels(imported);
      _lastUpdated = DateTime.now();
      onProgress?.call(imported.length, imported.length, 'Import complete');
      return imported.length;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUseFirestore(bool value) async {
    _useFirestore = value && _isFirebaseConfigured;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firestoreEnabledKey, _useFirestore);
    notifyListeners();
    await refresh();
  }

  Future<void> signInWithGoogle() async {
    if (!await _ensureFirebaseReady()) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _firebase.signInWithGoogle();
      if (_user == null) {
        throw const FirebaseFinanceException(
          'Google did not return an account. Please try again.',
        );
      }
      await _ensureCurrentUserAllowed();
      _useFirestore = true;
      _resetWalletState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firestoreEnabledKey, true);
      _categoryRules = _loadCategoryRules(
        prefs,
        key: _categoryRulesStorageKey(),
      );
      _loadAutoBackupState(prefs);
      // Sheet settings are optional. They must not block a successful login.
      try {
        await _loadSheetIntegrationSettings();
      } catch (_) {}
      await _loadWalletSettings();
      await refresh();
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(
      () => _firebase.signInWithEmail(email: email, password: password),
    );
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (!await _ensureFirebaseReady()) {
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebase.sendPasswordResetEmail(email);
      return true;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAccountWithEmail({
    required String name,
    required String email,
    required String password,
    required String accountId,
  }) async {
    return _runAuthAction(
      () => _firebase.createAccountWithEmail(
        name: name,
        email: email,
        password: password,
        accountId: accountId,
      ),
    );
  }

  Future<bool> isAccountIdAvailable(String accountId) async {
    if (!await _ensureFirebaseReady()) {
      return false;
    }
    return _firebase.isAccountIdAvailable(accountId);
  }

  Future<bool> _runAuthAction(Future<FinanceUser?> Function() action) async {
    if (!await _ensureFirebaseReady()) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await action();
      await _ensureCurrentUserAllowed();
      _useFirestore = true;
      _resetWalletState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firestoreEnabledKey, true);
      _categoryRules = _loadCategoryRules(
        prefs,
        key: _categoryRulesStorageKey(),
      );
      _loadAutoBackupState(prefs);
      await _loadSheetIntegrationSettings();
      await _loadWalletSettings();
      await refresh();
      return _user != null;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureCurrentUserAllowed() async {
    final user = _user;
    if (user == null) {
      return;
    }
    if (user.blocked) {
      await _firebase.signOut();
      _user = null;
      throw const FirebaseFinanceException(
        'This account is blocked. Contact the administrator.',
      );
    }
    if (user.isTrialExpired) {
      await _firebase.signOut();
      _user = null;
      throw const FirebaseFinanceException(
        'This trial account has expired. Contact the administrator.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      if (_isFirebaseConfigured) await _firebase.signOut();
    } catch (_) {
      // A local logout must still succeed if a web session has expired.
    }
    _user = null;
    _useFirestore = false;
    _resetWalletState();
    _transactions = const [];
    _adminUsers = const [];
    _errorMessage = null;
    _lastUpdated = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firestoreEnabledKey, false);
    notifyListeners();
  }

  Future<void> saveCategoryRules(List<CategoryRule> rules) async {
    final cleaned = <String, CategoryRule>{};
    for (final rule in rules) {
      final name = rule.name.trim();
      if (name.isEmpty || rule.statuses.isEmpty) {
        continue;
      }
      cleaned[name.toLowerCase()] = CategoryRule(
        name: name,
        statuses: {...rule.statuses}..remove(TransactionType.unknown),
      );
    }
    _categoryRules = cleaned.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _categoryRulesStorageKey(),
      jsonEncode(_categoryRules.map((rule) => rule.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<CategoryCleanupResult> standardizeTransactionCategories() async {
    final original = [..._transactions];
    _transactions = _cleanTransactionLabels(original);
    final updated = await _persistCategoryCleanup(original);
    _lastUpdated = DateTime.now();
    notifyListeners();
    return CategoryCleanupResult(
      scanned: original.length,
      updated: updated,
      categories: _categoryRules.length,
    );
  }

  Future<int> _persistCategoryCleanup(
    List<FinancialTransaction> original,
  ) async {
    final cleanedById = {
      for (final transaction in _transactions)
        if ((transaction.id?.trim() ?? '').isNotEmpty)
          transaction.id!.trim(): transaction,
    };
    final changed = <FinancialTransaction>[];
    for (final transaction in original) {
      final id = transaction.id?.trim() ?? '';
      final cleaned = cleanedById[id];
      if (id.isEmpty || cleaned == null) {
        continue;
      }
      final oldCategory = transaction.category.trim();
      final oldRawCategory =
          (transaction.raw['category'] ?? transaction.raw['Category'] ?? '')
              .trim();
      if (oldCategory != cleaned.category ||
          (oldRawCategory.isNotEmpty && oldRawCategory != cleaned.category)) {
        changed.add(cleaned);
      }
    }
    if (changed.isNotEmpty &&
        _isFirebaseConfigured &&
        _firebase.currentUser != null) {
      await _firebase.upsertTransactions(changed);
    }
    await saveCategoryRules(_standardCategoryRules(_transactions));
    return changed.length;
  }

  List<CategoryRule> _standardCategoryRules(
    List<FinancialTransaction> transactions,
  ) {
    final rules = <String, CategoryRule>{};

    void add(String name, TransactionType type) {
      final key = name.toLowerCase();
      final current = rules[key];
      rules[key] = CategoryRule(
        name: name,
        statuses: {...?current?.statuses, type},
      );
    }

    for (final name in CategoryTaxonomy.expenseCategories) {
      add(name, TransactionType.expense);
    }
    for (final name in CategoryTaxonomy.incomeCategories) {
      add(name, TransactionType.income);
    }
    add(CategoryTaxonomy.receivableCategory, TransactionType.reserveable);
    add(CategoryTaxonomy.payableCategory, TransactionType.debt);
    add(CategoryTaxonomy.transferCategory, TransactionType.transfer);
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.unknown &&
          transaction.category.trim().isNotEmpty) {
        add(transaction.category.trim(), transaction.type);
      }
    }
    return rules.values.toList(growable: false);
  }

  Future<void> registerCategoryForTransaction(
    FinancialTransaction transaction,
  ) async {
    final name = transaction.category.trim();
    final type = transaction.type;
    if (name.isEmpty ||
        name.toLowerCase() == 'uncategorized' ||
        type == TransactionType.unknown) {
      return;
    }
    final index = _categoryRules.indexWhere(
      (rule) => rule.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (index >= 0 && _categoryRules[index].statuses.contains(type)) {
      return;
    }
    final updated = [..._categoryRules];
    if (index >= 0) {
      updated[index] = CategoryRule(
        name: _categoryRules[index].name,
        statuses: {..._categoryRules[index].statuses, type},
      );
    } else {
      updated.add(CategoryRule(name: name, statuses: {type}));
    }
    await saveCategoryRules(updated);
  }

  String _categoryRulesStorageKey() {
    final uid = _user?.uid.trim() ?? '';
    return uid.isEmpty
        ? '${_categoryRulesKey}_guest'
        : '${_categoryRulesKey}_$uid';
  }

  String _lastAutoBackupStorageKey() {
    final uid = _user?.uid.trim() ?? '';
    return uid.isEmpty
        ? '${_lastAutoBackupKey}_guest'
        : '${_lastAutoBackupKey}_$uid';
  }

  void _loadAutoBackupState(SharedPreferences prefs) {
    _lastAutoBackup = DateTime.tryParse(
      prefs.getString(_lastAutoBackupStorageKey()) ?? '',
    );
    _lastAutoBackupError = null;
  }

  List<CategoryRule> _loadCategoryRules(
    SharedPreferences prefs, {
    required String key,
  }) {
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final rules = decoded
              .whereType<Map>()
              .map(
                (item) =>
                    CategoryRule.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((rule) => rule.name.isNotEmpty && rule.statuses.isNotEmpty)
              .toList();
          if (rules.isNotEmpty) return rules;
        }
      } catch (_) {}
    }
    return _standardCategoryRules(const []);
  }

  Future<void> refreshAdminUsers({bool silent = false}) async {
    if (!isAdmin) {
      _adminUsers = const [];
      return;
    }
    if (!silent) {
      _isAdminLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      _adminUsers = await _firebase.fetchAdminUserSnapshots();
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(error);
    } finally {
      _isAdminLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveAdminUserProfile(FinanceUser user) async {
    await _firebase.saveAdminUserProfile(user);
    await refreshAdminUsers();
  }

  Future<void> sendAdminPasswordReset(String email) async {
    await _firebase.sendPasswordResetEmail(email);
  }

  Future<void> deleteAdminUserData(String uid) async {
    await _firebase.deleteAdminUserData(uid);
    await refreshAdminUsers();
  }

  Future<void> saveAdminTransaction({
    required String uid,
    required FinancialTransaction transaction,
  }) async {
    await _firebase.saveAdminTransaction(uid: uid, transaction: transaction);
    await refreshAdminUsers();
  }

  Future<void> deleteAdminTransaction({
    required String uid,
    required String transactionId,
  }) async {
    await _firebase.deleteAdminTransaction(
      uid: uid,
      transactionId: transactionId,
    );
    await refreshAdminUsers();
  }

  Future<String> createLocalBackup({String? label}) async {
    final prefs = await SharedPreferences.getInstance();
    final backups = _readLocalBackups(prefs);
    final backup = _createBackupDocument(label: label);
    final id = '${backup['id']}';
    backups.insert(0, backup);
    await prefs.setString(
      _localBackupsKey,
      jsonEncode(backups.take(10).toList()),
    );
    return id;
  }

  String createBackupJson({String? label}) =>
      jsonEncode(_createBackupDocument(label: label));

  Future<List<Map<String, dynamic>>> localBackups() async {
    final prefs = await SharedPreferences.getInstance();
    return _readLocalBackups(prefs);
  }

  Future<int> restoreLocalBackup(String id) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? backup;
    for (final item in _readLocalBackups(prefs)) {
      if ('${item['id']}' == id) {
        backup = item;
        break;
      }
    }
    if (backup == null) {
      throw const FirebaseFinanceException('Backup was not found.');
    }
    return _restoreBackupDocument(backup);
  }

  Future<int> restoreBackupJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FirebaseFinanceException('Backup file is invalid.');
    }
    return _restoreBackupDocument(Map<String, dynamic>.from(decoded));
  }

  Future<GoogleDriveBackupFile> createGoogleDriveBackup({
    String? label,
    bool allowInteractiveSignIn = true,
  }) {
    return _googleDriveBackupService.uploadBackup(
      _createBackupDocument(label: label),
      allowInteractiveSignIn: allowInteractiveSignIn,
    );
  }

  Future<List<GoogleDriveBackupFile>> googleDriveBackups() {
    return _googleDriveBackupService.listBackups();
  }

  Future<int> restoreGoogleDriveBackup(String fileId) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    final backup = await _googleDriveBackupService.downloadBackup(fileId);
    return _restoreBackupDocument(backup);
  }

  Map<String, dynamic> _createBackupDocument({String? label}) {
    final now = DateTime.now();
    return {
      'id': now.millisecondsSinceEpoch.toString(),
      'label': label?.trim().isNotEmpty == true
          ? label!.trim()
          : 'Backup ${now.toIso8601String()}',
      'savedAt': now.toIso8601String(),
      'accountId': _user?.accountId ?? '',
      'email': _user?.email ?? '',
      'transactions': [
        for (final transaction in _transactions)
          _transactionToJson(transaction),
      ],
    };
  }

  Future<int> _restoreBackupDocument(Map<String, dynamic> backup) async {
    final rows = backup['transactions'];
    if (rows is! List) {
      throw const FirebaseFinanceException('Backup file is invalid.');
    }
    final transactions = rows
        .whereType<Map>()
        .map((item) => _transactionFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final restored = await _firebase.replaceTransactions(transactions);
    _transactions = restored;
    _lastUpdated = DateTime.now();
    notifyListeners();
    return restored.length;
  }

  List<Map<String, dynamic>> _readLocalBackups(SharedPreferences prefs) {
    final raw = prefs.getString(_localBackupsKey);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _transactionToJson(FinancialTransaction transaction) {
    return {
      'id': transaction.id,
      'createdAt': transaction.createdAt?.toIso8601String(),
      'source': transaction.source.label,
      'date': transaction.date.toIso8601String(),
      'hasDate': transaction.hasDate,
      'type': transaction.type.label,
      'category': transaction.category,
      'description': transaction.description,
      'currency': transaction.currency.label,
      'amount': transaction.amount,
      'paymentMethod': transaction.paymentMethod,
      'notes': transaction.notes,
      'raw': transaction.raw,
    };
  }

  FinancialTransaction _transactionFromJson(Map<String, dynamic> data) {
    final raw = data['raw'];
    return FinancialTransaction(
      id: '${data['id'] ?? ''}'.trim(),
      createdAt: DateTime.tryParse('${data['createdAt'] ?? ''}'),
      source: _parseBackupSource('${data['source'] ?? ''}'),
      date: DateTime.tryParse('${data['date'] ?? ''}') ?? DateTime.now(),
      hasDate: data['hasDate'] != false,
      type: _parseBackupType('${data['type'] ?? ''}'),
      category: '${data['category'] ?? 'Uncategorized'}'.trim(),
      description: '${data['description'] ?? ''}'.trim(),
      currency: _parseBackupCurrency('${data['currency'] ?? ''}'),
      amount: double.tryParse('${data['amount'] ?? 0}')?.abs() ?? 0,
      paymentMethod: '${data['paymentMethod'] ?? ''}'.trim(),
      notes: '${data['notes'] ?? ''}'.trim(),
      raw: raw is Map
          ? raw.map((key, value) => MapEntry('$key', '$value'))
          : const {},
    );
  }

  TransactionSource _parseBackupSource(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('sheet')) {
      return TransactionSource.googleSheet;
    }
    if (normalized.contains('script') || normalized.contains('gemini')) {
      return TransactionSource.script;
    }
    return TransactionSource.application;
  }

  TransactionType _parseBackupType(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('income')) {
      return TransactionType.income;
    }
    if (normalized.contains('expense')) {
      return TransactionType.expense;
    }
    if (normalized.contains('credit') ||
        normalized.contains('reserve') ||
        normalized.contains('receivable')) {
      return TransactionType.reserveable;
    }
    if (normalized.contains('debt') ||
        normalized.contains('payable') ||
        normalized.contains('payables')) {
      return TransactionType.debt;
    }
    if (normalized.contains('transfer')) {
      return TransactionType.transfer;
    }
    return TransactionType.unknown;
  }

  CurrencyCode _parseBackupCurrency(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('lbp')) {
      return CurrencyCode.lbp;
    }
    if (normalized.contains('usd')) {
      return CurrencyCode.usd;
    }
    return CurrencyCode.unknown;
  }

  Future<int> addTransactionsFromGeminiScript(
    String script, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final result = await executeSmartTransactionScript(
      script,
      onProgress: onProgress,
    );
    if (result.hasFailures) {
      throw FirebaseFinanceException(result.failures.join('\n'));
    }
    return result.succeeded;
  }

  Future<SmartActionExecutionSummary> executeSmartTransactionScript(
    String script, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final actions = _geminiParser.parseActions(script);
    final total = actions.length;
    var added = 0;
    var edited = 0;
    var deleted = 0;
    var settled = 0;
    final failures = <String>[];

    for (var index = 0; index < actions.length; index += 1) {
      final action = actions[index];
      try {
        await applySmartTransactionAction(action);
        switch (action.type) {
          case SmartTransactionActionType.add:
            added += 1;
          case SmartTransactionActionType.edit:
            edited += 1;
          case SmartTransactionActionType.delete:
            deleted += 1;
          case SmartTransactionActionType.settle:
            settled += 1;
        }
      } catch (error) {
        failures.add('${action.label} #${index + 1}: $error');
      }
      onProgress?.call(index + 1, total);
    }

    return SmartActionExecutionSummary(
      total: total,
      added: added,
      edited: edited,
      deleted: deleted,
      settled: settled,
      failures: failures,
    );
  }

  Future<void> applySmartTransactionAction(
    SmartTransactionAction action,
  ) async {
    switch (action.type) {
      case SmartTransactionActionType.add:
        final transaction = action.transaction;
        if (transaction == null) {
          throw const FirebaseFinanceException(
            'Add action has no transaction.',
          );
        }
        if (transaction.isExpense) {
          final timing = (transaction.raw['payment_timing'] ?? '')
              .trim()
              .toLowerCase();
          final paidNow =
              timing.isEmpty ||
              timing == AccountingRules.paidNow.toLowerCase() ||
              timing == 'paid_now' ||
              timing == 'pay now';
          await addExpenseWithPaymentTiming(transaction, paidNow: paidNow);
        } else {
          await addTransaction(transaction);
        }
        await registerCategoryForTransaction(transaction);
      case SmartTransactionActionType.edit:
        final updated = action.transaction;
        if (updated == null) {
          throw const FirebaseFinanceException(
            'Edit action has no transaction.',
          );
        }
        final current = _findSmartTarget(action);
        if (current == null) {
          throw FirebaseFinanceException(
            'Could not find transaction to edit: ${action.targetId ?? action.targetTitle ?? updated.description}',
          );
        }
        await updateTransaction(
          current,
          updated.copyWith(id: current.id, source: TransactionSource.script),
        );
        await registerCategoryForTransaction(updated);
      case SmartTransactionActionType.delete:
        final current = _findSmartTarget(action);
        if (current == null) {
          throw FirebaseFinanceException(
            'Could not find transaction to delete: ${action.targetId ?? action.targetTitle ?? ''}',
          );
        }
        await deleteTransaction(current);
      case SmartTransactionActionType.settle:
        final current = _findSmartTarget(action);
        if (current == null) {
          throw FirebaseFinanceException(
            'Could not find transaction to settle: ${action.targetId ?? action.targetTitle ?? ''}',
          );
        }
        await settleTransaction(
          current,
          walletId: action.settlementWallet?.trim().isNotEmpty == true
              ? action.settlementWallet!.trim()
              : current.walletId,
          date: action.settlementDate,
          amountUsd: action.settlementAmountUsd > 0
              ? action.settlementAmountUsd
              : null,
          amountLbp: action.settlementAmountLbp > 0
              ? action.settlementAmountLbp
              : null,
          conversionRate: action.settlementExchangeRate,
        );
    }
  }

  FinancialTransaction? _findSmartTarget(SmartTransactionAction action) {
    final targetId = action.targetId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      for (final transaction in _transactions) {
        if ((transaction.id ?? '').trim() == targetId) {
          return transaction;
        }
      }
    }

    final targetTitle =
        action.targetTitle?.trim().toLowerCase() ??
        action.transaction?.description.trim().toLowerCase() ??
        '';
    if (targetTitle.isEmpty) {
      return null;
    }
    for (final transaction in _transactions) {
      if (transaction.description.trim().toLowerCase() == targetTitle) {
        return transaction;
      }
    }
    return null;
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }
    final ready = _assignMissingId(AccountingRules.normalize(transaction));
    _ensureOutgoingWalletFunds(
      afterTransactions: [..._transactions, ready],
      changedTransactions: [ready],
    );
    final saved = AccountingRules.normalize(
      await _firebase.addTransaction(ready),
    );
    _transactions = [
      saved,
      ..._transactions,
    ]..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
    _lastUpdated = DateTime.now();
    notifyListeners();
    await _afterTransactionMutation();
  }

  Future<void> addTransactions(List<FinancialTransaction> transactions) async {
    if (transactions.isEmpty) {
      return;
    }
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }
    final ready = _assignMissingSequentialIds(
      transactions.map(AccountingRules.normalize).toList(growable: false),
    );
    _ensureOutgoingWalletFunds(
      afterTransactions: [..._transactions, ...ready],
      changedTransactions: ready,
    );
    await _firebase.upsertTransactions(ready);
    _transactions = [
      ...ready,
      ..._transactions,
    ]..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
    _lastUpdated = DateTime.now();
    notifyListeners();
    await _afterTransactionMutation();
  }

  Future<void> addExpenseWithPaymentTiming(
    FinancialTransaction expense, {
    required bool paidNow,
  }) async {
    await addTransactions(
      AccountingRules.expandExpensePayment(expense, paidNow: paidNow),
    );
  }

  Future<void> addSplitIncome({
    required FinancialTransaction income,
    required double receivedAmount,
    required double owedAmount,
  }) async {
    await addTransactions(
      AccountingRules.splitIncome(
        income,
        receivedAmount: receivedAmount,
        owedAmount: owedAmount,
      ),
    );
  }

  Future<FinancialTransaction> settleTransaction(
    FinancialTransaction transaction, {
    required String walletId,
    DateTime? date,
    double? amountUsd,
    double? amountLbp,
    double? conversionRate,
  }) async {
    // A target can have been selected in Add while a collection is saved from
    // another screen. Always settle the latest canonical record, otherwise a
    // stale copy could overwrite the previous collected amount.
    final transactionId = transaction.id?.trim() ?? '';
    final current = transactionId.isEmpty
        ? transaction
        : _transactions.firstWhere(
            (item) =>
                item.id?.trim() == transactionId && !item.isSettlementEntry,
            orElse: () => transaction,
          );
    if (!current.isDebt && !current.isCredit) {
      throw const FirebaseFinanceException(
        'Only Credit and Debt transactions can be settled.',
      );
    }
    if (current.isSettled || !current.hasOutstandingBalance) {
      throw const FirebaseFinanceException(
        'This transaction is already settled.',
      );
    }
    final paidUsd = amountUsd ?? current.remainingAmountUsd;
    final paidLbp = amountLbp ?? current.remainingAmountLbp;
    final rate = conversionRate ?? exchangeRate;
    if (paidUsd < 0 || paidLbp < 0) {
      throw const FirebaseFinanceException(
        'Settlement amounts cannot be negative.',
      );
    }
    if (paidUsd <= 0.0001 && paidLbp <= 0.5) {
      throw const FirebaseFinanceException('Enter an amount to settle.');
    }
    final remainingUsdValue =
        current.remainingAmountUsd + current.remainingAmountLbp / rate;
    final paidUsdValue = paidUsd + paidLbp / rate;
    if (paidUsdValue - remainingUsdValue > 0.0001) {
      throw const FirebaseFinanceException(
        'The payment cannot be more than the remaining balance.',
      );
    }
    final allocation = AccountingRules.settlementAllocation(
      current,
      paidUsd: paidUsd,
      paidLbp: paidLbp,
      exchangeRate: rate,
    );
    final provisionalSettlement = AccountingRules.settlementEntry(
      current,
      walletId: walletId.trim().isEmpty ? current.walletId : walletId,
      date: date ?? DateTime.now(),
      amountUsd: paidUsd,
      amountLbp: paidLbp,
      allocatedUsd: allocation.amountUsd,
      allocatedLbp: allocation.amountLbp,
      exchangeRate: rate,
    );
    _ensureOutgoingWalletFunds(
      afterTransactions: [..._transactions, provisionalSettlement],
      changedTransactions: [provisionalSettlement],
    );
    final id = current.id?.trim() ?? '';
    if (id.isEmpty) {
      throw const FirebaseFinanceException(
        'The Credit or Debt record has no database ID.',
      );
    }
    final result = await _firebase.settleTransaction(
      transactionId: id,
      walletId: walletId,
      date: date ?? DateTime.now(),
      amountUsd: paidUsd,
      amountLbp: paidLbp,
      exchangeRate: rate,
    );
    _transactions = [
      result.payment,
      for (final item in _transactions)
        if (item.id?.trim() == id && !item.isSettlementEntry)
          result.parent
        else
          item,
    ]..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
    _lastUpdated = DateTime.now();
    notifyListeners();
    await _afterTransactionMutation();
    return result.parent;
  }

  Future<void> archiveTransaction(FinancialTransaction transaction) async {
    final raw = Map<String, String>.from(transaction.raw)
      ..['archived'] = 'true';
    await updateTransaction(transaction, transaction.copyWith(raw: raw));
  }

  Future<void> restoreTransaction(FinancialTransaction transaction) async {
    final raw = Map<String, String>.from(transaction.raw)..remove('archived');
    await updateTransaction(transaction, transaction.copyWith(raw: raw));
  }

  FinancialTransaction _assignMissingId(FinancialTransaction transaction) {
    final current = transaction.id?.trim() ?? '';
    if (current.isNotEmpty) {
      return transaction;
    }
    final id = _nextSequentialId(_transactions);
    return transaction.copyWith(id: id, raw: _rawWithId(transaction.raw, id));
  }

  List<FinancialTransaction> _assignMissingSequentialIds(
    List<FinancialTransaction> transactions,
  ) {
    final assigned = <FinancialTransaction>[];
    for (final transaction in transactions) {
      final current = transaction.id?.trim() ?? '';
      if (current.isNotEmpty) {
        assigned.add(
          transaction.copyWith(raw: _rawWithId(transaction.raw, current)),
        );
        continue;
      }
      final id = _nextSequentialId([..._transactions, ...assigned]);
      assigned.add(
        transaction.copyWith(id: id, raw: _rawWithId(transaction.raw, id)),
      );
    }
    return assigned;
  }

  List<FinancialTransaction> _normalizeSequentialIds(
    List<FinancialTransaction> transactions,
  ) {
    final sorted = _sortForSequentialIds(transactions);
    final accountId = _currentAccountIdPrefix();

    return [
      for (var index = 0; index < sorted.length; index += 1)
        sorted[index].copyWith(
          id: '$accountId-${index + 1}',
          raw: _rawWithId(sorted[index].raw, '$accountId-${index + 1}'),
        ),
    ];
  }

  Future<List<FinancialTransaction>> _saveSequentialIdsIfNeeded({
    void Function(int completed, int total, String label)? onProgress,
  }) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }

    final normalized = _normalizeSequentialIds(_transactions);
    final total = normalized.length;
    if (!_needsSequentialIdRepair()) {
      _transactions = normalized..sort((a, b) => b.date.compareTo(a.date));
      onProgress?.call(total, total, 'IDs already ready');
      notifyListeners();
      return _transactions;
    }

    onProgress?.call(0, total, 'Saving clean IDs');
    final saved = await _firebase.replaceTransactions(normalized);
    _transactions = saved..sort((a, b) => b.date.compareTo(a.date));
    _lastUpdated = DateTime.now();
    onProgress?.call(total, total, 'IDs saved');
    notifyListeners();
    return _transactions;
  }

  bool _needsSequentialIdRepair() {
    final sorted = _sortForSequentialIds(_transactions);
    final accountId = _currentAccountIdPrefix();
    for (var index = 0; index < sorted.length; index += 1) {
      if ((sorted[index].id?.trim() ?? '') != '$accountId-${index + 1}') {
        return true;
      }
    }
    return false;
  }

  List<FinancialTransaction> _sortForSequentialIds(
    List<FinancialTransaction> transactions,
  ) {
    return [...transactions]..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final createdA = a.createdAt;
      final createdB = b.createdAt;
      if (createdA != null && createdB != null) {
        final createdCompare = createdA.compareTo(createdB);
        if (createdCompare != 0) {
          return createdCompare;
        }
      } else if (createdA != null) {
        return -1;
      } else if (createdB != null) {
        return 1;
      }
      return a.description.trim().toLowerCase().compareTo(
        b.description.trim().toLowerCase(),
      );
    });
  }

  Map<String, String> _rawWithId(Map<String, String> raw, String id) {
    return {...raw, 'ID': id, 'Transaction ID': id};
  }

  String _nextSequentialId(List<FinancialTransaction> source) {
    var maxNumber = 0;
    for (final transaction in source) {
      final number = _idNumber(transaction.id);
      if (number == null) {
        continue;
      }
      if (number > maxNumber) {
        maxNumber = number;
      }
    }
    return '${_currentAccountIdPrefix()}-${maxNumber + 1}';
  }

  int? _idNumber(String? id) {
    final value = id?.trim() ?? '';
    final match = RegExp(r'(\d+)$', caseSensitive: false).firstMatch(value);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  String _currentAccountIdPrefix() {
    final accountId = _user?.accountId?.trim() ?? '';
    if (accountId.isNotEmpty) {
      return accountId;
    }
    final emailPrefix = (_user?.email ?? '').split('@').first;
    final normalized = FirebaseFinanceService.normalizeAccountId(emailPrefix);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    final uid = _user?.uid ?? 'user';
    final normalizedUid = FirebaseFinanceService.normalizeAccountId(uid);
    return normalizedUid.isEmpty ? 'user' : normalizedUid;
  }

  Future<void> updateLanguage(AppLanguage language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.name);
    notifyListeners();
  }

  Future<void> updateThemeStyle(AppThemeStyle style) async {
    _themeStyle = AppThemeStyle.cyberGrid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeStyleKey, style.name);
    notifyListeners();
  }

  Future<void> updateAppLockEnabled(bool enabled) async {
    _appLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> updateAppLockMethod(AppLockMethod method) async {
    _appLockMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLockMethodKey, method.name);
    notifyListeners();
  }

  Future<void> updateAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
    notifyListeners();
    if (enabled) {
      await _runDailyAutoBackupIfDue(force: true, rethrowError: true);
    } else {
      _lastAutoBackupError = null;
      notifyListeners();
    }
  }

  Future<void> updateWalletOpeningBalances({
    required double usd,
    required double lbp,
  }) => setWalletCurrentBalance(isWishMoney: false, usd: usd, lbp: lbp);

  Future<void> updateWishWalletOpeningBalances({
    required double usd,
    required double lbp,
  }) => setWalletCurrentBalance(isWishMoney: true, usd: usd, lbp: lbp);

  /// Sets the live balance of one wallet without deleting or editing any
  /// transaction. Existing rows become the wallet's historical baseline and
  /// only transactions created after this point change the entered balance.
  Future<void> setWalletCurrentBalance({
    required bool isWishMoney,
    required double usd,
    required double lbp,
  }) async {
    final currentUsd = usd < 0 ? 0.0 : usd;
    final currentLbp = lbp < 0 ? 0.0 : lbp;
    final baselineIds = _walletBaselineIds(isWishMoney: isWishMoney);
    if (isWishMoney) {
      _wishWalletOpeningUsd = currentUsd;
      _wishWalletOpeningLbp = currentLbp;
      _wishWalletBaselineTransactionIds = baselineIds;
    } else {
      _walletOpeningUsd = currentUsd;
      _walletOpeningLbp = currentLbp;
      _cashWalletBaselineTransactionIds = baselineIds;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      isWishMoney ? _wishWalletOpeningUsdKey : _walletOpeningUsdKey,
      currentUsd,
    );
    await prefs.setDouble(
      isWishMoney ? _wishWalletOpeningLbpKey : _walletOpeningLbpKey,
      currentLbp,
    );
    await prefs.setStringList(
      isWishMoney
          ? _wishWalletBaselineTransactionIdsKey
          : _cashWalletBaselineTransactionIdsKey,
      baselineIds.toList(),
    );
    await _saveWalletSettings();
    notifyListeners();
  }

  Set<String> _walletBaselineIds({required bool isWishMoney}) {
    return _transactions
        .where((transaction) {
          if (!transaction.affectsWallet) {
            return false;
          }
          final sourceMatches =
              !LabelNormalizer.isService(transaction.walletId) &&
              LabelNormalizer.isWishMoney(transaction.walletId) == isWishMoney;
          final destination = transaction.destinationWalletId;
          final destinationMatches =
              transaction.isTransfer &&
              destination != null &&
              !LabelNormalizer.isService(destination) &&
              LabelNormalizer.isWishMoney(destination) == isWishMoney;
          return sourceMatches || destinationMatches;
        })
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) {
          return id.isNotEmpty;
        })
        .toSet();
  }

  Future<void> updateWalletComparisonRange({
    required bool isWishMoney,
    required WalletComparisonRange range,
  }) async {
    if (isWishMoney) {
      _wishWalletComparisonRange = range;
    } else {
      _cashWalletComparisonRange = range;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      isWishMoney
          ? _wishWalletComparisonRangeKey
          : _cashWalletComparisonRangeKey,
      range.name,
    );
    await _saveWalletSettings();
    notifyListeners();
  }

  /// Starts wallet tracking from the balances entered now. Existing income and
  /// expenses remain in the app but no longer affect either wallet.
  Future<void> resetWalletTracking({
    required double cashUsd,
    required double cashLbp,
    required double wishUsd,
    required double wishLbp,
  }) async {
    _walletOpeningUsd = cashUsd < 0 ? 0 : cashUsd;
    _walletOpeningLbp = cashLbp < 0 ? 0 : cashLbp;
    _wishWalletOpeningUsd = wishUsd < 0 ? 0 : wishUsd;
    _wishWalletOpeningLbp = wishLbp < 0 ? 0 : wishLbp;
    _cashWalletBaselineTransactionIds = _transactions
        .where(
          (transaction) => !LabelNormalizer.isWishMoney(transaction.walletId),
        )
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    _wishWalletBaselineTransactionIds = _transactions
        .where(
          (transaction) => LabelNormalizer.isWishMoney(transaction.walletId),
        )
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_walletOpeningUsdKey, _walletOpeningUsd);
    await prefs.setDouble(_walletOpeningLbpKey, _walletOpeningLbp);
    await prefs.setDouble(_wishWalletOpeningUsdKey, _wishWalletOpeningUsd);
    await prefs.setDouble(_wishWalletOpeningLbpKey, _wishWalletOpeningLbp);
    await prefs.setStringList(
      _cashWalletBaselineTransactionIdsKey,
      _cashWalletBaselineTransactionIds.toList(),
    );
    await prefs.setStringList(
      _wishWalletBaselineTransactionIdsKey,
      _wishWalletBaselineTransactionIds.toList(),
    );
    await _saveWalletSettings();
    notifyListeners();
  }

  Future<void> resetCashWalletTracking({
    required double usd,
    required double lbp,
  }) => setWalletCurrentBalance(isWishMoney: false, usd: usd, lbp: lbp);

  Future<void> resetWishWalletTracking({
    required double usd,
    required double lbp,
  }) => setWalletCurrentBalance(isWishMoney: true, usd: usd, lbp: lbp);

  /// Clears a single wallet completely. Records assigned to that wallet, plus
  /// transfers targeting it, are deleted from Firebase so its history and
  /// outstanding credit/debt balances truly restart from zero.
  Future<void> resetWalletData({required bool isWishMoney}) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }
    final matching = _transactions
        .where((transaction) {
          final isWalletTransaction =
              !LabelNormalizer.isService(transaction.walletId) &&
              LabelNormalizer.isWishMoney(transaction.walletId) == isWishMoney;
          final isTransferIntoWallet =
              transaction.isTransfer &&
              LabelNormalizer.isWishMoney(
                    transaction.destinationWalletId ?? '',
                  ) ==
                  isWishMoney;
          return isWalletTransaction || isTransferIntoWallet;
        })
        .toList(growable: false);
    _isLoading = true;
    notifyListeners();
    try {
      await _firebase.deleteTransactionsByIds(
        matching.map((transaction) => transaction.id ?? ''),
      );
      final removedIds = matching
          .map((transaction) => transaction.id?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      _transactions = _transactions
          .where((transaction) => !removedIds.contains(transaction.id?.trim()))
          .toList(growable: false);
      if (isWishMoney) {
        _wishWalletOpeningUsd = 0;
        _wishWalletOpeningLbp = 0;
        _wishWalletBaselineTransactionIds = <String>{};
      } else {
        _walletOpeningUsd = 0;
        _walletOpeningLbp = 0;
        _cashWalletBaselineTransactionIds = <String>{};
      }
      _lastUpdated = DateTime.now();
      await _saveWalletSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _afterTransactionMutation() async {
    try {
      await SpendingNotificationService.instance.evaluateAndNotify(
        transactions: _transactions,
        exchangeRate: _exchangeRate,
      );
    } catch (_) {
      // A notification failure must never undo a saved transaction.
    }
    _runDailyAutoBackupIfDue().ignore();
  }

  Future<void> _runDailyAutoBackupIfDue({
    bool force = false,
    bool rethrowError = false,
  }) async {
    if (!_autoBackupEnabled || _user == null) {
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!force &&
        _lastAutoBackup != null &&
        !_lastAutoBackup!.isBefore(today)) {
      return;
    }
    try {
      await createGoogleDriveBackup(
        label: 'Auto backup ${now.toIso8601String()}',
        allowInteractiveSignIn: rethrowError,
      );
      _lastAutoBackup = now;
      _lastAutoBackupError = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAutoBackupStorageKey(), now.toIso8601String());
      notifyListeners();
    } catch (error) {
      _lastAutoBackupError = error.toString();
      notifyListeners();
      if (rethrowError) {
        rethrow;
      }
    }
  }

  Future<void> updateCalculationStartMonth(DateTime? month) async {
    _calculationStartMonth = month == null
        ? null
        : DateTime(month.year, month.month);
    final prefs = await SharedPreferences.getInstance();
    if (_calculationStartMonth == null) {
      await prefs.remove(_calculationStartMonthKey);
    } else {
      await prefs.setString(
        _calculationStartMonthKey,
        _calculationStartMonth!.toIso8601String(),
      );
    }
    notifyListeners();
  }

  void selectTimeFilter(TimeFilter filter) {
    _selectedRecentDay = null;
    _selectedMonth = null;
    _selectedMonthWeek = null;
    if (filter == TimeFilter.allTime) {
      _referenceMonth = null;
    }
    _timeFilter = filter;
    notifyListeners();
  }

  void selectRecentDay(DateTime day) {
    _selectedRecentDay = DateTime(day.year, day.month, day.day);
    _timeFilter = TimeFilter.last3Days;
    notifyListeners();
  }

  void selectMonth(DateTime month) {
    _selectedRecentDay = null;
    _selectedMonth = DateTime(month.year, month.month);
    _selectedMonthWeek = null;
    _timeFilter = TimeFilter.thisMonth;
    notifyListeners();
  }

  void selectReferenceMonth(DateTime month) {
    _selectedRecentDay = null;
    _selectedMonth = null;
    _selectedMonthWeek = null;
    _referenceMonth = DateTime(month.year, month.month);
    _timeFilter = TimeFilter.allTime;
    notifyListeners();
  }

  void selectMonthWeek(int index) {
    _selectedRecentDay = null;
    _selectedMonth = null;
    _selectedMonthWeek = index;
    _timeFilter = TimeFilter.thisWeek;
    notifyListeners();
  }

  void setCustomRange(DateTimeRange range) {
    _selectedRecentDay = null;
    _selectedMonth = null;
    _selectedMonthWeek = null;
    _customStart = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    _customEnd = DateTime(range.end.year, range.end.month, range.end.day);
    _timeFilter = TimeFilter.custom;
    notifyListeners();
  }

  DateTime? _monthFromStorage(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    return parsed == null ? null : DateTime(parsed.year, parsed.month);
  }

  Future<void> _loadSheetIntegrationSettings() async {
    if (!_isFirebaseConfigured || _user == null) {
      return;
    }

    final settings = await _firebase.fetchSheetIntegrationSettings();
    if (settings == null) {
      await _saveSheetIntegrationSettings();
      return;
    }

    if (settings.exportEndpoint.isNotEmpty) {
      _sheetExportEndpoint = settings.exportEndpoint;
    }
    if (settings.exportSecret.isNotEmpty) {
      _sheetExportSecret = settings.exportSecret;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetExportEndpointKey, _sheetExportEndpoint);
    await prefs.setString(_sheetExportSecretKey, _sheetExportSecret);
  }

  Future<void> _saveSheetIntegrationSettings() async {
    if (!_isFirebaseConfigured || _user == null) {
      return;
    }

    await _firebase.saveSheetIntegrationSettings(
      SheetIntegrationSettings(
        exportEndpoint: _sheetExportEndpoint,
        exportSecret: _sheetExportSecret,
      ),
    );
  }

  void _resetWalletState() {
    _walletOpeningUsd = 0;
    _walletOpeningLbp = 0;
    _wishWalletOpeningUsd = 0;
    _wishWalletOpeningLbp = 0;
    _cashWalletBaselineTransactionIds = <String>{};
    _wishWalletBaselineTransactionIds = <String>{};
    _cashWalletComparisonRange = WalletComparisonRange.week;
    _wishWalletComparisonRange = WalletComparisonRange.week;
  }

  Future<void> _loadWalletSettings() async {
    if (!_isFirebaseConfigured || _user == null) {
      return;
    }
    try {
      final settings = await _firebase.fetchWalletSettings();
      if (settings == null) {
        // A newly signed-in account starts with its own empty wallets. Do not
        // copy balances from a prior user of this phone.
        _resetWalletState();
        await _saveWalletSettings();
        return;
      }
      _walletOpeningUsd = settings.cashOpeningUsd;
      _walletOpeningLbp = settings.cashOpeningLbp;
      _wishWalletOpeningUsd = settings.wishOpeningUsd;
      _wishWalletOpeningLbp = settings.wishOpeningLbp;
      _cashWalletBaselineTransactionIds = settings.cashBaselineTransactionIds
          .toSet();
      _wishWalletBaselineTransactionIds = settings.wishBaselineTransactionIds
          .toSet();
      _cashWalletComparisonRange = WalletComparisonRange.values.firstWhere(
        (value) => value.name == settings.cashComparisonRange,
        orElse: () => WalletComparisonRange.week,
      );
      _wishWalletComparisonRange = WalletComparisonRange.values.firstWhere(
        (value) => value.name == settings.wishComparisonRange,
        orElse: () => WalletComparisonRange.week,
      );
    } catch (_) {
      // Wallet sync must never prevent sign-in or offline usage.
    }
  }

  Future<void> _saveWalletSettings() async {
    if (!_isFirebaseConfigured || _user == null) {
      return;
    }
    try {
      await _firebase.saveWalletSettings(
        WalletSyncSettings(
          cashOpeningUsd: _walletOpeningUsd,
          cashOpeningLbp: _walletOpeningLbp,
          wishOpeningUsd: _wishWalletOpeningUsd,
          wishOpeningLbp: _wishWalletOpeningLbp,
          cashBaselineTransactionIds: _cashWalletBaselineTransactionIds
              .toList(),
          wishBaselineTransactionIds: _wishWalletBaselineTransactionIds
              .toList(),
          cashComparisonRange: _cashWalletComparisonRange.name,
          wishComparisonRange: _wishWalletComparisonRange.name,
        ),
      );
    } catch (_) {
      // Local settings remain available if Firestore is temporarily offline.
    }
  }

  Future<void> updateTransaction(
    FinancialTransaction current,
    FinancialTransaction updated,
  ) async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    final index = _transactions.indexOf(current);
    if (index == -1) {
      return;
    }
    final ready = AccountingRules.normalize(updated);
    final afterTransactions = [
      ..._transactions.take(index),
      ready,
      ..._transactions.skip(index + 1),
    ];
    _ensureOutgoingWalletFunds(
      afterTransactions: afterTransactions,
      changedTransactions: [ready],
    );
    final updatedWithId = AccountingRules.normalize(
      await _firebase.updateTransaction(ready),
    );
    _transactions = [
      ..._transactions.take(index),
      updatedWithId,
      ..._transactions.skip(index + 1),
    ];
    notifyListeners();
    await _afterTransactionMutation();
  }

  void _ensureOutgoingWalletFunds({
    required List<FinancialTransaction> afterTransactions,
    required Iterable<FinancialTransaction> changedTransactions,
  }) {
    final after = _walletSummaryFor(afterTransactions);
    for (final transaction in changedTransactions) {
      if (transaction.walletDirection >= 0) {
        continue;
      }
      final isWish = LabelNormalizer.isWishMoney(transaction.walletId);
      final balance = isWish ? after.wish : after.cash;
      final hasUsdShortfall =
          transaction.amountUsd > 0 && balance.balanceUsd < -0.0001;
      final hasLbpShortfall =
          transaction.amountLbp > 0 && balance.balanceLbp < -0.5;
      if (!hasUsdShortfall && !hasLbpShortfall) {
        continue;
      }
      final walletName = isWish ? 'Whish Money' : 'My Wallet';
      final availableUsd = (balance.balanceUsd + transaction.amountUsd)
          .clamp(0.0, double.infinity)
          .toDouble();
      final availableLbp = (balance.balanceLbp + transaction.amountLbp)
          .clamp(0.0, double.infinity)
          .toDouble();
      throw FirebaseFinanceException(
        'Not enough balance in $walletName. Available: '
        '${availableUsd.toStringAsFixed(2)} USD | '
        '${availableLbp.toStringAsFixed(0)} LBP.',
      );
    }
  }

  Future<FinancialTransaction> moveTransactionWallet(
    FinancialTransaction transaction, {
    required String walletId,
  }) async {
    final moved = AccountingRules.moveWallet(transaction, walletId: walletId);
    await updateTransaction(transaction, moved);
    return _transactions.firstWhere(
      (item) => item.id?.trim() == moved.id?.trim(),
      orElse: () => moved,
    );
  }

  Future<void> deleteTransaction(FinancialTransaction transaction) async {
    final id = transaction.id?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (transaction.isSettlementEntry) {
      throw const FirebaseFinanceException(
        'Payments are part of the Credit or Debt history and cannot be deleted separately.',
      );
    }
    final linkedIds = _transactions
        .where((item) => item.linkedTransactionId == id)
        .map((item) => item.id?.trim() ?? '')
        .where((linkedId) => linkedId.isNotEmpty)
        .toSet();
    await _firebase.deleteTransactionCascade(id);
    _transactions = _transactions
        .where(
          (item) =>
              item.id?.trim() != id &&
              !linkedIds.contains(item.id?.trim()) &&
              item.linkedTransactionId != id,
        )
        .toList(growable: false);
    _lastUpdated = DateTime.now();
    notifyListeners();
    await _afterTransactionMutation();
  }

  /// Permanently removes every transaction for the active Firebase account and
  /// returns both wallets to a clean zero-balance state.
  Future<void> resetAccountData() async {
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    if (_firebase.currentUser == null) {
      throw const FirebaseFinanceException('Sign in first.');
    }
    _isLoading = true;
    notifyListeners();
    try {
      await _firebase.clearTransactions();
      _transactions = const [];
      _resetWalletState();
      _lastUpdated = DateTime.now();
      _errorMessage = null;
      await _saveWalletSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  factory DateWindow.forMonth(DateTime month) {
    return DateWindow(
      start: DateTime(month.year, month.month),
      endExclusive: DateTime(month.year, month.month + 1),
    );
  }

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

  DateWindow intersect(DateWindow other) {
    final nextStart = switch ((start, other.start)) {
      (null, final value) => value,
      (final value, null) => value,
      (final first?, final second?) => first.isAfter(second) ? first : second,
    };
    final nextEnd = switch ((endExclusive, other.endExclusive)) {
      (null, final value) => value,
      (final value, null) => value,
      (final first?, final second?) => first.isBefore(second) ? first : second,
    };
    return DateWindow(start: nextStart, endExclusive: nextEnd);
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
    required this.totalDebtUsd,
    required this.totalDebtLbp,
    required this.totalDebt,
    required this.totalNetUsd,
    required this.totalNetLbp,
    required this.totalNet,
    required this.expenseRatio,
    required this.topExpenseCategory,
    required this.topIncomeCategory,
    required this.topReserveableCategory,
    required this.topDebtCategory,
    required this.averageDailyExpense,
    required this.transactionCount,
    required this.largestExpense,
    required this.largestIncome,
    required this.largestReserveable,
    required this.categoryExpenseTotals,
    required this.categoryIncomeTotals,
    required this.categoryReserveableTotals,
    required this.categoryDebtTotals,
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
  final double totalDebtUsd;
  final double totalDebtLbp;
  final double totalDebt;
  final double totalNetUsd;
  final double totalNetLbp;
  final double totalNet;
  final double expenseRatio;
  final String topExpenseCategory;
  final String topIncomeCategory;
  final String topReserveableCategory;
  final String topDebtCategory;
  final double averageDailyExpense;
  final int transactionCount;
  final FinancialTransaction? largestExpense;
  final FinancialTransaction? largestIncome;
  final FinancialTransaction? largestReserveable;
  final Map<String, double> categoryExpenseTotals;
  final Map<String, double> categoryIncomeTotals;
  final Map<String, double> categoryReserveableTotals;
  final Map<String, double> categoryDebtTotals;
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
    var debtUsd = 0.0;
    var debtLbp = 0.0;
    FinancialTransaction? largestExpense;
    FinancialTransaction? largestIncome;
    FinancialTransaction? largestReserveable;
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};
    final reserveableByCategory = <String, double>{};
    final debtByCategory = <String, double>{};
    final dailyNet = <DateTime, double>{};
    final dailyExpense = <DateTime, double>{};
    final dailyIncome = <DateTime, double>{};
    final dailyReserveable = <DateTime, double>{};

    for (final transaction in transactions) {
      final amountUsd = transaction.amountInUsd(exchangeRate);
      final transactionUsd = transaction.amountUsd;
      final transactionLbp = transaction.amountLbp;
      final day = transaction.hasDate
          ? DateTime(
              transaction.date.year,
              transaction.date.month,
              transaction.date.day,
            )
          : null;

      if (transaction.affectsExpenseStats) {
        expenseUsd += transactionUsd;
        expenseLbp += transactionLbp;

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

      if (transaction.affectsIncomeStats) {
        incomeUsd += transactionUsd;
        incomeLbp += transactionLbp;

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

      if (transaction.affectsReceivables) {
        final remainingUsd = transaction.remainingAmountUsd;
        final remainingLbp = transaction.remainingAmountLbp;
        final remainingUsdValue = remainingUsd + remainingLbp / exchangeRate;
        reserveableUsd += remainingUsd;
        reserveableLbp += remainingLbp;

        reserveableByCategory.update(
          transaction.category,
          (value) => value + remainingUsdValue,
          ifAbsent: () => remainingUsdValue,
        );
        if (day != null) {
          dailyReserveable.update(
            day,
            (value) => value + remainingUsdValue,
            ifAbsent: () => remainingUsdValue,
          );
        }

        if (largestReserveable == null ||
            remainingUsdValue >
                largestReserveable.remainingAmountUsd +
                    largestReserveable.remainingAmountLbp / exchangeRate) {
          largestReserveable = transaction;
        }
      }

      if (transaction.affectsPayables) {
        final remainingUsd = transaction.remainingAmountUsd;
        final remainingLbp = transaction.remainingAmountLbp;
        final remainingUsdValue = remainingUsd + remainingLbp / exchangeRate;
        debtUsd += remainingUsd;
        debtLbp += remainingLbp;

        debtByCategory.update(
          transaction.category,
          (value) => value + remainingUsdValue,
          ifAbsent: () => remainingUsdValue,
        );
      }
    }

    final totalExpense = expenseUsd + expenseLbp / exchangeRate;
    final totalIncome = incomeUsd + incomeLbp / exchangeRate;
    final totalReserveable = reserveableUsd + reserveableLbp / exchangeRate;
    final totalDebt = debtUsd + debtLbp / exchangeRate;
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
      totalDebtUsd: debtUsd,
      totalDebtLbp: debtLbp,
      totalDebt: totalDebt,
      totalNetUsd: totalNetUsd,
      totalNetLbp: totalNetLbp,
      totalNet: totalNet,
      expenseRatio: totalIncome <= 0 ? 0 : totalExpense / totalIncome,
      topExpenseCategory: _topCategory(expenseByCategory),
      topIncomeCategory: _topCategory(incomeByCategory),
      topReserveableCategory: _topCategory(reserveableByCategory),
      topDebtCategory: _topCategory(debtByCategory),
      averageDailyExpense: totalExpense / dayCount,
      transactionCount: transactions.length,
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      largestReserveable: largestReserveable,
      categoryExpenseTotals: _sortMap(expenseByCategory),
      categoryIncomeTotals: _sortMap(incomeByCategory),
      categoryReserveableTotals: _sortMap(reserveableByCategory),
      categoryDebtTotals: _sortMap(debtByCategory),
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

class WalletSummary {
  const WalletSummary({required this.cash, required this.wish});

  final WalletAccountSummary cash;
  final WalletAccountSummary wish;

  factory WalletSummary.fromTransactions(
    List<FinancialTransaction> transactions, {
    required double cashOpeningUsd,
    required double cashOpeningLbp,
    required double wishOpeningUsd,
    required double wishOpeningLbp,
    required Set<String> ignoredCashTransactionIds,
    required Set<String> ignoredWishTransactionIds,
  }) {
    final cashTransactions = <FinancialTransaction>[];
    final wishTransactions = <FinancialTransaction>[];
    for (final transaction in transactions) {
      if (transaction.isTransfer && transaction.destinationWalletId != null) {
        final sourceRaw = Map<String, String>.from(transaction.raw)
          ..['wallet_direction'] = '-1';
        final destinationRaw = Map<String, String>.from(transaction.raw)
          ..['wallet_direction'] = '1'
          ..['wallet_id'] = transaction.destinationWalletId!;
        final source = transaction.copyWith(raw: sourceRaw);
        final destination = transaction.copyWith(
          paymentMethod: transaction.destinationWalletId!,
          raw: destinationRaw,
        );
        _addWalletTransaction(
          source,
          cashTransactions: cashTransactions,
          wishTransactions: wishTransactions,
          ignoredCashTransactionIds: ignoredCashTransactionIds,
          ignoredWishTransactionIds: ignoredWishTransactionIds,
        );
        _addWalletTransaction(
          destination,
          cashTransactions: cashTransactions,
          wishTransactions: wishTransactions,
          ignoredCashTransactionIds: ignoredCashTransactionIds,
          ignoredWishTransactionIds: ignoredWishTransactionIds,
        );
        continue;
      }
      _addWalletTransaction(
        transaction,
        cashTransactions: cashTransactions,
        wishTransactions: wishTransactions,
        ignoredCashTransactionIds: ignoredCashTransactionIds,
        ignoredWishTransactionIds: ignoredWishTransactionIds,
      );
    }
    return WalletSummary(
      cash: WalletAccountSummary.fromTransactions(
        cashTransactions,
        openingUsd: cashOpeningUsd,
        openingLbp: cashOpeningLbp,
      ),
      wish: WalletAccountSummary.fromTransactions(
        wishTransactions,
        openingUsd: wishOpeningUsd,
        openingLbp: wishOpeningLbp,
      ),
    );
  }

  static void _addWalletTransaction(
    FinancialTransaction transaction, {
    required List<FinancialTransaction> cashTransactions,
    required List<FinancialTransaction> wishTransactions,
    required Set<String> ignoredCashTransactionIds,
    required Set<String> ignoredWishTransactionIds,
  }) {
    final id = transaction.id?.trim() ?? '';
    final isWish = LabelNormalizer.isWishMoney(transaction.walletId);
    if (id.isNotEmpty &&
        (isWish
            ? ignoredWishTransactionIds.contains(id)
            : ignoredCashTransactionIds.contains(id))) {
      return;
    }
    if (isWish) {
      wishTransactions.add(transaction);
    } else {
      cashTransactions.add(transaction);
    }
  }
}

class WalletBalanceComparison {
  const WalletBalanceComparison({
    required this.range,
    required this.usdChange,
    required this.lbpChange,
  });

  final WalletComparisonRange range;
  final double usdChange;
  final double lbpChange;
}

class WalletAccountSummary {
  const WalletAccountSummary({
    required this.openingUsd,
    required this.openingLbp,
    required this.inflowUsd,
    required this.inflowLbp,
    required this.outflowUsd,
    required this.outflowLbp,
  });

  final double openingUsd;
  final double openingLbp;
  final double inflowUsd;
  final double inflowLbp;
  final double outflowUsd;
  final double outflowLbp;

  double get incomeUsd => inflowUsd;
  double get incomeLbp => inflowLbp;
  double get expenseUsd => outflowUsd;
  double get expenseLbp => outflowLbp;
  double get reserveableUsd => 0;
  double get reserveableLbp => 0;

  double get balanceUsd => openingUsd + inflowUsd - outflowUsd;
  double get balanceLbp => openingLbp + inflowLbp - outflowLbp;

  factory WalletAccountSummary.fromTransactions(
    List<FinancialTransaction> transactions, {
    required double openingUsd,
    required double openingLbp,
  }) {
    var inflowUsd = 0.0;
    var inflowLbp = 0.0;
    var outflowUsd = 0.0;
    var outflowLbp = 0.0;
    for (final transaction in transactions) {
      if (transaction.walletDirection > 0) {
        inflowUsd += transaction.amountUsd;
        inflowLbp += transaction.amountLbp;
      } else if (transaction.walletDirection < 0) {
        outflowUsd += transaction.amountUsd;
        outflowLbp += transaction.amountLbp;
      }
    }
    return WalletAccountSummary(
      openingUsd: openingUsd,
      openingLbp: openingLbp,
      inflowUsd: inflowUsd,
      inflowLbp: inflowLbp,
      outflowUsd: outflowUsd,
      outflowLbp: outflowLbp,
    );
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
