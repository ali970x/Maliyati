import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/widgets/app_menu_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category editor keeps advanced options collapsed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CategorySettingsScreen(controller: DashboardController()),
      ),
    );

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    expect(find.text('Category icon (optional)'), findsNothing);
    expect(find.byTooltip('Change category icon'), findsOneWidget);
    expect(find.byTooltip('Save changes'), findsOneWidget);
    expect(find.text('Transaction types'), findsOneWidget);
    expect(find.text('Budget group'), findsOneWidget);

    await tester.tap(find.text('Transaction types'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
