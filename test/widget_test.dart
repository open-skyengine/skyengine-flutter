// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mrpoid/main.dart';

void main() {
  testWidgets('Home shows local and store tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    expect(find.text('MrpOid'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('商店'), findsOneWidget);

    await tester.tap(find.text('商店'));
    await tester.pump();

    expect(find.text('搜索应用'), findsOneWidget);
  });
}
