import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/transaction.dart';
import '../services/firebase_finance_service.dart';
import '../services/firebase_bootstrap.dart';
import '../services/gemini_transaction_parser.dart';
import '../services/google_sheet_service.dart';
import '../services/sheet_export_service.dart';

enum TimeFilter { today, last3Days, thisWeek, thisMonth, custom, allTime }

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
  }) : _usesInjectedSheetService = service != null,
       _service = service ?? GoogleSheetService(),
       _sheetExportService = sheetExportService ?? SheetExportService(),
       _geminiParser = geminiParser ?? GeminiTransactionParser() {
    _firebaseService = firebaseService;
  }

  static const _sheetUrlKey = 'sheet_url';
  static const _exchangeRateKey = 'exchange_rate';
  static const _languageKey = 'language';
  static const _themeModeKey = 'theme_mode';
  static const _calculationStartMonthKey = 'calculation_start_month';
  static const _firestoreEnabledKey = 'firestore_enabled';
  static const _sheetExportEndpointKey = 'sheet_export_endpoint';
  static const _sheetExportSecretKey = 'sheet_export_secret';

  final GoogleSheetService _service;
  final bool _usesInjectedSheetService;
  FirebaseFinanceService? _firebaseService;
  final SheetExportService _sheetExportService;
  final GeminiTransactionParser _geminiParser;

  List<FinancialTransaction> _transactions = [];
  String _sheetUrl = AppConfig.defaultGoogleSheetUrl;
  String _sheetExportEndpoint = AppConfig.sheetExportEndpoint;
  String _sheetExportSecret = AppConfig.sheetExportSecret;
  double _exchangeRate = AppConfig.defaultExchangeRate;
  AppLanguage _language = AppLanguage.english;
  ThemeMode _themeMode = ThemeMode.light;
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

  List<FinancialTransaction> get transactions =>
      List.unmodifiable(_transactions);

  String get sheetUrl => _sheetUrl;

  String get sheetExportEndpoint => _sheetExportEndpoint;

  String get sheetExportSecret => _sheetExportSecret;

  double get exchangeRate => _exchangeRate;

  AppLanguage get language => _language;

  ThemeMode get themeMode => _themeMode;

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
    final values =
        _transactions
            .map((transaction) => transaction.paymentMethod.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
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
      return List.unmodifiable(_transactions);
    }
    return _transactions.where((transaction) {
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
      _themeMode = prefs.getString(_themeModeKey) == ThemeMode.dark.name
          ? ThemeMode.dark
          : ThemeMode.light;
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
      await refresh(silentWhenSignedOut: true);
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
    if (_isFirebaseConfigured) {
      await _firebase.signOut();
    }
    _user = null;
    _useFirestore = false;
    _transactions = const [];
    _errorMessage = null;
    _lastUpdated = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firestoreEnabledKey, false);
    notifyListeners();
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
    _transactions = [saved, ..._transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    _lastUpdated = DateTime.now();
    notifyListeners();
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
    await prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
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
