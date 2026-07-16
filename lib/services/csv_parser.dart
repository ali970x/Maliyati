import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';

class CsvParser {
  List<FinancialTransaction> parse(String csvText) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
      eol: '\n',
    ).convert(csvText.trim());

    if (rows.isEmpty) {
      return const [];
    }

    final headers = rows.first
        .map((cell) => _normalizeHeader('$cell'))
        .toList();
    final transactions = <FinancialTransaction>[];

    for (final row in rows.skip(1)) {
      if (row.every((cell) => '$cell'.trim().isEmpty)) {
        continue;
      }

      final map = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? '${row[i]}'.trim() : '';
      }

      final parsedDate = _parseDate(_value(map, 'date'));
      final createdAt = _parseDateTime(
        _valueAny(map, const [
          'created_at',
          'created',
          'created_at_time',
          'createdat',
        ]),
      );
      final source = _parseSource(_valueAny(map, const ['source', 'origin']));
      final date = parsedDate ?? _today();
      final hasDate = parsedDate != null;
      final type = _parseType(
        _valueAny(map, const ['type', 'status', 'expense', 'income']),
      );
      if (type == TransactionType.unknown) {
        continue;
      }

      final title = _valueAny(map, const [
        'title',
        'name',
        'item',
        'item_name',
        'product',
        'product_name',
        'description',
        'details',
      ]);
      final sheetDescription = _valueAny(map, const ['description', 'details']);
      final description = title;
      final category = _fallback(
        _valueAny(map, const ['category', 'categories', 'cat']),
        _fallback(description, 'Uncategorized'),
      );
      final paymentMethod = _valueAny(map, const [
        'payment_method',
        'payment',
        'method',
      ]);
      final notes = _fallback(
        _valueAny(map, const ['notes', 'note', 'remarks']),
        title.isNotEmpty &&
                sheetDescription.isNotEmpty &&
                title != sheetDescription
            ? sheetDescription
            : '',
      );

      final amount = _parseAmount(_value(map, 'amount'));
      if (amount != null && amount != 0) {
        final currency = _parseCurrency(_value(map, 'currency'));
        transactions.add(
          _transaction(
            date: date,
            hasDate: hasDate,
            type: type,
            category: category,
            description: description,
            currency: currency == CurrencyCode.unknown
                ? CurrencyCode.usd
                : currency,
            amount: amount,
            paymentMethod: paymentMethod,
            notes: notes,
            raw: map,
            id: _valueAny(map, const ['id', 'transaction_id']),
            createdAt: createdAt,
            source: source,
          ),
        );
        continue;
      }

      final usdAmount = _parseAmount(_valueStartingWith(map, 'amount_usd'));
      final lbpAmount = _parseAmount(_valueStartingWith(map, 'amount_lbp'));

      if (usdAmount != null && usdAmount != 0) {
        transactions.add(
          _transaction(
            date: date,
            hasDate: hasDate,
            type: type,
            category: category,
            description: description,
            currency: CurrencyCode.usd,
            amount: usdAmount,
            paymentMethod: paymentMethod,
            notes: notes,
            raw: map,
            id: _valueAny(map, const ['id', 'transaction_id']),
            createdAt: createdAt,
            source: source,
          ),
        );
      }

      if (lbpAmount != null && lbpAmount != 0) {
        transactions.add(
          _transaction(
            date: date,
            hasDate: hasDate,
            type: type,
            category: category,
            description: description,
            currency: CurrencyCode.lbp,
            amount: lbpAmount,
            paymentMethod: paymentMethod,
            notes: notes,
            raw: map,
            id: _valueAny(map, const ['id', 'transaction_id']),
            createdAt: createdAt,
            source: source,
          ),
        );
      }
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  String _normalizeHeader(String header) {
    var normalized = header.trim().toLowerCase();
    normalized = normalized.replaceAll(r'$', 'usd').replaceAll('dollar', 'usd');
    normalized = normalized
        .replaceAll('كاتيجوري', 'category')
        .replaceAll('الفئة', 'category')
        .replaceAll('تصنيف', 'category')
        .replaceAll('النوتز', 'notes')
        .replaceAll('ملاحظات', 'notes')
        .replaceAll('ملاحظة', 'notes')
        .replaceAll('العنوان', 'title')
        .replaceAll('عنوان', 'title')
        .replaceAll('اسم المنتج', 'product_name')
        .replaceAll('المنتج', 'product')
        .replaceAll('الصنف', 'item')
        .replaceAll('الاسم', 'name')
        .replaceAll('الوصف', 'description')
        .replaceAll('تفاصيل', 'description')
        .replaceAll('التاريخ', 'date')
        .replaceAll('تاريخ', 'date')
        .replaceAll('الحالة', 'status')
        .replaceAll('حالة', 'status')
        .replaceAll('status', 'status')
        .replaceAll('النوع', 'type')
        .replaceAll('نوع', 'type')
        .replaceAll('الدفع', 'payment_method')
        .replaceAll('طريقة الدفع', 'payment_method')
        .replaceAll('المبلغ', 'amount')
        .replaceAll('عملة', 'currency')
        .replaceAll('العملة', 'currency');
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _value(Map<String, String> row, String key) {
    final normalized = _normalizeHeader(key);
    if (row.containsKey(normalized)) {
      return row[normalized]!.trim();
    }
    return '';
  }

  String _valueAny(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = _value(row, key);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _valueStartingWith(Map<String, String> row, String prefix) {
    for (final entry in row.entries) {
      if (entry.key.startsWith(prefix) && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return '';
  }

  String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  FinancialTransaction _transaction({
    required DateTime date,
    required bool hasDate,
    required TransactionType type,
    required String category,
    required String description,
    required CurrencyCode currency,
    required double amount,
    required String paymentMethod,
    required String notes,
    required Map<String, String> raw,
    String? id,
    DateTime? createdAt,
    TransactionSource source = TransactionSource.googleSheet,
  }) {
    return FinancialTransaction(
      id: id == null || id.trim().isEmpty ? null : id.trim(),
      createdAt: createdAt,
      source: source,
      date: date,
      hasDate: hasDate,
      type: type,
      category: category,
      description: description,
      currency: currency,
      amount: amount.abs(),
      paymentMethod: paymentMethod,
      notes: notes,
      raw: raw,
    );
  }

  TransactionSource _parseSource(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'application' || normalized == 'app') {
      return TransactionSource.application;
    }
    if (normalized == 'script' ||
        normalized == 'gemini' ||
        normalized == 'manual') {
      return TransactionSource.script;
    }
    return TransactionSource.googleSheet;
  }

  TransactionType _parseType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('reserveable') ||
        normalized.contains('receivable') ||
        normalized.contains('reserved') ||
        normalized.contains('\u0645\u0633\u062a\u062d\u0642')) {
      return TransactionType.reserveable;
    }
    if (normalized.contains('income') ||
        normalized.contains('\u062f\u062e\u0644')) {
      return TransactionType.income;
    }
    if (normalized.contains('expense') ||
        normalized.contains('\u0645\u0635\u0627\u0631\u064a\u0641') ||
        normalized.contains('\u0635\u0631\u0641')) {
      return TransactionType.expense;
    }
    return TransactionType.unknown;
  }

  CurrencyCode _parseCurrency(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('usd') || normalized.contains(r'$')) {
      return CurrencyCode.usd;
    }
    if (normalized.contains('lbp') ||
        normalized.contains('l.l') ||
        normalized.contains('\u0644\u064a\u0631\u0629')) {
      return CurrencyCode.lbp;
    }
    return CurrencyCode.unknown;
  }

  double? _parseAmount(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    final isNegative = value.contains('(') && value.contains(')');
    var cleaned = value
        .replaceAll(RegExp(r'usd|lbp|l\.l|\$', caseSensitive: false), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('(', '-')
        .replaceAll(')', '')
        .trim();

    cleaned = cleaned.replaceAll(RegExp(r'[^-0-9.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return null;
    }
    return isNegative ? -parsed.abs() : parsed;
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(trimmed);
    if (isoDate != null) {
      return DateTime(isoDate.year, isoDate.month, isoDate.day);
    }

    final patterns = [
      'M/d/yyyy',
      'MM/dd/yyyy',
      'd/M/yyyy',
      'dd/MM/yyyy',
      'yyyy/M/d',
      'yyyy-MM-dd',
      'd-M-yyyy',
      'dd-MM-yyyy',
      'MMM d, yyyy',
      'd MMM yyyy',
    ];

    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(trimmed);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        // Try the next common spreadsheet date format.
      }
    }

    return null;
  }

  DateTime? _parseDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed =
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T')) ??
        _parseDate(trimmed);
    if (parsed == null || parsed.year < 2000) {
      return null;
    }
    return parsed;
  }
}
