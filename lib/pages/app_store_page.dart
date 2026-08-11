import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../services/app_store_api.dart';
import '../services/search_history.dart';
import '../widgets/app_store_app_tile.dart';
import 'app_store_app_details_page.dart';
import 'app_store_search_page.dart';

enum _StoreSection {
  latest(null),
  software('software'),
  game('game');

  const _StoreSection(this.apiType);

  final String? apiType;

  String localizedLabel(AppLocalizations l10n) => switch (this) {
    _StoreSection.latest => l10n.latest,
    _StoreSection.software => l10n.software,
    _StoreSection.game => l10n.game,
  };
}

class _StoreTabCache {
  _StoreTabCache(this.section);

  final _StoreSection section;
  final ScrollController scrollController = ScrollController();
  final List<AppStoreApp> apps = [];

  bool hasLoaded = false;
  bool loadingFirstPage = false;
  bool loadingMore = false;
  bool hasMore = true;
  int nextPage = 1;
  int requestGeneration = 0;
  String? error;

  void dispose() {
    scrollController.dispose();
  }
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
  late final PageController _pageController;
  late final List<_StoreTabCache> _tabCaches;

  int _activeTabIndex = 0;

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
    _pageController = PageController();
    _tabCaches = [
      for (final section in _StoreSection.values) _StoreTabCache(section),
    ];
    for (var index = 0; index < _tabCaches.length; index++) {
      _tabCaches[index].scrollController.addListener(() => _onScroll(index));
    }
    unawaited(_reloadSection(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final cache in _tabCaches) {
      cache.dispose();
    }
    _tabController.dispose();
    if (_ownsClient) {
      _client.close();
    }
    if (_ownsSearchHistory) {
      unawaited(_searchHistory.close());
    }
    super.dispose();
  }

  Future<void> _reloadSection(int index) async {
    final cache = _tabCaches[index];
    final generation = ++cache.requestGeneration;
    setState(() {
      cache.hasLoaded = true;
      cache.apps.clear();
      cache.nextPage = 1;
      cache.hasMore = true;
      cache.error = null;
      cache.loadingFirstPage = true;
    });
    try {
      final result = await _fetchPage(index, 1);
      if (!mounted || generation != cache.requestGeneration) {
        return;
      }
      setState(() {
        cache.apps.addAll(result.items);
        cache.nextPage = 2;
        cache.hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && generation == cache.requestGeneration) {
        setState(() {
          cache.error = error.toString();
          cache.hasMore = false;
        });
      }
    } finally {
      if (mounted && generation == cache.requestGeneration) {
        setState(() => cache.loadingFirstPage = false);
      }
    }
  }

  Future<void> _ensureLoaded(int index) async {
    final cache = _tabCaches[index];
    if (cache.hasLoaded || cache.loadingFirstPage) {
      return;
    }
    await _reloadSection(index);
  }

  Future<void> _loadMore(int index) async {
    final cache = _tabCaches[index];
    if (cache.loadingFirstPage || cache.loadingMore || !cache.hasMore) {
      return;
    }
    final generation = cache.requestGeneration;
    setState(() => cache.loadingMore = true);
    try {
      final result = await _fetchPage(index, cache.nextPage);
      if (!mounted || generation != cache.requestGeneration) {
        return;
      }
      setState(() {
        cache.apps.addAll(result.items);
        cache.nextPage += 1;
        cache.hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && generation == cache.requestGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.loadMoreFailed)));
      }
    } finally {
      if (mounted && generation == cache.requestGeneration) {
        setState(() => cache.loadingMore = false);
      }
    }
  }

  Future<PagedResult<AppStoreApp>> _fetchPage(int index, int page) {
    final section = _tabCaches[index].section;
    return _client.fetchApps(
      page: page,
      pageSize: _pageSize,
      resolution: null,
      type: section.apiType,
      sortBy: 'created_at',
      sortOrder: 'desc',
    );
  }

  void _onScroll(int index) {
    final controller = _tabCaches[index].scrollController;
    if (controller.hasClients && controller.position.extentAfter < 280) {
      unawaited(_loadMore(index));
    }
  }

  void _selectSection(int index) {
    if (index < 0 || index >= _StoreSection.values.length) {
      return;
    }
    final currentPage = _pageController.hasClients
        ? _pageController.page?.round()
        : _activeTabIndex;
    if (currentPage == index) {
      return;
    }
    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _onPageChanged(int index) {
    if (_activeTabIndex != index) {
      setState(() => _activeTabIndex = index);
    }
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
    unawaited(_ensureLoaded(index));
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
    final l10n = context.l10n;
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
                  elevation: const WidgetStatePropertyAll(0),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  hintText: l10n.searchAppsHint,
                  leading: const Icon(Icons.search),
                  readOnly: true,
                  onTap: () => unawaited(_openSearch()),
                ),
                const SizedBox(height: 6),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    for (final section in _StoreSection.values)
                      Tab(text: section.localizedLabel(l10n)),
                  ],
                  onTap: _selectSection,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _StoreSection.values.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return RefreshIndicator(
                onRefresh: () => _reloadSection(index),
                child: _buildBody(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(int index) {
    final cache = _tabCaches[index];
    if (!cache.hasLoaded) {
      return const SizedBox.expand();
    }
    if (cache.loadingFirstPage && cache.apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cache.error != null && cache.apps.isEmpty) {
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
            child: Text(
              context.l10n.appStoreLoadFailed,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => unawaited(_reloadSection(index)),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ),
        ],
      );
    }
    if (cache.apps.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.apps_outage, size: 48),
          const SizedBox(height: 16),
          Center(child: Text(context.l10n.emptyStore)),
        ],
      );
    }
    return ListView.separated(
      controller: cache.scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: cache.apps.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == cache.apps.length) {
          return _buildFooter(cache);
        }
        final app = cache.apps[index];
        return AppStoreAppTile(
          app: app,
          client: _client,
          onTap: () => _openDetails(app),
        );
      },
    );
  }

  Widget _buildFooter(_StoreTabCache cache) {
    if (cache.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!cache.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text(context.l10n.storeEndReached)),
      );
    }
    return const SizedBox(height: 12);
  }
}
