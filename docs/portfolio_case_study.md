# Maliyati Portfolio Audit and Case Study

Audit date: 2026-07-25  
Audited commit: `32bb26a`  
Version: `1.5.0+22`

## Evidence labels

- **[Confirmed in code]**: directly supported by source code, configuration, tests, or a verified build.
- **[Needs owner confirmation]**: plausible, but the repository contains no telemetry, customer evidence, or business validation.
- **[Not present]**: no implementation or evidence was found in the audited repository.

## Portfolio summary

| Item | Portfolio-ready answer | Evidence status |
|---|---|---|
| Project name | **Maliyati** | **[Confirmed in code]** `lib/config/app_config.dart`, `pubspec.yaml` |
| One-line description | A bilingual Flutter financial workspace that unifies income, expenses, receivables, payables, multi-wallet balances, settlements, analytics, and manual backups for USD/LBP operations. | **[Confirmed in code]** |
| Problem solved | It replaces fragmented notes and spreadsheets with an account-scoped ledger where cash flow, debts, collections, wallets, and backups follow explicit accounting rules. | **[Confirmed in code]** as product behavior; the prevalence of this customer pain is **[Needs owner confirmation]** |
| Intended user | Individuals and small service businesses that operate in USD and LBP and need to track money owed to them or by them. | **[Confirmed in repository description]**; validated customer segment is **[Needs owner confirmation]** |
| Current state | **Functional release candidate / pilot** with live web deployment and Android artifacts. It should not yet be described as a finished production SaaS. | **[Confirmed in code and builds]** |
| Actual usage | The app has been installed and exercised on an Android phone during development. Number of active users, retention, and real business usage are unknown. | Device use **[Confirmed during development]**; business usage **[Needs owner confirmation]** |

## Most important implemented features

1. **Account-isolated cloud ledger** for Income, Expense, Credit/receivables, Debt/payables, and wallet transfers. **[Confirmed in code]**
2. **My Wallet and Whish Money tracking** in USD and LBP, with configurable exchange rate, wallet history, opening balances, resets, and balance comparisons. **[Confirmed in code]**
3. **Partial and full Credit/Debt settlements** with mixed-currency allocation and an immutable linked payment log. **[Confirmed in code]**
4. **Atomic Firestore settlement writes** that update the parent balance and create the payment entry in one database transaction. **[Confirmed in code]**
5. **Dashboard and analytics** with date windows, current-versus-previous comparison, category/payment-method rankings, daily trends, best/worst days, and weekly/monthly summaries. **[Confirmed in code]**
6. **Searchable transaction workspace** with type, currency, category, date, amount sorting, archive, edit, and delete flows. **[Confirmed in code]**
7. **Firebase Authentication** with email/password, password reset, account creation, Google sign-in, and session restoration. **[Confirmed in code]**
8. **Manual Google Sheet import/export** using a real CSV parser and a web-side allowlisted proxy; Firestore remains the live source of truth. **[Confirmed in code]**
9. **Google Drive and local JSON backup/restore** using the limited `drive.file` OAuth scope. **[Confirmed in code]**
10. **Smart Input actions** that parse structured AI-generated scripts for add, edit, delete, and settle operations. **[Confirmed in code]**
11. **Android floating quick-input button** implemented as a native foreground overlay service with drag, edge snap, and remove target. **[Confirmed in code]**
12. **Whish receipt OCR review** using Google ML Kit text recognition before saving a transaction. **[Confirmed in code]**
13. **Biometric/PIN application lock**, spending alerts, light/dark appearance, and partial Arabic localization. **[Confirmed in code]**

## Technology stack

