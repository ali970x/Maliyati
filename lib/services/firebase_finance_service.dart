import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/transaction.dart';

class FinanceUser {
  const FinanceUser({
    required this.uid,
    this.accountId,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? accountId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
}

class AdminUserSnapshot {
  const AdminUserSnapshot({required this.user, required this.transactions});

  final FinanceUser user;
  final List<FinancialTransaction> transactions;
}

class SheetIntegrationSettings {
  const SheetIntegrationSettings({
    required this.exportEndpoint,
    required this.exportSecret,
  });

  final String exportEndpoint;
  final String exportSecret;
}

class WalletSyncSettings {
  const WalletSyncSettings({
    required this.cashOpeningUsd,
    required this.cashOpeningLbp,
    required this.wishOpeningUsd,
    required this.wishOpeningLbp,
    required this.cashBaselineTransactionIds,
    required this.wishBaselineTransactionIds,
    required this.cashComparisonRange,
    required this.wishComparisonRange,
  });

  final double cashOpeningUsd;
  final double cashOpeningLbp;
  final double wishOpeningUsd;
  final double wishOpeningLbp;
  final List<String> cashBaselineTransactionIds;
  final List<String> wishBaselineTransactionIds;
  final String cashComparisonRange;
  final String wishComparisonRange;
}

class FirebaseFinanceService {
  static const adminEmail = 'labdev99@gmail.com';

  FirebaseFinanceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  FinanceUser? get currentUser => _toBasicFinanceUser(_auth.currentUser);

  bool get isCurrentUserAdmin =>
      (_auth.currentUser?.email ?? '').trim().toLowerCase() == adminEmail;

  Future<FinanceUser?> waitForStoredUser() async {
    final user = await _auth.authStateChanges().first;
    // Authentication must be able to restore independently of Firestore.
    // A missing profile document should never prevent the login screen from
    // opening, especially on the web after a Google redirect/popup.
    return _toBasicFinanceUser(user);
  }

  Future<FinanceUser?> loadCurrentUser() async {
    return _toBasicFinanceUser(_auth.currentUser);
  }

  Future<bool> isAccountIdAvailable(String accountId) async {
    final id = normalizeAccountId(accountId);
    if (id.isEmpty) {
      return false;
    }
    final snapshot = await _firestore.collection('user_ids').doc(id).get();
    return !snapshot.exists;
  }

  Future<FinanceUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toFinanceUser(result.user, includeProfile: true);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const FirebaseFinanceException('Enter your email first.');
    }
    await _auth.sendPasswordResetEmail(email: trimmed);
  }

