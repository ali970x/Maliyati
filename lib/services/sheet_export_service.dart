import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/transaction.dart';
import 'label_normalizer.dart';

class SheetExportService {
  SheetExportService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool isConfigured({String? endpoint, String? secret}) {
    final resolvedEndpoint = endpoint ?? AppConfig.sheetExportEndpoint;
    final resolvedSecret = secret ?? AppConfig.sheetExportSecret;
    return resolvedEndpoint.trim().isNotEmpty &&
        resolvedSecret.trim().isNotEmpty;
  }

  Future<void> appendTransaction(
    FinancialTransaction transaction, {
    String? endpoint,
    String? secret,
  }) async {
    final resolvedEndpoint = endpoint ?? AppConfig.sheetExportEndpoint;
    final resolvedSecret = secret ?? AppConfig.sheetExportSecret;
    if (!isConfigured(endpoint: resolvedEndpoint, secret: resolvedSecret)) {
      return;
    }

    await _post(
      resolvedEndpoint: resolvedEndpoint,
      resolvedSecret: resolvedSecret,
      body: {
        'secret': resolvedSecret.trim(),
        'action': 'upsert_transaction',
        'row': toSheetRow(transaction),
      },
    );
  }

  Future<Map<String, Object?>> syncTransactions(
    List<FinancialTransaction> transactions, {
    String? endpoint,
    String? secret,
    void Function(int completed, int total, String label)? onProgress,
  }) async {
    final resolvedEndpoint = endpoint ?? AppConfig.sheetExportEndpoint;
    final resolvedSecret = secret ?? AppConfig.sheetExportSecret;
    if (!isConfigured(endpoint: resolvedEndpoint, secret: resolvedSecret)) {
      return const {};
    }

    final prepTotal = transactions.isEmpty ? 1 : transactions.length;
    final totalWork = prepTotal * 2;
    final rows = <Map<String, Object>>[];

    if (transactions.isEmpty) {
      onProgress?.call(1, totalWork, 'Preparing rows');
      await Future<void>.delayed(Duration.zero);
    } else {
      for (var index = 0; index < transactions.length; index += 1) {
        rows.add(toSheetRow(transactions[index]));
        onProgress?.call(index + 1, totalWork, 'Preparing rows');
        if (index % 20 == 0 || index == transactions.length - 1) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    var sentProgress = prepTotal;
    Timer? sendTimer;
    onProgress?.call(sentProgress, totalWork, 'Sending to Google Sheet');
    if (onProgress != null) {
      sendTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
        if (sentProgress < totalWork - 1) {
          sentProgress += 1;
          onProgress(sentProgress, totalWork, 'Sending to Google Sheet');
        }
      });
    }

    try {
      final result = await _post(
        resolvedEndpoint: resolvedEndpoint,
        resolvedSecret: resolvedSecret,
        body: {
          'secret': resolvedSecret.trim(),
          'action': 'sync_transactions',
          'rows': rows,
        },
      );
      onProgress?.call(totalWork, totalWork, 'Google Sheet synced');
      return result;
    } finally {
      sendTimer?.cancel();
    }
  }

