import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/dashboard_pin.dart';
import 'package:finance_tracker/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dashboard pin preserves its metric category mode and comparison', () {
    const pin = DashboardPinnedItem(
      metric: DashboardPinMetric.expense,
      category: 'Transportation',
      mode: 'all',
      comparison: DashboardPinComparison.month,
    );

    final restored = DashboardPinnedItem.fromJson(pin.toJson());

    expect(restored.identity, pin.identity);
    expect(restored.category, 'Transportation');
    expect(restored.comparison, DashboardPinComparison.month);
  });

  test('dashboard accepts only three unique pinned items', () async {
    final controller = DashboardController();
    addTearDown(controller.dispose);

    for (final metric in DashboardPinMetric.values.take(3)) {
      await controller.addOrUpdateDashboardPin(
        DashboardPinnedItem(
          metric: metric,
          comparison: DashboardPinComparison.week,
        ),
      );
    }

    expect(controller.dashboardPins, hasLength(3));
    await expectLater(
      controller.addOrUpdateDashboardPin(
        const DashboardPinnedItem(
          metric: DashboardPinMetric.payable,
          comparison: DashboardPinComparison.month,
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  testWidgets('light dashboard displays a pinned category comparison', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DashboardController();
    addTearDown(controller.dispose);
    await controller.saveDashboardPins(const [
      DashboardPinnedItem(
        metric: DashboardPinMetric.expense,
        category: 'Transportation',
        comparison: DashboardPinComparison.month,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('Pinned comparisons'), findsNothing);
    expect(find.text('Transportation'), findsOneWidget);
    expect(find.textContaining('Previous month'), findsOneWidget);
    expect(find.byTooltip('Pinned on dashboard'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Income allocation')).dy,
      lessThan(tester.getTopLeft(find.text('Transportation')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard hides pinned comparisons when none are configured', (
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

    expect(find.text('Pinned comparisons'), findsNothing);
    expect(
      find.textContaining('Open a financial section or category'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a financial section can be pinned from its focus page', (
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

    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show on dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Compare with'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Show on dashboard'));
    await tester.pumpAndSettle();

    expect(controller.dashboardPins, hasLength(1));
    expect(controller.dashboardPins.single.metric, DashboardPinMetric.income);
    expect(find.byTooltip('Pinned on dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
