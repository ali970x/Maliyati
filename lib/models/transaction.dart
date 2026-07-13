enum TransactionType { income, expense, reserveable, unknown }

enum CurrencyCode { usd, lbp, unknown }

class FinancialTransaction {
  const FinancialTransaction({
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
