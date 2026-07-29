import '../models/transaction.dart';
import 'category_taxonomy.dart';
import 'label_normalizer.dart';

class AccountingRules {
  const AccountingRules._();

  static const paidNow = 'Paid Now';
  static const onCredit = 'On Credit';

  static FinancialTransaction normalize(FinancialTransaction transaction) {
    final raw = Map<String, String>.from(transaction.raw);
    final normalizedCategory = LabelNormalizer.category(transaction.category);
    final preserveCategory =
        raw['custom_category']?.trim().toLowerCase() == 'true';
    final category = preserveCategory && normalizedCategory.isNotEmpty
        ? normalizedCategory
        : CategoryTaxonomy.forTransaction(
            transaction.copyWith(category: normalizedCategory),
          );
    final paymentMethod = LabelNormalizer.wallet(transaction.paymentMethod);
    final walletId = LabelNormalizer.wallet(transaction.walletId);
    final destinationWalletId = LabelNormalizer.wallet(
      transaction.destinationWalletId ?? '',
    );
    final amountUsd = transaction.amountUsd;
    final amountLbp = transaction.amountLbp;
    final isServiceSource = LabelNormalizer.isService(walletId);
    raw['category'] = category;
    raw['Category'] = category;
    raw['amount_usd'] = amountUsd.toString();
    raw['amount_lbp'] = amountLbp.toString();
    raw['Amount (\$)'] = amountUsd.toString();
    raw['Amount (LBP)'] = amountLbp.toString();
    raw['payment_method'] = paymentMethod;
    raw['Payment Method'] = paymentMethod;
    raw['wallet_id'] = walletId;
    raw['walletId'] = walletId;
    if (destinationWalletId.isNotEmpty) {
      raw['destination_wallet_id'] = destinationWalletId;
      raw['destinationWalletId'] = destinationWalletId;
    }
    raw.putIfAbsent('settlement_status', () {
      if (transaction.isCredit || transaction.isDebt) {
        return AccountingSettlementStatus.open.label;
      }
      return '';
    });
    if (transaction.isCredit || transaction.isDebt) {
      raw.putIfAbsent('settled_amount_usd', () => '0');
      raw.putIfAbsent('settled_amount_lbp', () => '0');
    }
    raw.putIfAbsent(
      'wallet_direction',
      () => transaction.walletDirection.toString(),
    );
    raw.putIfAbsent(
      'affects_expense_stats',
      () => transaction.isExpense || (transaction.isCredit && !isServiceSource)
          ? 'true'
          : 'false',
    );
    raw.putIfAbsent(
      'affects_income_stats',
      () => transaction.isIncome || (transaction.isDebt && !isServiceSource)
          ? 'true'
          : 'false',
    );
    raw.putIfAbsent(
      'affects_receivables',
      () => transaction.isCredit ? 'true' : 'false',
    );
    raw.putIfAbsent(
      'affects_payables',
      () => transaction.isDebt ? 'true' : 'false',
    );
    return transaction.copyWith(
      category: category,
      description: LabelNormalizer.text(transaction.description),
      paymentMethod: paymentMethod,
      notes: LabelNormalizer.text(transaction.notes),
      raw: raw,
    );
  }

  static List<FinancialTransaction> expandExpensePayment(
    FinancialTransaction expense, {
    required bool paidNow,
  }) {
    final normalizedExpense = normalize(
      expense.copyWith(
        type: TransactionType.expense,
        raw: {
          ...expense.raw,
          'payment_timing': paidNow ? AccountingRules.paidNow : onCredit,
          'wallet_direction': paidNow ? '-1' : '0',
          'affects_expense_stats': 'true',
        },
      ),
    );
    if (paidNow) {
      return [normalizedExpense];
    }
    final debt = normalize(
      normalizedExpense.copyWith(
        id: null,
        type: TransactionType.debt,
        category: 'Payables',
        description: 'Payable: ${normalizedExpense.description}',
        raw: {
          ...normalizedExpense.raw,
          'status': TransactionType.debt.label,
          'Status': TransactionType.debt.label,
          'category': 'Payables',
          'Category': 'Payables',
          'payment_timing': onCredit,
          'wallet_direction': '0',
          'affects_expense_stats': 'false',
          'affects_payables': 'true',
          'settlement_status': AccountingSettlementStatus.open.label,
          'accounting_role': 'accrued_expense_payable',
        },
      ),
    );
    return [normalizedExpense, debt];
  }

