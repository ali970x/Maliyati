import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartClipboardService {
  SmartClipboardService._();

  static final instance = SmartClipboardService._();

  static const enabledKey = 'smart_clipboard_enabled';
  static const bubbleTapKey = 'smart_clipboard_bubble_tapped';
  static const _channel = MethodChannel('maliyati/floating_input');

  SharedPreferences? _preferences;
  FutureOr<void> Function(String script)? _onOpenSmartInput;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get isEnabled async {
    final prefs = await _prefs;
    return prefs.getBool(enabledKey) ?? false;
  }

  Future<void> initialize({
    required FutureOr<void> Function(String script) onOpenSmartInput,
  }) async {
    _onOpenSmartInput = onOpenSmartInput;
    if (await isEnabled) {
      await _showBubble();
    }
    await _openClipboardAfterBubbleTap();
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(enabledKey, enabled);
    if (enabled) {
      await _showBubble();
    } else if (isSupported) {
      await _channel.invokeMethod<void>('hide');
    }
  }

  Future<bool> requestOverlayPermission() async {
    if (!isSupported) {
      return false;
    }
    final granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
    if (!granted) {
      await _channel.invokeMethod<void>('requestPermission');
    }
    return granted;
  }

  void updateLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openClipboardAfterBubbleTap();
    }
  }

  Future<void> dispose() async {}

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> _showBubble() async {
    if (!isSupported) {
      return;
    }
    final granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
    if (granted) {
      await _channel.invokeMethod<void>('show');
    }
  }

  Future<void> _openClipboardAfterBubbleTap() async {
    final prefs = await _prefs;
    if (prefs.getBool(bubbleTapKey) != true) {
      return;
    }
    await prefs.remove(bubbleTapKey);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      await _onOpenSmartInput?.call(text);
    }
  }
}
