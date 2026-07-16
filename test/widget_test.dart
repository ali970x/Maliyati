import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App opens on session check, login, or dashboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FinanceTrackerApp());
    await tester.pump();
    expect(
      find.text('Dashboard').evaluate().isNotEmpty ||
          find.text('Login').evaluate().isNotEmpty ||
          find.text('Checking saved session...').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
