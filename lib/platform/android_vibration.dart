import 'dart:io';
import 'package:flutter/services.dart';

class AndroidVibration {
  static const MethodChannel _channel = MethodChannel('skyengine/haptics');

  static Future<void> keyPress() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('virtualKeyVibrate');
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> vibrate(int durationMs) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('vibrate', durationMs);
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('cancelVibration');
  }
}
