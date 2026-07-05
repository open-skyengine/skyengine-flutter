import 'package:flutter/material.dart';

import 'debug_page.dart';
import 'emulator_settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

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
