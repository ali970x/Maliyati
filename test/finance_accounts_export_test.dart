import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/finance_account.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/data_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finance account settings survive serialization', () {
    const account = FinanceAccount(
      id: 'bank_1',
      name: 'Business bank',
      kind: FinanceAccountKind.bank,
      scope: FinanceAccountScope.shared,
      colorValue: 0xFF1478C9,
      openingUsd: 250,
      joinCode: 'ABC12345',
    );

    final restored = FinanceAccount.fromJson(account.toJson());
    expect(restored.name, account.name);
    expect(restored.scope, FinanceAccountScope.shared);
    expect(restored.openingUsd, 250);
    expect(restored.joinCode, 'ABC12345');
  });

  test('CSV export contains transaction details and account', () async {
    final transaction = FinancialTransaction(
      date: DateTime(2026, 8, 4),
      hasDate: true,
      type: TransactionType.expense,
      category: 'Supplies',
      description: 'Printer paper',
      currency: CurrencyCode.usd,
      amount: 12.5,
      paymentMethod: 'Business bank',
      notes: 'Office',
      raw: const {},
    );

    final file = await DataExportService().build(DataExportFormat.csv, [
      transaction,
    ]);
    final text = utf8.decode(file.bytes);

    expect(file.name, endsWith('.csv'));
    expect(text, contains('Printer paper'));
    expect(text, contains('Business bank'));
    expect(text, contains('12.50'));

    for (final format in [DataExportFormat.pdf, DataExportFormat.excel]) {
      final generated = await DataExportService().build(format, [transaction]);
      expect(generated.bytes, isNotEmpty);
    }
  });
}
