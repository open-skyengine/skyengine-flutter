import 'dart:developer' as developer;
import 'dart:io';

import '../platform/android_app_update.dart';
import 'app_store_api.dart';

typedef EmulatorVersionCodeProvider = Future<int?> Function();
typedef EmulatorArchitectureProvider = String Function();
typedef EmulatorPlatformSupportProvider = bool Function();
typedef EmulatorUpdateProvider =
    Future<AppStoreEmulatorUpdate> Function({
      required int? versionCode,
      required String architecture,
    });
typedef EmulatorUpdateCleanup =
    Future<void> Function({
      required Directory destinationDir,
      required int installedVersionCode,
    });
typedef EmulatorUpdateCleanupErrorHandler =
    void Function(Object error, StackTrace stackTrace);

enum EmulatorUpdateCheckStatus { unsupported, upToDate, updateAvailable }

class EmulatorUpdateCheckResult {
  final EmulatorUpdateCheckStatus status;
  final AppStoreEmulatorVersion? latest;

  const EmulatorUpdateCheckResult._(this.status, {this.latest});

  const EmulatorUpdateCheckResult.unsupported()
    : this._(EmulatorUpdateCheckStatus.unsupported);

  const EmulatorUpdateCheckResult.upToDate()
    : this._(EmulatorUpdateCheckStatus.upToDate);

  const EmulatorUpdateCheckResult.updateAvailable(
    AppStoreEmulatorVersion latest,
  ) : this._(EmulatorUpdateCheckStatus.updateAvailable, latest: latest);
}

class EmulatorUpdateChecker {
  final EmulatorPlatformSupportProvider _platformSupported;
  final EmulatorVersionCodeProvider _versionCodeProvider;
  final EmulatorArchitectureProvider _architectureProvider;
  final EmulatorUpdateProvider _updateProvider;
  final EmulatorUpdateCleanup _cleanup;
  final EmulatorUpdateCleanupErrorHandler? _onCleanupError;

  const EmulatorUpdateChecker({
    required EmulatorPlatformSupportProvider platformSupported,
    required EmulatorVersionCodeProvider versionCodeProvider,
    required EmulatorArchitectureProvider architectureProvider,
    required EmulatorUpdateProvider updateProvider,
    required EmulatorUpdateCleanup cleanup,
    EmulatorUpdateCleanupErrorHandler? onCleanupError,
  }) : _platformSupported = platformSupported,
       _versionCodeProvider = versionCodeProvider,
       _architectureProvider = architectureProvider,
       _updateProvider = updateProvider,
       _cleanup = cleanup,
       _onCleanupError = onCleanupError;

  factory EmulatorUpdateChecker.android({
    required AppStoreClient appStoreClient,
    required AndroidAppUpdate androidAppUpdate,
  }) {
    return EmulatorUpdateChecker(
      platformSupported: () => Platform.isAndroid,
      versionCodeProvider: androidAppUpdate.getVersionCode,
      architectureProvider: currentEmulatorArchitecture,
      updateProvider:
          ({required int? versionCode, required String architecture}) {
            return appStoreClient.checkEmulatorUpdate(
              versionCode: versionCode,
              architecture: architecture,
            );
          },
      cleanup:
          ({
            required Directory destinationDir,
            required int installedVersionCode,
          }) {
            return appStoreClient.cleanupInstalledEmulatorUpdates(
              destinationDir: destinationDir,
              installedVersionCode: installedVersionCode,
            );
          },
      onCleanupError: (error, stackTrace) {
        developer.log(
          'Failed to clean installed update packages',
          name: 'skyengine.update',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<EmulatorUpdateCheckResult> check({Directory? workingDirectory}) async {
    if (!_platformSupported()) {
      return const EmulatorUpdateCheckResult.unsupported();
    }

    final versionCode = await _versionCodeProvider();
    if (versionCode != null && workingDirectory != null) {
      final updatesDir = Directory(
        '${workingDirectory.path}${Platform.pathSeparator}updates',
      );
      try {
        await _cleanup(
          destinationDir: updatesDir,
          installedVersionCode: versionCode,
        );
      } catch (error, stackTrace) {
        _onCleanupError?.call(error, stackTrace);
      }
    }

    final update = await _updateProvider(
      versionCode: versionCode,
      architecture: _architectureProvider(),
    );
    final latest = update.latest;
    if (!update.updateAvailable || latest == null) {
      return const EmulatorUpdateCheckResult.upToDate();
    }
    return EmulatorUpdateCheckResult.updateAvailable(latest);
  }
}
