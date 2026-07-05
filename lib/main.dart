import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'pages/app_store_page.dart';
import 'pages/home_page.dart';
import 'pages/mrp_player_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyEngine',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomePage(
        workingDirectoryProvider: _getWorkingDirectory,
        pickMrpFile: _pickMrpFile,
        appStoreBuilder: (mrpDir, onRunMrp, onDownloaded) {
          return AppStorePage(
            mrpDir: mrpDir,
            onRunMrp: onRunMrp,
            onDownloaded: onDownloaded,
          );
        },
        playerBuilder: (request, dnsMap) => MrpPlayerPage(
          mrpPath: request.path,
          dnsMap: dnsMap,
          screenWidth: request.screenWidth ?? 240,
          screenHeight: request.screenHeight ?? 320,
        ),
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
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result == null || result.files.isEmpty) return null;

  final pickedFile = result.files.first;
  final path = pickedFile.path;
  if (path == null) return null;

  return PickedMrpFile(path: path, name: pickedFile.name);
}
