import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/pages/more_page.dart';
import 'package:skyengine/services/theme_settings.dart';

void main() {
  testWidgets('dark settings hides manual switch while following system', (
    tester,
  ) async {
    final settings = ThemeSettings.inMemory();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MorePage(themeSettings: settings)),
      ),
    );

    expect(find.text('深色设置'), findsOneWidget);
    await tester.tap(find.text('深色设置'));
    await tester.pumpAndSettle();

    expect(find.text('深色跟随系统'), findsOneWidget);
    expect(find.text('深色模式'), findsNothing);

    tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '深色跟随系统'))
        .onChanged!(false);
    await tester.pumpAndSettle();

    expect(settings.followSystem, isFalse);
    expect(settings.darkMode, isFalse);
    expect(find.text('深色模式'), findsOneWidget);

    tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '深色模式'))
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(settings.darkMode, isTrue);
    expect(settings.themeMode, ThemeMode.dark);
  });
}
