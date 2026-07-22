import 'dart:convert';

import '../models/transaction.dart';
import 'label_normalizer.dart';

enum SmartTransactionActionType { add, edit, delete, settle }

class SmartTransactionAction {
  const SmartTransactionAction({
    required this.type,
    this.transaction,
    this.targetId,
    this.targetTitle,
    this.settlementWallet,
    this.settlementDate,
  });

  final SmartTransactionActionType type;
  final FinancialTransaction? transaction;
  final String? targetId;
  final String? targetTitle;
  final String? settlementWallet;
  final DateTime? settlementDate;

  String get label {
    return switch (type) {
      SmartTransactionActionType.add => 'Add',
      SmartTransactionActionType.edit => 'Edit',
      SmartTransactionActionType.delete => 'Delete',
      SmartTransactionActionType.settle => 'Settle',
    };
  }
}

class GeminiTransactionParser {
  List<FinancialTransaction> parse(String input) {
    return parseActions(input)
        .where((action) => action.transaction != null)
        .map((action) => action.transaction!)
        .toList(growable: false);
  }

  List<SmartTransactionAction> parseActions(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const GeminiTransactionParseException(
        'Paste a Gemini script first.',
      );
    }

    final decoded = jsonDecode(_extractJson(trimmed));
    final items = _itemsFromDecoded(decoded);
    return items.map(_parseAction).toList(growable: false);
  }

  String _extractJson(String value) {
    var text = value.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final objectStart = text.indexOf('{');
    final listStart = text.indexOf('[');
    final starts = [objectStart, listStart].where((index) => index >= 0);
    if (starts.isEmpty) {
      return text;
    }
    final start = starts.reduce((a, b) => a < b ? a : b);
    final endObject = text.lastIndexOf('}');
    final endList = text.lastIndexOf(']');
    final end = endObject > endList ? endObject : endList;
    if (end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

  List<Object?> _itemsFromDecoded(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      for (final key in const [
        'transactions',
        'items',
        'rows',
        'data',
        'entries',
      ]) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
      return [decoded];
    }
    throw const GeminiTransactionParseException(
      'Input must be one transaction object or a list of transactions.',
    );
  }

  SmartTransactionAction _parseAction(Object? item) {
    if (item is! Map) {
      throw const GeminiTransactionParseException(
        'Each Gemini script item must be a JSON object.',
      );
    }

    final action = _parseActionType(_string(item, 'action'));
    if (action == SmartTransactionActionType.delete ||
        action == SmartTransactionActionType.settle) {
      final targetId = _stringAny(item, const [
        'id',
        'transaction_id',
        'transactionId',
        'Transaction ID',
      ]);
      final targetTitle = _stringAny(item, const [
        'target_title',
        'targetTitle',
        'title',
        'description',
        'Title',
        'Description',
      ]);
      if (targetId.isEmpty && targetTitle.isEmpty) {
        throw GeminiTransactionParseException(
          '${_actionLabel(action)} action needs id or target_title.',
        );
      }
      return SmartTransactionAction(
        type: action,
        targetId: targetId.isEmpty ? null : targetId,
        targetTitle: targetTitle.isEmpty ? null : targetTitle,
        settlementWallet: _stringAny(item, const [
          'wallet',
          'Wallet',
          'wallet_id',
          'walletId',
          'payment_method',
          'paymentMethod',
          'Payment Method',
        ]),
        settlementDate: _parseDateOrNull(
          _stringAny(item, const [
            'date',
            'Date',
            'settlement_date',
            'settlementDate',
          ]),
        ),
      );
    }

    final transaction = _parseTransaction(item);
    return SmartTransactionAction(
      type: action,
      transaction: transaction,
      targetId: _targetId(item, transaction),
      targetTitle: _targetTitle(item, transaction),
    );
  }

  FinancialTransaction _parseTransaction(Map item) {
    final date = _parseDate(_stringAny(item, const ['date', 'Date']));
    final amountUsd = _doubleAny(item, const [
      'amount_usd',
      'amountUsd',
      'Amount (\$)',
    ]);
    final amountLbp = _doubleAny(item, const [
      'amount_lbp',
      'amountLbp',
      'Amount (LBP)',
    ]);
    final currency = amountUsd > 0 ? CurrencyCode.usd : CurrencyCode.lbp;
    final amount = currency == CurrencyCode.usd ? amountUsd : amountLbp;
    if (amount <= 0) {
      throw const GeminiTransactionParseException(
        'Amount must be greater than zero.',
      );
    }

    final statusText = _stringAny(item, const [
      'status',
      'type',
      'Status',
      'Type',
    ]);
    final type = _parseType(statusText);
    if (type == TransactionType.unknown) {
      throw const GeminiTransactionParseException(
        'Status must be Income, Expense, Credit, Debt, or Transfer.',
      );
    }

    final title = _stringAny(item, const [
      'title',
      'description',
      'Title',
      'Description',
    ]);
    final category = LabelNormalizer.category(
      _fallback(
        _stringAny(item, const ['category', 'Category']),
        'Uncategorized',
      ),
    );
    final requestedPaymentMethod = _stringAny(item, const [
      'payment_method',
      'paymentMethod',
      'Payment Method',
      'wallet',
      'Wallet',
      'wallet_id',
    ]);
    final paymentMethod = LabelNormalizer.wallet(requestedPaymentMethod);
    final notes = LabelNormalizer.text(
      _stringAny(item, const ['notes', 'Notes']),
    );
    final paymentTiming = _stringAny(item, const [
      'payment_timing',
      'paymentTiming',
      'Payment Timing',
      'paid_now',
      'paidNow',
    ]);
    final createdAt =
        _parseDateTime(
          _stringAny(item, const ['created_at', 'createdAt', 'Created At']),
        ) ??
        DateTime.now();
    const source = TransactionSource.script;
    final raw = <String, String>{
      'date': _dateText(date),
      'status': type.label,
      'title': LabelNormalizer.text(title),
      'amount_usd': amountUsd.toString(),
      'amount_lbp': amountLbp.toString(),
      'category': category,
      'payment_method': paymentMethod,
      'wallet_id': LabelNormalizer.wallet(
        _fallback(
          _stringAny(item, const ['wallet_id', 'walletId', 'Wallet']),
          paymentMethod,
        ),
      ),
      'destination_wallet_id': LabelNormalizer.wallet(
        _stringAny(item, const [
          'destination_wallet_id',
          'destinationWalletId',
          'Destination Wallet',
        ]),
      ),
      'wallet_direction': _stringAny(item, const [
        'wallet_direction',
        'walletDirection',
        'Wallet Direction',
      ]),
      'settlement_status': _stringAny(item, const [
        'settlement_status',
        'settlementStatus',
        'Settlement Status',
      ]),
      'linked_transaction_id': _stringAny(item, const [
        'linked_transaction_id',
        'linkedTransactionId',
        'Linked Transaction ID',
      ]),
      'payment_timing': _normalizePaymentTiming(paymentTiming),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'source': source.label,
    };

    return FinancialTransaction(
      id: _stringAny(item, const ['id', 'transaction_id', 'Transaction ID']),
      createdAt: createdAt,
      source: source,
      date: date,
      hasDate: true,
      type: type,
      category: category,
      description: _fallback(title, category),
      currency: currency,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      raw: raw,
    );
  }

  SmartTransactionActionType _parseActionType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.isEmpty ||
        normalized == 'add' ||
        normalized == 'add_transaction' ||
        normalized == 'create' ||
        normalized == 'create_transaction' ||
        normalized == 'insert' ||
        normalized == 'insert_transaction' ||
        normalized == 'upsert' ||
        normalized == 'upsert_transaction') {
      return SmartTransactionActionType.add;
    }
    if (normalized == 'edit' ||
        normalized == 'update' ||
        normalized == 'edit_transaction' ||
        normalized == 'update_transaction' ||
        normalized == 'update_now') {
      return SmartTransactionActionType.edit;
    }
    if (normalized == 'delete' ||
        normalized == 'remove' ||
        normalized == 'delete_transaction' ||
        normalized == 'remove_transaction') {
      return SmartTransactionActionType.delete;
    }
    if (normalized == 'settle' ||
        normalized == 'settle_transaction' ||
        normalized == 'paid' ||
        normalized == 'mark_paid' ||
        normalized == 'collect' ||
        normalized == 'collect_credit' ||
        normalized == 'pay_debt') {
      return SmartTransactionActionType.settle;
    }
    throw GeminiTransactionParseException('Unsupported action: $value');
  }

  String _actionLabel(SmartTransactionActionType action) {
    return switch (action) {
      SmartTransactionActionType.add => 'Add',
      SmartTransactionActionType.edit => 'Edit',
      SmartTransactionActionType.delete => 'Delete',
      SmartTransactionActionType.settle => 'Settle',
    };
  }

  String? _targetId(Map item, FinancialTransaction transaction) {
    final explicit = _stringAny(item, const [
      'target_id',
      'targetId',
      'existing_id',
      'existingId',
    ]);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final id = transaction.id?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  String? _targetTitle(Map item, FinancialTransaction transaction) {
    final explicit = _stringAny(item, const [
      'target_title',
      'targetTitle',
      'existing_title',
      'existingTitle',
      'old_title',
      'oldTitle',
    ]);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final title = transaction.description.trim();
    return title.isEmpty ? null : title;
  }

  TransactionType _parseType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('credit') ||
        normalized.contains('reserveable') ||
        normalized.contains('receivable') ||
        normalized.contains('reserved')) {
      return TransactionType.reserveable;
    }
    if (normalized.contains('income')) {
      return TransactionType.income;
    }
    if (normalized.contains('debt') ||
        normalized.contains('payable') ||
        normalized.contains('payables')) {
      return TransactionType.debt;
    }
    if (normalized.contains('transfer')) {
      return TransactionType.transfer;
    }
    if (normalized.contains('expense') || normalized.contains('debit')) {
      return TransactionType.expense;
    }
    return TransactionType.unknown;
  }

  DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDateOrNull(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _parseDateTime(String value) {
    final parsed = DateTime.tryParse(value.trim().replaceFirst(' ', 'T'));
    return parsed;
  }

  String _stringAny(Map item, List<String> keys) {
    for (final key in keys) {
      final value = _string(item, key);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _string(Map item, String key) {
    final value = item[key];
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }

  double _doubleAny(Map item, List<String> keys) {
    for (final key in keys) {
      final parsed = _toDouble(item[key]);
      if (parsed > 0) {
        return parsed;
      }
    }
    return 0;
  }

  double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(
          '$value'
              .replaceAll(',', '')
              .replaceAll(r'$', '')
              .replaceAll(RegExp('usd|lbp', caseSensitive: false), '')
              .trim(),
        ) ??
        0;
  }

  String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  String _normalizePaymentTiming(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized == 'false' ||
        normalized.contains('credit') ||
        normalized.contains('later') ||
        normalized.contains('دين')) {
      return 'On Credit';
    }
    return 'Paid Now';
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class GeminiTransactionParseException implements Exception {
  const GeminiTransactionParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
