class AppConfig {
  const AppConfig._();

  static const appName = 'Maliyati';
  static const appVersion = '1.5.0';
  static const buildNumber = '22';
  static const fullVersion = '$appVersion+$buildNumber';
  static const serverVersion = appVersion;
  static const flutterVersion = appVersion;

  // New accounts start disconnected. Existing users keep their saved URL.
  static const defaultGoogleSheetUrl = '';

  // Web OAuth client from the Firebase project. It is used only by the
  // Google Drive picker/backup flow in browsers.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '34788182639-nsp1ct80jvr0jkc4teqs1vlk8gkcd1lt.apps.googleusercontent.com',
  );

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
    defaultValue: '',
  );

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static bool get isSheetExportConfigured =>
      sheetExportEndpoint.isNotEmpty && sheetExportSecret.isNotEmpty;
}
