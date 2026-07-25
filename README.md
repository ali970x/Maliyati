# Maliyati

Maliyati is a Flutter finance workspace for individuals and small service
businesses. It tracks income, expenses, receivables, payables, wallet movement,
settlements, analytics, and manual backups in one account-scoped ledger.

For a code-audited portfolio narrative, evidence matrix, security review, and
bilingual case study, see
[`docs/portfolio_case_study.md`](docs/portfolio_case_study.md).

## Product capabilities

- Firebase Authentication with isolated data for every account.
- Cloud Firestore as the live source of truth.
- My Wallet and Whish Money balances with transaction history.
- Income, expenses, receivables, payables, partial settlements, and service
  balances.
- USD and LBP support with a configurable exchange rate.
- Dashboard period filters and financial analytics.
- Manual Google Sheet import/export and Google Drive JSON backup.
- English and Arabic interface with light and dark themes.
- Android and responsive web builds.
- Optional Android floating quick input for sending copied text to Smart Input.

Google Sheet is a manual backup/integration channel. Normal application edits
are stored in Firestore and are not sent to a sheet until the user exports.

## Architecture

```text
lib/
  config/       Runtime defaults and release metadata
  controllers/  Account state and finance workflows
  l10n/         English and Arabic application copy
  models/       Ledger and transaction models
  screens/      Dashboard, transactions, analytics, add, and settings
  services/     Firebase, accounting, CSV, backup, and smart-input services
  widgets/      Shared interface components
```

Critical accounting rules are centralized in
`lib/services/accounting_rules.dart`. Firestore persistence is implemented in
`lib/services/firebase_finance_service.dart`.

## Local setup

Requirements:

- Flutter stable compatible with Dart `^3.12.1`
- Android Studio and Android SDK
- A Firebase project configured for Android and Web

From the project root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Open `C:\Users\User\Desktop\test` in Android Studio and run
`lib/main.dart` on a connected device.

## Firebase

The repository is configured for the Firebase project `maliyati-app-2026`.
Authentication providers and Firestore must be enabled in that project.

Deploy the checked-in security rules after reviewing the administrator email:

```bash
firebase deploy --only firestore:rules
```

The web hostname must also be listed in Firebase Authentication under
**Authorized domains** for Google sign-in.

## Runtime configuration

Non-secret defaults live in `lib/config/app_config.dart`.

The Google Sheet export endpoint and secret are optional build-time values:

```bash
flutter run \
  --dart-define=SHEET_EXPORT_ENDPOINT=https://example.com/export \
  --dart-define=SHEET_EXPORT_SECRET=your-secret
```

Do not commit production secrets to source control.

## Release builds

Web:

```bash
flutter build web --release
```

Android uses `android/key.properties` for release signing. That file and the
keystore are ignored by Git. A local file has this shape:

```properties
storePassword=...
keyPassword=...
keyAlias=maliyati
storeFile=../maliyati-upload.jks
```

Build the signed package:

```bash
flutter build appbundle --release
```

For device demonstrations:

```bash
flutter build apk --debug
flutter install
```

## Quality gate

Before a company demo or release:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

Use a separate Firebase test account and test the full cycle: create a
receivable/payable, add partial and full settlements in both currencies, move
wallets, export a backup, restore it, sign out, and confirm account isolation.
