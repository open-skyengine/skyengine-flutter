import 'dart:async';

import 'package:flutter/material.dart';

import '../models/mrp_resolution.dart';
import '../services/app_store_api.dart';
import '../services/search_history.dart';
import '../widgets/app_store_app_tile.dart';
import 'app_store_app_details_page.dart';

enum _SearchType {
  all('全部', null),
  software('软件', 'software'),
  game('游戏', 'game');

  const _SearchType(this.label, this.apiValue);

  final String label;
  final String? apiValue;
}

enum _SearchSort {
  newest('发布时间：从新到旧', 'created_at', 'desc'),
  oldest('发布时间：从旧到新', 'created_at', 'asc'),
  nameAscending('名称：A-Z', 'name', 'asc'),
  nameDescending('名称：Z-A', 'name', 'desc');

  const _SearchSort(this.label, this.sortBy, this.sortOrder);

  final String label;
  final String sortBy;
  final String sortOrder;
}

class AppStoreSearchPage extends StatefulWidget {
  const AppStoreSearchPage({
    super.key,
    required this.client,
    required this.searchHistory,
    required this.mrpDir,
    required this.onRunMrp,
    required this.onDownloaded,
  });

  final AppStoreClient client;
  final SearchHistoryService searchHistory;
  final String? mrpDir;
  final RunMrpCallback onRunMrp;
  final Future<void> Function(String path) onDownloaded;

  @override
  State<AppStoreSearchPage> createState() => _AppStoreSearchPageState();
}

class _AppStoreSearchPageState extends State<AppStoreSearchPage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _history = const [];
  final List<AppStoreApp> _apps = [];

  _SearchType _type = _SearchType.all;
  _SearchSort _sort = _SearchSort.newest;
  String _resolution = '';
  String _submittedQuery = '';
  String? _error;
  bool _loadingHistory = true;
  bool _loadingFirstPage = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 1;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      await widget.searchHistory.open();
      final entries = await widget.searchHistory.entries();
      if (mounted) {
        setState(() => _history = entries);
      }
    } catch (_) {
      // Search remains usable when local history storage is unavailable.
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    try {
      await widget.searchHistory.clear();
    } catch (_) {
      // The visible history should still clear for the current session.
    }
    if (mounted) {
      setState(() => _history = const []);
    }
  }

  Future<void> _submitSearch([String? term]) async {
    final query = (term ?? _searchController.text).trim();
    if (query.isEmpty) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusScope.of(context).unfocus();
    try {
      await widget.searchHistory.add(query);
      final entries = await widget.searchHistory.entries();
      if (mounted) {
        setState(() => _history = entries);
      }
    } catch (_) {
      // A history write failure must not block the actual search.
    }
    if (!mounted) {
      return;
    }
    setState(() => _submittedQuery = query);
    await _reloadResults();
  }

  Future<void> _reloadResults() async {
    if (_submittedQuery.isEmpty) {
      return;
    }
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
    return widget.client.searchApps(
      query: _submittedQuery,
      page: page,
      pageSize: _pageSize,
      type: _type.apiValue,
      resolution: _resolution.isEmpty ? null : _resolution,
      sortBy: _sort.sortBy,
      sortOrder: _sort.sortOrder,
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 280) {
      unawaited(_loadMore());
    }
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
    if (_submittedQuery.isNotEmpty) {
      unawaited(_reloadResults());
    }
  }

  void _openDetails(AppStoreApp app) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AppStoreAppDetailsPage(
          app: app,
          client: widget.client,
          mrpDir: widget.mrpDir,
          onRunMrp: widget.onRunMrp,
          onDownloaded: widget.onDownloaded,
          initialResolution: _resolution.isEmpty ? null : _resolution,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('close-app-store-search'),
          tooltip: '返回',
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
          icon: const Icon(Icons.chevron_left, size: 32),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  key: const ValueKey('app-store-search-field'),
                  controller: _searchController,
                  autoFocus: true,
                  constraints: const BoxConstraints.tightFor(
                    height: kToolbarHeight * 0.7,
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  textInputAction: TextInputAction.search,
                  hintText: '搜索软件或游戏',
                  leading: const Icon(Icons.search),
                  onChanged: (value) {
                    if (value.trim().isEmpty && _submittedQuery.isNotEmpty) {
                      ++_requestGeneration;
                      setState(() {
                        _submittedQuery = '';
                        _apps.clear();
                        _error = null;
                        _loadingFirstPage = false;
                      });
                    }
                  },
                  onSubmitted: (_) => unawaited(_submitSearch()),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: const ValueKey('submit-app-store-search'),
                onPressed: () => unawaited(_submitSearch()),
                child: const Text('搜索'),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_submittedQuery.isNotEmpty) ...[
            _buildFilters(),
            const Divider(height: 1),
          ],
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in _SearchType.values) ...[
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => _updateFilters(() => _type = type),
                  ),
                  if (type != _SearchType.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('search-resolution-filter'),
                  initialValue: _resolution,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '分辨率',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('全部')),
                    for (final resolution in kCommonMrpResolutions)
                      DropdownMenuItem(
                        value: resolution.label,
                        child: Text(resolution.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateFilters(() => _resolution = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_SearchSort>(
                  key: const ValueKey('search-sort-filter'),
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '排序',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    for (final sort in _SearchSort.values)
                      DropdownMenuItem(value: sort, child: Text(sort.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateFilters(() => _sort = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_submittedQuery.isEmpty) {
      return _buildHistory();
    }
    if (_loadingFirstPage && _apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _apps.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 88),
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('搜索失败\n$_error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _reloadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }
    if (_apps.isEmpty) {
      return const Center(child: Text('没有找到相关应用或游戏'));
    }
    return RefreshIndicator(
      onRefresh: _reloadResults,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _apps.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _apps.length) {
            return _buildFooter();
          }
          final app = _apps[index];
          return AppStoreAppTile(
            app: app,
            client: widget.client,
            onTap: () => _openDetails(app),
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView(
      children: [
        ListTile(
          title: const Text('搜索历史'),
          trailing: IconButton(
            key: const ValueKey('clear-search-history'),
            tooltip: '清除搜索历史',
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
        for (final term in _history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => unawaited(_submitSearch(term)),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('已经到底了')),
      );
    }
    return const SizedBox(height: 12);
  }
}
