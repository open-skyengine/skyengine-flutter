import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/app_store_api.dart';

void main() {
  test('app store credentials fall back to development defaults', () {
    // 未通过 --dart-define 注入时使用仓库内置的开发凭据。
    const config = AppStoreApiConfig();
    expect(config.appId, kDefaultAppStoreAppId);
    expect(config.secret, kDefaultAppStoreSecret);
    expect(config.baseUrl, kDefaultAppStoreBaseUrl);
    expect(config.usesDevelopmentCredentials, isTrue);
  });

  test('explicit credentials override the compiled-in defaults', () {
    const config = AppStoreApiConfig(
      baseUrl: 'https://store.example.com/api/app/v1',
      appId: 'prod-app-id',
      secret: 'prod-app-secret',
    );
    expect(config.appId, 'prod-app-id');
    expect(config.secret, 'prod-app-secret');
    expect(config.baseUri.host, 'store.example.com');
    expect(config.baseUri.path, '/api/app/v1');
    expect(config.usesDevelopmentCredentials, isFalse);
  });

  test('maps Android runtime ABIs to emulator package architectures', () {
    expect(
      emulatorArchitectureForAbi(Abi.androidArm64),
      kEmulatorArchitectureArm64,
    );
    expect(
      emulatorArchitectureForAbi(Abi.androidArm),
      kEmulatorArchitectureArm,
    );
  });

  test(
    'emulator versions default to universal and preserve download ABI',
    () async {
      final legacyVersion = AppStoreEmulatorVersion.fromJson({
        'id': 8,
        'platform': 'android',
        'version_code': 41,
      });
      expect(legacyVersion.architecture, kEmulatorArchitectureUniversal);

      final client = AppStoreClient(const AppStoreApiConfig());
      final tempDir = await Directory.systemTemp.createTemp(
        'skyengine_emulator_architecture_test_',
      );
      final version = AppStoreEmulatorVersion(
        id: 9,
        platform: 'android',
        architecture: kEmulatorArchitectureArm64,
        versionCode: 42,
        version: '1.2.3',
        changelog: '',
        downloadUrl: null,
        fileSize: 0,
        checksum: '',
        forceUpdate: false,
      );

      try {
        final request = await client.prepareEmulatorVersionDownload(
          version: version,
          destinationDir: tempDir,
        );
        expect(request.uri.queryParameters, {
          'architecture': kEmulatorArchitectureArm64,
        });
      } finally {
        client.close();
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('AppStoreClient signs, searches, paginates, and downloads', () async {
    final requests = <Uri>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = _serveAppApi(server, requests);
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_api_test_',
    );
    final client = AppStoreClient(
      AppStoreApiConfig(
        baseUrl: 'http://${server.address.host}:${server.port}/api/app/v1',
        appId: 'dev-app-key',
        secret: 'dev-app-secret-change-me',
      ),
    );

    try {
      final list = await client.fetchApps(page: 1, pageSize: 1);
      expect(list.items.single.name, 'Demo App 1');
      expect(list.items.single.downloadCount, 12);
      expect(list.items.single.createdAt, DateTime.utc(2026, 6, 14, 8));
      expect(list.hasMore, isTrue);

      final filteredList = await client.fetchApps(
        page: 3,
        pageSize: 1,
        resolution: '176x220',
        type: 'game',
        sortBy: 'name',
        sortOrder: 'asc',
      );
      expect(filteredList.items.single.name, 'Demo App 3');

      final search = await client.searchApps(
        query: 'demo',
        page: 2,
        pageSize: 1,
        type: 'software',
        sortBy: 'created_at',
        sortOrder: 'desc',
      );
      expect(search.items.single.name, 'Demo App 2');
      expect(search.hasMore, isFalse);

      final downloaded = await client.downloadLatestVersion(
        app: search.items.single,
        destinationDir: tempDir,
      );
      expect(await downloaded.file.readAsString(), 'MRP-DATA');
      expect(downloaded.file.path.endsWith('demo2.mrp'), isTrue);
      expect(downloaded.version.packages.single.resolution, '240x320');

      final foundDownloaded = await client.findDownloadedVersion(
        app: search.items.single,
        version: downloaded.version,
        destinationDir: tempDir,
        resolution: '240x320',
      );
      expect(foundDownloaded?.path, downloaded.file.path);

      final downloadedAgain = await client.downloadLatestVersion(
        app: search.items.single,
        destinationDir: tempDir,
      );
      expect(downloadedAgain.file.path, downloaded.file.path);
      expect(downloadedAgain.alreadyDownloaded, isTrue);

      final config = await client.fetchConfig();
      expect(config.hosts.single.domain, 'api.example.com');
      expect(config.hosts.single.ip, '192.168.1.10');

      final update = await client.checkEmulatorUpdate(
        versionCode: 1,
        architecture: kEmulatorArchitectureArm64,
      );
      expect(update.updateAvailable, isTrue);
      expect(update.latest!.versionCode, 42);
      expect(update.latest!.architecture, kEmulatorArchitectureArm64);

      final apk = await client.downloadEmulatorVersion(
        version: update.latest!,
        destinationDir: tempDir,
      );
      expect(await apk.file.readAsString(), 'APK-DATA');
      expect(apk.file.path.endsWith('skyengine-v42-id9.apk'), isTrue);

      final apkAgain = await client.downloadEmulatorVersion(
        version: update.latest!,
        destinationDir: tempDir,
      );
      expect(apkAgain.file.path, apk.file.path);
      expect(apkAgain.alreadyDownloaded, isTrue);

      expect(
        requests.map((uri) => uri.path),
        containsAllInOrder([
          '/api/app/v1/apps',
          '/api/app/v1/apps',
          '/api/app/v1/apps/search',
          '/api/app/v1/apps/399402/versions',
          '/api/app/v1/apps/399402/versions/1002/download',
          '/api/app/v1/apps/399402/versions',
          '/api/app/v1/config',
          '/api/app/v1/emulator/updates',
          '/api/app/v1/emulator/versions/9/download',
        ]),
      );
      expect(
        requests
            .where(
              (uri) =>
                  uri.path == '/api/app/v1/apps/399402/versions/1002/download',
            )
            .length,
        1,
      );
      expect(
        requests
            .where(
              (uri) => uri.path == '/api/app/v1/emulator/versions/9/download',
            )
            .length,
        1,
      );
    } finally {
      client.close();
      await server.close(force: true);
      await serverDone;
      await tempDir.delete(recursive: true);
    }
  });

  test('AppStoreApp defaults a missing download count to zero', () {
    final app = AppStoreApp.fromJson({
      'id': 1,
      'app_id': 399401,
      'type': 'game',
      'internal_name': 'demo',
      'name': 'Demo',
    });

    expect(app.downloadCount, 0);
  });

  test(
    'AppStoreClient downloads a newer emulator apk instead of reusing old cache',
    () async {
      final requests = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverDone = _serveEmulatorDownloads(server, requests);
      final tempDir = await Directory.systemTemp.createTemp(
        'skyengine_emulator_update_test_',
      );
      final client = AppStoreClient(
        AppStoreApiConfig(
          baseUrl: 'http://${server.address.host}:${server.port}/api/app/v1',
          appId: 'dev-app-key',
          secret: 'dev-app-secret-change-me',
        ),
      );

      const oldContent = 'APK-OLD!';
      const newContent = 'APK-NEW!';
      final oldVersion = AppStoreEmulatorVersion(
        id: 9,
        platform: 'android',
        versionCode: 42,
        version: '1.2.3',
        changelog: 'old',
        downloadUrl: '/api/app/v1/emulator/versions/9/download',
        fileSize: oldContent.length,
        checksum: _sha256Text(oldContent),
        forceUpdate: false,
      );
      final newVersion = AppStoreEmulatorVersion(
        id: 10,
        platform: 'android',
        versionCode: 43,
        version: '1.2.4',
        changelog: 'new',
        downloadUrl: '/api/app/v1/emulator/versions/10/download',
        fileSize: newContent.length,
        checksum: _sha256Text(newContent),
        forceUpdate: false,
      );

      try {
        final oldApk = await client.downloadEmulatorVersion(
          version: oldVersion,
          destinationDir: tempDir,
        );
        expect(await oldApk.file.readAsString(), oldContent);
        expect(oldApk.file.path.endsWith('skyengine-v42-id9.apk'), isTrue);

        final newApk = await client.downloadEmulatorVersion(
          version: newVersion,
          destinationDir: tempDir,
        );
        expect(await newApk.file.readAsString(), newContent);
        expect(newApk.file.path.endsWith('skyengine-v43-id10.apk'), isTrue);
        expect(await oldApk.file.exists(), isFalse);

        final newApkAgain = await client.downloadEmulatorVersion(
          version: newVersion,
          destinationDir: tempDir,
        );
        expect(newApkAgain.file.path, newApk.file.path);
        expect(newApkAgain.alreadyDownloaded, isTrue);

        expect(
          requests
              .where(
                (uri) => uri.path == '/api/app/v1/emulator/versions/9/download',
              )
              .length,
          1,
        );
        expect(
          requests
              .where(
                (uri) =>
                    uri.path == '/api/app/v1/emulator/versions/10/download',
              )
              .length,
          1,
        );
      } finally {
        client.close();
        await server.close(force: true);
        await serverDone;
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('AppStoreClient cleans installed emulator update packages', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_emulator_cleanup_test_',
    );
    final client = AppStoreClient(const AppStoreApiConfig());

    try {
      final installedApk = File(
        '${tempDir.path}${Platform.pathSeparator}skyengine-v42-id9.apk',
      );
      final pendingApk = File(
        '${tempDir.path}${Platform.pathSeparator}skyengine-v43-id10.apk',
      );
      final legacyApk = File(
        '${tempDir.path}${Platform.pathSeparator}skyengine.apk',
      );
      final partialApk = File(
        '${tempDir.path}${Platform.pathSeparator}skyengine-v44-id11.apk.download',
      );
      await installedApk.writeAsString('installed');
      await pendingApk.writeAsString('pending');
      await legacyApk.writeAsString('legacy');
      await partialApk.writeAsString('partial');

      await client.cleanupInstalledEmulatorUpdates(
        destinationDir: tempDir,
        installedVersionCode: 42,
      );

      expect(await installedApk.exists(), isFalse);
      expect(await pendingApk.exists(), isTrue);
      expect(await legacyApk.exists(), isFalse);
      expect(await partialApk.exists(), isFalse);
    } finally {
      client.close();
      await tempDir.delete(recursive: true);
    }
  });
}

Future<void> _serveAppApi(HttpServer server, List<Uri> requests) async {
  await for (final request in server) {
    requests.add(request.uri);
    expect(request.headers.value('X-App-Key'), 'dev-app-key');
    expect(request.headers.value('X-App-Timestamp'), isNotEmpty);
    expect(request.headers.value('X-App-Nonce'), isNotEmpty);
    expect(
      request.headers.value('X-App-Signature'),
      _expectedSignature(request),
    );

    final path = request.uri.path;
    final query = request.uri.queryParameters;
    if (path == '/api/app/v1/apps' && query['page'] == '1') {
      expect(query, {'page': '1', 'page_size': '1', 'resolution': '240x320'});
      _writeJson(
        request.response,
        _appPage(
          page: 1,
          total: 2,
          appId: 399401,
          name: 'Demo App 1',
          internalName: 'demo1',
        ),
      );
    } else if (path == '/api/app/v1/apps' && query['page'] == '3') {
      expect(query, {
        'page': '3',
        'page_size': '1',
        'resolution': '176x220',
        'type': 'game',
        'sort_by': 'name',
        'sort_order': 'asc',
      });
      _writeJson(
        request.response,
        _appPage(
          page: 3,
          total: 3,
          appId: 399403,
          name: 'Demo App 3',
          internalName: 'demo3',
        ),
      );
    } else if (path == '/api/app/v1/apps/search') {
      expect(query, {
        'q': 'demo',
        'page': '2',
        'page_size': '1',
        'resolution': '240x320',
        'type': 'software',
        'sort_by': 'created_at',
        'sort_order': 'desc',
      });
      _writeJson(
        request.response,
        _appPage(
          page: 2,
          total: 2,
          appId: 399402,
          name: 'Demo App 2',
          internalName: 'demo2',
        ),
      );
    } else if (path == '/api/app/v1/apps/399402/versions') {
      expect(query, {'page': '1', 'page_size': '1', 'resolution': '240x320'});
      _writeJson(request.response, {
        'items': [
          {
            'id': 10,
            'app_id': 399402,
            'version_code': 1002,
            'version': '1.0.2',
            'changelog': 'fix',
            'packages': [
              {
                'id': 21,
                'resolution': {'id': 3, 'resolution': '240x320'},
                'file_size': 8,
                'checksum': 'test',
                'download_url':
                    '/api/app/v1/apps/399402/versions/1002/download?resolution=240x320',
              },
            ],
          },
        ],
        'total': 1,
        'page': 1,
        'page_size': 1,
      });
    } else if (path == '/api/app/v1/apps/399402/versions/1002/download') {
      expect(query, {'resolution': '240x320'});
      request.response.headers.contentType = ContentType.binary;
      request.response.headers.set(
        'content-disposition',
        'attachment; filename="demo2.mrp"',
      );
      request.response.add(utf8.encode('MRP-DATA'));
      await request.response.close();
    } else if (path == '/api/app/v1/config') {
      expect(query, isEmpty);
      _writeJson(request.response, {
        'hosts': [
          {'domain': 'api.example.com', 'ip': '192.168.1.10'},
        ],
      });
    } else if (path == '/api/app/v1/emulator/updates') {
      expect(query, {
        'platform': 'android',
        'architecture': 'arm64-v8a',
        'version_code': '1',
      });
      _writeJson(request.response, {
        'update_available': true,
        'latest': {
          'id': 9,
          'platform': 'android',
          'architecture': 'arm64-v8a',
          'version_code': 42,
          'version': '1.2.3',
          'changelog': 'fix',
          'download_url':
              '/api/app/v1/emulator/versions/9/download?architecture=arm64-v8a',
          'file_size': 8,
          'checksum': 'test-apk',
          'force_update': false,
          'published_at': '2026-06-14T08:00:00Z',
        },
      });
    } else if (path == '/api/app/v1/emulator/versions/9/download') {
      expect(query, {'architecture': 'arm64-v8a'});
      request.response.headers.contentType = ContentType(
        'application',
        'vnd.android.package-archive',
      );
      request.response.headers.set(
        'content-disposition',
        'attachment; filename="skyengine.apk"',
      );
      request.response.add(utf8.encode('APK-DATA'));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}

Map<String, Object> _appPage({
  required int page,
  required int total,
  required int appId,
  required String name,
  required String internalName,
}) {
  return {
    'items': [
      {
        'id': appId - 399400,
        'app_id': appId,
        'type': 'app',
        'internal_name': internalName,
        'name': name,
        'manufacturer': {'id': 2, 'name': 'Demo Vendor'},
        'description': 'Demo description',
        'icon_url': '/storage/icons/demo.png',
        'download_count': 12,
        'created_at': '2026-06-14T08:00:00Z',
        'updated_at': '2026-06-14T08:00:00Z',
      },
    ],
    'total': total,
    'page': page,
    'page_size': 1,
  };
}

void _writeJson(HttpResponse response, Map<String, Object> body) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}

Future<void> _serveEmulatorDownloads(
  HttpServer server,
  List<Uri> requests,
) async {
  await for (final request in server) {
    requests.add(request.uri);
    expect(request.headers.value('X-App-Key'), 'dev-app-key');
    expect(request.headers.value('X-App-Timestamp'), isNotEmpty);
    expect(request.headers.value('X-App-Nonce'), isNotEmpty);
    expect(
      request.headers.value('X-App-Signature'),
      _expectedSignature(request),
    );

    final content = switch (request.uri.path) {
      '/api/app/v1/emulator/versions/9/download' => 'APK-OLD!',
      '/api/app/v1/emulator/versions/10/download' => 'APK-NEW!',
      _ => null,
    };
    if (content == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    request.response.headers.contentType = ContentType(
      'application',
      'vnd.android.package-archive',
    );
    request.response.headers.set(
      'content-disposition',
      'attachment; filename="skyengine.apk"',
    );
    request.response.add(utf8.encode(content));
    await request.response.close();
  }
}

String _expectedSignature(HttpRequest request) {
  const emptyBodySha256 =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  final message = [
    request.method,
    request.uri.path,
    _canonicalQuery(request.uri),
    request.headers.value('X-App-Timestamp'),
    request.headers.value('X-App-Nonce'),
    emptyBodySha256,
  ].join('\n');
  return Hmac(
    sha256,
    utf8.encode('dev-app-secret-change-me'),
  ).convert(utf8.encode(message)).toString();
}

String _sha256Text(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

String _canonicalQuery(Uri uri) {
  final pairs = <MapEntry<String, String>>[];
  for (final entry in uri.queryParametersAll.entries) {
    if (entry.key == 'signature') {
      continue;
    }
    final values = [...entry.value]..sort();
    for (final value in values) {
      pairs.add(MapEntry(entry.key, value));
    }
  }
  pairs.sort((a, b) {
    final keyCompare = a.key.compareTo(b.key);
    return keyCompare == 0 ? a.value.compareTo(b.value) : keyCompare;
  });
  return pairs
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
}
