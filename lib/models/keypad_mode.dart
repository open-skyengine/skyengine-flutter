enum KeypadMode { directional, joystick, numeric, full, none }

const defaultKeypadMode = KeypadMode.directional;

extension KeypadModeDisplay on KeypadMode {
  String get label => switch (this) {
    KeypadMode.directional => '方向键',
    KeypadMode.joystick => '摇杆',
    KeypadMode.numeric => '9键',
    KeypadMode.full => '全键',
    KeypadMode.none => '无键盘',
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
