import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/screens/budget_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('budget builder opens its interactive customization page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DashboardController();

    await tester.pumpWidget(
      MaterialApp(home: BudgetPlanScreen(controller: controller)),
    );

    expect(find.text('Budget Builder'), findsOneWidget);
    expect(find.text('Required target'), findsOneWidget);
    expect(find.text('Funded'), findsOneWidget);
    expect(find.text('Still required'), findsOneWidget);
    expect(
      find.text('No investment funding recorded in this period.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Customize plan'));
    await tester.pumpAndSettle();

    expect(find.text('Customize budget'), findsOneWidget);
    expect(find.text('Your plan is balanced at 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planning income can switch to a manual amount', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DashboardController();

    await tester.pumpWidget(
      MaterialApp(home: BudgetIncomeSourceScreen(controller: controller)),
    );

    await tester.tap(find.text('Manual amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.text('Save planning income'));
    await tester.pumpAndSettle();

    expect(controller.budgetPlanSettings.incomeTargetOverrideUsd, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press opens settings for the selected budget group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DashboardController();

    await tester.pumpWidget(
      MaterialApp(home: BudgetPlanScreen(controller: controller)),
    );
    await tester.longPress(find.text('Investment').first);
    await tester.pumpAndSettle();

    expect(find.text('Manage Investment'), findsOneWidget);
    expect(find.text('Group name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
