import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'android_app_update.dart';
import 'android_mythroad_assets.dart';
import 'android_mrp_open.dart';
import 'app_store_api.dart';
import 'debug_page.dart';
import 'local_mrp_files.dart';

class PickedMrpFile {
  final String path;
  final String name;

  const PickedMrpFile({required this.path, required this.name});
}

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef MrpFilePicker = Future<PickedMrpFile?> Function();
typedef InitialMrpProvider = Future<String?> Function();
typedef OpenMrpStreamProvider = Stream<String> Function();
typedef AppStoreBuilder =
    Widget Function(
      String? mrpDir,
      ValueChanged<String> onRunMrp,
      Future<void> Function() onDownloaded,
    );
typedef MrpPlayerBuilder = Widget Function(String mrpPath, String? dnsMap);

Directory mrpDirectoryForWorkDir(Directory workDir) {
  return Directory('${workDir.path}${Platform.pathSeparator}mythroad');
}

class HomePage extends StatefulWidget {
  final DocumentsDirectoryProvider workingDirectoryProvider;
  final MrpFilePicker pickMrpFile;
  final AppStoreBuilder appStoreBuilder;
  final MrpPlayerBuilder playerBuilder;
  final InitialMrpProvider initialMrpProvider;
  final OpenMrpStreamProvider openMrpStreamProvider;
  final bool enableStartupRemoteConfig;
  final bool enableStartupUpdateCheck;

  const HomePage({
    super.key,
    required this.workingDirectoryProvider,
    required this.pickMrpFile,
    required this.appStoreBuilder,
    required this.playerBuilder,
    this.initialMrpProvider = _defaultInitialMrpProvider,
    this.openMrpStreamProvider = _defaultOpenMrpStreamProvider,
    this.enableStartupRemoteConfig = true,
    this.enableStartupUpdateCheck = true,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

Future<String?> _defaultInitialMrpProvider() {
  return const AndroidMrpOpen().getInitialMrp();
}

Stream<String> _defaultOpenMrpStreamProvider() {
  return const AndroidMrpOpen().openMrps();
}

enum _MrpRemovalAction { removeFromList, deleteFile }

enum _LocalMrpMenuAction { details }

class _HomePageState extends State<HomePage> {
  final LocalMrpFiles _localFiles = LocalMrpFiles();
  final AppStoreClient _appStoreClient = AppStoreClient(
    const AppStoreApiConfig(),
  );
  final AndroidAppUpdate _androidAppUpdate = const AndroidAppUpdate();
  List<LocalMrpFile> _mrpFiles = [];
  String? _mrpDir;
  Directory? _workDir;
  String? _dnsMap;
  int _selectedIndex = 0;
  bool _checkingUpdate = false;
  bool _downloadingUpdate = false;
  bool _updatePromptShown = false;
  bool _openedInitialMrp = false;
  StreamSubscription<String>? _mrpOpenSubscription;

  @override
  void initState() {
    super.initState();
    _loadMrpFiles();
    _mrpOpenSubscription = widget.openMrpStreamProvider().listen(
      _openImportedMrp,
    );
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
      _workDir = dir;
      _mrpDir = mrpDir.path;
    });
    if (widget.enableStartupRemoteConfig) {
      unawaited(_refreshRemoteConfig());
    }
    if (widget.enableStartupUpdateCheck) {
      unawaited(_checkAppUpdate());
    }
    await _refreshFileList();
    await _openInitialMrp();
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

  Future<void> _openInitialMrp() async {
    if (_openedInitialMrp) {
      return;
    }
    _openedInitialMrp = true;
    final path = await widget.initialMrpProvider();
    if (path != null && path.isNotEmpty) {
      await _openImportedMrp(path);
    }
  }

  Future<void> _openImportedMrp(String path) async {
    await _refreshFileList();
    if (!mounted) {
      return;
    }
    _runMrp(path);
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => widget.playerBuilder(path, _dnsMap)),
    );
  }

