import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'pages/app_store_page.dart';
import 'pages/home_page.dart';
import 'pages/mrp_player_page.dart';
import 'services/theme_settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final ThemeSettings? themeSettings;

  const MyApp({super.key, this.themeSettings});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeSettings _themeSettings;

  @override
  void initState() {
    super.initState();
    _themeSettings = widget.themeSettings ?? ThemeSettings.instance;
    unawaited(_themeSettings.ensureLoaded());
  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSettings = widget.themeSettings ?? ThemeSettings.instance;
    if (!identical(newSettings, _themeSettings)) {
      _themeSettings = newSettings;
      unawaited(_themeSettings.ensureLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeSettings,
      builder: (context, _) {
        return MaterialApp(
          title: 'SkyEngine',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: _themeSettings.themeMode,
          home: HomePage(
            themeSettings: _themeSettings,
            workingDirectoryProvider: _getWorkingDirectory,
            pickMrpFile: _pickMrpFile,
            appStoreBuilder: (mrpDir, onRunMrp, onDownloaded) {
              return AppStorePage(
                mrpDir: mrpDir,
                onRunMrp: onRunMrp,
                onDownloaded: onDownloaded,
              );
            },
            playerBuilder: (request, dnsMap, onResolutionChanged) =>
                MrpPlayerPage(
                  mrpPath: request.path,
                  dnsMap: dnsMap,
                  screenWidth: request.screenWidth ?? 240,
                  screenHeight: request.screenHeight ?? 320,
                  onResolutionChanged: onResolutionChanged,
                ),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      ),
    );
  }
}

Future<Directory> _getWorkingDirectory() async {
  try {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir;
      }
    } else {
      return File(Platform.resolvedExecutable).parent;
    }
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    return Directory.systemTemp.createTemp('skyengine_docs_');
  }
}

Future<PickedMrpFile?> _pickMrpFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.any,
    lockParentWindow: Platform.isWindows,
  );
  if (result == null || result.files.isEmpty) return null;

  final pickedFile = result.files.first;
  final path = pickedFile.path;
  if (path == null) return null;

  return PickedMrpFile(path: path, name: pickedFile.name);
}
