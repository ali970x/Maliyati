import '../models/transaction.dart';

class AccountingRules {
  const AccountingRules._();

  static const paidNow = 'Paid Now';
  static const onCredit = 'On Credit';

  static FinancialTransaction normalize(FinancialTransaction transaction) {
    final raw = Map<String, String>.from(transaction.raw);
    raw.putIfAbsent('wallet_id', () => transaction.walletId);
    raw.putIfAbsent('settlement_status', () {
      if (transaction.isCredit || transaction.isDebt) {
        return AccountingSettlementStatus.open.label;
      }
      return '';
    });
    raw.putIfAbsent(
      'wallet_direction',
      () => transaction.walletDirection.toString(),
    );
    raw.putIfAbsent(
      'affects_expense_stats',
      () => transaction.isExpense ? 'true' : 'false',
    );
    raw.putIfAbsent(
      'affects_income_stats',
      () => transaction.isIncome ? 'true' : 'false',
    );
    raw.putIfAbsent(
      'affects_receivables',
      () => transaction.isCredit ? 'true' : 'false',
    );
    raw.putIfAbsent(
      'affects_payables',
      () => transaction.isDebt ? 'true' : 'false',
    );
    return transaction.copyWith(raw: raw);
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

  static FinancialTransaction markSettled(FinancialTransaction transaction) {
    final raw = Map<String, String>.from(transaction.raw)
      ..['settlement_status'] = AccountingSettlementStatus.settled.label;
    return transaction.copyWith(raw: raw);
  }

  static FinancialTransaction settlementEntry(
    FinancialTransaction target, {
    required String walletId,
    required DateTime date,
  }) {
    final isDebtSettlement = target.isDebt;
    final type = isDebtSettlement
        ? TransactionType.debt
        : TransactionType.reserveable;
    return normalize(
      target.copyWith(
        id: null,
        type: type,
        date: DateTime(date.year, date.month, date.day),
        hasDate: true,
        paymentMethod: walletId,
        description:
            '${isDebtSettlement ? 'Debt payment' : 'Credit collection'}: ${target.description}',
        raw: {
          ...target.raw,
          'status': type.label,
          'Status': type.label,
          'wallet_id': walletId,
          'payment_method': walletId,
          'Payment Method': walletId,
          'linked_transaction_id': target.id ?? '',
          'settlement_status': AccountingSettlementStatus.settled.label,
          'wallet_direction': isDebtSettlement ? '-1' : '1',
          'affects_expense_stats': 'false',
          'affects_income_stats': 'false',
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
