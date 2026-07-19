import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../services/firebase_finance_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/gemini_transaction_parser.dart';
import '../services/google_drive_backup_service.dart';
import '../services/google_sheet_service.dart';
import '../services/sheet_export_service.dart';

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
    required this.failures,
  });

  final int total;
  final int added;
  final int edited;
  final int deleted;
  final List<String> failures;

  int get succeeded => added + edited + deleted;

  bool get hasFailures => failures.isNotEmpty;
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
  /// wallet changes; only the selected payment method (Cash or Wish Money)
  /// does.
  WalletSummary get walletSummary => WalletSummary.fromTransactions(
    _transactions,
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
    return WalletSummary.fromTransactions(
      _transactions
          .where((transaction) => !transaction.date.isAfter(cutoff))
          .toList(),
      cashOpeningUsd: _walletOpeningUsd,
      cashOpeningLbp: _walletOpeningLbp,
      wishOpeningUsd: _wishWalletOpeningUsd,
      wishOpeningLbp: _wishWalletOpeningLbp,
      ignoredCashTransactionIds: _cashWalletBaselineTransactionIds,
      ignoredWishTransactionIds: _wishWalletBaselineTransactionIds,
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
    final values =
        _transactions
            .map((transaction) => transaction.category.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get paymentMethodOptions {
    final values = <String>{
      'Cash',
      'Wish Money',
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
      _themeMode = ThemeMode.light;
      await prefs.setString(_themeStyleKey, _themeStyle.name);
      await prefs.setString(_themeModeKey, _themeMode.name);
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
      _walletOpeningUsd = prefs.getDouble(_walletOpeningUsdKey) ?? 0;
      _walletOpeningLbp = prefs.getDouble(_walletOpeningLbpKey) ?? 0;
      _wishWalletOpeningUsd = prefs.getDouble(_wishWalletOpeningUsdKey) ?? 0;
      _wishWalletOpeningLbp = prefs.getDouble(_wishWalletOpeningLbpKey) ?? 0;
      // Older versions used one baseline for both wallets. Keep it as the
      // first-run fallback, then persist separate baselines from now on.
      final legacyBaseline =
          prefs.getStringList(_walletBaselineTransactionIdsKey)?.toSet() ??
          <String>{};
      _cashWalletBaselineTransactionIds =
          prefs.getStringList(_cashWalletBaselineTransactionIdsKey)?.toSet() ??
          legacyBaseline;
      _wishWalletBaselineTransactionIds =
          prefs.getStringList(_wishWalletBaselineTransactionIdsKey)?.toSet() ??
          legacyBaseline;
      _cashWalletComparisonRange = WalletComparisonRange.values.firstWhere(
        (value) => value.name == prefs.getString(_cashWalletComparisonRangeKey),
        orElse: () => WalletComparisonRange.week,
      );
      _wishWalletComparisonRange = WalletComparisonRange.values.firstWhere(
        (value) => value.name == prefs.getString(_wishWalletComparisonRangeKey),
        orElse: () => WalletComparisonRange.week,
      );
      _lastAutoBackup = DateTime.tryParse(
        prefs.getString(_lastAutoBackupKey) ?? '',
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

  Future<void> refresh({bool silentWhenSignedOut = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_usesInjectedSheetService) {
        _transactions = await _service.fetchTransactions(_sheetUrl);
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
      _transactions = await _firebase.fetchTransactions();
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
    _sheetExportSecret = sheetExportSecret.trim().isEmpty
        ? AppConfig.defaultSheetExportSecret
        : sheetExportSecret.trim();
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
      _transactions = imported;
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
      _useFirestore = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firestoreEnabledKey, true);
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
      _useFirestore = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firestoreEnabledKey, true);
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

  Future<void> signOut() async {
    try {
      if (_isFirebaseConfigured) await _firebase.signOut();
    } catch (_) {
      // A local logout must still succeed if a web session has expired.
    }
    _user = null;
    _useFirestore = false;
    _transactions = const [];
    _adminUsers = const [];
    _errorMessage = null;
    _lastUpdated = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firestoreEnabledKey, false);
    notifyListeners();
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

  Future<GoogleDriveBackupFile> createGoogleDriveBackup({String? label}) {
    return _googleDriveBackupService.uploadBackup(
      _createBackupDocument(label: label),
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
    if (normalized.contains('reserve')) {
      return TransactionType.reserveable;
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
        await addTransaction(transaction);
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
      case SmartTransactionActionType.delete:
        final current = _findSmartTarget(action);
        if (current == null) {
          throw FirebaseFinanceException(
            'Could not find transaction to delete: ${action.targetId ?? action.targetTitle ?? ''}',
          );
        }
        await deleteTransaction(current);
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
    final ready = _assignMissingId(transaction);
    final saved = await _firebase.addTransaction(ready);
    _transactions = [
      saved,
      ..._transactions,
    ]..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
    _lastUpdated = DateTime.now();
    notifyListeners();
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
    _themeMode = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeStyleKey, style.name);
    await prefs.setString(_themeModeKey, _themeMode.name);
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
  }

  Future<void> updateWalletOpeningBalances({
    required double usd,
    required double lbp,
  }) async {
    _walletOpeningUsd = usd < 0 ? 0 : usd;
    _walletOpeningLbp = lbp < 0 ? 0 : lbp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_walletOpeningUsdKey, _walletOpeningUsd);
    await prefs.setDouble(_walletOpeningLbpKey, _walletOpeningLbp);
    await _saveWalletSettings();
    notifyListeners();
  }

  Future<void> updateWishWalletOpeningBalances({
    required double usd,
    required double lbp,
  }) async {
    _wishWalletOpeningUsd = usd < 0 ? 0 : usd;
    _wishWalletOpeningLbp = lbp < 0 ? 0 : lbp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_wishWalletOpeningUsdKey, _wishWalletOpeningUsd);
    await prefs.setDouble(_wishWalletOpeningLbpKey, _wishWalletOpeningLbp);
    await _saveWalletSettings();
    notifyListeners();
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
          (transaction) =>
              !transaction.paymentMethod.toLowerCase().contains('wish'),
        )
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    _wishWalletBaselineTransactionIds = _transactions
        .where(
          (transaction) =>
              transaction.paymentMethod.toLowerCase().contains('wish'),
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
  }) async {
    _walletOpeningUsd = usd < 0 ? 0 : usd;
    _walletOpeningLbp = lbp < 0 ? 0 : lbp;
    _cashWalletBaselineTransactionIds = _transactions
        .where(
          (transaction) =>
              !transaction.paymentMethod.toLowerCase().contains('wish'),
        )
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_walletOpeningUsdKey, _walletOpeningUsd);
    await prefs.setDouble(_walletOpeningLbpKey, _walletOpeningLbp);
    await prefs.setStringList(
      _cashWalletBaselineTransactionIdsKey,
      _cashWalletBaselineTransactionIds.toList(),
    );
    await _saveWalletSettings();
    notifyListeners();
  }

  Future<void> resetWishWalletTracking({
    required double usd,
    required double lbp,
  }) async {
    _wishWalletOpeningUsd = usd < 0 ? 0 : usd;
    _wishWalletOpeningLbp = lbp < 0 ? 0 : lbp;
    _wishWalletBaselineTransactionIds = _transactions
        .where(
          (transaction) =>
              transaction.paymentMethod.toLowerCase().contains('wish'),
        )
        .map((transaction) => transaction.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_wishWalletOpeningUsdKey, _wishWalletOpeningUsd);
    await prefs.setDouble(_wishWalletOpeningLbpKey, _wishWalletOpeningLbp);
    await prefs.setStringList(
      _wishWalletBaselineTransactionIdsKey,
      _wishWalletBaselineTransactionIds.toList(),
    );
    await _saveWalletSettings();
    notifyListeners();
  }

  Future<void> _runDailyAutoBackupIfDue() async {
    if (!_autoBackupEnabled || _user == null) {
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastAutoBackup != null && !_lastAutoBackup!.isBefore(today)) {
      return;
    }
    try {
      await createGoogleDriveBackup(
        label: 'Auto backup ${now.toIso8601String()}',
      );
      _lastAutoBackup = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAutoBackupKey, now.toIso8601String());
    } catch (_) {
      // Backup can retry when the app is opened again with a working account.
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

  Future<void> _loadWalletSettings() async {
    if (!_isFirebaseConfigured || _user == null) {
      return;
    }
    try {
      final settings = await _firebase.fetchWalletSettings();
      if (settings == null) {
        // The phone may already have balances stored locally from an older
        // release. Let it publish that data once; a new browser must not
        // overwrite it with empty values.
        if (!kIsWeb) {
          await _saveWalletSettings();
        }
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
      await prefs.setString(
        _cashWalletComparisonRangeKey,
        _cashWalletComparisonRange.name,
      );
      await prefs.setString(
        _wishWalletComparisonRangeKey,
        _wishWalletComparisonRange.name,
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
    final updatedWithId = await _firebase.updateTransaction(updated);
    _transactions = [
      ..._transactions.take(index),
      updatedWithId,
      ..._transactions.skip(index + 1),
    ];
    notifyListeners();
  }

  Future<void> deleteTransaction(FinancialTransaction transaction) async {
    final id = transaction.id?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    if (!_isFirebaseConfigured) {
      throw const FirebaseFinanceException('Firebase is not configured.');
    }
    await _firebase.deleteTransaction(id);
    _transactions = _transactions
        .where((item) => item.id?.trim() != id)
        .toList(growable: false);
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
      final id = transaction.id?.trim() ?? '';
      final isWish = transaction.paymentMethod.trim().toLowerCase().contains(
        'wish',
      );
      if (id.isNotEmpty &&
          (isWish
              ? ignoredWishTransactionIds.contains(id)
              : ignoredCashTransactionIds.contains(id))) {
        continue;
      }
      if (isWish) {
        wishTransactions.add(transaction);
      } else {
        cashTransactions.add(transaction);
      }
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
    required this.incomeUsd,
    required this.incomeLbp,
    required this.expenseUsd,
    required this.expenseLbp,
    required this.reserveableUsd,
    required this.reserveableLbp,
  });

  final double openingUsd;
  final double openingLbp;
  final double incomeUsd;
  final double incomeLbp;
  final double expenseUsd;
  final double expenseLbp;
  final double reserveableUsd;
  final double reserveableLbp;

  double get balanceUsd => openingUsd + incomeUsd - expenseUsd - reserveableUsd;
  double get balanceLbp => openingLbp + incomeLbp - expenseLbp - reserveableLbp;

  factory WalletAccountSummary.fromTransactions(
    List<FinancialTransaction> transactions, {
    required double openingUsd,
    required double openingLbp,
  }) {
    var incomeUsd = 0.0;
    var incomeLbp = 0.0;
    var expenseUsd = 0.0;
    var expenseLbp = 0.0;
    var reserveableUsd = 0.0;
    var reserveableLbp = 0.0;
    for (final transaction in transactions) {
      final amount = transaction.amount;
      final isUsd = transaction.currency == CurrencyCode.usd;
      final isLbp = transaction.currency == CurrencyCode.lbp;
      if (transaction.isIncome) {
        if (isUsd) incomeUsd += amount;
        if (isLbp) incomeLbp += amount;
      } else if (transaction.isExpense) {
        if (isUsd) expenseUsd += amount;
        if (isLbp) expenseLbp += amount;
      } else if (transaction.isReserveable) {
        if (isUsd) reserveableUsd += amount;
        if (isLbp) reserveableLbp += amount;
      }
    }
    return WalletAccountSummary(
      openingUsd: openingUsd,
      openingLbp: openingLbp,
      incomeUsd: incomeUsd,
      incomeLbp: incomeLbp,
      expenseUsd: expenseUsd,
      expenseLbp: expenseLbp,
      reserveableUsd: reserveableUsd,
      reserveableLbp: reserveableLbp,
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