  Future<void> _refreshRemoteConfig() async {
    try {
      final config = await _appStoreClient.fetchConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _dnsMap = _dnsMapFromHosts(config.hosts);
      });
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to refresh app config: $error');
    }
  }

  Future<void> _checkAppUpdate() async {
    if (!Platform.isAndroid || _checkingUpdate || _updatePromptShown) {
      return;
    }
    _checkingUpdate = true;
    try {
      final versionCode = await _androidAppUpdate.getVersionCode();
      final update = await _appStoreClient.checkEmulatorUpdate(
        versionCode: versionCode,
      );
      final latest = update.latest;
      if (!mounted || !update.updateAvailable || latest == null) {
        return;
      }
      _updatePromptShown = true;
      await _showAppUpdateDialog(latest);
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('Failed to check app update: $error');
    } finally {
      _checkingUpdate = false;
    }
  }

  Future<void> _showAppUpdateDialog(AppStoreEmulatorVersion version) async {
    final forceUpdate = version.forceUpdate;
    final shouldDownload = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        final title = version.version.isEmpty
            ? '发现新版本'
            : '发现新版本 ${version.version}';
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Text(
                version.changelog.isEmpty ? '是否下载并安装更新？' : version.changelog,
              ),
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('稍后'),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('更新'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldDownload == true) {
      await _downloadAndInstallUpdate(version);
    }
  }

  Future<void> _downloadAndInstallUpdate(
    AppStoreEmulatorVersion version,
  ) async {
    final workDir = _workDir;
    if (workDir == null || _downloadingUpdate) {
      return;
    }
    Future<void> pendingProgressNotification = Future<void>.value();
    var canShowDownloadNotification = false;
    var downloadStarted = false;
    try {
      canShowDownloadNotification = await _prepareDownloadNotification();
      if (!mounted) {
        return;
      }

      setState(() => _downloadingUpdate = true);
      downloadStarted = true;

      final updatesDir = Directory(
        '${workDir.path}${Platform.pathSeparator}updates',
      );
      var lastNotifiedPercent = -1;
      var lastNotifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
      Future<void> notifyProgress(int downloadedBytes, int totalBytes) async {
        if (!canShowDownloadNotification) {
          return;
        }
        final now = DateTime.now();
        final percent = totalBytes > 0
            ? (downloadedBytes * 100 ~/ totalBytes).clamp(0, 100)
            : -1;
        if (percent == lastNotifiedPercent &&
            now.difference(lastNotifiedAt) < const Duration(seconds: 1)) {
          return;
        }
        lastNotifiedPercent = percent;
        lastNotifiedAt = now;
        await _androidAppUpdate.showDownloadProgress(
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        );
      }

      void queueProgressNotification(int downloadedBytes, int totalBytes) {
        if (!canShowDownloadNotification) {
          return;
        }
        pendingProgressNotification = pendingProgressNotification
            .then((_) => notifyProgress(downloadedBytes, totalBytes))
            .catchError((Object error, StackTrace stackTrace) {
              debugPrintStack(stackTrace: stackTrace);
              debugPrint('Failed to update download notification: $error');
            });
        unawaited(pendingProgressNotification);
      }

      queueProgressNotification(0, version.fileSize);
      final downloaded = await _appStoreClient.downloadEmulatorVersion(
        version: version,
        destinationDir: updatesDir,
        onProgress: queueProgressNotification,
      );
      await pendingProgressNotification;
      if (downloaded.alreadyDownloaded) {
        if (canShowDownloadNotification) {
          await _androidAppUpdate.cancelDownloadNotification();
        }
      } else if (canShowDownloadNotification) {
        await _androidAppUpdate.showDownloadComplete(downloaded.file.path);
      }
      try {
        await _androidAppUpdate.installApk(downloaded.file.path);
      } on PlatformException catch (error) {
        if (error.code == 'INSTALL_PERMISSION_REQUIRED') {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message ?? '允许后会自动继续安装')),
          );
          return;
        }
        rethrow;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已打开安装程序')));
    } catch (e) {
      await pendingProgressNotification;
      if (canShowDownloadNotification) {
        await _androidAppUpdate.showDownloadFailed(e.toString());
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败：$e')));
      if (version.forceUpdate) {
        unawaited(_showAppUpdateDialog(version));
      }
    } finally {
      if (downloadStarted && mounted) {
        setState(() => _downloadingUpdate = false);
      }
    }
  }

  String? _dnsMapFromHosts(List<AppStoreHostMapping> hosts) {
    final entries = hosts
        .where((host) => host.domain.isNotEmpty && host.ip.isNotEmpty)
        .map((host) => '${host.domain}->${host.ip}')
        .toList();
    return entries.isEmpty ? null : entries.join(';');
  }

  Future<bool> _prepareDownloadNotification() async {
    var status = await _androidAppUpdate.ensureDownloadNotificationPermission();
    if (status.canShow) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    final openSettings = await _showDownloadNotificationPermissionDialog(
      status,
    );
    if (openSettings != true || !mounted) {
      return false;
    }

    final resumed = _waitForNextAppResume();
    await _androidAppUpdate.openDownloadNotificationSettings();
    if (!mounted) {
      return false;
    }

    await resumed;
    if (!mounted) {
      return false;
    }

    status = await _androidAppUpdate.ensureDownloadNotificationPermission();
    if (status.canShow) {
      return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_downloadNotificationMessage(status))),
      );
    }
    return false;
  }

  Future<bool?> _showDownloadNotificationPermissionDialog(
    DownloadNotificationPermissionStatus status,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('开启通知'),
          content: Text(_downloadNotificationMessage(status)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: status.canOpenSettings
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: const Text('去开启'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _waitForNextAppResume() {
    final completer = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
        listener.dispose();
      },
    );
    return completer.future;
  }

  String _downloadNotificationMessage(
    DownloadNotificationPermissionStatus status,
  ) {
    return status.message.isEmpty ? '开启通知后，下载进度会显示在通知栏' : status.message;
  }

  @override
  void dispose() {
    _mrpOpenSubscription?.cancel();
    _appStoreClient.close();
    super.dispose();
  }

  Future<void> _confirmRemoveMrp(LocalMrpFile file) async {
    final name = file.displayName;
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
        _removeMrpFromList(file.path);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已从列表移除：$name')));
      case _MrpRemovalAction.deleteFile:
        await _deleteMrpFile(file.path);
    }
  }

  void _removeMrpFromList(String path) {
    final key = _fileListKey(path);
    setState(() {
      _localFiles.hide(path);
      _mrpFiles = _mrpFiles
          .where((file) => _localFiles.fileListKey(file.path) != key)
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

  Future<void> _showLocalMrpMenu(
    LocalMrpFile file,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_LocalMrpMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: _LocalMrpMenuAction.details,
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('查看详情'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _LocalMrpMenuAction.details:
        await _showMrpDetails(file);
    }
  }

  Future<void> _showMrpDetails(LocalMrpFile file) async {
    final metadata = file.metadata;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(file.displayName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('文件名', file.fileName),
                _detailRow('路径', file.path),
                _detailRow('厂商', _emptyAsDash(metadata.vendor)),
                _detailRow('版本号', metadata.version?.toString() ?? '-'),
                _detailRow('包内文件名', _emptyAsDash(metadata.fileHeaderName)),
                _detailRow('应用 ID', metadata.appId?.toString() ?? '-'),
                _detailRow(
                  '分辨率',
                  metadata.screenWidth == null || metadata.screenHeight == null
                      ? '-'
                      : '${metadata.screenWidth} x ${metadata.screenHeight}',
                ),
                _detailRow('描述', _emptyAsDash(metadata.description)),
                _detailRow('MRP 头', metadata.validHeader ? '有效' : '未识别'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  String _emptyAsDash(String value) => value.isEmpty ? '-' : value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SkyEngine')),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildLocalList(),
          Stack(
            children: [
              widget.appStoreBuilder(_mrpDir, _runMrp, _refreshFileList),
              if (_downloadingUpdate)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          const DebugPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: '本地'),
          NavigationDestination(icon: Icon(Icons.storefront), label: '商店'),
          NavigationDestination(icon: Icon(Icons.bug_report), label: '调试'),
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
        Offset? longPressPosition;
        return GestureDetector(
          onLongPressStart: (details) {
            longPressPosition = details.globalPosition;
          },
          onLongPress: () {
            _showLocalMrpMenu(file, longPressPosition ?? Offset.zero);
          },
          child: ListTile(
            leading: const Icon(Icons.videogame_asset),
            title: Text(
              file.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              file.vendorAndVersion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '删除',
              onPressed: () => _confirmRemoveMrp(file),
              icon: const Icon(Icons.delete_outline),
            ),
            onTap: () => _runMrp(file.path),
          ),
        );
      },
    );
  }
}
