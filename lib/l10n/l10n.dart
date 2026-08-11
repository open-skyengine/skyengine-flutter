import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_zh.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsZh();
}

Locale resolveAppLocale(Locale? systemLocale) {
  return systemLocale?.languageCode.toLowerCase() == 'zh'
      ? const Locale('zh')
      : const Locale('en');
}
