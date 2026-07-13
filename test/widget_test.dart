import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App opens on dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FinanceTrackerApp());
    expect(find.text('Dashboard'), findsWidgets);
  });
}
