import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/screens/transaction_detail_screen.dart';
import 'package:finance_tracker/widgets/finance_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    FinanceFormatters.localeCode = 'en';
    await initializeDateFormatting('en');
  });

  testWidgets('payable uses the shared settlement workspace', (tester) async {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettlementWorkspaceScreen(
          controller: controller,
          transaction: _account(TransactionType.debt),
        ),
      ),
    );

    expect(find.text('Payable payment'), findsOneWidget);
    expect(find.text('Amount left to pay'), findsOneWidget);
    expect(find.text('Add payment'), findsOneWidget);
    expect(find.text('Payment log'), findsOneWidget);
    expect(find.text('No payment recorded yet'), findsOneWidget);
  });

  testWidgets('receivable uses the same settlement workspace', (tester) async {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettlementWorkspaceScreen(
          controller: controller,
          transaction: _account(TransactionType.reserveable),
        ),
      ),
    );

    expect(find.text('Receivable collection'), findsOneWidget);
    expect(find.text('Amount left to collect'), findsOneWidget);
    expect(find.text('Add collection'), findsOneWidget);
    expect(find.text('Payment log'), findsOneWidget);
    expect(find.text('No collection recorded yet'), findsOneWidget);
  });

  testWidgets('long-press account view is compact and keeps edit available', (
    tester,
  ) async {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SettlementWorkspaceScreen(
          controller: controller,
          transaction: _account(TransactionType.debt),
          showAccountDetails: true,
        ),
      ),
    );

    expect(find.text('Payable details'), findsOneWidget);
    expect(find.text('Supplier invoice'), findsOneWidget);
    expect(find.text('Amount left to pay'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

FinancialTransaction _account(TransactionType type) {
  return FinancialTransaction(
    id: type == TransactionType.debt ? 'payable-1' : 'receivable-1',
    date: DateTime(2026, 7, 26),
    hasDate: true,
    type: type,
    category: type == TransactionType.debt ? 'Payables' : 'Receivables',
    description: type == TransactionType.debt
        ? 'Supplier invoice'
        : 'Customer invoice',
    currency: CurrencyCode.usd,
    amount: 50,
    paymentMethod: 'My Wallet',
    notes: '',
    raw: {
      'amount_usd': '50',
      'amount_lbp': '0',
      'wallet_id': 'My Wallet',
      'settlement_status': 'open',
      'settled_amount_usd': '0',
      'settled_amount_lbp': '0',
    },
  );
}