| Layer | Actual technology | Evidence status |
|---|---|---|
| Frontend | Flutter, Dart, Material 3, `ChangeNotifier`/`AnimatedBuilder`, `fl_chart`, `intl` | **[Confirmed in code]** |
| Android native | Kotlin, `MethodChannel`, foreground service, `SYSTEM_ALERT_WINDOW` overlay | **[Confirmed in code]** |
| Authentication | Firebase Authentication and Google Sign-In | **[Confirmed in code]** |
| Database | Cloud Firestore under `users/{uid}/transactions` and account settings subcollections | **[Confirmed in code]** |
| Backend | Firebase services plus a small Node.js 20 HTTP host/proxy. There is no separate custom financial REST API. | **[Confirmed in code]** |
| Integrations | Google Sheets CSV/Apps Script, Google Drive API, Google ML Kit OCR, Android clipboard/share intents | **[Confirmed in code]** |
| Local storage | SharedPreferences for preferences/local backups and Flutter Secure Storage for the PIN hash | **[Confirmed in code]** |
| Hosting | Render web service, free plan, automatic deploy on commit | **[Confirmed in `render.yaml`]** |
| Testing | Flutter unit/widget tests covering dates, CSV parsing, currency conversion, summaries, wallets, and settlements | **[Confirmed in code]** |

## Architecture and data flow

```text
Flutter Screens and Widgets
        |
        v
DashboardController (ChangeNotifier, in-memory account state)
        |
        +--> AccountingRules + FinancialTransaction domain model
        |
        +--> FirebaseFinanceService --> Firebase Auth / Cloud Firestore
        +--> GoogleSheetService ------> CSV or Render allowlisted proxy
        +--> SheetExportService ------> Google Apps Script
        +--> GoogleDriveBackupService -> Google Drive API
        +--> Native MethodChannel -----> Android floating overlay service
```

After authentication, the controller fetches the signed-in user's Firestore ledger, normalizes it through centralized accounting rules, calculates summaries in memory, and notifies the UI. Writes pass through the controller and service layer; important settlement writes use a Firestore transaction, then update local state immediately. Preferences are local/account-scoped where appropriate. The implementation uses explicit refreshes and local state updates rather than a continuous Firestore snapshot subscription. **[Confirmed in code]**

## Three strongest technical challenges

1. **Mixed-currency debt settlement:** a payment can be entered in USD or LBP against a balance stored in another currency. `AccountingRules.settlementAllocation` converts using the configured rate, rejects overpayment, records both paid and allocated values, and preserves the exchange rate. **[Confirmed in code]**
2. **Settlement consistency under concurrency:** updating the outstanding balance and creating a payment separately could produce lost or duplicated state. `FirebaseFinanceService.settleTransaction` performs both writes in one Firestore transaction against the latest canonical parent. **[Confirmed in code]**
3. **Cross-platform integrations:** Web Google authentication, Google Sheet CORS, and Android overlay restrictions require different platform implementations. The project uses Firebase popup authentication on web, a Node allowlisted Sheet proxy, and a native Android foreground overlay service. **[Confirmed in code]**

## Security and data protection

### Implemented

- Firestore transaction data is restricted to the authenticated UID; the configured administrator can access account records. **[Confirmed in code]**
- Authentication is delegated to Firebase Auth; passwords are not stored by the app. **[Confirmed in code]**
- App lock supports device authentication and a SHA-256 PIN hash stored in secure storage. **[Confirmed in code]**
- Google Drive backup requests only `drive.file`, limiting access to files created/selected by the app. **[Confirmed in code]**
- Google Sheet write secrets are supplied through runtime configuration/Script Properties rather than committed production values. **[Confirmed in code]**
- The Render Sheet proxy allows only HTTPS `docs.google.com/spreadsheets` URLs, applies a 25-second timeout and a 5 MB response limit, and disables caching. **[Confirmed in code]**
- Android release signing is configured through ignored local keystore properties. **[Confirmed in code]**

### Security gaps before a public production launch

