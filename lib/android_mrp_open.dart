import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mrp_resolution.dart';

class MrpOpenRequest {
  final String path;
  final String? resolution;

  const MrpOpenRequest({required this.path, this.resolution});

  MrpResolution? get parsedResolution => MrpResolution.tryParse(resolution);

  int? get screenWidth => parsedResolution?.width;

  int? get screenHeight => parsedResolution?.height;

  static MrpOpenRequest? fromArguments(Object? arguments) {
    if (arguments is String) {
      return arguments.isEmpty ? null : MrpOpenRequest(path: arguments);
    }
    if (arguments is! Map) {
      return null;
    }

    final path = _readString(arguments, 'path');
    if (path == null || path.isEmpty) {
      return null;
    }

    var resolution = _readString(arguments, 'resolution');
    if (MrpResolution.tryParse(resolution) == null) {
      final width =
          _readInt(arguments, 'screenWidth') ?? _readInt(arguments, 'width');
      final height =
          _readInt(arguments, 'screenHeight') ?? _readInt(arguments, 'height');
      if (width != null && height != null && width > 0 && height > 0) {
        resolution = MrpResolution(width, height).label;
      } else {
        resolution = null;
      }
    }

    return MrpOpenRequest(path: path, resolution: resolution);
  }
}

String? _readString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  final string = value.toString().trim();
  return string.isEmpty ? null : string;
}

int? _readInt(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

class AndroidMrpOpen {
  const AndroidMrpOpen();

  static const MethodChannel _channel = MethodChannel('skyengine/mrp_open');

  Future<String?> getInitialMrp() async {
    final request = await getInitialMrpRequest();
    return request?.path;
  }

  Future<MrpOpenRequest?> getInitialMrpRequest() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final arguments = await _channel.invokeMethod<Object?>('getInitialMrp');
      return MrpOpenRequest.fromArguments(arguments);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to get initial MRP: $error');
      return null;
    }
  }

  Stream<String> openMrps() {
    return openMrpRequests().map((request) => request.path);
  }

  Stream<MrpOpenRequest> openMrpRequests() {
    if (!Platform.isAndroid) {
      return const Stream.empty();
    }

    late final StreamController<MrpOpenRequest> controller;
    controller = StreamController<MrpOpenRequest>.broadcast(
      onListen: () {
        _channel.setMethodCallHandler((call) async {
          if (call.method != 'openMrp') {
            throw MissingPluginException('Unknown method ${call.method}');
          }
          final request = MrpOpenRequest.fromArguments(call.arguments);
          if (request != null) {
            controller.add(request);
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
