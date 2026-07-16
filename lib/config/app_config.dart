class AppConfig {
  const AppConfig._();

  static const appName = 'Maliyati';

  static const defaultGoogleSheetUrl =
      'https://docs.google.com/spreadsheets/d/1CMtELArv48IVjIo_u5wKSPR8Bqe7JfFqMI0qLLG5Zck/edit?usp=sharing';

  static const defaultExchangeRate = 89000.0;

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static const sheetExportEndpoint = String.fromEnvironment(
    'SHEET_EXPORT_ENDPOINT',
  );
  static const sheetExportSecret = String.fromEnvironment(
    'SHEET_EXPORT_SECRET',
    defaultValue: defaultSheetExportSecret,
  );
  static const defaultSheetExportSecret = 'maliyati-2026';

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static bool get isSheetExportConfigured =>
      sheetExportEndpoint.isNotEmpty && sheetExportSecret.isNotEmpty;
}