  Future<FinanceUser?> createAccountWithEmail({
    required String name,
    required String email,
    required String password,
    required String accountId,
  }) async {
    final normalizedAccountId = normalizeAccountId(accountId);
    if (normalizedAccountId.isEmpty) {
      throw const FirebaseFinanceException('User ID is required.');
    }
    if (!await isAccountIdAvailable(normalizedAccountId)) {
      throw const FirebaseFinanceException('This User ID is already used.');
    }
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      return null;
    }
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
    }
    await _saveUserProfile(
      uid: user.uid,
      accountId: normalizedAccountId,
      email: user.email,
      displayName: trimmedName.isEmpty ? user.displayName : trimmedName,
      photoUrl: user.photoURL,
    );
    return _toFinanceUser(user, includeProfile: true);
  }

  Future<FinanceUser?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        final user = result.user ?? _auth.currentUser;
        if (user == null) {
          throw const FirebaseFinanceException(
            'Google did not return an account. Please try again.',
          );
        }

        // The account is authenticated at this point. Profile creation is
        // intentionally best-effort, so a Firestore setup/rules issue cannot
        // turn a successful Google login into a null-check web error.
        try {
          await _ensureUserProfile(user);
        } catch (_) {}
        return _toBasicFinanceUser(user);
      } on FirebaseAuthException catch (error) {
        throw FirebaseFinanceException(_googleWebErrorMessage(error));
      } on FirebaseFinanceException {
        rethrow;
      } catch (error) {
        final existingUser = _auth.currentUser;
        if (existingUser != null) {
          return _toBasicFinanceUser(existingUser);
        }
        throw FirebaseFinanceException(_googleUnexpectedWebError(error));
      }
    }

    final googleAccount = await _googleSignIn.signIn();
    if (googleAccount == null) {
      return currentUser;
    }
    final googleAuth = await googleAccount.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserProfile(result.user);
    return _toFinanceUser(result.user, includeProfile: true);
  }

  String _googleWebErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'unauthorized-domain':
        return 'This website is not yet allowed by Firebase. Add maliyati-finance.onrender.com under Firebase Authentication > Settings > Authorized domains.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Authentication.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in window. Allow popups, then try again.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Google sign-in was cancelled.';
      default:
        return error.message ??
            'Google sign-in could not be completed. Please try again.';
    }
  }

  String _googleUnexpectedWebError(Object error) {
    final message = error.toString();
    if (message.contains('Null check operator used on a null value')) {
      return 'Google signed in, but the web session could not be completed. Please refresh this page once and try again.';
    }
    return 'Google sign-in could not be completed. Please try again.';
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase Auth is the source of truth. On web, GoogleSignIn can throw
      // after the Firebase session is already closed, so sign-out must continue.
    }
  }

  Future<List<AdminUserSnapshot>> fetchAdminUserSnapshots() async {
    _requireAdmin();
    final users = await _firestore.collection('users').get();
    final snapshots = <AdminUserSnapshot>[];
    for (final userDoc in users.docs) {
      final data = userDoc.data();
      final transactions = await _transactions(
        userDoc.id,
      ).orderBy('date', descending: true).get();
      snapshots.add(
        AdminUserSnapshot(
          user: FinanceUser(
            uid: userDoc.id,
            accountId: '${data['accountId'] ?? ''}'.trim(),
            email: '${data['email'] ?? ''}'.trim(),
            displayName: '${data['displayName'] ?? ''}'.trim(),
            photoUrl: '${data['photoUrl'] ?? ''}'.trim(),
          ),
          transactions: transactions.docs
              .map((doc) => _fromFirestore(doc.data(), fallbackId: doc.id))
              .toList(growable: false),
        ),
      );
    }
    snapshots.sort((a, b) {
      final left = a.user.email ?? a.user.accountId ?? a.user.uid;
      final right = b.user.email ?? b.user.accountId ?? b.user.uid;
      return left.compareTo(right);
    });
    return snapshots;
  }

  Future<void> saveAdminUserProfile(FinanceUser user) async {
    _requireAdmin();
    final accountId = normalizeAccountId(user.accountId ?? '');
    if (user.uid.trim().isEmpty || accountId.isEmpty) {
      throw const FirebaseFinanceException(
        'User UID and User ID are required.',
      );
    }
    final batch = _firestore.batch();
    batch.set(_firestore.collection('user_ids').doc(accountId), {
      'uid': user.uid.trim(),
      'email': user.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(user.uid.trim()), {
      'accountId': accountId,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoUrl': user.photoUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteAdminUserData(String uid) async {
    _requireAdmin();
    final userDoc = _firestore.collection('users').doc(uid);
    final userSnapshot = await userDoc.get();
    final accountId = '${userSnapshot.data()?['accountId'] ?? ''}'.trim();
    final txs = await _transactions(uid).get();
    final batch = _firestore.batch();
    for (final doc in txs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(userDoc);
    if (accountId.isNotEmpty) {
      batch.delete(_firestore.collection('user_ids').doc(accountId));
    }
    await batch.commit();
  }

  Future<void> saveAdminTransaction({
    required String uid,
    required FinancialTransaction transaction,
  }) async {
    _requireAdmin();
    final id = _requireTransactionId(transaction);
    await _transactions(
      uid,
    ).doc(id).set(_toFirestore(transaction), SetOptions(merge: true));
  }

  Future<void> deleteAdminTransaction({
    required String uid,
    required String transactionId,
  }) async {
    _requireAdmin();
    await _transactions(uid).doc(transactionId).delete();
  }

  Future<List<FinancialTransaction>> replaceAdminTransactions({
    required String uid,
    required List<FinancialTransaction> transactions,
  }) async {
    _requireAdmin();
    final existing = await _transactions(uid).get();
    final deleteBatch = _firestore.batch();
    for (final doc in existing.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();
    if (transactions.isEmpty) {
      return const [];
    }
    final writeBatch = _firestore.batch();
    for (final transaction in transactions) {
      final id = _requireTransactionId(transaction);
      writeBatch.set(_transactions(uid).doc(id), _toFirestore(transaction));
    }
    await writeBatch.commit();
    return transactions;
  }

  Future<List<FinancialTransaction>> fetchTransactions() async {
    final user = _requireUser();
    final snapshot = await _transactions(
      user.uid,
    ).orderBy('date', descending: true).get();
    return snapshot.docs
        .map((doc) => _fromFirestore(doc.data(), fallbackId: doc.id))
        .toList();
  }

  Future<FinancialTransaction> addTransaction(
    FinancialTransaction transaction,
  ) async {
    final user = _requireUser();
    final saved = await _withId(user, transaction);
    await _transactions(user.uid).doc(saved.id!).set(_toFirestore(saved));
    return saved;
  }

  Future<FinancialTransaction> updateTransaction(
    FinancialTransaction transaction,
  ) async {
    final user = _requireUser();
    final id = _requireTransactionId(transaction);
    await _transactions(
      user.uid,
    ).doc(id).set(_toFirestore(transaction), SetOptions(merge: true));
    return transaction;
  }

  Future<void> deleteTransaction(String id) async {
    final user = _requireUser();
    await _transactions(user.uid).doc(id).delete();
  }

  Future<void> upsertTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    final user = _requireUser();
    final batch = _firestore.batch();
    for (final transaction in transactions) {
      final id = _requireTransactionId(transaction);
      batch.set(_transactions(user.uid).doc(id), _toFirestore(transaction));
    }
    await batch.commit();
  }

  Future<List<FinancialTransaction>> replaceTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    final user = _requireUser();
    final existing = await _transactions(user.uid).get();
    final deleteBatch = _firestore.batch();
    for (final doc in existing.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    if (transactions.isEmpty) {
      return const [];
    }

    final accountId = await _currentAccountId(user);
    final saved = _withSequentialIds(transactions, accountId: accountId);
    final writeBatch = _firestore.batch();
    for (final transaction in saved) {
      writeBatch.set(
        _transactions(user.uid).doc(transaction.id!),
        _toFirestore(transaction),
      );
    }
    await writeBatch.commit();
    return saved;
  }

  Future<SheetIntegrationSettings?> fetchSheetIntegrationSettings() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return SheetIntegrationSettings(
      exportEndpoint: '${data['sheetExportEndpoint'] ?? ''}'.trim(),
      exportSecret: '${data['sheetExportSecret'] ?? ''}'.trim(),
    );
  }

  Future<void> saveSheetIntegrationSettings(
    SheetIntegrationSettings settings,
  ) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'sheetExportEndpoint': settings.exportEndpoint.trim(),
      'sheetExportSecret': settings.exportSecret.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<WalletSyncSettings?> fetchWalletSettings() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final data = snapshot.data();
    if (data == null || !data.containsKey('walletOpeningUsd')) {
      return null;
    }
    double number(String key) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    List<String> ids(String key) => (data[key] as List<dynamic>? ?? const [])
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return WalletSyncSettings(
      cashOpeningUsd: number('walletOpeningUsd'),
      cashOpeningLbp: number('walletOpeningLbp'),
      wishOpeningUsd: number('wishWalletOpeningUsd'),
      wishOpeningLbp: number('wishWalletOpeningLbp'),
      cashBaselineTransactionIds: ids('cashWalletBaselineTransactionIds'),
      wishBaselineTransactionIds: ids('wishWalletBaselineTransactionIds'),
      cashComparisonRange: '${data['cashWalletComparisonRange'] ?? 'week'}',
      wishComparisonRange: '${data['wishWalletComparisonRange'] ?? 'week'}',
    );
  }

  Future<void> saveWalletSettings(WalletSyncSettings settings) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'walletOpeningUsd': settings.cashOpeningUsd,
      'walletOpeningLbp': settings.cashOpeningLbp,
      'wishWalletOpeningUsd': settings.wishOpeningUsd,
      'wishWalletOpeningLbp': settings.wishOpeningLbp,
      'cashWalletBaselineTransactionIds': settings.cashBaselineTransactionIds,
      'wishWalletBaselineTransactionIds': settings.wishBaselineTransactionIds,
      'cashWalletComparisonRange': settings.cashComparisonRange,
      'wishWalletComparisonRange': settings.wishComparisonRange,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _transactions(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  DocumentReference<Map<String, dynamic>> _settings(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('google_sheet');
  }

  static String normalizeAccountId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const FirebaseFinanceException('Sign in with Google first.');
    }
    return user;
  }

  User _requireAdmin() {
    final user = _requireUser();
    if ((user.email ?? '').trim().toLowerCase() != adminEmail) {
      throw const FirebaseFinanceException('Admin access is required.');
    }
    return user;
  }

  FinanceUser? _toBasicFinanceUser(User? user) {
    if (user == null) {
      return null;
    }
    return FinanceUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<void> _ensureUserProfile(User? user) async {
    if (user == null) {
      return;
    }
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final currentAccountId = '${data?['accountId'] ?? ''}'.trim();
    if (currentAccountId.isNotEmpty) {
      return;
    }
    await _saveUserProfile(
      uid: user.uid,
      accountId: _fallbackAccountId(user),
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<void> _saveUserProfile({
    required String uid,
    required String accountId,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('user_ids').doc(accountId), {
      'uid': uid,
      'email': email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('users').doc(uid), {
      'accountId': accountId,
      'email': email ?? '',
      'displayName': displayName ?? '',
      'photoUrl': photoUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  String _fallbackAccountId(User user) {
    final fromEmail = normalizeAccountId((user.email ?? '').split('@').first);
    if (fromEmail.isNotEmpty) {
      return fromEmail;
    }
    return normalizeAccountId(user.uid).isEmpty
        ? 'user'
        : normalizeAccountId(user.uid);
  }

  Future<String> _currentAccountId(User user) async {
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();
    final accountId = normalizeAccountId('${data?['accountId'] ?? ''}');
    if (accountId.isNotEmpty) {
      return accountId;
    }
    final fallback = _fallbackAccountId(user);
    await _saveUserProfile(
      uid: user.uid,
      accountId: fallback,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
    return fallback;
  }

  Future<FinanceUser?> _toFinanceUser(
    User? user, {
    bool includeProfile = false,
  }) async {
    if (user == null) {
      return null;
    }
    String? accountId;
    if (includeProfile) {
      accountId = await _currentAccountId(user);
    }
    return FinanceUser(
      uid: user.uid,
      accountId: accountId,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Map<String, dynamic> _toFirestore(FinancialTransaction transaction) {
    final id = _requireTransactionId(transaction);
    return {
      'id': id,
      'date': Timestamp.fromDate(
        DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        ),
      ),
      'hasDate': transaction.hasDate,
      'status': transaction.type.label,
      'title': transaction.description,
      'amountUsd': transaction.currency == CurrencyCode.usd
          ? transaction.amount
          : 0,
      'amountLbp': transaction.currency == CurrencyCode.lbp
          ? transaction.amount
          : 0,
      'currency': transaction.currency.label,
      'amount': transaction.amount,
      'category': transaction.category,
      'paymentMethod': transaction.paymentMethod,
      'notes': transaction.notes,
      // Keep this at the document root as well as in `raw`.  A few legacy
      // import paths rebuild `raw`, while this field must survive refreshes.
      'archived': transaction.isArchived,
      'createdAt': transaction.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(transaction.createdAt!),
      'source': transaction.source.label,
      'raw': transaction.raw,
    };
  }

  FinancialTransaction _fromFirestore(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final dateValue = data['date'];
    final date = dateValue is Timestamp ? dateValue.toDate() : DateTime.now();
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : DateTime.tryParse('${data['createdAt'] ?? ''}');
    final amountUsd = _toDouble(data['amountUsd']);
    final amountLbp = _toDouble(data['amountLbp']);
    final currency = amountLbp > 0 ? CurrencyCode.lbp : CurrencyCode.usd;
    final amount = currency == CurrencyCode.lbp
        ? amountLbp
        : amountUsd > 0
        ? amountUsd
        : _toDouble(data['amount']);
    final raw = <String, String>{
      'date': _dateText(date),
      'status': '${data['status'] ?? ''}',
      'title': '${data['title'] ?? ''}',
      'amount_usd': amountUsd.toString(),
      'amount_lbp': amountLbp.toString(),
      'category': '${data['category'] ?? ''}',
      'payment_method': '${data['paymentMethod'] ?? ''}',
      'notes': '${data['notes'] ?? ''}',
      'source': '${data['source'] ?? ''}',
      'created_at': createdAt?.toIso8601String() ?? '',
      'archived': '${data['archived'] == true}',
    };
    final storedRaw = data['raw'];
    if (storedRaw is Map) {
      for (final entry in storedRaw.entries) {
        raw['${entry.key}'] = '${entry.value}';
      }
    }
    // The document-level flag is authoritative. Older versions stored a
    // stale `archived` value in raw, which could make an archived item return
    // after a refresh or prevent a restored item from returning to the list.
    final archivedValue = data['archived'];
    if (archivedValue is bool) {
      raw['archived'] = archivedValue ? 'true' : 'false';
    }

    return FinancialTransaction(
      id: '${data['id'] ?? ''}'.trim().isEmpty
          ? fallbackId
          : '${data['id']}'.trim(),
      createdAt: createdAt,
      source: _parseSource('${data['source'] ?? ''}'),
      date: DateTime(date.year, date.month, date.day),
      hasDate: data['hasDate'] != false,
      type: _parseType('${data['status'] ?? data['type'] ?? ''}'),
      category: '${data['category'] ?? 'Uncategorized'}'.trim(),
      description: '${data['title'] ?? data['description'] ?? ''}'.trim(),
      currency: currency,
      amount: amount.abs(),
      paymentMethod: '${data['paymentMethod'] ?? ''}'.trim(),
      notes: '${data['notes'] ?? ''}'.trim(),
      raw: raw,
    );
  }

  TransactionSource _parseSource(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'script' ||
        normalized == 'gemini' ||
        normalized == 'manual') {
      return TransactionSource.script;
    }
    if (normalized == 'google sheet' || normalized == 'sheet') {
      return TransactionSource.googleSheet;
    }
    return TransactionSource.application;
  }

  String _requireTransactionId(FinancialTransaction transaction) {
    final id = transaction.id?.trim() ?? '';
    if (id.isEmpty) {
      throw const FirebaseFinanceException('Transaction ID is missing.');
    }
    return id;
  }

  Future<FinancialTransaction> _withId(
    User user,
    FinancialTransaction transaction,
  ) async {
    final current = transaction.id?.trim();
    if (current != null && current.isNotEmpty) {
      return transaction;
    }
    final id = await _nextSequentialId(user);
    return _copyWithId(transaction, id);
  }

  List<FinancialTransaction> _withSequentialIds(
    List<FinancialTransaction> transactions, {
    required String accountId,
  }) {
    return [
      for (var index = 0; index < transactions.length; index += 1)
        _copyWithId(transactions[index], '$accountId-${index + 1}'),
    ];
  }

  FinancialTransaction _copyWithId(
    FinancialTransaction transaction,
    String id,
  ) {
    return transaction.copyWith(
      id: id,
      raw: {...transaction.raw, 'ID': id, 'Transaction ID': id},
    );
  }

  Future<String> _nextSequentialId(User user) async {
    final accountId = await _currentAccountId(user);
    final snapshot = await _transactions(user.uid).get();
    final existing = snapshot.docs
        .map((doc) => _fromFirestore(doc.data(), fallbackId: doc.id))
        .toList(growable: false);
    return '$accountId-${_maxSequentialNumber(existing) + 1}';
  }

  int _maxSequentialNumber(List<FinancialTransaction> transactions) {
    var maxNumber = 0;
    for (final transaction in transactions) {
      final number = _idNumber(transaction.id);
      if (number == null) {
        continue;
      }
      if (number > maxNumber) {
        maxNumber = number;
      }
    }
    return maxNumber;
  }

  int? _idNumber(String? id) {
    final value = id?.trim() ?? '';
    final match = RegExp(r'(\d+)$', caseSensitive: false).firstMatch(value);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  TransactionType _parseType(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('reserve')) {
      return TransactionType.reserveable;
    }
    if (normalized.contains('income')) {
      return TransactionType.income;
    }
    if (normalized.contains('expense')) {
      return TransactionType.expense;
    }
    return TransactionType.unknown;
  }

  double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value'.replaceAll(',', '').trim()) ?? 0;
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class FirebaseFinanceException implements Exception {
  const FirebaseFinanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
