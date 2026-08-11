import '../l10n/app_localizations.dart';

enum KeypadMode { directional, joystick, numeric, full, none }

const defaultKeypadMode = KeypadMode.directional;

extension KeypadModeDisplay on KeypadMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    KeypadMode.directional => l10n.directionalKeys,
    KeypadMode.joystick => l10n.joystick,
    KeypadMode.numeric => l10n.numericKeypad,
    KeypadMode.full => l10n.fullKeypad,
    KeypadMode.none => l10n.noKeypad,
  };
}

KeypadMode? parseKeypadMode(String? value) {
  for (final mode in KeypadMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return null;
}
