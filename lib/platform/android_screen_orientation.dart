import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidScreenOrientation {
  static const MethodChannel _channel = MethodChannel(
    'skyengine/screen_orientation',
  );

  static Future<void> setVmrpRotation(
    int rotation, {
    required bool landscape,
  }) async {
    if (!Platform.isAndroid) return;
    if (rotation < 0 || rotation > 3) {
      throw ArgumentError.value(
        rotation,
        'rotation',
        'must be between 0 and 3',
      );
    }
    await _invoke('setVmrpRotation', {
      'rotation': rotation,
      'landscape': landscape,
    });
  }

  static Future<void> clearVmrpRotation() async {
    if (!Platform.isAndroid) return;
    await _invoke('clearVmrpRotation');
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint(
        '[VMRP] Android screen orientation failed: '
        '${error.code}, ${error.message}, ${error.details}',
      );
    } on MissingPluginException catch (error) {
      debugPrint('[VMRP] Android screen orientation channel missing: $error');
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('[VMRP] Android screen orientation failed: $error');
    }
  }
}
