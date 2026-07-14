import 'dart:io';

import 'package:flutter/services.dart';

class DownloadNotificationPermissionStatus {
  final bool canShow;
  final bool canOpenSettings;
  final String message;

  const DownloadNotificationPermissionStatus({
    required this.canShow,
    required this.canOpenSettings,
    required this.message,
  });

  const DownloadNotificationPermissionStatus.unavailable()
    : canShow = false,
      canOpenSettings = false,
      message = '';

  factory DownloadNotificationPermissionStatus.fromJson(
    Map<dynamic, dynamic>? json,
  ) {
    if (json == null) {
      return const DownloadNotificationPermissionStatus.unavailable();
    }
    return DownloadNotificationPermissionStatus(
      canShow: json['canShow'] == true,
      canOpenSettings: json['canOpenSettings'] == true,
      message: json['message'] is String ? json['message'] as String : '',
    );
  }
}

class AndroidUpdateDownloadRequest {
  final Uri uri;
  final String destinationPath;
  final Map<String, String> headers;
  final int expectedSize;
  final String checksum;

  const AndroidUpdateDownloadRequest({
    required this.uri,
    required this.destinationPath,
    required this.headers,
    required this.expectedSize,
    required this.checksum,
  });
}

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

  Future<bool> installApk(String path) async {
    if (!Platform.isAndroid) {
      return true;
    }
    final opened = await _channel.invokeMethod<bool>('installApk', {
      'path': path,
    });
    return opened ?? true;
  }

  Future<String> downloadUpdateInBackground(
    AndroidUpdateDownloadRequest request,
  ) async {
    if (!Platform.isAndroid) {
      return request.destinationPath;
    }
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('downloadUpdateInBackground', {
          'url': request.uri.toString(),
          'destinationPath': request.destinationPath,
          'headers': request.headers,
          'expectedSize': request.expectedSize,
          'checksum': request.checksum,
        });
    final path = result?['path'];
    if (path is! String || path.isEmpty) {
      throw PlatformException(
        code: 'UPDATE_DOWNLOAD_FAILED',
        message: '后台下载未返回更新包路径',
      );
    }
    return path;
  }

  Future<DownloadNotificationPermissionStatus>
  ensureDownloadNotificationPermission() async {
    if (!Platform.isAndroid) {
      return const DownloadNotificationPermissionStatus.unavailable();
    }
    final status = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'ensureDownloadNotificationPermission',
    );
    return DownloadNotificationPermissionStatus.fromJson(status);
  }

  Future<void> openDownloadNotificationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openDownloadNotificationSettings');
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
