import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/emulator_settings.dart';

class EmulatorSettingsPage extends StatefulWidget {
  const EmulatorSettingsPage({super.key});

  @override
  State<EmulatorSettingsPage> createState() => _EmulatorSettingsPageState();
}

class _EmulatorSettingsPageState extends State<EmulatorSettingsPage> {
  final EmulatorSettings _settings = EmulatorSettings.instance;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    unawaited(
      _settings.ensureLoaded().then((_) {
        if (mounted) {
          setState(() => _loaded = true);
        }
      }),
    );
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
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
      appBar: AppBar(title: Text(l10n.emulatorSettings)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: Text(l10n.memorySize),
                  subtitle: Text(l10n.memorySizeDescription),
                  trailing: DropdownButton<int>(
                    value: _settings.memoryMb,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final mb in kEmulatorMemoryOptionsMb)
                        DropdownMenuItem(value: mb, child: Text('${mb}MB')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        unawaited(_settings.setMemoryMb(value));
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