- Administrator authorization depends on a hardcoded email in client code and Firestore rules; replace it with Firebase custom claims. **[Confirmed gap]**
- `user_ids` documents are publicly readable in Firestore rules; account-ID availability should be checked through a protected backend or a narrower rule. **[Confirmed gap]**
- Firebase App Check is not integrated. **[Not present]**
- No MFA, audit trail for administrator actions, or formal role model was found. **[Not present]**
- The Sheet connection secret can be saved through regular preferences/account settings; sensitive integration credentials should be moved to secure storage or a server-side secret store. **[Confirmed gap]**
- The local PIN is unsalted SHA-256. Secure storage helps, but a platform-backed secret or a slow password hash would be stronger. **[Confirmed gap]**

## What differentiates Maliyati

- Google Sheet is treated as an explicit backup/integration channel, not as the live transactional database. **[Confirmed in code]**
- Receivables and payables are first-class workflows with linked settlement history instead of simple category labels. **[Confirmed in code]**
- Wallet effects are separated from accounting effects, including Service-based Credit/Debt records that do not immediately change a wallet. **[Confirmed in code]**
- USD/LBP conversion is built into display, settlement, summaries, and CSV import rather than being a decorative converter. **[Confirmed in code]**
- Structured AI-generated commands can perform reviewed add/edit/delete/settle actions, and Android can route copied text through a floating quick-input control. **[Confirmed in code]**
- A claim that these features outperform named competitors requires a documented competitor comparison. **[Needs owner confirmation]**

## What works and what remains

### Works now

- Version `1.5.0+22`; Android debug APK, signed release AAB, and Flutter web build exist. **[Confirmed]**
- Live web endpoint returned HTTP `200` with title `Maliyati` on 2026-07-25. **[Confirmed]**
- All **34** automated tests pass. **[Confirmed]**
- Core ledger, wallets, summaries, date filters, CSV import, and settlement rules have automated coverage. **[Confirmed]**
- The repository contains 44 Dart source files, 23,334 Dart lines, six test files, and 81 commits at audit time. **[Confirmed]**

### Still incomplete or unproven

- `flutter analyze` reports **42 issues**: mostly unused legacy code/style findings, plus async `BuildContext` warnings that should be fixed. **[Confirmed]**
- No integration/E2E test suite, Firestore emulator security-rule tests, or automated visual regression tests were found. **[Not present]**
- No GitHub Actions or equivalent CI quality gate was found. Render only auto-deploys commits. **[Not present]**
- No Crashlytics, product analytics, performance monitoring, or measurable usage telemetry was found. **[Not present]**
- Arabic localization is incomplete because several screens still contain hardcoded English labels. **[Confirmed gap]**
- The web manifest still describes the product as “powered by Google Sheets,” which no longer matches the Firestore architecture. **[Confirmed gap]**
- The iOS Firebase bundle ID still carries an older identifier; do not advertise an iOS release until it is reconfigured and tested. **[Confirmed gap]**
- The Android debug APK is about 194 MB and the AAB about 78 MB; release size optimization is still needed. **[Confirmed]**
- End-to-end Google sign-in, Drive backup permissions, Apps Script export, and Firestore production rules were not exercised with a test account during this audit. **[Needs owner confirmation]**
- Play Store/App Store listing, privacy policy, terms, support page, and public download page were not found. **[Not present]**

## Verifiable results

| Result | Value | Status |
|---|---:|---|
| Automated tests | 34 passed | **[Confirmed]** |
| Flutter static-analysis findings | 42 | **[Confirmed]** |
| Dart production files / lines | 44 / 23,334 | **[Confirmed]** |
| Test files / lines | 6 / 641 | **[Confirmed]** |
| Repository commits | 81 | **[Confirmed]** |
| Android AAB | 82,126,917 bytes | **[Confirmed]** |
| Android debug APK | 203,543,895 bytes | **[Confirmed]** |
| Compiled web JavaScript | 4,410,406 bytes | **[Confirmed]** |
| Live endpoint | HTTP 200 | **[Confirmed]** |
| Active users, transactions managed, retention, revenue, or hours saved | No reliable measurement available | **[Needs owner confirmation]** |

Do not claim user counts, money managed, time saved, uptime, conversion, or performance improvements until telemetry or documented customer evidence exists.

