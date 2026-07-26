import 'dart:async';

import 'package:flutter/material.dart';

import '../services/theme_settings.dart';
import 'dark_mode_settings_page.dart';
import 'debug_page.dart';
import 'emulator_settings_page.dart';

class MorePage extends StatelessWidget {
  final ThemeSettings? themeSettings;
  final Future<void> Function()? onCheckForUpdate;
  final bool checkingForUpdate;

  const MorePage({
    super.key,
    this.themeSettings,
    this.onCheckForUpdate,
    this.checkingForUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('模拟器设置'),
          subtitle: const Text('内存大小等运行参数'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmulatorSettingsPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.system_update_alt),
          title: const Text('检查更新'),
          subtitle: checkingForUpdate ? const Text('正在检查...') : null,
          trailing: checkingForUpdate
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onTap: checkingForUpdate || onCheckForUpdate == null
              ? null
              : () => unawaited(onCheckForUpdate!()),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('调试'),
          subtitle: const Text('按键测试等调试工具'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DebugToolsPage()),
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
      ],
    );
  }
}

class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('调试')),
      body: const DebugPage(),
    );
  }
}