  static List<FinancialTransaction> splitIncome(
    FinancialTransaction baseIncome, {
    required double receivedAmount,
    required double owedAmount,
  }) {
    final received = normalize(
      baseIncome.copyWith(
        type: TransactionType.income,
        amount: receivedAmount,
        raw: {
          ...baseIncome.raw,
          'status': TransactionType.income.label,
          'Status': TransactionType.income.label,
          'amount': receivedAmount.toString(),
          'wallet_direction': '1',
          'affects_income_stats': 'true',
        },
      ),
    );
    if (owedAmount <= 0) {
      return [received];
    }
    final credit = normalize(
      baseIncome.copyWith(
        id: null,
        type: TransactionType.reserveable,
        amount: owedAmount,
        category: 'Salary receivable',
        description: 'Receivable: ${baseIncome.description}',
        raw: {
          ...baseIncome.raw,
          'status': TransactionType.reserveable.label,
          'Status': TransactionType.reserveable.label,
          'category': 'Salary receivable',
          'Category': 'Salary receivable',
          'amount': owedAmount.toString(),
          'wallet_direction': '0',
          'affects_income_stats': 'false',
          'affects_receivables': 'true',
          'settlement_status': AccountingSettlementStatus.open.label,
          'accounting_role': 'split_income_receivable',
        },
      ),
    );
    return [received, credit];
  }

  static FinancialTransaction applySettlement(
    FinancialTransaction transaction, {
    required double amountUsd,
    required double amountLbp,
  }) {
    final settledUsd = transaction.settledAmountUsd + amountUsd;
    final settledLbp = transaction.settledAmountLbp + amountLbp;
    final isComplete =
        transaction.amountUsd - settledUsd <= 0.0001 &&
        transaction.amountLbp - settledLbp <= 0.5;
    final raw = Map<String, String>.from(transaction.raw)
      ..['settled_amount_usd'] = settledUsd.toString()
      ..['settled_amount_lbp'] = settledLbp.toString()
      ..['settlement_status'] = isComplete
          ? AccountingSettlementStatus.settled.label
          : AccountingSettlementStatus.partial.label;
    return transaction.copyWith(raw: raw);
  }

  static FinancialTransaction removeSettlement(
    FinancialTransaction transaction, {
    required double amountUsd,
    required double amountLbp,
  }) {
    final settledUsd = (transaction.settledAmountUsd - amountUsd)
        .clamp(0, double.infinity)
        .toDouble();
    final settledLbp = (transaction.settledAmountLbp - amountLbp)
        .clamp(0, double.infinity)
        .toDouble();
    final hasPayments = settledUsd > 0.0001 || settledLbp > 0.5;
    final isComplete =
        transaction.amountUsd - settledUsd <= 0.0001 &&
        transaction.amountLbp - settledLbp <= 0.5;
    final raw = Map<String, String>.from(transaction.raw)
      ..['settled_amount_usd'] = settledUsd.toString()
      ..['settled_amount_lbp'] = settledLbp.toString()
      ..['settlement_status'] = isComplete
          ? AccountingSettlementStatus.settled.label
          : hasPayments
          ? AccountingSettlementStatus.partial.label
          : AccountingSettlementStatus.open.label;
    return transaction.copyWith(raw: raw);
  }

  /// Converts one payment value into the USD/LBP portions of the original
  /// balance. The payment itself remains recorded in the currency selected by
  /// the user; this allocation is only used to reduce the outstanding debt.
  static ({double amountUsd, double amountLbp}) settlementAllocation(
    FinancialTransaction transaction, {
    required double paidUsd,
    required double paidLbp,
    required double exchangeRate,
  }) {
    if (exchangeRate <= 0) {
      throw ArgumentError.value(exchangeRate, 'exchangeRate');
    }
    final remainingUsd = transaction.remainingAmountUsd;
    final remainingLbp = transaction.remainingAmountLbp;
    final remainingUsdValue = remainingUsd + remainingLbp / exchangeRate;
    final paidUsdValue = paidUsd + paidLbp / exchangeRate;
    if (paidUsdValue - remainingUsdValue > 0.0001) {
      throw ArgumentError('Payment is greater than the remaining balance.');
    }
    final ratio = remainingUsdValue - paidUsdValue <= 0.0001
        ? 1.0
        : (paidUsdValue / remainingUsdValue).clamp(0.0, 1.0).toDouble();
    return (amountUsd: remainingUsd * ratio, amountLbp: remainingLbp * ratio);
  }

