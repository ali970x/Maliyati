# Finance Tracker

A complete Flutter mobile app for tracking income and expenses from a public Google Sheet CSV feed.

## Features

- Material 3 mobile-first dashboard.
- Reads directly from a public Google Sheet without login.
- Automatically converts normal Google Sheet URLs to CSV export URLs.
- Pull to refresh and refresh buttons.
- Loading, error, and empty states.
- Time filters: today, this week, this month, last 30 days, custom range, all time.
- Dashboard totals for USD, LBP, converted USD totals, net balance, expense ratio, top categories, averages, largest transactions, and previous-period comparison.
- Transactions screen with search, type/currency/category filters, and sorting by date or amount.
- Analytics screen with category charts, daily trend, weekly/monthly summaries, and best/worst days.
- Settings screen for Google Sheet URL, exchange rate, refresh, and last update info.

## Google Sheet Columns

The first row should contain these headers:

```text
date,type,category,description,currency,amount,payment method,notes
```

Accepted values:

- `type`: `income` or `expense`
- `currency`: `usd` or `lbp`
- `amount`: values can include commas, `$`, `USD`, or `LBP`
- `date`: common formats such as `2026-07-07`, `7/7/2026`, `07/07/2026`, `Jul 7, 2026`

## Default Configuration

Configuration lives in:

```text
lib/config/app_config.dart
```

Defaults:

- Google Sheet URL: `https://docs.google.com/spreadsheets/d/1CMtELArv48IVjIo_u5wKSPR8Bqe7JfFqMI0qLLG5Zck/edit?usp=sharing`
- Exchange rate: `89000 LBP = 1 USD`

The app also lets you change these from the Settings screen and stores them locally.

## Run in Android Studio

1. Open this folder in Android Studio:

```text
C:\Users\User\Desktop\test
```

2. Run:

```bash
flutter pub get
```

3. Select an Android emulator or connected device.

4. Run `lib/main.dart`.

## Important Files

```text
lib/main.dart
lib/config/app_config.dart
lib/models/transaction.dart
lib/services/google_sheet_service.dart
lib/services/csv_parser.dart
lib/controllers/dashboard_controller.dart
lib/screens/dashboard_screen.dart
lib/screens/transactions_screen.dart
lib/screens/analytics_screen.dart
lib/screens/settings_screen.dart
lib/widgets/
android/app/src/main/AndroidManifest.xml
```
