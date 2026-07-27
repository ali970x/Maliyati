import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a new script category is saved with its transaction type', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DashboardController();
    addTearDown(controller.dispose);

    await controller.registerCategoryForTransaction(
      FinancialTransaction(
        source: TransactionSource.script,
        date: DateTime(2026, 7, 27),
        hasDate: true,
        type: TransactionType.income,
        category: 'Phone repairs',
        description: 'Repair income',
        currency: CurrencyCode.usd,
        amount: 20,
        paymentMethod: 'My Wallet',
        notes: '',
        raw: const {},
      ),
    );

    expect(
      controller.categoryOptionsFor(TransactionType.income),
      contains('Phone repairs'),
    );
    expect(
      controller.categoryRules
          .singleWhere((rule) => rule.name == 'Phone repairs')
          .statuses,
      contains(TransactionType.income),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('category_rules_v1_guest'),
      contains('Phone repairs'),
    );
  });

  test('an existing category can be shared by more than one type', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DashboardController();
    addTearDown(controller.dispose);

    for (final type in [TransactionType.income, TransactionType.expense]) {
      await controller.registerCategoryForTransaction(
        FinancialTransaction(
          source: TransactionSource.script,
          date: DateTime(2026, 7, 27),
          hasDate: true,
          type: type,
          category: 'Services',
          description: 'Service',
          currency: CurrencyCode.usd,
          amount: 10,
          paymentMethod: 'My Wallet',
          notes: '',
          raw: const {},
        ),
      );
    }

    final rule = controller.categoryRules.singleWhere(
      (item) => item.name == 'Services',
    );
    expect(
      rule.statuses,
      containsAll([TransactionType.income, TransactionType.expense]),
    );
  });
}
