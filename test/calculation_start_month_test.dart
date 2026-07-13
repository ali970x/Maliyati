import 'package:finance_tracker/controllers/dashboard_controller.dart';
import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/google_sheet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('calculation start month excludes older and undated rows', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DashboardController(
      service: _FakeSheetService([
        _transaction(DateTime(2026, 5, 31)),
        _transaction(DateTime(2026, 6, 1)),
        _transaction(DateTime(2026, 7, 12)),
        _transaction(DateTime(2026, 7, 12), hasDate: false),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.updateCalculationStartMonth(DateTime(2026, 6, 17));
    controller.selectTimeFilter(TimeFilter.allTime);

    expect(controller.calculationStartMonth, DateTime(2026, 6));
    expect(controller.transactions, hasLength(4));
    expect(controller.calculationTransactions, hasLength(2));
    expect(controller.periodTransactions, hasLength(2));
  });

  test('clearing calculation start month restores all rows', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DashboardController(
      service: _FakeSheetService([
        _transaction(DateTime(2026, 5, 31)),
        _transaction(DateTime(2026, 6, 1)),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.updateCalculationStartMonth(DateTime(2026, 6));
    expect(controller.calculationTransactions, hasLength(1));

    await controller.updateCalculationStartMonth(null);
    expect(controller.calculationTransactions, hasLength(2));
  });

  test('dark theme preference is restored on the next controller', () async {
    SharedPreferences.setMockInitialValues({});
    final first = DashboardController(service: _FakeSheetService(const []));
    await first.initialize();
    await first.updateThemeMode(ThemeMode.dark);
    first.dispose();

    final second = DashboardController(service: _FakeSheetService(const []));
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.themeMode, ThemeMode.dark);
  });
}

class _FakeSheetService extends GoogleSheetService {
  _FakeSheetService(this.rows);

  final List<FinancialTransaction> rows;

  @override
  Future<List<FinancialTransaction>> fetchTransactions(String sheetUrl) async {
    return rows;
  }
}

FinancialTransaction _transaction(DateTime date, {bool hasDate = true}) {
  return FinancialTransaction(
    date: date,
    hasDate: hasDate,
    type: TransactionType.expense,
    category: 'Test',
    description: 'Test row',
    currency: CurrencyCode.usd,
    amount: 10,
    paymentMethod: 'Cash',
    notes: '',
    raw: const {},
  );
}
