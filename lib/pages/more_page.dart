import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/theme_settings.dart';
import 'about_page.dart';
import 'changelog_page.dart';
import 'dark_mode_settings_page.dart';
import 'emulator_settings_page.dart';

export 'about_page.dart';

class MorePage extends StatelessWidget {
  final ThemeSettings? themeSettings;
  final Future<void> Function()? onCheckForUpdate;
  final bool checkingForUpdate;
  final ValueListenable<bool>? checkingForUpdateListenable;
  final AppVersionLoader? versionLoader;
  final ChangelogLoader? changelogLoader;
  final ExternalUrlLauncher? externalUrlLauncher;

  const MorePage({
    super.key,
    this.themeSettings,
    this.onCheckForUpdate,
    this.checkingForUpdate = false,
    this.checkingForUpdateListenable,
    this.versionLoader,
    this.changelogLoader,
    this.externalUrlLauncher,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('模拟器设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmulatorSettingsPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: const Text('深色设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DarkModeSettingsPage(
                  settings: themeSettings ?? ThemeSettings.instance,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AboutPage(
                  onCheckForUpdate: onCheckForUpdate,
                  checkingForUpdate: checkingForUpdate,
                  checkingForUpdateListenable: checkingForUpdateListenable,
                  versionLoader: versionLoader,
                  changelogLoader: changelogLoader,
                  externalUrlLauncher: externalUrlLauncher,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
