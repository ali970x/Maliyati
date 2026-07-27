import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/widgets/finance_formatters.dart';
import 'package:finance_tracker/widgets/period_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    FinanceFormatters.localeCode = 'en';
    await initializeDateFormatting('en');
  });

  testWidgets('month week picker scrolls without bottom overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PeriodFilterBar(controller: controller)),
      ),
    );

    await tester.longPress(find.text('This week'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
