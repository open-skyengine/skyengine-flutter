import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/theme_settings.dart';

class DarkModeSettingsPage extends StatefulWidget {
  final ThemeSettings settings;

  const DarkModeSettingsPage({super.key, required this.settings});

  @override
  State<DarkModeSettingsPage> createState() => _DarkModeSettingsPageState();
}

class _DarkModeSettingsPageState extends State<DarkModeSettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    unawaited(widget.settings.ensureLoaded());
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.darkModeSettings)),
      body: !widget.settings.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.brightness_auto),
                  title: Text(l10n.darkModeFollowSystem),
                  value: widget.settings.followSystem,
                  onChanged: (value) {
                    unawaited(
                      widget.settings.setFollowSystem(
                        value,
                        currentBrightness: Theme.of(context).brightness,
                      ),
                    );
                  },
                ),
                if (!widget.settings.followSystem)
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode),
                    title: Text(l10n.darkMode),
                    value: widget.settings.darkMode,
                    onChanged: (value) {
                      unawaited(widget.settings.setDarkMode(value));
                    },
                  ),
              ],
            ),
    );
  }
}
