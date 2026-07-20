import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

typedef ThemeSettingsFileProvider = Future<File> Function();

/// Controls the application theme and persists the user's preference.
class ThemeSettings extends ChangeNotifier {
  ThemeSettings({ThemeSettingsFileProvider? settingsFileProvider})
    : _settingsFileProvider =
          settingsFileProvider ?? _defaultSettingsFileProvider;

  @visibleForTesting
  ThemeSettings.inMemory({bool followSystem = true, bool darkMode = false})
    : _settingsFileProvider = null {
    _loaded = true;
    _followSystem = followSystem;
    _darkMode = darkMode;
  }

  static final ThemeSettings instance = ThemeSettings();

  final ThemeSettingsFileProvider? _settingsFileProvider;
  Future<void>? _loading;
  Future<void> _pendingSave = Future<void>.value();
  bool _loaded = false;
  bool _followSystem = true;
  bool _darkMode = false;

  bool get isLoaded => _loaded;
  bool get followSystem => _followSystem;
  bool get darkMode => _darkMode;

  ThemeMode get themeMode {
    if (_followSystem) {
      return ThemeMode.system;
    }
    return _darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final file = await _settingsFileProvider!();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map<String, dynamic>) {
          final followSystem = data['followSystem'];
          final darkMode = data['darkMode'];
          if (followSystem is bool) {
            _followSystem = followSystem;
          }
          if (darkMode is bool) {
            _darkMode = darkMode;
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to load theme settings: $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setFollowSystem(
    bool value, {
    Brightness? currentBrightness,
  }) async {
    if (!_loaded) {
      await ensureLoaded();
    }
    if (value == _followSystem) {
      await _pendingSave;
      return;
    }

    if (!value && currentBrightness != null) {
      _darkMode = currentBrightness == Brightness.dark;
    }
    _followSystem = value;
    notifyListeners();
    await _save();
  }

  Future<void> setDarkMode(bool value) async {
    if (!_loaded) {
      await ensureLoaded();
    }
    if (value == _darkMode) {
      await _pendingSave;
      return;
    }
    _darkMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> toggleTheme(Brightness currentBrightness) async {
    if (!_loaded) {
      await ensureLoaded();
    }
    _followSystem = false;
    _darkMode = currentBrightness != Brightness.dark;
    notifyListeners();
    await _save();
  }

  Future<void> _save() {
    final contents = jsonEncode({
      'followSystem': _followSystem,
      'darkMode': _darkMode,
    });
    _pendingSave = _pendingSave.then((_) => _write(contents));
    return _pendingSave;
  }

  Future<void> _write(String contents) async {
    final settingsFileProvider = _settingsFileProvider;
    if (settingsFileProvider == null) {
      return;
    }
    try {
      final file = await settingsFileProvider();
      await file.writeAsString(contents);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to save theme settings: $error');
    }
  }

  static Future<File> _defaultSettingsFileProvider() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}theme_settings.json');
  }
}
