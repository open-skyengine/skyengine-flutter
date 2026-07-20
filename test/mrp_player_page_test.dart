import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/models/mrp_resolution.dart';
import 'package:skyengine/pages/mrp_player_page.dart';

void main() {
  test('MRP player title uses package metadata name', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_player_title_test_',
    );

    try {
      final mrp = await _writeMrpHeader(
        tempDir,
        name: '冒泡幻想',
        fileName: 'fallback.mrp',
      );

      expect(mrpPlayerTitleForPath(mrp.path), '冒泡幻想');
      expect(mrpPlayerTitleForPath(mrp.path, title: '商店标题'), '商店标题');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('MRP player title falls back to file name', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_player_title_test_',
    );

    try {
      final file = File('${tempDir.path}${Platform.pathSeparator}普通游戏.mrp');
      await file.writeAsString('not-an-mrp-header');

      expect(mrpPlayerTitleForPath(file.path), '普通游戏');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('common MRP resolutions include supported sizes', () {
    expect(
      kCommonMrpResolutions.map((resolution) => resolution.label),
      containsAll([
        '128x160',
        '176x220',
        '240x400',
        '320x240',
        '320x480',
        '480x800',
      ]),
    );
  });

  testWidgets('keyboard dialog includes all keypad modes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MrpPlayerPage(mrpPath: 'missing.mrp')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('切换键盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('方向键'), findsOneWidget);
    expect(find.text('摇杆'), findsOneWidget);
    expect(find.text('9键'), findsOneWidget);
    expect(find.text('全键'), findsOneWidget);
    expect(find.text('无键盘'), findsOneWidget);
  });

  testWidgets('switching resolution reports the selected resolution', (
    tester,
  ) async {
    final resolutions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MrpPlayerPage(
          mrpPath: 'missing.mrp',
          onResolutionChanged: resolutions.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('切换分辨率'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('320x480'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(resolutions, ['320x480']);
  });

  testWidgets('landscape hides header but keeps back and more controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: MrpPlayerPage(mrpPath: 'missing.mrp')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
  });

  testWidgets('player close pops route without waiting for another frame', (
    tester,
  ) async {
    final observer = _TestNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                PageRouteBuilder(
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (_, _, _) =>
                      MrpPlayerPage(mrpPath: 'missing.mrp'),
                ),
              );
            },
            child: const Text('打开播放器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开播放器'));
    await tester.pump();

    final poppedBeforeClose = observer.popCount;
    await tester.tap(find.byKey(const ValueKey('mrp-player-back')));
    await tester.idle();

    expect(observer.popCount, poppedBeforeClose + 1);

    // Let Navigator remove the popped route before flutter_tester finalizes.
    await tester.pumpAndSettle();
  });
}

class _TestNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

Future<File> _writeMrpHeader(
  Directory dir, {
  required String name,
  required String fileName,
}) async {
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  final bytes = List<int>.filled(208, 0);
  bytes[0] = 0x4d;
  bytes[1] = 0x52;
  bytes[2] = 0x50;
  bytes[3] = 0x47;
  _writeGbkField(bytes, 28, 24, name);
  await file.writeAsBytes(bytes);
  return file;
}

void _writeGbkField(List<int> bytes, int offset, int length, String value) {
  final encoded = gbk.encode(value).take(length).toList();
  for (var i = 0; i < encoded.length; i++) {
    bytes[offset + i] = encoded[i];
  }
}
