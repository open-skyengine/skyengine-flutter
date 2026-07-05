import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const kEmulatorMemoryOptionsMb = [1, 2, 4, 6, 8, 16];
const kDefaultEmulatorMemoryMb = 1;

/// 模拟器设置，持久化为应用支持目录下的 JSON 文件。
class EmulatorSettings extends ChangeNotifier {
  EmulatorSettings._();

  static final EmulatorSettings instance = EmulatorSettings._();

  Future<void>? _loading;
  int _memoryMb = kDefaultEmulatorMemoryMb;

  int get memoryMb => _memoryMb;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return;
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) {
        return;
      }
      final memory = data['memoryMb'];
      if (memory is int && kEmulatorMemoryOptionsMb.contains(memory)) {
        _memoryMb = memory;
      }
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to load emulator settings: $error');
    }
  }

  Future<void> setMemoryMb(int value) async {
    if (!kEmulatorMemoryOptionsMb.contains(value) || value == _memoryMb) {
      return;
    }
    _memoryMb = value;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _settingsFile();
      await file.writeAsString(jsonEncode({'memoryMb': _memoryMb}));
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to save emulator settings: $error');
    }
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}emulator_settings.json');
  }
}
