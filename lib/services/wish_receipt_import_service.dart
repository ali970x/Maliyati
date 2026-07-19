import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';

enum WishReceiptKind { exchange, transfer, merchant, topup, unknown }

class WishReceiptDraft {
  const WishReceiptDraft({
    required this.kind,
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.type,
    required this.date,
    required this.hasDate,
    required this.exchangeRate,
    required this.rawText,
    required this.imagePath,
    required this.sharedAt,
  });

  final WishReceiptKind kind;
  final String id;
  final String description;
  final String category;
  final double amount;
  final CurrencyCode currency;
  final TransactionType type;
  final DateTime date;
  final bool hasDate;
  final double? exchangeRate;
  final String rawText;
  final String imagePath;
  final DateTime sharedAt;

  WishReceiptDraft copyWith({
    String? description,
    String? category,
    double? amount,
    CurrencyCode? currency,
    TransactionType? type,
    DateTime? date,
    bool? hasDate,
  }) => WishReceiptDraft(
        kind: kind,
        id: id,
        description: description ?? this.description,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        type: type ?? this.type,
        date: date ?? this.date,
        hasDate: hasDate ?? this.hasDate,
        exchangeRate: exchangeRate,
        rawText: rawText,
        imagePath: imagePath,
        sharedAt: sharedAt,
      );

  FinancialTransaction toTransaction({required String persistedImagePath}) {
    final raw = <String, String>{
      'wish_kind': kind.name,
      'wish_receipt_image': persistedImagePath,
      'wish_shared_at': sharedAt.toIso8601String(),
      'wish_ocr': rawText,
      if (exchangeRate != null) 'wish_exchange_rate': exchangeRate!.toString(),
    };
    return FinancialTransaction(
      id: id,
      createdAt: DateTime.now(),
      source: TransactionSource.application,
      date: date,
      hasDate: hasDate,
      type: type,
      category: category,
      description: description,
      currency: currency,
      amount: amount,
      paymentMethod: 'Wish Money',
      notes: 'Wish receipt shared ${sharedAt.toLocal().toIso8601String()}',
      raw: raw,
    );
  }
}

class WishReceiptImportService {
  Future<WishReceiptDraft> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return _parse(result.text, imagePath, DateTime.now());
    } finally {
      await recognizer.close();
    }
  }

  Future<String> persistImage(WishReceiptDraft draft) async {
    final extension = _extension(draft.imagePath);
    final directory = await getApplicationDocumentsDirectory();
    final target = Directory('${directory.path}${Platform.pathSeparator}wish_receipts');
    await target.create(recursive: true);
    final safeId = draft.id.isEmpty
        ? draft.sharedAt.microsecondsSinceEpoch.toString()
        : draft.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final output = File('${target.path}${Platform.pathSeparator}wish_$safeId$extension');
    await File(draft.imagePath).copy(output.path);
    return output.path;
  }

  WishReceiptDraft _parse(String raw, String imagePath, DateTime sharedAt) {
    final text = raw.replaceAll('\r', '\n');
    final upper = text.toUpperCase();
    final id = _match(text, RegExp(r'TRANSACTION\s*ID\s*:\s*([0-9]+)', caseSensitive: false));
    final date = _parseDate(_match(text, RegExp(r'(20\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})')));
    final kind = upper.contains('LBP TO USD')
        ? WishReceiptKind.exchange
        : upper.contains('WHISH MONEY') && upper.contains('TOPUP')
        ? WishReceiptKind.topup
        : upper.contains('WHISH TO WHISH')
        ? WishReceiptKind.transfer
        : upper.contains('MERCHANT NAME')
        ? WishReceiptKind.merchant
        : WishReceiptKind.unknown;
    final amountMatch = kind == WishReceiptKind.exchange
        ? RegExp(r'TO\s*AMOUNT\s*:\s*([\d,.]+)\s*(USD|LBP)', caseSensitive: false).firstMatch(text)
        : RegExp(r'AMOUNT\s*:\s*([\d,.]+)\s*(USD|LBP)', caseSensitive: false).firstMatch(text);
    final amount = _number(amountMatch?.group(1) ?? '0');
    final currency = (amountMatch?.group(2) ?? '').toUpperCase() == 'LBP'
        ? CurrencyCode.lbp
        : CurrencyCode.usd;
    final rate = _number(_match(text, RegExp(r'1\s*USD\s*[↔⇄<=>-]+\s*([\d,.]+)\s*LBP', caseSensitive: false)));
    final merchant = _match(text, RegExp(r'MERCHANT\s*NAME\s*:\s*(.+)', caseSensitive: false));
    final phone = _match(text, RegExp(r'(?:RECEIVER\s*PHONE\s*NUMBER|\+961)\s*:?\s*(\+?\d+)', caseSensitive: false));
    final hasPlus = RegExp(r'\+\s*[\d,.]+\s*(?:USD|LBP)', caseSensitive: false).hasMatch(text);
    final defaultType = switch (kind) {
      WishReceiptKind.exchange => TransactionType.unknown,
      WishReceiptKind.topup => TransactionType.income,
      WishReceiptKind.merchant => TransactionType.expense,
      WishReceiptKind.transfer => hasPlus ? TransactionType.income : TransactionType.expense,
      WishReceiptKind.unknown => TransactionType.expense,
    };
    final description = switch (kind) {
      WishReceiptKind.exchange => 'Wish exchange: LBP to USD',
      WishReceiptKind.topup => 'Wish Money top up',
      WishReceiptKind.merchant => merchant.isEmpty ? 'Wish merchant payment' : merchant,
      WishReceiptKind.transfer => phone.isEmpty ? 'Wish to Wish transfer' : 'Wish transfer · $phone',
      WishReceiptKind.unknown => 'Wish receipt',
    };
    final category = switch (kind) {
      WishReceiptKind.exchange => 'Currency exchange',
      WishReceiptKind.topup => 'Wish top up',
      WishReceiptKind.merchant => 'Games',
      WishReceiptKind.transfer => hasPlus ? 'Wish received' : 'Wish transfer',
      WishReceiptKind.unknown => 'Wish Money',
    };
    return WishReceiptDraft(
      kind: kind,
      id: id,
      description: description,
      category: category,
      amount: amount,
      currency: currency,
      type: defaultType,
      date: date ?? sharedAt,
      hasDate: date != null,
      exchangeRate: rate > 0 ? rate : null,
      rawText: text,
      imagePath: imagePath,
      sharedAt: sharedAt,
    );
  }

  String _match(String input, RegExp expression) => expression.firstMatch(input)?.group(1)?.trim() ?? '';
  double _number(String value) => double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  DateTime? _parseDate(String value) => DateTime.tryParse(value.replaceFirst(' ', 'T'));
  String _extension(String path) {
    final index = path.lastIndexOf('.');
    return index < 0 ? '.jpg' : path.substring(index);
  }
}
