import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'mrp_player_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MrpOid',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FileSystemEntity> _mrpFiles = [];
  String? _mrpDir;

  @override
  void initState() {
    super.initState();
    _loadMrpFiles();
  }

  Future<void> _loadMrpFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final mrpDir = Directory('${dir.path}/mythroad');
    if (!await mrpDir.exists()) {
      await mrpDir.create(recursive: true);
    }
    setState(() {
      _mrpDir = mrpDir.path;
    });
    await _refreshFileList();
  }

  Future<void> _refreshFileList() async {
    if (_mrpDir == null) return;
    final dir = Directory(_mrpDir!);
    final files = await dir
        .list()
        .where((e) => e.path.toLowerCase().endsWith('.mrp'))
        .toList();
    setState(() {
      _mrpFiles = files;
    });
  }

  Future<void> _pickAndCopyMrp() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    final source = File(pickedFile.path!);
    final dest = File('$_mrpDir/${pickedFile.name}');
    await source.copy(dest.path);
    await _refreshFileList();
  }

  void _runMrp(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MrpPlayerPage(mrpPath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MrpOid'),
      ),
      body: _mrpFiles.isEmpty
          ? const Center(
              child: Text('没有 MRP 文件，点击右下角按钮导入'),
            )
          : ListView.builder(
              itemCount: _mrpFiles.length,
              itemBuilder: (context, index) {
                final file = _mrpFiles[index];
                final name = file.path.split(Platform.pathSeparator).last;
                return ListTile(
                  leading: const Icon(Icons.videogame_asset),
                  title: Text(name),
                  subtitle: Text(file.path),
                  onTap: () => _runMrp(file.path),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndCopyMrp,
        tooltip: '导入 MRP 文件',
        child: const Icon(Icons.add),
      ),
    );
  }
}