## Links and demo access

- Live web app: https://maliyati-finance.onrender.com **[Confirmed live]**
- Git remote: https://github.com/ali970x/Maliyati **[Confirmed remote]**. It is not visible through the public GitHub API, so it is likely private; public accessibility **[Needs owner confirmation]**.
- Android AAB: `build/app/outputs/bundle/release/app-release.aab` **[Confirmed local artifact]**
- Android debug APK: `build/app/outputs/flutter-apk/app-debug.apk` **[Confirmed local artifact]**
- Public APK/download page: **[Not present]**
- Demo dataset or seeded demo account: **[Not present]**

Recommended demo approach: create a separate Firebase demo account, seed it with fictional transactions covering both wallets, both currencies, one open Credit, one partially settled Debt, and several categories. Publish only the demo email and a replaceable password, never an administrator or personal account.

## Best screens for the portfolio

1. **Dashboard:** proves financial hierarchy, time filters, net cash flow, wallets, Income/Expense, Credit/Debt, and recent activity.
2. **Credit collection:** proves the hardest domain workflow: outstanding balance, partial settlement progress, wallet destination, and linked payment log.
3. **Analytics:** proves category/payment-method rankings, daily trends, best/worst days, and multi-period reporting with real charts.
4. **Transactions:** proves search, filters, stable sorting, mixed currencies, and operational transaction management.
5. **Backup and integrations:** proves Firebase as source of truth plus deliberate Google Sheet/Drive backup workflows.

Use fictional, internally consistent data and capture both a mobile screen and a responsive desktop web screen. Avoid screenshots containing personal email, real customer names, account IDs, or integration endpoints.

## Information that must not be published

- Release keystore, `key.properties`, passwords, access tokens, Sheet export secret, Apps Script deployment secret, or private Google Sheet URLs.
- Administrator email/authorization details and any real user account identifiers.
- Real financial transactions, balances, receipt images, notes, customer names, phone numbers, or debt records.
- Private Firebase service-account credentials or unrestricted API credentials. Firebase client configuration is not a server secret, but it should be protected with correct rules, API restrictions, and App Check.
- Demo credentials that are reused by a real account.

## Arabic case study

### المشكلة

كانت البيانات المالية موزعة بين ملاحظات وعمليات يدوية وجداول، بينما يحتاج المستخدم إلى فهم الدخل والمصاريف، رصيد أكثر من محفظة، والمبالغ المستحقة له وعليه بعملتي USD وLBP من دون احتساب مزدوج أو فقدان سجل الدفعات. **[Confirmed as implemented problem scope; customer validation needs owner confirmation]**

### الحل

طورت **Maliyati** كتطبيق Flutter للويب وAndroid يعتمد على Firebase Authentication وCloud Firestore كمصدر البيانات المباشر. يجمع التطبيق العمليات المالية والمحافظ والمستحقات والديون والتسويات الجزئية والكاملة في Ledger واحد، ويقدم Dashboard وتحليلات زمنية، مع Google Sheet وGoogle Drive كقنوات نسخ واستعادة يدوية. **[Confirmed in code]**

### دوري

صممت تدفق المنتج، نموذج البيانات، قواعد المحاسبة، واجهات Flutter المتجاوبة، تكامل Firebase، منطق التسويات، استيراد CSV، النسخ الاحتياطي، وخدمة Android العائمة، ثم أعددت نسخ Android وWeb والاختبارات. إن كان العمل تم بمشاركة مطورين آخرين أو أدوات AI، يجب وصف مساهمتك بدقة بدل ادعاء الملكية المنفردة. **[Technical work confirmed in repository; personal authorship scope needs owner confirmation]**

### التقنيات

Flutter، Dart، Material 3، Firebase Auth، Cloud Firestore، Google Sign-In، Node.js، Render، Google Drive API، Google Sheets/Apps Script، ML Kit OCR، Kotlin، `fl_chart`، وFlutter Secure Storage. **[Confirmed in code]**

