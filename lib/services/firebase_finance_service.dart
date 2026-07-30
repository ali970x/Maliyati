import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/transaction.dart';
import 'accounting_rules.dart';

class FinanceUser {
  const FinanceUser({
    required this.uid,
    this.accountId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.blocked = false,
    this.trialEndsAt,
  });

  final String uid;
  final String? accountId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool blocked;
  final DateTime? trialEndsAt;

  bool get isTrialExpired {
    final end = trialEndsAt;
    return end != null && DateTime.now().isAfter(end);
  }
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

class SettlementWriteResult {
  const SettlementWriteResult({required this.parent, required this.payment});

  final FinancialTransaction parent;
  final FinancialTransaction payment;
}

class FirebaseFinanceService {
  static const _batchSize = 400;
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
    return _toFinanceUser(user, includeProfile: true);
  }

  Future<FinanceUser?> loadCurrentUser() async {
    return _toFinanceUser(_auth.currentUser, includeProfile: true);
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
        return _toFinanceUser(user, includeProfile: true);
      } on FirebaseAuthException catch (error) {
        throw FirebaseFinanceException(_googleWebErrorMessage(error));
      } on FirebaseFinanceException {
        rethrow;
      } catch (error) {
        final existingUser = _auth.currentUser;
        if (existingUser != null) {
          return _toFinanceUser(existingUser, includeProfile: true);
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
            blocked: data['blocked'] == true,
            trialEndsAt: _toNullableDate(data['trialEndsAt']),
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
      'blocked': user.blocked,
      'trialEndsAt': user.trialEndsAt == null
          ? null
          : Timestamp.fromDate(user.trialEndsAt!),
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
    final normalized = AccountingRules.normalize(transaction);
    await _transactions(
      uid,
    ).doc(id).set(_toFirestore(normalized), SetOptions(merge: true));
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
    if (transactions.isEmpty) {
      await _deleteReferences(existing.docs.map((doc) => doc.reference));
      return const [];
    }

    final normalized = transactions
        .map(AccountingRules.normalize)
        .toList(growable: false);
    for (var start = 0; start < normalized.length; start += _batchSize) {
      final writeBatch = _firestore.batch();
      for (final transaction in normalized.skip(start).take(_batchSize)) {
        final id = _requireTransactionId(transaction);
        writeBatch.set(_transactions(uid).doc(id), _toFirestore(transaction));
      }
      await writeBatch.commit();
    }
    final incomingIds = normalized.map((transaction) => transaction.id).toSet();
    await _deleteReferences(
      existing.docs
          .where((document) => !incomingIds.contains(document.id))
          .map((document) => document.reference),
    );
    return normalized;
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
    final saved = await _withId(user, AccountingRules.normalize(transaction));
    await _transactions(user.uid).doc(saved.id!).set(_toFirestore(saved));
    return saved;
  }

  Future<FinancialTransaction> updateTransaction(
    FinancialTransaction transaction,
  ) async {
    final user = _requireUser();
    final id = _requireTransactionId(transaction);
    final normalized = AccountingRules.normalize(transaction);
    await _transactions(
      user.uid,
    ).doc(id).set(_toFirestore(normalized), SetOptions(merge: true));
    return normalized;
  }

  Future<void> deleteTransaction(String id) async {
    final user = _requireUser();
    await _transactions(user.uid).doc(id).delete();
  }

  Future<void> setTransactionDeleted(
    FinancialTransaction transaction, {
    required bool deleted,
  }) async {
    final user = _requireUser();
    final id = _requireTransactionId(transaction);
    final collection = _transactions(user.uid);
    final transactionReference = collection.doc(id);
    await _firestore.runTransaction((databaseTransaction) async {
      final snapshot = await databaseTransaction.get(transactionReference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const FirebaseFinanceException('Transaction no longer exists.');
      }

      final stored = _fromFirestore(data, fallbackId: snapshot.id);
      if (stored.isDeleted == deleted) {
        return;
      }

      DocumentReference<Map<String, dynamic>>? parentReference;
      FinancialTransaction? updatedParent;
      var parentAdjusted = false;
      final parentId = stored.linkedTransactionId?.trim() ?? '';
      if (parentId.isNotEmpty) {
        parentReference = collection.doc(parentId);
        final parentSnapshot = await databaseTransaction.get(parentReference);
        final parentData = parentSnapshot.data();
        if (parentSnapshot.exists && parentData != null) {
          final parent = _fromFirestore(
            parentData,
            fallbackId: parentSnapshot.id,
          );
          // Old sequential IDs were occasionally reused. Only a real
          // Credit/Payable parent is allowed to receive settlement changes.
          if (parent.isCredit || parent.isDebt) {
            final allocatedUsd = _settlementAmount(stored, const [
              'settlement_allocation_usd',
              'settlement_amount_usd',
            ], stored.amountUsd);
            final allocatedLbp = _settlementAmount(stored, const [
              'settlement_allocation_lbp',
              'settlement_amount_lbp',
            ], stored.amountLbp);
            if (deleted) {
              updatedParent = AccountingRules.removeSettlement(
                parent,
                amountUsd: allocatedUsd,
                amountLbp: allocatedLbp,
              );
              parentAdjusted = true;
            } else if (stored.raw['recycle_parent_adjusted'] == 'true') {
              updatedParent = AccountingRules.applySettlement(
                parent,
                amountUsd: allocatedUsd,
                amountLbp: allocatedLbp,
              );
            }
          }
        }
      }

      final raw = Map<String, String>.from(stored.raw);
      if (deleted) {
        raw['deleted'] = 'true';
        raw['deleted_at'] = DateTime.now().toUtc().toIso8601String();
        if (parentAdjusted) {
          raw['recycle_parent_adjusted'] = 'true';
        }
      } else {
        raw.remove('deleted');
        raw.remove('deleted_at');
        raw.remove('deletedAt');
        raw.remove('recycle_parent_adjusted');
      }
      final updated = stored.copyWith(raw: raw);
      if (updatedParent != null && parentReference != null) {
        databaseTransaction.set(parentReference, _toFirestore(updatedParent));
      }
      databaseTransaction.set(transactionReference, _toFirestore(updated));
    });
  }

  double _settlementAmount(
    FinancialTransaction transaction,
    List<String> keys,
    double fallback,
  ) {
    for (final key in keys) {
      final parsed = double.tryParse(transaction.raw[key] ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  Future<void> deleteTransactionCascade(String id) async {
    final user = _requireUser();
    final collection = _transactions(user.uid);
    final linked = await collection
        .where('linkedTransactionId', isEqualTo: id)
        .get();
    final references = <DocumentReference<Map<String, dynamic>>>{
      collection.doc(id),
      for (final document in linked.docs) document.reference,
    }.toList(growable: false);
    for (var start = 0; start < references.length; start += _batchSize) {
      final batch = _firestore.batch();
      for (final reference in references.skip(start).take(_batchSize)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<FinancialTransaction?> deleteSettlementEntry(String paymentId) async {
    final user = _requireUser();
    final collection = _transactions(user.uid);
    final paymentReference = collection.doc(paymentId);
    return _firestore.runTransaction((databaseTransaction) async {
      final paymentSnapshot = await databaseTransaction.get(paymentReference);
      final paymentData = paymentSnapshot.data();
      if (!paymentSnapshot.exists || paymentData == null) {
        return null;
      }
      final payment = _fromFirestore(
        paymentData,
        fallbackId: paymentSnapshot.id,
      );
      final parentId = payment.linkedTransactionId?.trim() ?? '';
      if (parentId.isEmpty) {
        databaseTransaction.delete(paymentReference);
        return null;
      }
      final parentReference = collection.doc(parentId);
      final parentSnapshot = await databaseTransaction.get(parentReference);
      final parentData = parentSnapshot.data();
      if (!parentSnapshot.exists || parentData == null) {
        databaseTransaction.delete(paymentReference);
        return null;
      }
      final parent = _fromFirestore(parentData, fallbackId: parentSnapshot.id);
      final allocatedUsd =
          double.tryParse(
            payment.raw['settlement_allocation_usd'] ??
                payment.raw['settlement_amount_usd'] ??
                '',
          ) ??
          payment.amountUsd;
      final allocatedLbp =
          double.tryParse(
            payment.raw['settlement_allocation_lbp'] ??
                payment.raw['settlement_amount_lbp'] ??
                '',
          ) ??
          payment.amountLbp;
      final updatedParent = AccountingRules.removeSettlement(
        parent,
        amountUsd: allocatedUsd,
        amountLbp: allocatedLbp,
      );
      databaseTransaction.set(parentReference, _toFirestore(updatedParent));
      databaseTransaction.delete(paymentReference);
      return updatedParent;
    });
  }

  Future<SettlementWriteResult> settleTransaction({
    required String transactionId,
    required String walletId,
    required DateTime date,
    required double amountUsd,
    required double amountLbp,
    required double exchangeRate,
  }) async {
    final user = _requireUser();
    final collection = _transactions(user.uid);
    final parentReference = collection.doc(transactionId);
    final paymentReference = collection.doc();

    return _firestore.runTransaction((databaseTransaction) async {
      final snapshot = await databaseTransaction.get(parentReference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const FirebaseFinanceException(
          'The Credit or Debt record no longer exists.',
        );
      }
      final current = _fromFirestore(data, fallbackId: snapshot.id);
      if (!current.isCredit && !current.isDebt) {
        throw const FirebaseFinanceException(
          'Only Credit and Debt transactions can be settled.',
        );
      }
      if (current.isSettled || !current.hasOutstandingBalance) {
        throw const FirebaseFinanceException(
          'This transaction is already settled.',
        );
      }
      if (exchangeRate <= 0) {
        throw const FirebaseFinanceException('Enter a valid exchange rate.');
      }
      if (amountUsd < 0 || amountLbp < 0) {
        throw const FirebaseFinanceException(
          'Settlement amounts cannot be negative.',
        );
      }
      if (amountUsd <= 0.0001 && amountLbp <= 0.5) {
        throw const FirebaseFinanceException('Enter an amount to settle.');
      }

      late final ({double amountUsd, double amountLbp}) allocation;
      try {
        allocation = AccountingRules.settlementAllocation(
          current,
          paidUsd: amountUsd,
          paidLbp: amountLbp,
          exchangeRate: exchangeRate,
        );
      } on ArgumentError catch (error) {
        throw FirebaseFinanceException(
          error.message?.toString() ??
              'The payment is greater than the remaining balance.',
        );
      }
      final parent = AccountingRules.applySettlement(
        current,
        amountUsd: allocation.amountUsd,
        amountLbp: allocation.amountLbp,
      );
      final paymentDraft = AccountingRules.settlementEntry(
        current,
        walletId: walletId.trim().isEmpty ? current.walletId : walletId,
        date: date,
        amountUsd: amountUsd,
        amountLbp: amountLbp,
        allocatedUsd: allocation.amountUsd,
        allocatedLbp: allocation.amountLbp,
        exchangeRate: exchangeRate,
      );
      final payment = paymentDraft.copyWith(
        id: paymentReference.id,
        raw: {
          ...paymentDraft.raw,
          'ID': paymentReference.id,
          'Transaction ID': paymentReference.id,
        },
      );

      databaseTransaction.set(parentReference, _toFirestore(parent));
      databaseTransaction.set(paymentReference, _toFirestore(payment));
      return SettlementWriteResult(parent: parent, payment: payment);
    });
  }

  /// Deletes only the signed-in user's transaction records. User profile and
  /// login credentials remain intact, so this can safely power "Reset account".
  Future<void> clearTransactions() async {
    final user = _requireUser();
    final collection = _transactions(user.uid);
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) {
        return;
      }
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteTransactionsByIds(Iterable<String> transactionIds) async {
    final user = _requireUser();
    final ids = transactionIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    for (var start = 0; start < ids.length; start += 400) {
      final batch = _firestore.batch();
      for (final id in ids.skip(start).take(400)) {
        batch.delete(_transactions(user.uid).doc(id));
      }
      await batch.commit();
    }
  }

  Future<void> _deleteReferences(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    final items = references.toList(growable: false);
    for (var start = 0; start < items.length; start += _batchSize) {
      final batch = _firestore.batch();
      for (final reference in items.skip(start).take(_batchSize)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<void> upsertTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    final user = _requireUser();
    for (var start = 0; start < transactions.length; start += _batchSize) {
      final batch = _firestore.batch();
      for (final transaction in transactions.skip(start).take(_batchSize)) {
        final id = _requireTransactionId(transaction);
        batch.set(
          _transactions(user.uid).doc(id),
          _toFirestore(AccountingRules.normalize(transaction)),
        );
      }
      await batch.commit();
    }
  }

  Future<List<FinancialTransaction>> replaceTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    final user = _requireUser();
    final existing = await _transactions(user.uid).get();
    if (transactions.isEmpty) {
      await deleteTransactionsByIds(existing.docs.map((doc) => doc.id));
      return const [];
    }

    final accountId = await _currentAccountId(user);
    final saved = _withSequentialIds(
      transactions.map(AccountingRules.normalize).toList(growable: false),
      accountId: accountId,
    );
    await upsertTransactions(saved);
    final incomingIds = saved.map((transaction) => transaction.id).toSet();
    await deleteTransactionsByIds(
      existing.docs
          .map((document) => document.id)
          .where((id) => !incomingIds.contains(id)),
    );
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

  Future<List<Map<String, dynamic>>?> fetchCategoryRules() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final raw = snapshot.data()?['categoryRules'];
    if (raw is! List) {
      return null;
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> saveCategoryRules(
    List<Map<String, dynamic>> categoryRules,
  ) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'categoryRules': categoryRules,
      'categoryRulesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchBudgetPlanSettings() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final raw = snapshot.data()?['budgetPlan'];
    if (raw is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveBudgetPlanSettings(Map<String, dynamic> budgetPlan) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'budgetPlan': budgetPlan,
      'budgetPlanUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>?> fetchDashboardPins() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final raw = snapshot.data()?['dashboardPins'];
    if (raw is! List) {
      return null;
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> saveDashboardPins(
    List<Map<String, dynamic>> dashboardPins,
  ) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'dashboardPins': dashboardPins,
      'dashboardPinsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchDashboardComparison() async {
    final user = _requireUser();
    final snapshot = await _settings(user.uid).get();
    final raw = snapshot.data()?['dashboardComparison'];
    if (raw is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveDashboardComparison(
    Map<String, dynamic> dashboardComparison,
  ) async {
    final user = _requireUser();
    await _settings(user.uid).set({
      'dashboardComparison': dashboardComparison,
      'dashboardComparisonUpdatedAt': FieldValue.serverTimestamp(),
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
    var blocked = false;
    DateTime? trialEndsAt;
    if (includeProfile) {
      accountId = await _currentAccountId(user);
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      blocked = data?['blocked'] == true;
      trialEndsAt = _toNullableDate(data?['trialEndsAt']);
    }
    return FinanceUser(
      uid: user.uid,
      accountId: accountId,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      blocked: blocked,
      trialEndsAt: trialEndsAt,
    );
  }

  DateTime? _toNullableDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
      'amountUsd': transaction.amountUsd,
      'amountLbp': transaction.amountLbp,
      'currency': transaction.currency.label,
      'amount': transaction.amount,
      'category': transaction.category,
      'paymentMethod': transaction.paymentMethod,
      'walletId': transaction.walletId,
      'destinationWalletId': transaction.destinationWalletId ?? '',
      'linkedTransactionId': transaction.linkedTransactionId ?? '',
      'walletDirection': transaction.walletDirection,
      'settlementStatus': transaction.settlementStatus.label,
      'affectsExpenseStats': transaction.affectsExpenseStats,
      'affectsIncomeStats': transaction.affectsIncomeStats,
      'affectsReceivables': transaction.affectsReceivables,
      'affectsPayables': transaction.affectsPayables,
      'notes': transaction.notes,
      // Keep this at the document root as well as in `raw`.  A few legacy
      // import paths rebuild `raw`, while this field must survive refreshes.
      'archived': transaction.isArchived,
      'deleted': transaction.isDeleted,
      'deletedAt': transaction.deletedAt == null
          ? null
          : Timestamp.fromDate(transaction.deletedAt!),
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
    final storedCurrency = _parseStoredCurrency('${data['currency'] ?? ''}');
    final currency = storedCurrency != CurrencyCode.unknown
        ? storedCurrency
        : amountUsd > 0
        ? CurrencyCode.usd
        : CurrencyCode.lbp;
    final amount = currency == CurrencyCode.usd
        ? (amountUsd > 0 ? amountUsd : _toDouble(data['amount']))
        : (amountLbp > 0 ? amountLbp : _toDouble(data['amount']));
    final raw = <String, String>{
      'date': _dateText(date),
      'status': '${data['status'] ?? ''}',
      'title': '${data['title'] ?? ''}',
      'amount_usd': amountUsd.toString(),
      'amount_lbp': amountLbp.toString(),
      'category': '${data['category'] ?? ''}',
      'payment_method': '${data['paymentMethod'] ?? ''}',
      'wallet_id': '${data['walletId'] ?? data['paymentMethod'] ?? ''}',
      'destination_wallet_id': '${data['destinationWalletId'] ?? ''}',
      'linked_transaction_id': '${data['linkedTransactionId'] ?? ''}',
      'wallet_direction': '${data['walletDirection'] ?? ''}',
      'settlement_status': '${data['settlementStatus'] ?? ''}',
      'affects_expense_stats': '${data['affectsExpenseStats'] ?? ''}',
      'affects_income_stats': '${data['affectsIncomeStats'] ?? ''}',
      'affects_receivables': '${data['affectsReceivables'] ?? ''}',
      'affects_payables': '${data['affectsPayables'] ?? ''}',
      'notes': '${data['notes'] ?? ''}',
      'source': '${data['source'] ?? ''}',
      'created_at': createdAt?.toIso8601String() ?? '',
      'archived': '${data['archived'] == true}',
      'deleted': '${data['deleted'] == true}',
      'deleted_at': _toNullableDate(data['deletedAt'])?.toIso8601String() ?? '',
    };
    final storedRaw = data['raw'];
    if (storedRaw is Map) {
      for (final entry in storedRaw.entries) {
        raw['${entry.key}'] = '${entry.value}';
      }
    }
    // The document-level relation is authoritative. A few old raw maps have
    // an empty linked_transaction_id which otherwise hides the relationship
    // and makes a collection look like a standalone Credit transaction.
    final linkedTransactionId = '${data['linkedTransactionId'] ?? ''}'.trim();
    if (linkedTransactionId.isNotEmpty) {
      raw['linked_transaction_id'] = linkedTransactionId;
      raw['linkedTransactionId'] = linkedTransactionId;
    }
    // The document-level flag is authoritative. Older versions stored a
    // stale `archived` value in raw, which could make an archived item return
    // after a refresh or prevent a restored item from returning to the list.
    final archivedValue = data['archived'];
    if (archivedValue is bool) {
      raw['archived'] = archivedValue ? 'true' : 'false';
    }
    final deletedValue = data['deleted'];
    if (deletedValue is bool) {
      raw['deleted'] = deletedValue ? 'true' : 'false';
    }

    return AccountingRules.normalize(
      FinancialTransaction(
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
      ),
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

  CurrencyCode _parseStoredCurrency(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'usd' || normalized.contains('dollar')) {
      return CurrencyCode.usd;
    }
    if (normalized == 'lbp' || normalized.contains('lebanese')) {
      return CurrencyCode.lbp;
    }
    return CurrencyCode.unknown;
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
