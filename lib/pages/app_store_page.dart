import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_store_api.dart';
import '../services/search_history.dart';
import '../widgets/app_store_app_tile.dart';
import 'app_store_app_details_page.dart';
import 'app_store_search_page.dart';

enum _StoreSection {
  latest('最新', null),
  software('软件', 'software'),
  game('游戏', 'game');

  const _StoreSection(this.label, this.apiType);

  final String label;
  final String? apiType;
}

class AppStorePage extends StatefulWidget {
  const AppStorePage({
    super.key,
    required this.mrpDir,
    required this.onRunMrp,
    required this.onDownloaded,
    this.client,
    this.searchHistory,
  });

  final String? mrpDir;
  final RunMrpCallback onRunMrp;
  final Future<void> Function(String path) onDownloaded;
  final AppStoreClient? client;
  final SearchHistoryService? searchHistory;

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

class _AppStorePageState extends State<AppStorePage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  late final AppStoreClient _client;
  late final SearchHistoryService _searchHistory;
  late final bool _ownsClient;
  late final bool _ownsSearchHistory;
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<AppStoreApp> _apps = [];

  _StoreSection _section = _StoreSection.latest;
  bool _loadingFirstPage = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  int _requestGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? AppStoreClient(const AppStoreApiConfig());
    _ownsSearchHistory = widget.searchHistory == null;
    _searchHistory = widget.searchHistory ?? SearchHistoryService();
    _tabController = TabController(
      length: _StoreSection.values.length,
      vsync: this,
    );
    _scrollController.addListener(_onScroll);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    if (_ownsClient) {
      _client.close();
    }
    if (_ownsSearchHistory) {
      unawaited(_searchHistory.close());
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_requestGeneration;
    setState(() {
      _apps.clear();
      _nextPage = 1;
      _hasMore = true;
      _error = null;
      _loadingFirstPage = true;
    });
    try {
      final result = await _fetchPage(1);
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _apps.addAll(result.items);
        _nextPage = 2;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _error = error.toString();
          _hasMore = false;
        });
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingFirstPage = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingFirstPage || _loadingMore || !_hasMore) {
      return;
    }
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetchPage(_nextPage);
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _apps.addAll(result.items);
        _nextPage += 1;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载下一页失败：$error')));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<PagedResult<AppStoreApp>> _fetchPage(int page) {
    return _client.fetchApps(
      page: page,
      pageSize: _pageSize,
      resolution: null,
      type: _section.apiType,
      sortBy: 'created_at',
      sortOrder: 'desc',
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 280) {
      unawaited(_loadMore());
    }
  }

  void _selectSection(int index) {
    final section = _StoreSection.values[index];
    if (section == _section) {
      return;
    }
    setState(() => _section = section);
    unawaited(_reload());
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AppStoreSearchPage(
          client: _client,
          searchHistory: _searchHistory,
          mrpDir: widget.mrpDir,
          onRunMrp: widget.onRunMrp,
          onDownloaded: widget.onDownloaded,
        ),
      ),
    );
  }

  void _openDetails(AppStoreApp app) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AppStoreAppDetailsPage(
          app: app,
          client: _client,
          mrpDir: widget.mrpDir,
          onRunMrp: widget.onRunMrp,
          onDownloaded: widget.onDownloaded,
          initialResolution: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          elevation: 1,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                SearchBar(
                  key: const ValueKey('open-app-store-search'),
                  constraints: const BoxConstraints.tightFor(
                    height: kToolbarHeight * 0.7,
                  ),
                  hintText: '搜索软件或游戏',
                  leading: const Icon(Icons.search),
                  readOnly: true,
                  onTap: () => unawaited(_openSearch()),
                ),
                const SizedBox(height: 6),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    for (final section in _StoreSection.values)
                      Tab(text: section.label),
                  ],
                  onTap: _selectSection,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(onRefresh: _reload, child: _buildBody()),
        ),
      ],
    );
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
          Icon(Icons.apps_outage, size: 48),
          SizedBox(height: 16),
          Center(child: Text('暂无内容')),
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
        final app = _apps[index];
        return AppStoreAppTile(
          app: app,
          client: _client,
          onTap: () => _openDetails(app),
        );
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
        child: Center(child: Text('已经到底了')),
      );
    }
    return const SizedBox(height: 12);
  }
}
