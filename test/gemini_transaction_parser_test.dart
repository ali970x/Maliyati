import 'dart:convert';

import 'package:finance_tracker/models/transaction.dart';
import 'package:finance_tracker/services/gemini_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = GeminiTransactionParser();

  test('parses an actions wrapper with a nested transaction payload', () {
    const script = '''
{
  "actions": [
    {
      "action": "add_transaction",
      "transaction": {
        "date": "2026-07-26",
        "status": "Expense",
        "title": "Internet subscription",
        "amount": "12 USD",
        "currency": "USD",
        "category": "Subscriptions",
        "payment_method": "My Wallet"
      }
    }
  ]
}
''';

    final actions = parser.parseActions(script);

    expect(actions, hasLength(1));
    expect(actions.single.type, SmartTransactionActionType.add);
    expect(actions.single.transaction?.type, TransactionType.expense);
    expect(actions.single.transaction?.amountUsd, 12);
    expect(actions.single.transaction?.description, 'Internet subscription');
    expect(actions.single.transaction?.walletId, 'My Wallet');
  });

  test('parses fenced JSON and a generic LBP amount', () {
    const script = '''
Here is the confirmed Maliyati action:
```json
{
  "action": "add",
  "date": "2026-07-26",
  "type": "Income",
  "title": "Repair service",
  "amount": "450,000 LBP",
  "currency": "LBP",
  "category": "Services",
  "wallet": "Whish Money"
}
```
''';

    final action = parser.parseActions(script).single;

    expect(action.transaction?.type, TransactionType.income);
    expect(action.transaction?.amountLbp, 450000);
    expect(action.transaction?.walletId, 'Whish Money');
  });

  test('infers LBP from the amount text and accepts an uppercase wrapper', () {
    const script = '''
{
  "Actions": [
    {
      "action": "add",
      "status": "Income",
      "title": "Accessory sale",
      "amount": "1,250,000 LBP",
      "payment_method": "My Wallet"
    }
  ]
}
''';

    final action = parser.parseActions(script).single;

    expect(action.transaction?.amountUsd, 0);
    expect(action.transaction?.amountLbp, 1250000);
  });

  test('parses a partial settlement amount and exchange rate', () {
    const script = '''
{
  "action": "settle_transaction",
  "target_id": "ali-25",
  "date": "2026-07-26",
  "amount": 890000,
  "currency": "LBP",
  "exchange_rate": 89000,
  "payment_method": "Wish Money"
}
''';

    final action = parser.parseActions(script).single;

    expect(action.type, SmartTransactionActionType.settle);
    expect(action.targetId, 'ali-25');
    expect(action.settlementAmountUsd, 0);
    expect(action.settlementAmountLbp, 890000);
    expect(action.settlementExchangeRate, 89000);
    expect(action.settlementWallet, 'Whish Money');
  });

  test('accepts Arabic action and transaction type labels', () {
    const script = '''
{
  "action": "إضافة",
  "date": "2026-07-26",
  "status": "مصروف",
  "title": "مواصلات",
  "amount_usd": 5,
  "category": "مواصلات",
  "payment_method": "محفظتي"
}
''';

    final action = parser.parseActions(script).single;

    expect(action.type, SmartTransactionActionType.add);
    expect(action.transaction?.type, TransactionType.expense);
    expect(action.transaction?.walletId, 'My Wallet');
  });

  test('returns a clear error for malformed JSON', () {
    expect(
      () => parser.parseActions('{"action": "add",}'),
      throwsA(
        isA<GeminiTransactionParseException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
  });

  test('parses a base64 encoded script shared by Android', () {
    const script =
        '{"action":"add","type":"expense","title":"Delivery madi 3","amount_usd":24,"currency":"usd","category":"Transportation & Delivery","payment_method":"Whish Money"}';
    final encoded = 'base64:${base64Encode(utf8.encode(script))}';

    final action = parser.parseActions(encoded).single;

    expect(action.type, SmartTransactionActionType.add);
    expect(action.transaction?.description, 'Delivery madi 3');
    expect(action.transaction?.amountUsd, 24);
  });
}
