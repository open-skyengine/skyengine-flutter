import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/l10n/app_localizations.dart';
import 'package:skyengine/pages/app_store_app_details_page.dart';
import 'package:skyengine/services/app_store_api.dart';

void main() {
  testWidgets('downloaded app shows Run and opens the local file', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'skyengine_details_downloaded_test_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final downloadedFile = File(
      '${directory.path}${Platform.pathSeparator}demo_10.mrp',
    );
    downloadedFile.writeAsStringSync('MRP-DATA');
    final client = _FakeAppStoreClient(downloadedFile: downloadedFile);
    addTearDown(client.close);
    String? runPath;
    String? runResolution;

    await tester.pumpWidget(
      _testApp(
        client: client,
        mrpDir: directory.path,
        onRunMrp: (path, {resolution}) {
          runPath = path;
          runResolution = resolution;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, '运行'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '运行'));
    await tester.pump();

    expect(runPath, downloadedFile.path);
    expect(runResolution, '240x320');
    expect(client.downloadCalls, 0);
  });

  testWidgets('missing app shows Download and run and updates after download', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'skyengine_details_missing_test_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final downloadedFile = File(
      '${directory.path}${Platform.pathSeparator}demo_10.mrp',
    );
    downloadedFile.writeAsStringSync('MRP-DATA');
    final client = _FakeAppStoreClient(downloadResult: downloadedFile);
    addTearDown(client.close);
    String? registeredPath;
    String? runPath;

    await tester.pumpWidget(
      _testApp(
        client: client,
        mrpDir: directory.path,
        onDownloaded: (path) async => registeredPath = path,
        onRunMrp: (path, {resolution}) => runPath = path,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, '下载并运行'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '下载并运行'));
    await tester.pump();
    await tester.pump();

    expect(client.downloadCalls, 1);
    expect(registeredPath, downloadedFile.path);
    expect(runPath, downloadedFile.path);
    expect(find.widgetWithText(FilledButton, '运行'), findsOneWidget);
  });
}

Widget _testApp({
  required _FakeAppStoreClient client,
  required String mrpDir,
  required RunMrpCallback onRunMrp,
  Future<void> Function(String path)? onDownloaded,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AppStoreAppDetailsPage(
      app: _FakeAppStoreClient.app,
      client: client,
      mrpDir: mrpDir,
      onRunMrp: onRunMrp,
      onDownloaded: onDownloaded ?? (_) async {},
    ),
  );
}

class _FakeAppStoreClient extends AppStoreClient {
  _FakeAppStoreClient({this.downloadedFile, this.downloadResult})
    : super(const AppStoreApiConfig());

  static const app = AppStoreApp(
    id: 1,
    appId: 1001,
    type: 'software',
    internalName: 'demo',
    name: 'Demo',
    manufacturer: null,
    description: '',
    iconUrl: null,
  );

  static const version = AppStoreVersion(
    id: 1,
    appId: 1001,
    versionCode: 10,
    version: '1.0.0',
    changelog: '',
    packages: [
      AppStorePackage(
        id: 1,
        model: null,
        resolution: '240x320',
        fileSize: 8,
        checksum: '',
        downloadUrl: '/demo.mrp',
      ),
    ],
  );

  final File? downloadedFile;
  final File? downloadResult;
  int downloadCalls = 0;

  @override
  Future<PagedResult<AppStoreVersion>> fetchVersions({
    required int appId,
    int page = 1,
    int pageSize = 1,
    String? resolution = '240x320',
  }) async {
    return PagedResult(
      items: const [version],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<File?> findDownloadedVersion({
    required AppStoreApp app,
    required AppStoreVersion version,
    required Directory destinationDir,
    required String resolution,
  }) async {
    return downloadedFile;
  }

  @override
  Future<DownloadedMrp> downloadLatestVersion({
    required AppStoreApp app,
    required Directory destinationDir,
    String resolution = '240x320',
    DownloadProgressCallback? onProgress,
  }) async {
    downloadCalls++;
    return DownloadedMrp(file: downloadResult!, version: version);
  }
}
