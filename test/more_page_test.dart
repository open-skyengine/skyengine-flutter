import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/pages/more_page.dart';

void main() {
  testWidgets('check update tile starts an immediate update check', (
    tester,
  ) async {
    var checks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MorePage(
            onCheckForUpdate: () async {
              checks += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checks, 1);
  });

  testWidgets('check update tile is disabled while checking', (tester) async {
    var checks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MorePage(
            checkingForUpdate: true,
            onCheckForUpdate: () async {
              checks += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('正在检查...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checks, 0);
  });
}
