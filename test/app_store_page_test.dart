import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/pages/app_store_page.dart';
import 'package:skyengine/services/app_store_api.dart';
import 'package:skyengine/services/search_history.dart';

void main() {
  testWidgets('store uses latest, software, and game tabs', (tester) async {
    final client = _FakeAppStoreClient();
    await tester.pumpWidget(_testApp(client: client));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('open-app-store-search')))
          .height,
      closeTo(kToolbarHeight * 0.7, 0.01),
    );
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('软件'), findsOneWidget);
    expect(find.text('游戏'), findsOneWidget);
    expect(find.text('Software Demo'), findsOneWidget);
    expect(find.text('Game Demo'), findsOneWidget);
    expect(client.fetchCalls.single.type, isNull);
    expect(client.fetchCalls.single.resolution, isNull);
    expect(client.fetchCalls.single.sortBy, 'created_at');
    expect(client.fetchCalls.single.sortOrder, 'desc');

    await tester.tap(find.text('游戏'));
    await tester.pumpAndSettle();

    expect(client.fetchCalls.last.type, 'game');
    expect(find.text('Game Demo'), findsOneWidget);
    expect(find.text('Software Demo'), findsNothing);
  });

  testWidgets('search opens as a separate page and history can be cleared', (
    tester,
  ) async {
    final history = _FakeSearchHistory(['俄罗斯方块', '词典']);
    await tester.pumpWidget(
      _testApp(client: _FakeAppStoreClient(), searchHistory: history),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-app-store-search')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.chevron_left)).size, 32);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    final searchBarFinder = find.byKey(
      const ValueKey('app-store-search-field'),
    );
    expect(searchBarFinder, findsOneWidget);
    expect(
      tester.getSize(searchBarFinder).height,
      closeTo(kToolbarHeight * 0.7, 0.01),
    );
    final searchBar = tester.widget<SearchBar>(searchBarFinder);
    expect(searchBar.elevation?.resolve({}), 0);
    expect(searchBar.shadowColor?.resolve({}), Colors.transparent);
    expect(searchBar.textInputAction, TextInputAction.search);
    expect(
      tester.testTextInput.setClientArgs?['inputAction'],
      TextInputAction.search.toString(),
    );
    expect(find.byIcon(Icons.close), findsNothing);
    expect(searchBar.trailing, isNull);
    expect(
      find.byKey(const ValueKey('submit-app-store-search')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: searchBarFinder,
        matching: find.byKey(const ValueKey('submit-app-store-search')),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('search-resolution-filter')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('search-sort-filter')), findsNothing);
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('俄罗斯方块'), findsOneWidget);
    expect(find.text('词典'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-search-history')));
    await tester.pump();

    expect(history.wasCleared, isTrue);
    expect(find.text('搜索历史'), findsNothing);
    expect(find.text('俄罗斯方块'), findsNothing);
    expect(find.text('词典'), findsNothing);
  });

  testWidgets('search filters results and opens app details', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _FakeAppStoreClient();
    final history = _FakeSearchHistory([]);
    await tester.pumpWidget(_testApp(client: client, searchHistory: history));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-app-store-search')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('search-resolution-filter')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('app-store-search-field')),
      'demo',
    );
    await tester.tap(find.byKey(const ValueKey('submit-app-store-search')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('search-resolution-filter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('search-sort-filter')), findsOneWidget);
    expect(find.text('Software Demo'), findsOneWidget);
    expect(find.text('Game Demo'), findsOneWidget);
    expect(history.values.first, 'demo');
    expect(client.searchCalls.last.type, isNull);
    expect(client.searchCalls.last.resolution, isNull);
    expect(client.searchCalls.last.sortBy, 'created_at');
    expect(client.searchCalls.last.sortOrder, 'desc');

    final callsAfterButtonSubmit = client.searchCalls.length;
    await tester.tap(find.byKey(const ValueKey('app-store-search-field')));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(client.searchCalls, hasLength(callsAfterButtonSubmit + 1));

    await tester.tap(find.widgetWithText(ChoiceChip, '软件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-resolution-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('176x220').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-sort-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布时间：从旧到新').last);
    await tester.pumpAndSettle();

    final filtered = client.searchCalls.last;
    expect(filtered.type, 'software');
    expect(filtered.resolution, '176x220');
    expect(filtered.sortBy, 'created_at');
    expect(filtered.sortOrder, 'asc');
    expect(find.text('Software Demo'), findsOneWidget);
    expect(find.text('Game Demo'), findsNothing);

    await tester.tap(find.text('Software Demo'));
    await tester.pumpAndSettle();

    expect(find.text('Demo details'), findsOneWidget);
    expect(find.text('版本与分辨率'), findsOneWidget);
    expect(find.text('下载并运行'), findsOneWidget);
    expect(client.versionAppIds, contains(1001));
  });
}

Widget _testApp({
  required _FakeAppStoreClient client,
  SearchHistoryService? searchHistory,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AppStorePage(
        mrpDir: null,
        onRunMrp: (path, {resolution}) {},
        onDownloaded: (_) async {},
        client: client,
        searchHistory: searchHistory,
      ),
    ),
  );
}

