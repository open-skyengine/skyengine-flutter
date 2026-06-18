import 'dart:io';

import 'package:flutter/material.dart';

import 'android_mythroad_assets.dart';
import 'local_mrp_files.dart';

class PickedMrpFile {
  final String path;
  final String name;

  const PickedMrpFile({required this.path, required this.name});
}

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef MrpFilePicker = Future<PickedMrpFile?> Function();
typedef AppStoreBuilder =
    Widget Function(
      String? mrpDir,
      ValueChanged<String> onRunMrp,
      Future<void> Function() onDownloaded,
    );
typedef MrpPlayerBuilder = Widget Function(String mrpPath);

Directory mrpDirectoryForWorkDir(Directory workDir) {
  return Directory('${workDir.path}${Platform.pathSeparator}mythroad');
}

class HomePage extends StatefulWidget {
  final DocumentsDirectoryProvider workingDirectoryProvider;
  final MrpFilePicker pickMrpFile;
  final AppStoreBuilder appStoreBuilder;
  final MrpPlayerBuilder playerBuilder;

  const HomePage({
    super.key,
    required this.workingDirectoryProvider,
    required this.pickMrpFile,
    required this.appStoreBuilder,
    required this.playerBuilder,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _MrpRemovalAction { removeFromList, deleteFile }

class _HomePageState extends State<HomePage> {
  final LocalMrpFiles _localFiles = LocalMrpFiles();
  List<FileSystemEntity> _mrpFiles = [];
  String? _mrpDir;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMrpFiles();
  }

  Future<void> _loadMrpFiles() async {
    final dir = await widget.workingDirectoryProvider();
    final mrpDir = _mrpDirectoryForWorkDir(dir);
    if (!await mrpDir.exists()) {
      await mrpDir.create(recursive: true);
    }
    try {
      await AndroidMythroadAssets.ensureSystem(mrpDir);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to prepare Mythroad system assets: $error');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _mrpDir = mrpDir.path;
    });
    await _refreshFileList();
  }

  Directory _mrpDirectoryForWorkDir(Directory workDir) {
    return mrpDirectoryForWorkDir(workDir);
  }

  Future<void> _refreshFileList() async {
    if (_mrpDir == null) return;
    final files = _localFiles.scan(_mrpDir!);
    if (!mounted) {
      return;
    }
    setState(() {
      _mrpFiles = files;
    });
  }

  Future<void> _pickAndCopyMrp() async {
    if (_mrpDir == null) return;
    final pickedFile = await widget.pickMrpFile();
    if (pickedFile == null) return;

    final source = File(pickedFile.path);
    final dest = File('$_mrpDir/${pickedFile.name}');
    await source.copy(dest.path);
    _localFiles.unhide(dest.path);
    await _refreshFileList();
  }

  void _runMrp(String path) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => widget.playerBuilder(path)));
  }

  Future<void> _confirmRemoveMrp(FileSystemEntity entity) async {
    final name = _fileName(entity.path);
    final action = await showDialog<_MrpRemovalAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('删除 $name？'),
          content: const Text('是否同步删除文件？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MrpRemovalAction.removeFromList),
              child: const Text('仅从列表移除'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MrpRemovalAction.deleteFile),
              child: const Text('同步删除文件'),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _MrpRemovalAction.removeFromList:
        _removeMrpFromList(entity.path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已从列表移除：$name')));
      case _MrpRemovalAction.deleteFile:
        await _deleteMrpFile(entity.path);
    }
  }

  void _removeMrpFromList(String path) {
    final key = _fileListKey(path);
    setState(() {
      _localFiles.hide(path);
      _mrpFiles = _mrpFiles
          .where((entity) => _localFiles.fileListKey(entity.path) != key)
          .toList();
    });
  }

  Future<void> _deleteMrpFile(String path) async {
    final name = _fileName(path);

    try {
      final existed = await _localFiles.deleteFile(path);
      await _refreshFileList();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existed ? '已删除文件：$name' : '文件不存在，已从列表移除：$name')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  String _fileListKey(String path) => _localFiles.fileListKey(path);

  String _fileName(String path) => _localFiles.fileName(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MrpOid')),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildLocalList(),
          widget.appStoreBuilder(_mrpDir, _runMrp, _refreshFileList),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: '本地'),
          NavigationDestination(icon: Icon(Icons.storefront), label: '商店'),
        ],
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _pickAndCopyMrp,
              tooltip: '导入 MRP 文件',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLocalList() {
    if (_mrpDir == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mrpFiles.isEmpty) {
      return const Center(child: Text('没有 MRP 文件，点击右下角按钮导入'));
    }

    return ListView.builder(
      itemCount: _mrpFiles.length,
      itemBuilder: (context, index) {
        final file = _mrpFiles[index];
        final name = _fileName(file.path);
        return ListTile(
          leading: const Icon(Icons.videogame_asset),
          title: Text(name),
          subtitle: Text(file.path),
          trailing: IconButton(
            tooltip: '删除',
            onPressed: () => _confirmRemoveMrp(file),
            icon: const Icon(Icons.delete_outline),
          ),
          onTap: () => _runMrp(file.path),
        );
      },
    );
  }
}