### التحديات

كان التحدي الأهم هو الحفاظ على صحة الحسابات عند تسديد دين بعملة مختلفة، ومنع تجاوز المبلغ المتبقي، وربط كل دفعة بسجلها الأصلي. تم حل ذلك بقواعد محاسبية مركزية وFirestore transaction ذرّية تسجل تحديث الرصيد والدفعة معًا. كما تم التعامل مع اختلافات المنصات عبر popup authentication وSheet proxy على الويب، وخدمة overlay أصلية على Android. **[Confirmed in code]**

### النتيجة

النتيجة الحالية هي Release Candidate يعمل على Android والويب، مع 34 اختبارًا ناجحًا ونسخة ويب حية وAndroid AAB موقّع. لا توجد بعد بيانات موثوقة عن عدد المستخدمين أو الوقت الموفر، لذلك لا تُنشر أرقام تجارية قبل قياسها. **[Confirmed]**

## English case study

### Problem

Financial activity was fragmented across notes, manual entries, and spreadsheets, while the user needed one reliable view of income, expenses, multiple wallets, receivables, and payables in both USD and LBP without double-counting or losing payment history. **[Confirmed as implemented scope; customer validation needs owner confirmation]**

### Solution

I built **Maliyati**, a Flutter application for Android and the web, with Firebase Authentication and Cloud Firestore as its live source of truth. It combines transactions, wallet balances, receivables, payables, partial/full settlements, dashboards, and period-based analytics in one account-scoped ledger, while Google Sheets and Google Drive remain deliberate backup and restore channels. **[Confirmed in code]**

### Role

My work covered product flow, data modeling, accounting rules, responsive Flutter UI, Firebase integration, settlement workflows, CSV import, backup integrations, Android native overlay behavior, builds, and automated tests. If other developers or AI tools contributed, the published wording should accurately reflect the final ownership split. **[Technical scope confirmed; personal authorship needs owner confirmation]**

### Technology

Flutter, Dart, Material 3, Firebase Auth, Cloud Firestore, Google Sign-In, Node.js, Render, Google Drive API, Google Sheets/Apps Script, ML Kit OCR, Kotlin, `fl_chart`, and Flutter Secure Storage. **[Confirmed in code]**

### Challenges

The hardest problem was preserving accounting correctness when settling a debt in a different currency, rejecting overpayments, and maintaining a traceable link between the parent record and every payment. I centralized the domain rules and used an atomic Firestore transaction to update the balance and create the payment together. Platform-specific authentication, Sheet CORS, and Android overlay constraints were handled with web popup auth, an allowlisted Node proxy, and a native foreground overlay service. **[Confirmed in code]**

### Outcome

Maliyati is currently a functional release candidate with a live web deployment, a signed Android App Bundle, and 34 passing automated tests. No defensible user, revenue, or time-saving metrics exist yet, so the portfolio should present engineering evidence rather than invented business outcomes. **[Confirmed]**

## Improvements that will make the portfolio convincing

1. Fix all 42 analyzer findings, prioritizing async-context warnings and dead code.
2. Replace hardcoded email-based admin access with Firebase custom claims; restrict `user_ids`; add Firebase App Check and rules tests.
3. Create a fictional demo dataset and public demo account with a reset mechanism.
4. Add GitHub Actions for format, analyze, test, Android build, and web build.
5. Add Crashlytics and privacy-conscious product/performance metrics, then publish only measured results.
6. Complete Arabic localization and standardize terminology (`Whish`/`Wish`, `Debt`/`Debit`, `Credit`/`Receivable`).
7. Correct the web manifest description and prepare privacy policy, terms, support contact, and store-ready screenshots.
8. Add integration tests for Google sign-in, Firestore rules, settlement concurrency, import replacement, and backup restore.
9. Optimize release size and measure cold-start, dashboard load, and Firestore request performance.
10. Publish a dedicated portfolio landing section with a 60-90 second product video, the five recommended screens, architecture diagram, and verified links.
