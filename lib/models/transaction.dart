enum TransactionType { income, expense, reserveable, debt, transfer, unknown }

enum CurrencyCode { usd, lbp, unknown }

enum TransactionSource { application, googleSheet, script }

enum AccountingSettlementStatus { open, partial, settled }

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

  bool get isCredit => isReserveable;

  bool get isDebt => type == TransactionType.debt;

  bool get isTransfer => type == TransactionType.transfer;

  bool get isDebit =>
      isExpense && paymentMethod.trim().toLowerCase().contains('debit');

  bool get isArchived => raw['archived']?.toLowerCase() == 'true';

  String get walletId {
    final explicit = raw['wallet_id'] ?? raw['walletId'];
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final method = paymentMethod.trim();
    return method.isEmpty ? 'My Wallet' : method;
  }

  String? get destinationWalletId {
    final value = raw['destination_wallet_id'] ?? raw['destinationWalletId'];
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get linkedTransactionId {
    final value = raw['linked_transaction_id'] ?? raw['linkedTransactionId'];
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get isSettlementEntry {
    // A link to another transaction is the stable accounting relationship.
    // Older Firestore documents may not carry the optional role in raw.
    return linkedTransactionId != null;
  }

  AccountingSettlementStatus get settlementStatus {
    final normalized =
        (raw['settlement_status'] ?? raw['settlementStatus'] ?? '')
            .trim()
            .toLowerCase();
    if (normalized == 'settled') {
      return AccountingSettlementStatus.settled;
    }
    if (normalized == 'partial') {
      return AccountingSettlementStatus.partial;
    }
    return AccountingSettlementStatus.open;
  }

  bool get isSettled => settlementStatus == AccountingSettlementStatus.settled;

  /// Amount already paid for a debt, or already collected for a credit.
  double get settledAmountUsd =>
      _rawAmount(const ['settled_amount_usd', 'settledAmountUsd']);

  double get settledAmountLbp =>
      _rawAmount(const ['settled_amount_lbp', 'settledAmountLbp']);

  double get remainingAmountUsd =>
      (amountUsd - settledAmountUsd).clamp(0, double.infinity).toDouble();

  double get remainingAmountLbp =>
      (amountLbp - settledAmountLbp).clamp(0, double.infinity).toDouble();

  bool get hasOutstandingBalance =>
      remainingAmountUsd > 0.0001 || remainingAmountLbp > 0.5;

  /// Giving someone a credit is an expense; collecting it is income. Borrowing
  /// is income; repaying it is an expense. The explicit accounting roles below
  /// protect the special split-income and expense-on-credit helper records from
  /// being counted twice.
  bool get affectsExpenseStats {
    if (isSettlementEntry) return isDebt;
    if (isCredit && raw['accounting_role'] != 'split_income_receivable') {
      return true;
    }
    return isExpense && raw['affects_expense_stats']?.toLowerCase() != 'false';
  }

  bool get affectsIncomeStats {
    if (isSettlementEntry) return isCredit;
    if (isDebt && raw['accounting_role'] != 'accrued_expense_payable') {
      return true;
    }
    return isIncome && raw['affects_income_stats']?.toLowerCase() != 'false';
  }

  bool get affectsReceivables =>
      isCredit &&
      !isSettled &&
      raw['affects_receivables']?.toLowerCase() != 'false';

  bool get affectsPayables =>
      isDebt && !isSettled && raw['affects_payables']?.toLowerCase() != 'false';

  int get walletDirection {
    final rawDirection =
        raw['wallet_direction'] ??
        raw['walletDirection'] ??
        raw['walletImpact'];
    final parsed = int.tryParse((rawDirection ?? '').trim());
    if (parsed != null) {
      return parsed.clamp(-1, 1);
    }
    return switch (type) {
      TransactionType.income => 1,
      TransactionType.expense => -1,
      TransactionType.reserveable => -1,
      TransactionType.debt => 1,
      TransactionType.transfer => 0,
      TransactionType.unknown => 0,
    };
  }

  bool get affectsWallet => walletDirection != 0 || isTransfer;

  double get amountUsd {
    final rawAmount = _rawAmount(const [
      'amount_usd',
      'amountUsd',
      'Amount (\$)',
      'Amount USD',
    ]);
    if (rawAmount > 0) {
      return rawAmount;
    }
    return currency == CurrencyCode.usd ? amount : 0;
  }

  double get amountLbp {
    final rawAmount = _rawAmount(const [
      'amount_lbp',
      'amountLbp',
      'Amount (LBP)',
      'Amount LBP',
    ]);
    if (rawAmount > 0) {
      return rawAmount;
    }
    return currency == CurrencyCode.lbp ? amount : 0;
  }

  bool get hasMixedAmounts => amountUsd > 0 && amountLbp > 0;

  double amountInUsd(double exchangeRate) {
    return amountUsd + amountLbp / exchangeRate;
  }

  double _rawAmount(List<String> keys) {
    for (final key in keys) {
      final value = raw[key]?.trim() ?? '';
      if (value.isEmpty) {
        continue;
      }
      final parsed = double.tryParse(
        value
            .replaceAll(',', '')
            .replaceAll(r'$', '')
            .replaceAll(RegExp('lbp|usd', caseSensitive: false), '')
            .trim(),
      );
      if (parsed != null && parsed > 0) {
        return parsed;
      }
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
        return 'Credit';
      case TransactionType.debt:
        return 'Debt';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.unknown:
        return 'Unknown';
    }
  }
}

extension AccountingSettlementStatusLabel on AccountingSettlementStatus {
  String get label {
    switch (this) {
      case AccountingSettlementStatus.open:
        return 'open';
      case AccountingSettlementStatus.partial:
        return 'partial';
      case AccountingSettlementStatus.settled:
        return 'settled';
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
