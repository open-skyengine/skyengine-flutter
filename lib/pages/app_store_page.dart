import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/app_store_api.dart';
import '../models/mrp_resolution.dart';

typedef RunMrpCallback = void Function(String path, {String? resolution});

class AppStorePage extends StatefulWidget {
  final String? mrpDir;
  final RunMrpCallback onRunMrp;
  final Future<void> Function() onDownloaded;

  const AppStorePage({
    super.key,
    required this.mrpDir,
    required this.onRunMrp,
    required this.onDownloaded,
  });

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AppStoreClient _client = AppStoreClient(const AppStoreApiConfig());

  final List<AppStoreApp> _apps = [];
  final Map<int, double?> _downloadProgress = {};
  Timer? _searchDebounce;
  bool _loadingFirstPage = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  String? _error;
  String _activeQuery = '';
  MrpResolution _selectedResolution = kDefaultMrpResolution;
  DateTime? _lastBottomPromptAt;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _apps.clear();
      _nextPage = 1;
      _hasMore = true;
      _error = null;
      _loadingFirstPage = true;
      _activeQuery = _searchController.text.trim();
    });

    try {
      final page = await _fetchPage(1, _activeQuery);
      if (!mounted) {
        return;
      }
      setState(() {
        _apps.addAll(page.items);
        _nextPage = 2;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFirstPage = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingFirstPage || _loadingMore || !_hasMore) {
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(_nextPage, _activeQuery);
      if (!mounted) {
        return;
      }
      setState(() {
        _apps.addAll(page.items);
        _nextPage += 1;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载下一页失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<PagedResult<AppStoreApp>> _fetchPage(int page, String query) {
    if (query.isEmpty) {
      return _client.fetchApps(
        page: page,
        pageSize: _pageSize,
        resolution: _selectedResolution.label,
      );
    }
    return _client.searchApps(
      query: query,
      page: page,
      pageSize: _pageSize,
      resolution: _selectedResolution.label,
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 280) {
      unawaited(_loadMore());
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_hasMore || _loadingFirstPage || _loadingMore || _apps.isEmpty) {
      return false;
    }
    final metrics = notification.metrics;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent - 8;
    final triedPastBottom =
        notification is OverscrollNotification && notification.overscroll > 0;
    final userScrolledAtBottom =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        atBottom;
    if (triedPastBottom || userScrolledAtBottom) {
      _showBottomReached();
    }
    return false;
  }

  void _showBottomReached() {
    final now = DateTime.now();
    final last = _lastBottomPromptAt;
    if (last != null && now.difference(last).inMilliseconds < 1200) {
      return;
    }
    _lastBottomPromptAt = now;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已经到底了~')));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted && value.trim() != _activeQuery) {
        unawaited(_reload());
      }
    });
  }

  Future<void> _downloadAndRun(AppStoreApp app) async {
    final mrpDir = widget.mrpDir;
    if (mrpDir == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MRP 目录还没有准备好')));
      return;
    }
    if (_downloadProgress.containsKey(app.appId)) {
      return;
    }

    setState(() => _downloadProgress[app.appId] = null);
    var lastShownPercent = -1;
    try {
      final downloaded = await _client.downloadLatestVersion(
        app: app,
        destinationDir: Directory(mrpDir),
        resolution: _selectedResolution.label,
        onProgress: (downloadedBytes, totalBytes) {
          if (!mounted || totalBytes <= 0) {
            return;
          }
          final fraction = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          final percent = (fraction * 100).floor();
          if (percent == lastShownPercent) {
            return;
          }
          lastShownPercent = percent;
          setState(() => _downloadProgress[app.appId] = fraction);
        },
      );
      await widget.onDownloaded();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded.alreadyDownloaded
                ? '已下载，直接打开 ${downloaded.file.uri.pathSegments.last}'
                : '已下载 ${downloaded.file.uri.pathSegments.last}',
          ),
        ),
      );
      widget.onRunMrp(
        downloaded.file.path,
        resolution: _selectedResolution.label,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _downloadProgress.remove(app.appId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: RefreshIndicator(onRefresh: _reload, child: _buildBody()),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBar(
              controller: _searchController,
              hintText: '搜索应用',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: '清空',
                    onPressed: () {
                      _searchController.clear();
                      unawaited(_reload());
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              onSubmitted: (_) => unawaited(_reload()),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('分辨率', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                DropdownButton<MrpResolution>(
                  value: _selectedResolution,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final resolution in kCommonMrpResolutions)
                      DropdownMenuItem(
                        value: resolution,
                        child: Text(resolution.label),
                      ),
                  ],
                  onChanged: (resolution) {
                    if (resolution != null) {
                      _selectResolution(resolution);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectResolution(MrpResolution resolution) {
    if (resolution == _selectedResolution) {
      return;
    }
    setState(() => _selectedResolution = resolution);
    unawaited(_reload());
  }

  Widget _buildBody() {
    if (_loadingFirstPage && _apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _apps.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('加载应用商店失败\n$_error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }

    if (_apps.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Icon(Icons.search_off, size: 48),
          SizedBox(height: 16),
          Center(child: Text('没有找到应用')),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: _apps.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _apps.length) {
          return _buildFooter();
        }
        return _buildAppTile(_apps[index]);
      },
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text('已经到底了~')),
      );
    }
    return const SizedBox(height: 12);
  }

  Widget _buildAppTile(AppStoreApp app) {
    final downloading = _downloadProgress.containsKey(app.appId);
    final progress = _downloadProgress[app.appId];
    final subtitleParts = [
      if (app.manufacturer?.name.isNotEmpty ?? false) app.manufacturer!.name,
      if (app.description.isNotEmpty) app.description,
    ];
    return ListTile(
      leading: _buildIcon(app),
      title: Text(app.name.isEmpty ? app.internalName : app.name),
      subtitle: downloading
          ? _buildDownloadProgress(progress)
          : Text(
              subtitleParts.isEmpty
                  ? 'APP ID: ${app.appId}'
                  : subtitleParts.join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      isThreeLine: !downloading && subtitleParts.length > 1,
      trailing: SizedBox(
        width: 48,
        height: 48,
        child: downloading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                ),
              )
            : IconButton(
                tooltip: '下载并启动',
                onPressed: () => unawaited(_downloadAndRun(app)),
                icon: const Icon(Icons.play_arrow),
              ),
      ),
    );
  }

  Widget _buildDownloadProgress(double? progress) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            progress == null
                ? '正在下载…'
                : '正在下载 ${(progress * 100).floor()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(AppStoreApp app) {
    final iconUrl = app.iconUrl;
    if (iconUrl == null || iconUrl.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.apps));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _client.resolveAssetUri(iconUrl).toString(),
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const CircleAvatar(child: Icon(Icons.apps)),
      ),
    );
  }
}
