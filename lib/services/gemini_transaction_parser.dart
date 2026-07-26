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
    this.settlementAmountUsd = 0,
    this.settlementAmountLbp = 0,
    this.settlementExchangeRate,
  });

  final SmartTransactionActionType type;
  final FinancialTransaction? transaction;
  final String? targetId;
  final String? targetTitle;
  final String? settlementWallet;
  final DateTime? settlementDate;
  final double settlementAmountUsd;
  final double settlementAmountLbp;
  final double? settlementExchangeRate;

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
        'Paste a Maliyati JSON script first.',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(_extractJson(trimmed));
    } on FormatException catch (error) {
      throw GeminiTransactionParseException(
        'The script is not valid JSON. Copy only the JSON code and try again. '
        '${error.message}',
      );
    }
    final items = _itemsFromDecoded(decoded);
    if (items.isEmpty) {
      throw const GeminiTransactionParseException(
        'The script does not contain any actions.',
      );
    }
    return items.map(_parseAction).toList(growable: false);
  }

  String _extractJson(String value) {
    var text = value
        .replaceAll('\uFEFF', '')
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .trim();
    final fenced = RegExp(
      r'```(?:json|javascript|js|dart|text)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenced != null) {
      final candidate = fenced.group(1)?.trim() ?? '';
      if (candidate.contains('{') || candidate.contains('[')) {
        text = candidate;
      }
    }
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
        'actions',
        'commands',
        'operations',
        'transactions',
        'items',
        'rows',
        'data',
        'entries',
        'result',
      ]) {
        final value = _value(decoded, key);
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

    final flattened = _flattenPayload(item);
    final action = _parseActionType(
      _stringAny(flattened, const ['action', 'operation', 'command']),
    );
    if (action == SmartTransactionActionType.delete ||
        action == SmartTransactionActionType.settle) {
      final targetId = _stringAny(flattened, const [
        'id',
        'target_id',
        'targetId',
        'transaction_id',
        'transactionId',
        'Transaction ID',
      ]);
      final targetTitle = _stringAny(flattened, const [
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
      final settlementAmounts = _settlementAmounts(flattened);
      return SmartTransactionAction(
        type: action,
        targetId: targetId.isEmpty ? null : targetId,
        targetTitle: targetTitle.isEmpty ? null : targetTitle,
        settlementWallet: LabelNormalizer.wallet(
          _stringAny(flattened, const [
            'wallet',
            'Wallet',
            'wallet_id',
            'walletId',
            'payment_method',
            'paymentMethod',
            'Payment Method',
          ]),
        ),
        settlementDate: _parseDateOrNull(
          _stringAny(flattened, const [
            'date',
            'Date',
            'settlement_date',
            'settlementDate',
          ]),
        ),
        settlementAmountUsd: settlementAmounts.amountUsd,
        settlementAmountLbp: settlementAmounts.amountLbp,
        settlementExchangeRate: _positiveDoubleAny(flattened, const [
          'exchange_rate',
          'exchangeRate',
          'settlement_exchange_rate',
          'settlementExchangeRate',
          'rate',
        ]),
      );
    }

    final transaction = _parseTransaction(flattened);
    return SmartTransactionAction(
      type: action,
      transaction: transaction,
      targetId: _targetId(flattened, transaction),
      targetTitle: _targetTitle(flattened, transaction),
    );
  }

  Map<dynamic, dynamic> _flattenPayload(Map item) {
    final flattened = <dynamic, dynamic>{...item};
    for (final key in const ['transaction', 'record', 'payload', 'details']) {
      final nested = _value(item, key);
      if (nested is Map) {
        flattened.addAll(nested);
        break;
      }
    }
    return flattened;
  }

  ({double amountUsd, double amountLbp}) _settlementAmounts(Map item) {
    var amountUsd = _doubleAny(item, const [
      'settlement_amount_usd',
      'settlementAmountUsd',
      'paid_usd',
      'paidUsd',
      'amount_usd',
      'amountUsd',
      'Amount (\$)',
    ]);
    var amountLbp = _doubleAny(item, const [
      'settlement_amount_lbp',
      'settlementAmountLbp',
      'paid_lbp',
      'paidLbp',
      'amount_lbp',
      'amountLbp',
      'Amount (LBP)',
    ]);
    if (amountUsd <= 0 && amountLbp <= 0) {
      final generic = _doubleAny(item, const [
        'settlement_amount',
        'settlementAmount',
        'paid_amount',
        'paidAmount',
        'amount',
        'value',
      ]);
      final currency = _currencyHint(
        item,
        currencyKeys: const [
          'settlement_currency',
          'settlementCurrency',
          'currency',
        ],
        amountKeys: const [
          'settlement_amount',
          'settlementAmount',
          'paid_amount',
          'paidAmount',
          'amount',
          'value',
        ],
      );
      if (currency.contains('lbp') || currency.contains('ليرة')) {
        amountLbp = generic;
      } else {
        amountUsd = generic;
      }
    }
    return (amountUsd: amountUsd, amountLbp: amountLbp);
  }

  String _currencyHint(
    Map item, {
    required List<String> currencyKeys,
    required List<String> amountKeys,
  }) {
    final currency = _stringAny(item, currencyKeys);
    return (currency.isEmpty ? _stringAny(item, amountKeys) : currency)
        .toLowerCase();
  }

  double? _positiveDoubleAny(Map item, List<String> keys) {
    final value = _doubleAny(item, keys);
    return value > 0 ? value : null;
  }

  FinancialTransaction _parseTransaction(Map item) {
    final date = _parseDate(_stringAny(item, const ['date', 'Date']));
    var amountUsd = _doubleAny(item, const [
      'amount_usd',
      'amountUsd',
      'usd_amount',
      'usdAmount',
      'usd',
      'Amount (\$)',
    ]);
    var amountLbp = _doubleAny(item, const [
      'amount_lbp',
      'amountLbp',
      'lbp_amount',
      'lbpAmount',
      'lbp',
      'Amount (LBP)',
    ]);
    if (amountUsd <= 0 && amountLbp <= 0) {
      final genericAmount = _doubleAny(item, const [
        'amount',
        'value',
        'total',
      ]);
      final genericCurrency = _currencyHint(
        item,
        currencyKeys: const ['currency', 'Currency'],
        amountKeys: const ['amount', 'value', 'total'],
      );
      if (genericCurrency.contains('lbp') ||
          genericCurrency.contains('l.l') ||
          genericCurrency.contains('ليرة')) {
        amountLbp = genericAmount;
      } else {
        amountUsd = genericAmount;
      }
    }
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
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized.isEmpty ||
        normalized == 'add' ||
        normalized == 'add_transaction' ||
        normalized == 'create' ||
        normalized == 'create_transaction' ||
        normalized == 'insert' ||
        normalized == 'insert_transaction' ||
        normalized == 'upsert' ||
        normalized == 'upsert_transaction' ||
        normalized == 'إضافة' ||
        normalized == 'اضافة') {
      return SmartTransactionActionType.add;
    }
    if (normalized == 'edit' ||
        normalized == 'update' ||
        normalized == 'edit_transaction' ||
        normalized == 'update_transaction' ||
        normalized == 'update_now' ||
        normalized == 'تعديل') {
      return SmartTransactionActionType.edit;
    }
    if (normalized == 'delete' ||
        normalized == 'remove' ||
        normalized == 'delete_transaction' ||
        normalized == 'remove_transaction' ||
        normalized == 'حذف') {
      return SmartTransactionActionType.delete;
    }
    if (normalized == 'settle' ||
        normalized == 'settle_transaction' ||
        normalized == 'paid' ||
        normalized == 'mark_paid' ||
        normalized == 'collect' ||
        normalized == 'collect_credit' ||
        normalized == 'pay_debt' ||
        normalized == 'تسديد' ||
        normalized == 'تحصيل' ||
        normalized == 'دفع') {
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
        normalized.contains('reserved') ||
        normalized.contains('مستحق') ||
        normalized.contains('ذمة_لي')) {
      return TransactionType.reserveable;
    }
    if (normalized.contains('income') ||
        normalized.contains('دخل') ||
        normalized.contains('وارد')) {
      return TransactionType.income;
    }
    if (normalized.contains('debt') ||
        normalized.contains('payable') ||
        normalized.contains('payables') ||
        normalized.contains('دين') ||
        normalized.contains('ذمة_علي')) {
      return TransactionType.debt;
    }
    if (normalized.contains('transfer') || normalized.contains('تحويل')) {
      return TransactionType.transfer;
    }
    if (normalized.contains('expense') ||
        normalized.contains('debit') ||
        normalized.contains('مصروف') ||
        normalized.contains('مصاريف') ||
        normalized.contains('صرف')) {
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
    final value = _value(item, key);
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }

  Object? _value(Map item, String key) {
    if (item.containsKey(key)) {
      return item[key];
    }
    final normalizedKey = _normalizedKey(key);
    for (final entry in item.entries) {
      if (_normalizedKey('${entry.key}') == normalizedKey) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalizedKey(String value) => value
      .toLowerCase()
      .replaceAll(r'$', 'usd')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');

  double _doubleAny(Map item, List<String> keys) {
    for (final key in keys) {
      final parsed = _toDouble(_value(item, key));
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