class _AppQuery {
  const _AppQuery({
    required this.page,
    required this.resolution,
    required this.type,
    required this.sortBy,
    required this.sortOrder,
  });

  final int page;
  final String? resolution;
  final String? type;
  final String? sortBy;
  final String? sortOrder;
}

class _FakeAppStoreClient extends AppStoreClient {
  _FakeAppStoreClient() : super(const AppStoreApiConfig());

  final List<_AppQuery> fetchCalls = [];
  final List<_AppQuery> searchCalls = [];
  final List<int> versionAppIds = [];

  static final software = AppStoreApp(
    id: 1,
    appId: 1001,
    type: 'software',
    internalName: 'software-demo',
    name: 'Software Demo',
    manufacturer: const AppStoreManufacturer(id: 1, name: 'Demo Vendor'),
    description: 'Demo details',
    iconUrl: null,
    createdAt: DateTime.utc(2026, 8, 9),
  );

  static final game = AppStoreApp(
    id: 2,
    appId: 1002,
    type: 'game',
    internalName: 'game-demo',
    name: 'Game Demo',
    manufacturer: const AppStoreManufacturer(id: 1, name: 'Demo Vendor'),
    description: 'A demo game',
    iconUrl: null,
    createdAt: DateTime.utc(2026, 8, 8),
  );

  @override
  Future<PagedResult<AppStoreApp>> fetchApps({
    required int page,
    int pageSize = 20,
    String? resolution = '240x320',
    String? type,
    String? sortBy,
    String? sortOrder,
  }) async {
    fetchCalls.add(
      _AppQuery(
        page: page,
        resolution: resolution,
        type: type,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );
    final items = switch (type) {
      'software' => [software],
      'game' => [game],
      _ => [software, game],
    };
    return PagedResult(
      items: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<PagedResult<AppStoreApp>> searchApps({
    required String query,
    required int page,
    int pageSize = 20,
    String? resolution = '240x320',
    String? type,
    String? sortBy,
    String? sortOrder,
  }) async {
    searchCalls.add(
      _AppQuery(
        page: page,
        resolution: resolution,
        type: type,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );
    final items = type == 'software' ? [software] : [software, game];
    return PagedResult(
      items: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<PagedResult<AppStoreVersion>> fetchVersions({
    required int appId,
    int page = 1,
    int pageSize = 1,
    String? resolution = '240x320',
  }) async {
    versionAppIds.add(appId);
    final version = AppStoreVersion(
      id: 1,
      appId: appId,
      versionCode: 10,
      version: '1.0.0',
      changelog: 'Initial release',
      packages: [
        AppStorePackage(
          id: 1,
          model: null,
          resolution: resolution ?? '240x320',
          fileSize: 10,
          checksum: '',
          downloadUrl: '/download',
        ),
      ],
    );
    return PagedResult(
      items: [version],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  void close() {}
}

class _FakeSearchHistory extends SearchHistoryService {
  _FakeSearchHistory(List<String> initial) : values = [...initial];

  List<String> values;
  bool wasCleared = false;

  @override
  Future<void> open() async {}

  @override
  Future<List<String>> entries() async => [...values];

  @override
  Future<void> add(String term) async {
    values.remove(term);
    values.insert(0, term);
  }

  @override
  Future<void> clear() async {
    wasCleared = true;
    values = [];
  }

  @override
  Future<void> close() async {}
}
