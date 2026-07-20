import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/theme_settings.dart';

void main() {
  late Directory tempDir;
  late File settingsFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_settings_test_');
    settingsFile = File(
      '${tempDir.path}${Platform.pathSeparator}theme_settings.json',
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ThemeSettings createSettings() {
    return ThemeSettings(settingsFileProvider: () async => settingsFile);
  }

  test('defaults to following the system theme', () async {
    final settings = createSettings();

    await settings.ensureLoaded();

    expect(settings.followSystem, isTrue);
    expect(settings.darkMode, isFalse);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('manual preference is persisted', () async {
    final settings = createSettings();
    await settings.ensureLoaded();

    await settings.setFollowSystem(false, currentBrightness: Brightness.dark);

    expect(settings.followSystem, isFalse);
    expect(settings.darkMode, isTrue);
    expect(settings.themeMode, ThemeMode.dark);

    final restored = createSettings();
    await restored.ensureLoaded();
    expect(restored.followSystem, isFalse);
    expect(restored.darkMode, isTrue);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test(
    'toolbar toggle exits follow-system and reverses current theme',
    () async {
      final settings = createSettings();
      await settings.ensureLoaded();

      await settings.toggleTheme(Brightness.dark);

      expect(settings.followSystem, isFalse);
      expect(settings.darkMode, isFalse);
      expect(settings.themeMode, ThemeMode.light);

      await settings.setFollowSystem(true);
      await settings.toggleTheme(Brightness.light);

      expect(settings.followSystem, isFalse);
      expect(settings.darkMode, isTrue);
      expect(settings.themeMode, ThemeMode.dark);
    },
  );
}
