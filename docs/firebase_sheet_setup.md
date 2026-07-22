# Firebase + Google Sheet Export Setup

This app now supports this flow:

```text
Google sign-in -> Firestore transactions -> optional export to Google Sheet
Gemini voice -> JSON paste -> Firestore add -> optional Google Sheet append
```

## Gemini JSON format

Ask Gemini to return only JSON:

```json
{
  "action": "add_transaction",
  "date": "2026-07-14",
  "status": "Expense",
  "title": "10 kg tomatoes",
  "amount_usd": 0,
  "amount_lbp": 450000,
  "category": "Home expenses",
  "payment_method": "Cash",
  "notes": "Gemini voice entry"
}
```

`status` must be one of:

```text
Income
Expense
Debt
Credit
```

The app also accepts a JSON array when Gemini returns more than one transaction.

## Flutter dart-defines

Run/build the app with Firebase settings:

```bash
flutter run ^
  --dart-define=FIREBASE_API_KEY=... ^
  --dart-define=FIREBASE_APP_ID=... ^
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... ^
  --dart-define=FIREBASE_PROJECT_ID=... ^
  --dart-define=FIREBASE_AUTH_DOMAIN=... ^
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Add these only after the Google Apps Script web app is deployed:

```bash
  --dart-define=SHEET_EXPORT_ENDPOINT=https://script.google.com/macros/s/.../exec ^
  --dart-define=SHEET_EXPORT_SECRET=choose-a-private-secret
```

## Firestore shape

Transactions are stored here:

```text
users/{uid}/transactions/{transactionId}
```

Suggested Firestore rules:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /user_ids/{accountId} {
      allow read: if true;
      allow create: if request.auth != null
        && request.resource.data.uid == request.auth.uid;
      allow update, delete: if false;
    }
  }
}
```

## Google Apps Script export

Use the existing V4 Google Sheet tab. Do not run a setup/formatting script on this
sheet, because it uses Google Sheets typed table columns.

The visible tab should have this header row:

```text
Date,Status,Title,Amount ($),Amount (LBP),Category,Payment Method,Notes
```

Open `Extensions > Apps Script`, paste the append-only script from:

```text
docs/apps_script_append_only_v4.js
```

Then deploy as a Web App.

```javascript
See `docs/apps_script_append_only_v4.js`.
```

Deploy settings:

```text
Execute as: Me
Who has access: Anyone with the link
```

The sheet can stay private because the script writes as your Google account.
The secret prevents random writes if the script URL is accidentally shared.
