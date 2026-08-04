import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/google_sheet_service.dart';
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

  test(
    'category name, types, selected color, and icon survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = DashboardController(service: _EmptySheetService());
      await first.initialize();
      await first.saveCategoryRules([
        const CategoryRule(
          name: 'Repairs',
          statuses: {TransactionType.income, TransactionType.expense},
          colorValue: 0xFFDB2777,
          icon: '🛠️',
        ),
      ]);
      first.dispose();

      final second = DashboardController(service: _EmptySheetService());
      addTearDown(second.dispose);
      await second.initialize();

      final restored = second.categoryRules.single;
      expect(restored.name, 'Repairs');
      expect(
        restored.statuses,
        containsAll([TransactionType.income, TransactionType.expense]),
      );
      expect(restored.effectiveColorValue, 0xFFDB2777);
      expect(restored.icon, '🛠️');
      expect(second.categoryIconFor('Repairs'), '🛠️');
    },
  );

  test('new categories always expose a usable default icon', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DashboardController();
    addTearDown(controller.dispose);

    await controller.registerCategoryForTransaction(
      FinancialTransaction(
        source: TransactionSource.application,
        date: DateTime(2026, 8, 4),
        hasDate: true,
        type: TransactionType.expense,
        category: 'Brand new category',
        description: 'Test',
        currency: CurrencyCode.usd,
        amount: 1,
        paymentMethod: 'My Wallet',
        notes: '',
        raw: const {},
      ),
    );

    expect(controller.categoryIconFor('Brand new category'), '🏷️');
  });
}

class _EmptySheetService extends GoogleSheetService {
  @override
  Future<List<FinancialTransaction>> fetchTransactions(String sheetUrl) async =>
      const [];
}
