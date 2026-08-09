import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/models/keypad_mode.dart';
import 'package:skyengine/services/local_mrp_database.dart';
import 'package:skyengine/services/local_mrp_files.dart';
import 'package:skyengine/services/theme_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:skyengine/platform/android_mrp_open.dart';
import 'package:skyengine/pages/home_page.dart';
import 'package:skyengine/pages/mrp_player_page.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('Home shows local and store tabs', (WidgetTester tester) async {
    final tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('skyengine_home_page_test_'),
    );
    if (tempDir == null) {
      fail('Failed to create temp directory');
    }
    final database = LocalMrpDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePathProvider: () async =>
          '${tempDir.path}${Platform.pathSeparator}$localMrpDatabaseFileName',
    );
    final themeSettings = ThemeSettings.inMemory();

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
            localMrpDatabase: database,
            themeSettings: themeSettings,
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
      expect(find.byTooltip('导入 MRP 文件'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('商店'));
      await tester.pump();

      expect(find.text('SkyEngine'), findsNothing);
      expect(find.text('搜索应用'), findsOneWidget);
      expect(find.byTooltip('导入 MRP 文件'), findsNothing);

      await tester.tap(find.text('更多'));
      await tester.pump();

      expect(find.text('SkyEngine'), findsOneWidget);
      expect(find.byTooltip('导入 MRP 文件'), findsNothing);
      expect(find.byTooltip('切换到深色模式'), findsOneWidget);
      expect(find.text('深色设置'), findsOneWidget);
      expect(find.text('模拟器设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('调试'), findsNothing);

      await tester.tap(find.byTooltip('切换到深色模式'));
      await tester.pump();

      expect(themeSettings.followSystem, isFalse);
      expect(themeSettings.darkMode, isTrue);
      expect(find.text('切换成功，关闭了深色跟随系统'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
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

  testWidgets('local MRP restores and updates resolution from database', (
    tester,
  ) async {
    final tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('skyengine_home_page_test_'),
    );
    if (tempDir == null) {
      fail('Failed to create temp directory');
    }
    final database = LocalMrpDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePathProvider: () async =>
          '${tempDir.path}${Platform.pathSeparator}$localMrpDatabaseFileName',
    );
    late File mrp;
    late File newerMrp;
    await tester.runAsync(() async {
      final mrpDir = mrpDirectoryForWorkDir(tempDir);
      await mrpDir.create(recursive: true);
      mrp = await File(
        '${mrpDir.path}${Platform.pathSeparator}demo.mrp',
      ).writeAsString('MRP-DATA');
      await database.open();
      await database.upsert(
        path: mrp.path,
        hash: await LocalMrpFiles().calculateHash(mrp.path),
        resolution: '320x480',
        addedAt: DateTime(2026, 7, 31, 18, 5),
        keypadMode: KeypadMode.numeric,
      );
      newerMrp = await File(
        '${mrpDir.path}${Platform.pathSeparator}newer.mrp',
      ).writeAsString('NEWER-MRP');
      await database.upsert(
        path: newerMrp.path,
        hash: await LocalMrpFiles().calculateHash(newerMrp.path),
        addedAt: DateTime(2026, 7, 31, 19, 5),
      );
    });
    MrpOpenRequest? openedRequest;
    KeypadMode? openedKeypadMode;
    ValueChanged<String>? updateResolution;
    ValueChanged<KeypadMode>? updateKeypadMode;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            workingDirectoryProvider: () async => tempDir,
            pickMrpFile: () async => null,
            appStoreBuilder: _buildTestAppStore,
            playerBuilder:
                (
                  request,
                  dnsMap,
                  initialKeypadMode,
                  onResolutionChanged,
                  onKeypadModeChanged,
                ) {
                  openedRequest = request;
                  openedKeypadMode = initialKeypadMode;
                  updateResolution = onResolutionChanged;
                  updateKeypadMode = onKeypadModeChanged;
                  return const Scaffold(body: Text('播放器'));
                },
            initialMrpProvider: () async => null,
            openMrpStreamProvider: () => const Stream<MrpOpenRequest>.empty(),
            localMrpDatabase: database,
            enableStartupRemoteConfig: false,
            enableStartupUpdateCheck: false,
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 20 && find.text('demo').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(find.text('加入时间 2026-07-31 18:05'), findsOneWidget);
      expect(find.text('加入时间 2026-07-31 19:05'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('newer')).dy,
        lessThan(tester.getTopLeft(find.text('demo')).dy),
      );

      await tester.tap(find.text('demo'));
      await tester.pump();
      for (var attempt = 0; attempt < 20 && openedRequest == null; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(openedRequest?.resolution, '320x480');
      expect(openedKeypadMode, KeypadMode.numeric);

      expect(updateResolution, isNotNull);
      expect(updateKeypadMode, isNotNull);
      updateResolution!('176x220');
      updateKeypadMode!(KeypadMode.joystick);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      final record = await tester.runAsync(
        () => database.recordForPath(mrp.path),
      );
      expect(record?.resolution, '176x220');
      expect(record?.keypadMode, KeypadMode.joystick);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await database.close();
        await tempDir.delete(recursive: true);
      });
    }
  });
}

Widget _buildTestAppStore(
  String? mrpDir,
  AppStoreRunMrp onRunMrp,
  Future<void> Function(String path) onDownloaded,
) {
  return const Center(child: Text('搜索应用'));
}

Widget _buildTestPlayer(
  MrpOpenRequest request,
  String? dnsMap,
  KeypadMode initialKeypadMode,
  ValueChanged<String> onResolutionChanged,
  ValueChanged<KeypadMode> onKeypadModeChanged,
) {
  return Scaffold(body: Text(request.path));
}
