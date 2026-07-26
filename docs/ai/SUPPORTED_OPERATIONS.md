# Maliyati Supported AI Operations

This document describes the commands implemented by
`GeminiTransactionParser` and `DashboardController`.

## Accepted input shapes

Maliyati accepts:

1. One action object.
2. A JSON array of action objects.
3. A wrapper containing `actions`, `commands`, `operations`, `transactions`,
   `items`, `rows`, `data`, `entries`, or `result`.
4. An action whose transaction fields are nested under `transaction`, `record`,
   `payload`, or `details`.
5. A JSON code block copied with surrounding explanatory text.

Canonical keys are recommended. Common snake_case, camelCase, spaced keys, and
case variations are normalized by the parser.

## 1. Add

Canonical action: `add_transaction`

Supported aliases include `add`, `create`, `insert`, and `upsert`.

```json
{
  "action": "add_transaction",
  "date": "2026-07-26",
  "status": "Expense",
  "title": "Internet subscription",
  "amount_usd": 12,
  "amount_lbp": 0,
  "category": "Subscriptions",
  "payment_method": "My Wallet",
  "payment_timing": "Paid Now",
  "notes": "",
  "source": "script"
}
```

Implemented statuses:

| Status | Immediate accounting behavior |
|---|---|
| Income | Increases the selected wallet and Income totals |
| Expense | Decreases the selected wallet and increases Expense totals |
| Credit | Tracks a receivable; wallet-funded Credit decreases its source wallet |
| Debt | Tracks a payable; wallet-funded Debt increases its source wallet |
| Transfer | Moves value between wallets without changing net worth |

For Credit or Debt, `payment_method` may be `Service`. Service records do not
change either wallet when created.

## 2. Edit

Canonical action: `edit_transaction`

Supported aliases include `edit`, `update`, and `update_now`.

```json
{
  "action": "edit_transaction",
  "target_id": "account-42",
  "date": "2026-07-26",
  "status": "Expense",
  "title": "Corrected internet subscription",
  "amount_usd": 15,
  "amount_lbp": 0,
  "category": "Subscriptions",
  "payment_method": "Whish Money",
  "payment_timing": "Paid Now",
  "notes": "Corrected amount",
  "source": "script"
}
```

Use `target_id` when possible. Otherwise use `target_title` containing the
exact old title. Include the complete updated transaction, not a patch.

## 3. Delete

Canonical action: `delete_transaction`

Supported aliases include `delete` and `remove`.

```json
{
  "action": "delete_transaction",
  "target_id": "account-42"
}
```

Deleting a parent Credit/Debt cascades to its linked payment records. A linked
settlement entry cannot be deleted as an independent normal transaction.

## 4. Settle Credit or Debt

Canonical action: `settle_transaction`

Supported aliases include `settle`, `paid`, `collect`, `collect_credit`, and
`pay_debt`.

Partial Credit collection in LBP:

```json
{
  "action": "settle_transaction",
  "target_id": "account-70",
  "date": "2026-07-26",
  "amount_usd": 0,
  "amount_lbp": 890000,
  "exchange_rate": 89000,
  "payment_method": "Whish Money"
}
```

Full settlement:

```json
{
  "action": "settle_transaction",
  "target_id": "account-70",
  "date": "2026-07-26",
  "payment_method": "My Wallet"
}
```

When both amount fields are omitted, Maliyati settles the entire remaining
balance. Settlement is atomic in Firestore: the parent balance and linked
payment record are written together.

## Amount formats accepted by the parser

Recommended:

```json
{"amount_usd": 10, "amount_lbp": 0}
```

Also accepted:

```json
{"amount": 10, "currency": "USD"}
```

```json
{"amount": "890,000 LBP"}
```

The AI should still output plain numeric `amount_usd` and `amount_lbp` whenever
possible.

## Arabic commands accepted by the parser

- Add: `إضافة`, `اضافة`
- Edit: `تعديل`
- Delete: `حذف`
- Settle: `تسديد`, `تحصيل`, `دفع`
- Types include common Arabic forms for دخل، مصروف، مستحق، دين، وتحويل.

Canonical English action/status values remain preferred because they are less
ambiguous.

## Common rejection reasons

- Invalid JSON.
- No action objects found.
- Missing or non-positive amount for Add/Edit.
- Unknown status.
- Delete/Settle without an ID or exact target title.
- Target transaction not found.
- Settlement exceeds the remaining balance.
- Insufficient balance in the selected outgoing wallet.
- Attempt to settle a transaction that is not Credit or Debt.
- Attempt to settle an already completed transaction.

