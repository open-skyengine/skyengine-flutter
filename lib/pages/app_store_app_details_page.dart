import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/mrp_resolution.dart';
import '../services/app_store_api.dart';
import '../widgets/app_store_app_tile.dart';

typedef RunMrpCallback = void Function(String path, {String? resolution});

class AppStoreAppDetailsPage extends StatefulWidget {
  const AppStoreAppDetailsPage({
    super.key,
    required this.app,
    required this.client,
    required this.mrpDir,
    required this.onRunMrp,
    required this.onDownloaded,
    this.initialResolution,
  });

  final AppStoreApp app;
  final AppStoreClient client;
  final String? mrpDir;
  final RunMrpCallback onRunMrp;
  final Future<void> Function(String path) onDownloaded;
  final String? initialResolution;

  @override
  State<AppStoreAppDetailsPage> createState() => _AppStoreAppDetailsPageState();
}

class _AppStoreAppDetailsPageState extends State<AppStoreAppDetailsPage> {
  List<AppStoreVersion> _versions = const [];
  String? _selectedResolution;
  String? _error;
  bool _loading = true;
  bool _downloading = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _selectedResolution = widget.initialResolution;
    unawaited(_loadVersions());
  }

  Future<void> _loadVersions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.client.fetchVersions(
        appId: widget.app.appId,
        pageSize: 20,
        resolution: widget.initialResolution,
      );
      if (!mounted) {
        return;
      }
      final resolutions = _packageResolutions(result.items);
      setState(() {
        _versions = result.items;
        if (_selectedResolution == null && resolutions.isNotEmpty) {
          _selectedResolution = resolutions.first;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _downloadAndRun() async {
    final directory = widget.mrpDir;
    if (directory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MRP 目录还没有准备好')));
      return;
    }
    if (_downloading) {
      return;
    }

    final resolution = _selectedResolution ?? kDefaultMrpResolution.label;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    var lastShownPercent = -1;
    try {
      final downloaded = await widget.client.downloadLatestVersion(
        app: widget.app,
        destinationDir: Directory(directory),
        resolution: resolution,
        onProgress: (downloadedBytes, totalBytes) {
          if (!mounted || totalBytes <= 0) {
            return;
          }
          final value = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          final percent = (value * 100).floor();
          if (percent != lastShownPercent) {
            lastShownPercent = percent;
            setState(() => _downloadProgress = value);
          }
        },
      );
      await widget.onDownloaded(downloaded.file.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded.alreadyDownloaded ? '已下载，正在打开' : '下载完成，正在打开',
          ),
        ),
      );
      widget.onRunMrp(downloaded.file.path, resolution: resolution);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final displayName = app.name.isEmpty ? app.internalName : app.name;
    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStoreAppIcon(app: app, client: widget.client, size: 72),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(app.manufacturer?.name ?? '未知厂商'),
                      const SizedBox(height: 8),
                      Text(_typeLabel(app.type)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _detailRow('APP ID', '${app.appId}'),
          if (app.createdAt != null)
            _detailRow('发布时间', _formatDateTime(app.createdAt!)),
          if (app.description.trim().isNotEmpty)
            _detailRow('应用介绍', app.description.trim()),
          const SizedBox(height: 20),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '版本与分辨率',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildVersionSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: FilledButton.icon(
              onPressed: _loading || _versions.isEmpty || _downloading
                  ? null
                  : _downloadAndRun,
              icon: _downloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_downloading ? _downloadLabel() : '下载并运行'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Text('版本加载失败：$_error'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadVersions,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_versions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Text('暂无可用版本'),
      );
    }

    final latest = _versions.first;
    final resolutions = _packageResolutions(_versions);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最新版本 ${latest.version.isEmpty ? latest.versionCode : latest.version}',
          ),
          if (latest.publishedAt != null) ...[
            const SizedBox(height: 4),
            Text('发布于 ${_formatDateTime(latest.publishedAt!)}'),
          ],
          if (latest.changelog.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(latest.changelog.trim()),
          ],
          if (resolutions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final resolution in resolutions)
                  ChoiceChip(
                    label: Text(resolution),
                    selected: _selectedResolution == resolution,
                    onSelected: (_) {
                      setState(() => _selectedResolution = resolution);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }

  String _downloadLabel() {
    final progress = _downloadProgress;
    return progress == null ? '正在下载' : '正在下载 ${(progress * 100).floor()}%';
  }
}

List<String> _packageResolutions(List<AppStoreVersion> versions) {
  final values = <String>{};
  for (final version in versions) {
    for (final package in version.packages) {
      final resolution = package.resolution?.trim();
      if (resolution != null && resolution.isNotEmpty) {
        values.add(resolution);
      }
    }
  }
  return values.toList();
}

String _typeLabel(String type) {
  return switch (type) {
    'game' => '游戏',
    'software' => '软件',
    _ => '应用',
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
