import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidMrpOpen {
  const AndroidMrpOpen();

  static const MethodChannel _channel = MethodChannel('skyengine/mrp_open');

  Future<String?> getInitialMrp() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('getInitialMrp');
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to get initial MRP: $error');
      return null;
    }
  }

  Stream<String> openMrps() {
    if (!Platform.isAndroid) {
      return const Stream.empty();
    }

    late final StreamController<String> controller;
    controller = StreamController<String>.broadcast(
      onListen: () {
        _channel.setMethodCallHandler((call) async {
          if (call.method != 'openMrp') {
            throw MissingPluginException('Unknown method ${call.method}');
          }
          final path = call.arguments as String?;
          if (path != null && path.isNotEmpty) {
            controller.add(path);
          }
        });
      },
      onCancel: () {
        _channel.setMethodCallHandler(null);
      },
    );
    return controller.stream;
  }
}
