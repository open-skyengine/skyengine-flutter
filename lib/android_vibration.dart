import 'dart:io';
import 'package:flutter/services.dart';

class AndroidVibration {
  static const MethodChannel _channel = MethodChannel('mrpoid/vibration');

  static Future<void> keyPress() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('keyPress');
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }
}
