import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<bool> initializeIfConfigured() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } on UnsupportedError {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static bool get supportsGoogleSignIn =>
      !kIsWeb || AppConfig.firebaseAuthDomain.isNotEmpty;
}
