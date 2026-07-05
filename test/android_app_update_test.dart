import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/platform/android_app_update.dart';

void main() {
  test('download notification status parses native payload', () {
    final status = DownloadNotificationPermissionStatus.fromJson({
      'canShow': false,
      'canOpenSettings': true,
      'message': '系统通知已关闭',
    });

    expect(status.canShow, isFalse);
    expect(status.canOpenSettings, isTrue);
    expect(status.message, '系统通知已关闭');
  });

  test('download notification status falls back for missing payload', () {
    const fallback = DownloadNotificationPermissionStatus.unavailable();
    final status = DownloadNotificationPermissionStatus.fromJson(null);

    expect(status.canShow, fallback.canShow);
    expect(status.canOpenSettings, fallback.canOpenSettings);
    expect(status.message, fallback.message);
  });
}
