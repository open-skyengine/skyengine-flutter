import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrpoid/home_page.dart';

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
