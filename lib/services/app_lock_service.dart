import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  AppLockService({
    LocalAuthentication? authentication,
    FlutterSecureStorage? secureStorage,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final LocalAuthentication _authentication;
  final FlutterSecureStorage _secureStorage;
  static const _pinKey = 'maliyati_app_lock_pin_hash';

  Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await _authentication.canCheckBiometrics &&
          await _authentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!await isAvailable()) {
      return false;
    }
    try {
      return await _authentication.authenticate(
        localizedReason: 'Use your fingerprint to unlock Maliyati.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPin() async =>
      (await _secureStorage.read(key: _pinKey)) != null;

  Future<void> savePin(String pin) =>
      _secureStorage.write(key: _pinKey, value: _hashPin(pin));

  Future<bool> verifyPin(String pin) async {
    final saved = await _secureStorage.read(key: _pinKey);
    return saved != null && saved == _hashPin(pin);
  }

  Future<void> clearPin() => _secureStorage.delete(key: _pinKey);

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
