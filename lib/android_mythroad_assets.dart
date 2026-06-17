import 'dart:io';

import 'package:flutter/services.dart';

class AndroidMythroadAssets {
  static const MethodChannel _channel = MethodChannel('mrpoid/mythroad_assets');

  static Future<void> ensureSystem(Directory mythroadDir) async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('ensureSystem', {
      'mythroadDir': mythroadDir.path,
    });
  }
}
