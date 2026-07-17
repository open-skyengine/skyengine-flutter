import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/emulator_runtime_config.dart';

void main() {
  test('gtxzj uses the configured legacy handset date', () async {
    final config = await emulatorRuntimeConfigForMrp('gtxzj.mrp');

    expect(config.deviceDate, '2011-01-01');
  });

  test('renamed gtxzj package is recognized from the MRP header', () async {
    final dir = await Directory.systemTemp.createTemp(
      'skyengine_runtime_config_test_',
    );
    try {
      final file = File('${dir.path}${Platform.pathSeparator}download_7.mrp');
      final bytes = List<int>.filled(208, 0);
      bytes.setAll(0, 'MRPG'.codeUnits);
      bytes.setAll(16, 'gtxzj.mrp'.codeUnits);
      await file.writeAsBytes(bytes);

      final config = await emulatorRuntimeConfigForMrp(file.path);

      expect(config.deviceDate, '2011-01-01');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('unmatched applications explicitly use the host date', () async {
    final config = await emulatorRuntimeConfigForMrp('other-game.mrp');

    expect(config.deviceDate, 'host');
  });

  test('normalization keeps package matching case-insensitive', () {
    expect(normalizeEmulatorAppKey(r'C:\Games\GTXZJ.MRP'), 'gtxzj');
    expect(normalizeEmulatorAppKey(''), isNull);
  });

  test('runtime config can be supplied by a replacement provider', () async {
    final config = await emulatorRuntimeConfigForMrp(
      'remote-rule.mrp',
      provider: _RemoteProvider(),
    );

    expect(config.deviceDate, '2024-05-06');
  });
}

class _RemoteProvider implements EmulatorRuntimeConfigProvider {
  @override
  Future<EmulatorRuntimeConfig> resolve(EmulatorAppIdentity app) async {
    expect(app.configKeys, contains('remote-rule'));
    return const EmulatorRuntimeConfig(deviceDate: '2024-05-06');
  }
}
