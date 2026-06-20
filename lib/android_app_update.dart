import 'dart:io';

import 'package:flutter/services.dart';

class AndroidAppUpdate {
  static const MethodChannel _channel = MethodChannel('skyengine/app_update');

  const AndroidAppUpdate();

  Future<int?> getVersionCode() async {
    if (!Platform.isAndroid) {
      return null;
    }
    final value = await _channel.invokeMethod<int>('getVersionCode');
    return value;
  }

  Future<void> installApk(String path) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
