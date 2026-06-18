import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrpoid/home_page.dart';
import 'package:mrpoid/mrp_player_page.dart';

void main() {
  testWidgets('Home shows local and store tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          workingDirectoryProvider: () async => Directory.systemTemp,
          pickMrpFile: () async => null,
          appStoreBuilder: _buildTestAppStore,
          playerBuilder: _buildTestPlayer,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MrpOid'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('商店'), findsOneWidget);

    await tester.tap(find.text('商店'));
    await tester.pump();

    expect(find.text('搜索应用'), findsOneWidget);
  });

  test('MRP directory uses mythroad without moving root files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'mrpoid_home_page_test_',
    );
    await File(
      '${tempDir.path}${Platform.pathSeparator}old.mrp',
    ).writeAsString('OLD-MRP');

    try {
      final mrpDir = mrpDirectoryForWorkDir(tempDir);
      await mrpDir.create(recursive: true);

      final expectedMrpDir = '${tempDir.path}${Platform.pathSeparator}mythroad';
      expect(mrpDir.path, expectedMrpDir);
      expect(
        await File('$expectedMrpDir${Platform.pathSeparator}old.mrp').exists(),
        isFalse,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('MRP directory is under mythroad', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'mrpoid_home_page_test_',
    );

    try {
      final expectedPath = '${tempDir.path}${Platform.pathSeparator}mythroad';
      expect(mrpDirectoryForWorkDir(tempDir).path, expectedPath);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('runtime MRP path is relative when file is inside work dir', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}mrpoid_runtime';
    final mrpPath =
        '$workDir${Platform.pathSeparator}mythroad${Platform.pathSeparator}mpc.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), 'mythroad/mpc.mrp');
  });

  test('runtime MRP path preserves external files', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}mrpoid_runtime';
    final mrpPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}external.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), mrpPath);
  });

  test('runtime MRP path preserves files directly under work dir', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}mrpoid_runtime';
    final mrpPath = '$workDir${Platform.pathSeparator}demo.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), mrpPath);
  });

  test('home page import smoke', () {
    expect(HomePage, isNotNull);
  });
}

Widget _buildTestAppStore(
  String? mrpDir,
  ValueChanged<String> onRunMrp,
  Future<void> Function() onDownloaded,
) {
  return const Center(child: Text('搜索应用'));
}

Widget _buildTestPlayer(String mrpPath) {
  return Scaffold(body: Text(mrpPath));
}
