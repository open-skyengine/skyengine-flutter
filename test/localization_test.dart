import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/l10n/app_localizations.dart';
import 'package:skyengine/l10n/l10n.dart';
import 'package:skyengine/pages/changelog_page.dart';
import 'package:skyengine/pages/settings_page.dart';

void main() {
  test('Chinese system locales resolve to Chinese', () {
    expect(resolveAppLocale(const Locale('zh', 'CN')), const Locale('zh'));
    expect(resolveAppLocale(const Locale('zh', 'TW')), const Locale('zh'));
  });

  test('non-Chinese system locales resolve to English', () {
    expect(resolveAppLocale(const Locale('en', 'US')), const Locale('en'));
    expect(resolveAppLocale(const Locale('fr', 'FR')), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });

  testWidgets('Chinese system locale displays the Chinese interface', (
    tester,
  ) async {
    await tester.pumpWidget(_localizedSettingsApp(const Locale('zh', 'CN')));

    expect(find.text('模拟器设置'), findsOneWidget);
    expect(find.text('深色设置'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('Emulator settings'), findsNothing);
  });

  testWidgets('non-Chinese system locale displays the English interface', (
    tester,
  ) async {
    await tester.pumpWidget(_localizedSettingsApp(const Locale('fr', 'FR')));

    expect(find.text('Emulator settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('模拟器设置'), findsNothing);
  });

  testWidgets('bundled changelog follows the resolved interface language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(const Locale('fr', 'FR'), const ChangelogPage()),
    );
    await tester.pumpAndSettle();

    var markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, contains('Improved store interactions'));
    expect(markdown.data, isNot(contains('优化商店操作逻辑')));

    await tester.pumpWidget(
      _localizedApp(const Locale('zh', 'CN'), const ChangelogPage()),
    );
    await tester.pumpAndSettle();

    markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, contains('优化商店操作逻辑'));
  });
}

Widget _localizedSettingsApp(Locale systemLocale) {
  return _localizedApp(systemLocale, const Scaffold(body: SettingsPage()));
}

Widget _localizedApp(Locale systemLocale, Widget home) {
  return MaterialApp(
    locale: systemLocale,
    localeResolutionCallback: (locale, _) => resolveAppLocale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
