import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrpoid/app_store_api.dart';

void main() {
  test('AppStoreClient signs, searches, paginates, and downloads', () async {
    final requests = <Uri>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = _serveAppApi(server, requests);
    final tempDir = await Directory.systemTemp.createTemp('mrpoid_api_test_');
    final client = AppStoreClient(
      AppStoreApiConfig(
        baseUrl: 'http://${server.address.host}:${server.port}/api/app/v1',
        key: 'dev-app-key',
        secret: 'dev-app-secret-change-me',
      ),
    );

    try {
      final list = await client.fetchApps(page: 1, pageSize: 1);
      expect(list.items.single.name, 'Demo App 1');
      expect(list.hasMore, isTrue);

      final filteredList = await client.fetchApps(page: 3, pageSize: 1);
      expect(filteredList.items.single.name, 'Demo App 3');

      final search = await client.searchApps(
        query: 'demo',
        page: 2,
        pageSize: 1,
      );
      expect(search.items.single.name, 'Demo App 2');
      expect(search.hasMore, isFalse);

      final downloaded = await client.downloadLatestVersion(
        app: search.items.single,
        destinationDir: tempDir,
      );
      expect(await downloaded.file.readAsString(), 'MRP-DATA');
      expect(downloaded.file.path.endsWith('demo2.mrp'), isTrue);

      final downloadedAgain = await client.downloadLatestVersion(
        app: search.items.single,
        destinationDir: tempDir,
      );
      expect(downloadedAgain.file.path, downloaded.file.path);
      expect(downloadedAgain.alreadyDownloaded, isTrue);

      expect(
        requests.map((uri) => uri.path),
        containsAllInOrder([
          '/api/app/v1/apps',
          '/api/app/v1/apps',
          '/api/app/v1/apps/search',
          '/api/app/v1/apps/399402/versions',
          '/api/app/v1/apps/399402/versions/1002/download',
          '/api/app/v1/apps/399402/versions',
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
    } finally {
      client.close();
      await server.close(force: true);
      await serverDone;
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
      expect(query, {'page': '3', 'page_size': '1', 'resolution': '240x320'});
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
                'model': {
                  'id': 3,
                  'name': 'VMRP',
                  'code': 'vmrp',
                  'resolution': '240x320',
                },
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
