import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/pages/settings_page.dart';

void main() {
  testWidgets('about page contains update and debug options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(versionLoader: () async => '1.0.1 (4)'),
        ),
      ),
    );

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('调试'), findsNothing);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.text('当前版本'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('SkyEngine'), findsNothing);
    expect(find.text('版本 1.0.1 (4)'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);
    expect(find.text('Github'), findsOneWidget);
    final orderedTitles = ['当前版本', '调试', '检查更新', 'Github'];
    final positions = orderedTitles
        .map((title) => tester.getTopLeft(find.text(title)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('check update tile starts an immediate update check', (
    tester,
  ) async {
    var checks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            onCheckForUpdate: () async {
              checks += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checks, 1);
  });

  testWidgets('version opens changelog rendered as Markdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            versionLoader: () async => '1.0.1 (4)',
            changelogLoader: () async => '## v1.0.1\n\n- 修复示例问题',
          ),
        ),
      ),
    );

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('版本 1.0.1 (4)'));
    await tester.pumpAndSettle();

    expect(find.text('更新日志'), findsOneWidget);
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.text('v1.0.1'), findsOneWidget);
    expect(find.text('修复示例问题'), findsOneWidget);
  });

  testWidgets('check update tile is disabled while checking', (tester) async {
    var checks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            checkingForUpdate: true,
            onCheckForUpdate: () async {
              checks += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('关于'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('正在检查...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checks, 0);
  });

  testWidgets('GitHub tile opens the project repository', (tester) async {
    Uri? openedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            versionLoader: () async => '1.0.1 (4)',
            externalUrlLauncher: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Github'));
    await tester.pump();

    expect(openedUri, Uri.parse('https://github.com/open-skyengine'));
  });
}
