import '../models/transaction.dart';

class TransactionIdentity {
  const TransactionIdentity._();

  static String fullId(FinancialTransaction transaction) {
    final direct = transaction.id?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    for (final key in const ['Transaction ID', 'transaction_id', 'id']) {
      final value = transaction.raw[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String shortId(FinancialTransaction transaction) {
    final id = fullId(transaction);
    if (id.isEmpty) {
      return 'No ID';
    }
    if (id.length <= 10) {
      return id;
    }
    return '${id.substring(0, 5)}...${id.substring(id.length - 4)}';
  }

  static String searchableText(FinancialTransaction transaction) {
    return [
      fullId(transaction),
      shortId(transaction),
      transaction.category,
      transaction.description,
      transaction.paymentMethod,
      transaction.notes,
      transaction.type.label,
      transaction.currency.label,
      transaction.source.label,
      ...transaction.raw.values,
    ].join(' ').toLowerCase();
  }
}
