import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/screens/dashboard_screen.dart';
import 'package:finance_tracker/services/google_sheet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('wallet cards open this week and sort newest first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final controller = DashboardController(
      service: _DefaultViewSheetService([
        _transaction(
          id: 'old',
          date: today,
          createdAt: today.add(const Duration(hours: 8)),
          type: TransactionType.income,
          title: 'Older wallet transaction',
          wallet: 'My Wallet',
        ),
        _transaction(
          id: 'new',
          date: today,
          createdAt: today.add(const Duration(hours: 12)),
          type: TransactionType.income,
          title: 'Newest wallet transaction',
          wallet: 'My Wallet',
        ),
        _transaction(
          id: 'outside',
          date: today.subtract(const Duration(days: 8)),
          type: TransactionType.income,
          title: 'Outside this week',
          wallet: 'My Wallet',
        ),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('My Wallet').first);
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Newest wallet transaction'), findsOneWidget);
    expect(find.text('Older wallet transaction'), findsOneWidget);
    expect(find.text('Outside this week'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Newest wallet transaction')).dy,
      lessThan(tester.getTopLeft(find.text('Older wallet transaction')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('receivables and payables open with all-time records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController(
      service: _DefaultViewSheetService([
        _transaction(
          id: 'credit-old',
          date: DateTime(2020, 1, 10),
          type: TransactionType.reserveable,
          title: 'Old receivable remains visible',
          wallet: 'Service',
        ),
        _transaction(
          id: 'debt-old',
          date: DateTime(2020, 2, 10),
          type: TransactionType.debt,
          title: 'Old payable remains visible',
          wallet: 'Service',
        ),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Receivables').first);
    await tester.pumpAndSettle();
    expect(find.text('Old receivable remains visible'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payables').first);
    await tester.pumpAndSettle();
    expect(find.text('Old payable remains visible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DefaultViewSheetService extends GoogleSheetService {
  _DefaultViewSheetService(this.rows);

  final List<FinancialTransaction> rows;

  @override
  Future<List<FinancialTransaction>> fetchTransactions(String sheetUrl) async {
    return rows;
  }
}

FinancialTransaction _transaction({
  required String id,
  required DateTime date,
  required TransactionType type,
  required String title,
  required String wallet,
  DateTime? createdAt,
}) {
  return FinancialTransaction(
    id: id,
    createdAt: createdAt,
    date: date,
    hasDate: true,
    type: type,
    category: type == TransactionType.debt
        ? 'Supplier Payables'
        : type == TransactionType.reserveable
        ? 'Customer Receivables'
        : 'Income',
    description: title,
    currency: CurrencyCode.usd,
    amount: 10,
    paymentMethod: wallet,
    notes: '',
    raw: {'wallet_id': wallet},
  );
}
