import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/app_store_api.dart';
import 'package:skyengine/services/emulator_update_checker.dart';

void main() {
  test('returns unsupported without invoking platform providers', () async {
    var versionRead = false;
    final checker = EmulatorUpdateChecker(
      platformSupported: () => false,
      versionCodeProvider: () async {
        versionRead = true;
        return 1;
      },
      architectureProvider: () => kEmulatorArchitectureArm64,
      updateProvider: ({required versionCode, required architecture}) async {
        return const AppStoreEmulatorUpdate(
          updateAvailable: false,
          latest: null,
        );
      },
      cleanup:
          ({required destinationDir, required installedVersionCode}) async {},
    );

    final result = await checker.check();

    expect(result.status, EmulatorUpdateCheckStatus.unsupported);
    expect(versionRead, isFalse);
  });

  test('checks the current version and architecture', () async {
    final workDir = Directory('work');
    Directory? cleanedDirectory;
    int? cleanedVersionCode;
    int? requestedVersionCode;
    String? requestedArchitecture;
    final latest = AppStoreEmulatorVersion(
      id: 9,
      platform: 'android',
      architecture: kEmulatorArchitectureArm64,
      versionCode: 42,
      version: '1.2.3',
      changelog: '',
      downloadUrl: null,
      fileSize: 0,
      checksum: '',
      forceUpdate: false,
    );
    final checker = EmulatorUpdateChecker(
      platformSupported: () => true,
      versionCodeProvider: () async => 41,
      architectureProvider: () => kEmulatorArchitectureArm64,
      updateProvider: ({required versionCode, required architecture}) async {
        requestedVersionCode = versionCode;
        requestedArchitecture = architecture;
        return AppStoreEmulatorUpdate(updateAvailable: true, latest: latest);
      },
      cleanup:
          ({required destinationDir, required installedVersionCode}) async {
            cleanedDirectory = destinationDir;
            cleanedVersionCode = installedVersionCode;
          },
    );

    final result = await checker.check(workingDirectory: workDir);

    expect(result.status, EmulatorUpdateCheckStatus.updateAvailable);
    expect(result.latest, same(latest));
    expect(requestedVersionCode, 41);
    expect(requestedArchitecture, kEmulatorArchitectureArm64);
    expect(cleanedVersionCode, 41);
    expect(cleanedDirectory!.path, 'work${Platform.pathSeparator}updates');
  });

  test('cleanup failure does not prevent an update check', () async {
    Object? cleanupError;
    var updateChecked = false;
    final checker = EmulatorUpdateChecker(
      platformSupported: () => true,
      versionCodeProvider: () async => 41,
      architectureProvider: () => kEmulatorArchitectureArm,
      updateProvider: ({required versionCode, required architecture}) async {
        updateChecked = true;
        return const AppStoreEmulatorUpdate(
          updateAvailable: false,
          latest: null,
        );
      },
      cleanup: ({required destinationDir, required installedVersionCode}) {
        throw StateError('cleanup failed');
      },
      onCleanupError: (error, stackTrace) => cleanupError = error,
    );

    final result = await checker.check(workingDirectory: Directory('work'));

    expect(result.status, EmulatorUpdateCheckStatus.upToDate);
    expect(updateChecked, isTrue);
    expect(cleanupError, isA<StateError>());
  });
}