  /// Moves the complete wallet impact of an existing transaction. Wallet
  /// summaries are derived from transactions, so replacing the wallet on this
  /// source record removes its effect from the old wallet and applies it to
  /// the new one without creating a duplicate charge.
  static FinancialTransaction moveWallet(
    FinancialTransaction transaction, {
    required String walletId,
  }) {
    final normalizedWallet = LabelNormalizer.wallet(walletId);
    final walletDirection = LabelNormalizer.isService(normalizedWallet)
        ? 0
        : switch (transaction.type) {
            TransactionType.income || TransactionType.debt => 1,
            TransactionType.expense || TransactionType.reserveable => -1,
            TransactionType.transfer || TransactionType.unknown => 0,
          };
    final raw = Map<String, String>.from(transaction.raw)
      ..['wallet_id'] = normalizedWallet
      ..['walletId'] = normalizedWallet
      ..['payment_method'] = normalizedWallet
      ..['Payment Method'] = normalizedWallet
      ..['wallet_direction'] = walletDirection.toString()
      ..['affects_expense_stats'] =
          transaction.isExpense ||
              (transaction.isCredit &&
                  !LabelNormalizer.isService(normalizedWallet))
          ? 'true'
          : 'false'
      ..['affects_income_stats'] =
          transaction.isIncome ||
              (transaction.isDebt &&
                  !LabelNormalizer.isService(normalizedWallet))
          ? 'true'
          : 'false';
    return normalize(
      transaction.copyWith(paymentMethod: normalizedWallet, raw: raw),
    );
  }

  static FinancialTransaction settlementEntry(
    FinancialTransaction target, {
    required String walletId,
    required DateTime date,
    required double amountUsd,
    required double amountLbp,
    double? allocatedUsd,
    double? allocatedLbp,
    double? exchangeRate,
  }) {
    final isDebtSettlement = target.isDebt;
    final type = isDebtSettlement
        ? TransactionType.debt
        : TransactionType.reserveable;
    return normalize(
      target.copyWith(
        // A collection/payment is a new ledger entry. It must never reuse the
        // Credit/Debt ID it is linked to.
        clearId: true,
        createdAt: DateTime.now(),
        type: type,
        date: DateTime(date.year, date.month, date.day),
        hasDate: true,
        currency: amountUsd > 0 ? CurrencyCode.usd : CurrencyCode.lbp,
        amount: amountUsd > 0 ? amountUsd : amountLbp,
        paymentMethod: walletId,
        description:
            '${isDebtSettlement ? 'Debt payment' : 'Credit collection'}: ${target.description}',
        raw: {
          ...target.raw,
          'status': type.label,
          'Status': type.label,
          'amount_usd': amountUsd.toString(),
          'amount_lbp': amountLbp.toString(),
          'Amount (\$)': amountUsd.toString(),
          'Amount (LBP)': amountLbp.toString(),
          'settlement_amount_usd': amountUsd.toString(),
          'settlement_amount_lbp': amountLbp.toString(),
          'settlement_allocation_usd': (allocatedUsd ?? amountUsd).toString(),
          'settlement_allocation_lbp': (allocatedLbp ?? amountLbp).toString(),
          if (exchangeRate != null)
            'settlement_exchange_rate': exchangeRate.toString(),
          'wallet_id': walletId,
          'payment_method': walletId,
          'Payment Method': walletId,
          'linked_transaction_id': target.id ?? '',
          'settlement_status': AccountingSettlementStatus.settled.label,
          'wallet_direction': isDebtSettlement ? '-1' : '1',
          'affects_expense_stats': isDebtSettlement ? 'true' : 'false',
          'affects_income_stats': isDebtSettlement ? 'false' : 'true',
          'affects_payables': 'false',
          'affects_receivables': 'false',
          'accounting_role': isDebtSettlement
              ? 'debt_settlement'
              : 'credit_collection',
        },
      ),
    );
  }

  static FinancialTransaction transferOut(
    FinancialTransaction base, {
    required String sourceWallet,
    required String destinationWallet,
  }) {
    return normalize(
      base.copyWith(
        type: TransactionType.transfer,
        paymentMethod: sourceWallet,
        raw: {
          ...base.raw,
          'status': TransactionType.transfer.label,
          'Status': TransactionType.transfer.label,
          'wallet_id': sourceWallet,
          'destination_wallet_id': destinationWallet,
          'wallet_direction': '0',
          'affects_expense_stats': 'false',
          'affects_income_stats': 'false',
          'affects_receivables': 'false',
          'affects_payables': 'false',
        },
      ),
    );
  }
}
