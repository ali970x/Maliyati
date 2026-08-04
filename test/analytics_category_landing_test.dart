import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/screens/analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('analytics opens on the visual category view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalyticsScreen(controller: DashboardController()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('All accounts'), findsOneWidget);
    expect(find.text('Expenses'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
