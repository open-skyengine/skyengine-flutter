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

  Future<bool> ensureDownloadNotificationPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final granted = await _channel.invokeMethod<bool>(
      'ensureDownloadNotificationPermission',
    );
    return granted ?? false;
  }

  Future<void> showDownloadProgress({
    required int downloadedBytes,
    required int totalBytes,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('showDownloadProgress', {
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
    });
  }

  Future<void> showDownloadComplete(String path) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('showDownloadComplete', {'path': path});
  }

  Future<void> showDownloadFailed(String message) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('showDownloadFailed', {
      'message': message,
    });
  }

  Future<void> cancelDownloadNotification() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('cancelDownloadNotification');
  }
}
