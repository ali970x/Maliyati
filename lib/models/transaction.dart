enum TransactionType { income, expense, reserveable, unknown }

enum CurrencyCode { usd, lbp, unknown }

enum TransactionSource { application, googleSheet, script }

class FinancialTransaction {
  const FinancialTransaction({
    this.id,
    this.createdAt,
    this.source = TransactionSource.application,
    required this.date,
    required this.hasDate,
    required this.type,
    required this.category,
    required this.description,
    required this.currency,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.raw,
  });

  final String? id;
  final DateTime? createdAt;
  final TransactionSource source;
  final DateTime date;
  final bool hasDate;
  final TransactionType type;
  final String category;
  final String description;
  final CurrencyCode currency;
  final double amount;
  final String paymentMethod;
  final String notes;
  final Map<String, String> raw;

  bool get isIncome => type == TransactionType.income;

  bool get isExpense => type == TransactionType.expense;

  bool get isReserveable => type == TransactionType.reserveable;

  double amountInUsd(double exchangeRate) {
    if (currency == CurrencyCode.usd) {
      return amount;
    }
    if (currency == CurrencyCode.lbp) {
      return amount / exchangeRate;
    }
    return 0;
  }

  FinancialTransaction copyWith({
    String? id,
    DateTime? createdAt,
    TransactionSource? source,
    DateTime? date,
    bool? hasDate,
    TransactionType? type,
    String? category,
    String? description,
    CurrencyCode? currency,
    double? amount,
    String? paymentMethod,
    String? notes,
    Map<String, String>? raw,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      date: date ?? this.date,
      hasDate: hasDate ?? this.hasDate,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      raw: raw ?? this.raw,
    );
  }
}

extension TransactionSourceLabel on TransactionSource {
  String get label {
    switch (this) {
      case TransactionSource.application:
        return 'application';
      case TransactionSource.googleSheet:
        return 'Google Sheet';
      case TransactionSource.script:
        return 'script';
    }
  }
}

extension TransactionTypeLabel on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.reserveable:
        return 'Reserveable';
      case TransactionType.unknown:
        return 'Unknown';
    }
  }
}

extension CurrencyCodeLabel on CurrencyCode {
  String get label {
    switch (this) {
      case CurrencyCode.usd:
        return 'USD';
      case CurrencyCode.lbp:
        return 'LBP';
      case CurrencyCode.unknown:
        return 'Unknown';
    }
  }
}