  Future<List<FinancialTransaction>> fetchTransactions({
    String? endpoint,
    String? secret,
  }) async {
    final resolvedEndpoint = endpoint ?? AppConfig.sheetExportEndpoint;
    final resolvedSecret = secret ?? AppConfig.sheetExportSecret;
    if (!isConfigured(endpoint: resolvedEndpoint, secret: resolvedSecret)) {
      return const [];
    }

    final decoded = await _post(
      resolvedEndpoint: resolvedEndpoint,
      resolvedSecret: resolvedSecret,
      body: {'secret': resolvedSecret.trim(), 'action': 'list_transactions'},
    );
    final rows = decoded['rows'];
    if (rows is! List) {
      return const [];
    }
    return rows
        .whereType<Map>()
        .map((row) => fromSheetRow(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _post({
    required String resolvedEndpoint,
    required String resolvedSecret,
    required Map<String, Object?> body,
  }) async {
    var response = await _client.post(
      Uri.parse(resolvedEndpoint.trim()),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );

    if (_isRedirect(response.statusCode)) {
      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        throw SheetExportException(
          'Google Sheet export redirected without a destination.',
        );
      }
      response = await _client.get(Uri.parse(location));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SheetExportException(
        'Google Sheet export failed with HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SheetExportException(
        'Google Sheet export returned invalid JSON.',
      );
    }
    final map = Map<String, Object?>.from(decoded);
    if (map['ok'] != true) {
      throw SheetExportException(
        '${map['error'] ?? 'Google Sheet export failed.'}',
      );
    }
    return map;
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  Map<String, Object> toSheetRow(FinancialTransaction transaction) {
    final date = transaction.hasDate ? _dateText(transaction.date) : '';
    return {
      'Date': date,
      'Status': transaction.type.label,
      'Title': transaction.description,
      'Amount (\$)': transaction.amountUsd,
      'Amount (LBP)': transaction.amountLbp,
      'Category': LabelNormalizer.category(transaction.category),
      'Payment Method': LabelNormalizer.wallet(transaction.paymentMethod),
      'Payment Timing': transaction.raw['payment_timing'] ?? '',
      'Notes': transaction.notes,
      'Created At': _dateTimeText(transaction.createdAt ?? DateTime.now()),
      'Source': transaction.source.label,
      'Wallet': LabelNormalizer.wallet(transaction.walletId),
      'Destination Wallet': LabelNormalizer.wallet(
        transaction.destinationWalletId ?? '',
      ),
      'Wallet Direction': transaction.walletDirection,
      'Settlement Status': transaction.settlementStatus.label,
      'Linked Transaction ID': transaction.linkedTransactionId ?? '',
      'ID': transaction.id ?? '',
      'Transaction ID': transaction.id ?? '',
    };
  }

  FinancialTransaction fromSheetRow(Map<String, Object?> row) {
    final date = DateTime.tryParse('${row['Date'] ?? ''}'.trim());
    final createdAt = _parseDateTime(row['Created At']);
    final amountUsd = _toDouble(row['Amount (\$)']);
    final amountLbp = _toDouble(row['Amount (LBP)']);
    final currency = amountUsd > 0 ? CurrencyCode.usd : CurrencyCode.lbp;
    final amount = currency == CurrencyCode.usd ? amountUsd : amountLbp;
    final normalizedDate = date == null
        ? DateTime.now()
        : DateTime(date.year, date.month, date.day);
    return FinancialTransaction(
      id: _firstText(row, const ['ID', 'Transaction ID', 'transaction_id']),
      createdAt: createdAt,
      source: _parseSource('${row['Source'] ?? 'Google Sheet'}'),
      date: normalizedDate,
      hasDate: date != null,
      type: _parseType('${row['Status'] ?? ''}'),
      category: LabelNormalizer.category(
        '${row['Category'] ?? 'Uncategorized'}',
      ),
      description: LabelNormalizer.text('${row['Title'] ?? ''}'),
      currency: currency,
      amount: amount.abs(),
      paymentMethod: LabelNormalizer.wallet('${row['Payment Method'] ?? ''}'),
      notes: LabelNormalizer.text('${row['Notes'] ?? ''}'),
      raw: {
        ...row.map((key, value) => MapEntry(key, '$value')),
        'payment_timing': _firstText(row, const [
          'Payment Timing',
          'payment_timing',
        ]),
        'wallet_id': _firstText(row, const ['Wallet', 'wallet_id']),
        'destination_wallet_id': _firstText(row, const [
          'Destination Wallet',
          'destination_wallet_id',
        ]),
        'wallet_direction': _firstText(row, const [
          'Wallet Direction',
          'wallet_direction',
        ]),
        'settlement_status': _firstText(row, const [
          'Settlement Status',
          'settlement_status',
        ]),
        'linked_transaction_id': _firstText(row, const [
          'Linked Transaction ID',
          'linked_transaction_id',
        ]),
      },
    );
  }

  TransactionSource _parseSource(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'script' ||
        normalized == 'gemini' ||
        normalized == 'manual') {
      return TransactionSource.script;
    }
    if (normalized == 'application' || normalized == 'app') {
      return TransactionSource.application;
    }
    return TransactionSource.googleSheet;
  }

  TransactionType _parseType(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('income')) return TransactionType.income;
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
    if (normalized.contains('expense') || normalized.contains('debit')) {
      return TransactionType.expense;
    }
    return TransactionType.unknown;
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          '$value'
              .replaceAll(',', '')
              .replaceAll(r'$', '')
              .replaceAll(RegExp('lbp|usd', caseSensitive: false), '')
              .trim(),
        ) ??
        0;
  }

  String _firstText(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateTimeText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute:$second';
  }

  DateTime? _parseDateTime(Object? value) {
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null || parsed.year < 2000) {
      return null;
    }
    return parsed;
  }
}

class SheetExportException implements Exception {
  const SheetExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
