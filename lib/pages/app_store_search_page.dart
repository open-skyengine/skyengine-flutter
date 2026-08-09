import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_store_api.dart';
import '../services/search_history.dart';
import '../widgets/app_store_app_tile.dart';
import 'app_store_app_details_page.dart';

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
  late final Future<void> _searchConfigFuture;
  List<AppStoreSearchConfigGroup> _filterGroups = const [];
  final Map<String, String> _selectedFilterValues = {};

  String _submittedQuery = '';
  String? _error;
  bool _loadingHistory = true;
  bool _loadingFirstPage = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _filtersExpanded = false;
  int _nextPage = 1;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchConfigFuture = _loadSearchConfig();
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

  Future<void> _loadSearchConfig() async {
    try {
      final groups = _usableSearchConfig(
        await widget.client.fetchSearchConfig().timeout(
          const Duration(seconds: 5),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _filterGroups = groups;
        _setDefaultFilterValues(groups);
      });
      if (_submittedQuery.isNotEmpty) {
        unawaited(_reloadResults());
      }
    } catch (_) {
      // Search remains usable without optional server-side filters.
    }
  }

  List<AppStoreSearchConfigGroup> _usableSearchConfig(
    List<AppStoreSearchConfigGroup> groups,
  ) {
    final seenKeys = <String>{};
    final result = <AppStoreSearchConfigGroup>[];
    for (final group in groups) {
      if (group.name.trim().isEmpty ||
          group.queryKey.trim().isEmpty ||
          seenKeys.contains(group.queryKey)) {
        continue;
      }
      final seenValues = <String>{};
      final options = [
        for (final option in group.options)
          if (option.name.trim().isNotEmpty &&
              option.value.trim().isNotEmpty &&
              seenValues.add(option.value))
            option,
      ];
      if (options.isNotEmpty) {
        seenKeys.add(group.queryKey);
        result.add(
          AppStoreSearchConfigGroup(
            name: group.name,
            queryKey: group.queryKey,
            options: options,
          ),
        );
      }
    }
    return result;
  }

  void _setDefaultFilterValues(List<AppStoreSearchConfigGroup> groups) {
    final validKeys = <String>{};
    for (final group in groups) {
      validKeys.add(group.queryKey);
      final selected = _selectedFilterValues[group.queryKey];
      if (selected != null &&
          group.options.any((option) => option.value == selected)) {
        continue;
      }
      AppStoreSearchConfigOption? defaultOption;
      for (final option in group.options) {
        if (option.value == 'default') {
          defaultOption = option;
          break;
        }
      }
      _selectedFilterValues[group.queryKey] =
          (defaultOption ?? group.options.first).value;
    }
    _selectedFilterValues.removeWhere((key, _) => !validKeys.contains(key));
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
    await _searchConfigFuture;
    if (!mounted) {
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
    return widget.client.searchAppsWithFilters(
      query: _submittedQuery,
      page: page,
      pageSize: _pageSize,
      filters: _selectedFilterValues,
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 280) {
      unawaited(_loadMore());
    }
  }

  void _updateFilter(AppStoreSearchConfigGroup group, String value) {
    setState(() => _selectedFilterValues[group.queryKey] = value);
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
          initialResolution: _selectedResolution,
        ),
      ),
    );
  }

  String? get _selectedResolution {
    final value = _selectedFilterValues['resolution'];
    return value == null || value == 'default' ? null : value;
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
                        _filtersExpanded = false;
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
          if (_submittedQuery.isNotEmpty) _buildFilterBar(),
          if (_submittedQuery.isNotEmpty) const Divider(height: 1),
          Expanded(
            child: _submittedQuery.isNotEmpty
                ? _buildResultsArea()
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBody(),
        if (_filtersExpanded) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _filtersExpanded = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              key: const ValueKey('search-filters-panel'),
              color: Theme.of(context).colorScheme.surface,
              elevation: 4,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: SingleChildScrollView(child: _buildFilters()),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterBar() {
    final canExpand = _filterGroups.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('搜索结果', style: Theme.of(context).textTheme.titleSmall),
          ),
          IconButton(
            key: const ValueKey('toggle-search-filters'),
            tooltip: _filtersExpanded ? '收起筛选' : '展开筛选',
            onPressed: canExpand
                ? () => setState(() => _filtersExpanded = !_filtersExpanded)
                : null,
            icon: Icon(
              _filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    if (_filterGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _filterGroups.length; index++) ...[
            _buildFilterGroup(_filterGroups[index]),
            if (index != _filterGroups.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterGroup(AppStoreSearchConfigGroup group) {
    final key = _filterKey(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.name),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < group.options.length; index++) ...[
                ChoiceChip(
                  key: index == 0 ? ValueKey(key) : null,
                  label: Text(
                    group.options[index].name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  selected:
                      _selectedFilterValues[group.queryKey] ==
                      group.options[index].value,
                  onSelected: (_) =>
                      _updateFilter(group, group.options[index].value),
                ),
                if (index != group.options.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _filterKey(AppStoreSearchConfigGroup group) {
    return 'search-${group.queryKey}-filter';
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
