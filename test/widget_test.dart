import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/platform/android_mrp_open.dart';
import 'package:skyengine/pages/home_page.dart';
import 'package:skyengine/pages/mrp_player_page.dart';

void main() {
  testWidgets('Home shows local and store tabs', (WidgetTester tester) async {
    final tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('skyengine_home_page_test_'),
    );
    if (tempDir == null) {
      fail('Failed to create temp directory');
    }

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            workingDirectoryProvider: () async => tempDir,
            pickMrpFile: () async => null,
            appStoreBuilder: _buildTestAppStore,
            playerBuilder: _buildTestPlayer,
            initialMrpProvider: () async => null,
            openMrpStreamProvider: () => const Stream<MrpOpenRequest>.empty(),
            enableStartupRemoteConfig: false,
            enableStartupUpdateCheck: false,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('SkyEngine'), findsOneWidget);
      expect(find.text('本地'), findsOneWidget);
      expect(find.text('商店'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);

      await tester.tap(find.text('商店'));
      await tester.pump();

      expect(find.text('搜索应用'), findsOneWidget);

      await tester.tap(find.text('更多'));
      await tester.pump();

      expect(find.text('模拟器设置'), findsOneWidget);
      expect(find.text('调试'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => tempDir.delete(recursive: true));
    }
  });

  test('MRP directory uses mythroad without moving root files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_home_page_test_',
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
      'skyengine_home_page_test_',
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
        '${Directory.systemTemp.path}${Platform.pathSeparator}skyengine_runtime';
    final mrpPath =
        '$workDir${Platform.pathSeparator}mythroad${Platform.pathSeparator}mpc.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), 'mythroad/mpc.mrp');
  });

  test('runtime MRP path preserves Chinese file name when made relative', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}skyengine_runtime';
    final mrpPath =
        '$workDir${Platform.pathSeparator}mythroad${Platform.pathSeparator}中文游戏.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), 'mythroad/中文游戏.mrp');
  });

  test('runtime MRP path preserves external files', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}skyengine_runtime';
    final mrpPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}external.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), mrpPath);
  });

  test('runtime MRP path preserves files directly under work dir', () {
    final workDir =
        '${Directory.systemTemp.path}${Platform.pathSeparator}skyengine_runtime';
    final mrpPath = '$workDir${Platform.pathSeparator}demo.mrp';

    expect(runtimeMrpPathForWorkDir(mrpPath, workDir), mrpPath);
  });

  test('home page import smoke', () {
    expect(HomePage, isNotNull);
  });
}

Widget _buildTestAppStore(
  String? mrpDir,
  AppStoreRunMrp onRunMrp,
  Future<void> Function() onDownloaded,
) {
  return const Center(child: Text('搜索应用'));
}

Widget _buildTestPlayer(MrpOpenRequest request, String? dnsMap) {
  return Scaffold(body: Text(request.path));
}
