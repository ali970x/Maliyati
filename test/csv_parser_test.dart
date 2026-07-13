import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the current Google Sheet column shape', () {
    const csv = r'''
"Date","Expense","Description","Amount (USD)","Amount (LBP)"
"","Expense","Delivery","$57.00","LBP0.00"
"","Income","Gemini & YouTube","$23.50","LBP0.00"
''';

    final transactions = CsvParser().parse(csv);

    expect(transactions, hasLength(2));
    expect(
      transactions.any(
        (transaction) =>
            transaction.type == TransactionType.income &&
            transaction.amount == 23.50,
      ),
      isTrue,
    );
    expect(
      transactions.any(
        (transaction) =>
            transaction.type == TransactionType.expense &&
            transaction.amount == 57,
      ),
      isTrue,
    );
  });

  test('uses title-like columns as the transaction card title', () {
    const csv = r'''
"Date","Expense","Title","Category","Description","Amount (LBP)"
"7/10/2026","Expense","Deodorant Nivea","Personal care","Delivery","LBP 200000"
''';

    final transactions = CsvParser().parse(csv);

    expect(transactions, hasLength(1));
    expect(transactions.single.description, 'Deodorant Nivea');
    expect(transactions.single.category, 'Personal care');
    expect(transactions.single.notes, 'Delivery');
  });

  test('parses the live sheet header shape with status and dollar amount', () {
    const csv = r'''
"Date","Status","Title","Amount ($)","Amount (LBP )","Category","Payment Method","Notes"
"7/1/2026","Expense","Delivery","$57.00","LBP0.00","Masrouf sha5se","Whish money","Delivery njabart"
"7/1/2026","Income","Salary aboudi","$300.00","LBP0.00","Income aboudi","Cash, Whish money","Month_7"
"7/2/2026","Expense","Coffee","$0.00","LBP200,000","Dyefe","Cash",""
''';

    final transactions = CsvParser().parse(csv);

    expect(transactions, hasLength(3));
    expect(
      transactions.any(
        (transaction) =>
            transaction.type == TransactionType.expense &&
            transaction.currency == CurrencyCode.usd &&
            transaction.amount == 57,
      ),
      isTrue,
    );
    expect(
      transactions.any(
        (transaction) =>
            transaction.type == TransactionType.income &&
            transaction.amount == 300,
      ),
      isTrue,
    );
    expect(
      transactions.any(
        (transaction) =>
            transaction.currency == CurrencyCode.lbp &&
            transaction.amount == 200000,
      ),
      isTrue,
    );
  });
}
