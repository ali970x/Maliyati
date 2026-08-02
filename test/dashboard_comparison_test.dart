import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/dashboard_comparison.dart';
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

  test('dashboard comparison supports a selected previous month', () async {
    final controller = DashboardController(
      service: _ComparisonSheetService(const []),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    controller.selectMonth(DateTime(2026, 7));

    await controller.saveDashboardComparison(
      const DashboardComparisonSettings(
        preset: DashboardComparisonPreset.previousMonth,
      ),
    );

    expect(controller.dashboardComparisonLabel, 'Previous month');
    expect(controller.previousWindow!.contains(DateTime(2026, 6, 1)), isTrue);
    expect(controller.previousWindow!.contains(DateTime(2026, 6, 30)), isTrue);
    expect(controller.previousWindow!.contains(DateTime(2026, 7, 1)), isFalse);
  });

  test('custom dashboard comparison includes both selected dates', () async {
    final controller = DashboardController(
      service: _ComparisonSheetService(const []),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.saveDashboardComparison(
      DashboardComparisonSettings(
        preset: DashboardComparisonPreset.custom,
        customStart: DateTime(2026, 5, 10),
        customEnd: DateTime(2026, 5, 12),
      ),
    );

    expect(controller.previousWindow!.contains(DateTime(2026, 5, 9)), isFalse);
    expect(controller.previousWindow!.contains(DateTime(2026, 5, 10)), isTrue);
    expect(controller.previousWindow!.contains(DateTime(2026, 5, 12)), isTrue);
    expect(controller.previousWindow!.contains(DateTime(2026, 5, 13)), isFalse);
  });

  testWidgets('dashboard comparison can be changed from the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('Compare all sections'), findsNothing);
    await tester.tap(
      find.byTooltip('Compare all sections: Previous selected period'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compare all sections with'), findsOneWidget);
    await tester.tap(find.text('Yesterday').last);
    await tester.pumpAndSettle();

    expect(
      controller.dashboardComparison.preset,
      DashboardComparisonPreset.yesterday,
    );
    expect(find.byTooltip('Compare all sections: Yesterday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard comparison selection is shared with category cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController(
      service: _ComparisonSheetService([
        _expense(DateTime(2026, 7, 10), 100),
        _expense(DateTime(2026, 6, 10), 50),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    controller.selectMonth(DateTime(2026, 7));
    await controller.saveDashboardComparison(
      const DashboardComparisonSettings(
        preset: DashboardComparisonPreset.previousMonth,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('Compare all sections'), findsNothing);
    expect(
      find.byTooltip('Compare all sections: Previous month'),
      findsOneWidget,
    );
    expect(find.text('+100.0%'), findsWidgets);
    await tester.tap(find.text('Expenses').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Choose comparison period'), findsOneWidget);
    expect(find.text('Comparison period'), findsNothing);
    expect(find.text('Transportation & Delivery'), findsOneWidget);
    expect(find.textContaining('Previous month:'), findsNothing);
    expect(find.text('+100.0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose comparison period'));
    await tester.pumpAndSettle();
    expect(find.text('Compare all sections with'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('income and expense category views hide zero-percent rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController(
      service: _ComparisonSheetService([
        _expense(DateTime(2026, 7, 10), 100),
        _expense(DateTime(2026, 7, 11), .1, category: 'Rounds to zero'),
        _expense(DateTime(2026, 6, 10), 50, category: 'Previous period only'),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    controller.selectMonth(DateTime(2026, 7));
    await controller.saveDashboardComparison(
      const DashboardComparisonSettings(
        preset: DashboardComparisonPreset.previousMonth,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Expenses').first);
    await tester.pumpAndSettle();

    expect(find.text('Transportation & Delivery'), findsOneWidget);
    expect(find.text('Rounds to zero'), findsNothing);
    expect(find.text('Previous period only'), findsNothing);
    expect(find.text('0% of Expenses'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ComparisonSheetService extends GoogleSheetService {
  _ComparisonSheetService(this.rows);

  final List<FinancialTransaction> rows;

  @override
  Future<List<FinancialTransaction>> fetchTransactions(String sheetUrl) async {
    return rows;
  }
}

FinancialTransaction _expense(
  DateTime date,
  double amount, {
  String category = 'Transportation',
}) {
  return FinancialTransaction(
    date: date,
    hasDate: true,
    type: TransactionType.expense,
    category: category,
    description: 'Taxi',
    currency: CurrencyCode.usd,
    amount: amount,
    paymentMethod: 'My Wallet',
    notes: '',
    raw: const {},
  );
}
