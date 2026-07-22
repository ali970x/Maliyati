import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'firebase_web_plugin_registrar.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Object? _lastError;

  static Object? get lastError => _lastError;

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<bool> initializeIfConfigured() async {
    if (Firebase.apps.isNotEmpty) {
      _lastError = null;
      return true;
    }

    try {
      WidgetsFlutterBinding.ensureInitialized();
      registerFirebaseWebPlugins();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Firebase web scripts took too long to load.');
        },
      );
      _lastError = null;
      return true;
    } on UnsupportedError catch (error) {
      _lastError = error;
      return false;
    } on PlatformException catch (error) {
      _lastError = error;
      return false;
    } on FirebaseException catch (error) {
      _lastError = error;
      return false;
    } on TimeoutException catch (error) {
      _lastError = error;
      return false;
    } catch (error) {
      _lastError = error;
      return false;
    }
  }

  static bool get supportsGoogleSignIn =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
