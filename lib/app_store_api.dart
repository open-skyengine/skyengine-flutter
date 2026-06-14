import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

const String kDefaultAppStoreBaseUrl = 'http://127.0.0.1:8080/api/app/v1';
const String kDefaultAppStoreKey = 'dev-app-key';
const String kDefaultAppStoreSecret = 'dev-app-secret-change-me';

const _emptyBodySha256 =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

class AppStoreApiConfig {
  final String baseUrl;
  final String key;
  final String secret;

  const AppStoreApiConfig({
    this.baseUrl = kDefaultAppStoreBaseUrl,
    this.key = kDefaultAppStoreKey,
    this.secret = kDefaultAppStoreSecret,
  });

  Uri get baseUri {
    final uri = Uri.parse(baseUrl.trim());
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('应用商店地址无效');
    }
    return uri;
  }
}

class PagedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total && items.length >= pageSize;
}

class AppStoreManufacturer {
  final int id;
  final String name;

  const AppStoreManufacturer({required this.id, required this.name});

  factory AppStoreManufacturer.fromJson(Map<String, dynamic> json) {
    return AppStoreManufacturer(
      id: _readInt(json['id']),
      name: _readString(json['name']),
    );
  }
}

class AppStoreApp {
  final int id;
  final int appId;
  final String type;
  final String internalName;
  final String name;
  final AppStoreManufacturer? manufacturer;
  final String description;
  final String? iconUrl;

  const AppStoreApp({
    required this.id,
    required this.appId,
    required this.type,
    required this.internalName,
    required this.name,
    required this.manufacturer,
    required this.description,
    required this.iconUrl,
  });

  factory AppStoreApp.fromJson(Map<String, dynamic> json) {
    final manufacturerJson = json['manufacturer'];
    return AppStoreApp(
      id: _readInt(json['id']),
      appId: _readInt(json['app_id']),
      type: _readString(json['type']),
      internalName: _readString(json['internal_name']),
      name: _readString(json['name']),
      manufacturer: manufacturerJson is Map<String, dynamic>
          ? AppStoreManufacturer.fromJson(manufacturerJson)
          : null,
      description: _readString(json['description']),
      iconUrl: _nullableString(json['icon_url']),
    );
  }
}

class AppStoreModel {
  final int id;
  final String name;
  final String code;
  final String resolution;

  const AppStoreModel({
    required this.id,
    required this.name,
    required this.code,
    required this.resolution,
  });

  factory AppStoreModel.fromJson(Map<String, dynamic> json) {
    return AppStoreModel(
      id: _readInt(json['id']),
      name: _readString(json['name']),
      code: _readString(json['code']),
      resolution: _readString(json['resolution']),
    );
  }
}

class AppStorePackage {
  final int id;
  final AppStoreModel? model;
  final int fileSize;
  final String checksum;
  final String? downloadUrl;

  const AppStorePackage({
    required this.id,
    required this.model,
    required this.fileSize,
    required this.checksum,
    required this.downloadUrl,
  });

  factory AppStorePackage.fromJson(Map<String, dynamic> json) {
    final modelJson = json['model'];
    return AppStorePackage(
      id: _readInt(json['id']),
      model: modelJson is Map<String, dynamic>
          ? AppStoreModel.fromJson(modelJson)
          : null,
      fileSize: _readInt(json['file_size']),
      checksum: _readString(json['checksum']),
      downloadUrl: _nullableString(json['download_url']),
    );
  }
}

class AppStoreVersion {
  final int id;
  final int appId;
  final int versionCode;
  final String version;
  final String changelog;
  final List<AppStorePackage> packages;

  const AppStoreVersion({
    required this.id,
    required this.appId,
    required this.versionCode,
    required this.version,
    required this.changelog,
    required this.packages,
  });

  factory AppStoreVersion.fromJson(Map<String, dynamic> json) {
    final packagesJson = json['packages'];
    return AppStoreVersion(
      id: _readInt(json['id']),
      appId: _readInt(json['app_id']),
      versionCode: _readInt(json['version_code']),
      version: _readString(json['version']),
      changelog: _readString(json['changelog']),
      packages: packagesJson is List
          ? packagesJson
                .whereType<Map<String, dynamic>>()
                .map(AppStorePackage.fromJson)
                .toList()
          : const [],
    );
  }
}

class DownloadedMrp {
  final File file;
  final AppStoreVersion version;

  const DownloadedMrp({required this.file, required this.version});
}

class AppStoreApiException implements Exception {
  final String message;
  final int? statusCode;

  const AppStoreApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AppStoreClient {
  final AppStoreApiConfig config;
  final HttpClient _httpClient;
  final Random _random = Random.secure();

  AppStoreClient(this.config) : _httpClient = HttpClient();

  void close() => _httpClient.close(force: true);

  Future<PagedResult<AppStoreApp>> fetchApps({
    required int page,
    int pageSize = 20,
    String resolution = '240x320',
  }) {
    return _fetchAppPage(
      '/apps',
      _queryParams({
        'page': '$page',
        'page_size': '$pageSize',
        'resolution': resolution,
      }),
    );
  }

  Future<PagedResult<AppStoreApp>> searchApps({
    required String query,
    required int page,
    int pageSize = 20,
    String resolution = '240x320',
  }) {
    return _fetchAppPage(
      '/apps/search',
      _queryParams({
        'q': query,
        'page': '$page',
        'page_size': '$pageSize',
        'resolution': resolution,
      }),
    );
  }

  Future<PagedResult<AppStoreVersion>> fetchVersions({
    required int appId,
    int page = 1,
    int pageSize = 1,
    String resolution = '240x320',
  }) async {
    final json = await _getJson(
      '/apps/$appId/versions',
      _queryParams({
        'page': '$page',
        'page_size': '$pageSize',
        'resolution': resolution,
      }),
    );
    return _readPagedResult(json, AppStoreVersion.fromJson);
  }

  Future<DownloadedMrp> downloadLatestVersion({
    required AppStoreApp app,
    required Directory destinationDir,
    String resolution = '240x320',
  }) async {
    final versions = await fetchVersions(
      appId: app.appId,
      resolution: resolution,
    );
    if (versions.items.isEmpty) {
      throw const AppStoreApiException('没有可下载的版本');
    }

    final version = versions.items.first;
    final package = version.packages.isNotEmpty ? version.packages.first : null;
    final uri = package?.downloadUrl == null
        ? _buildUri(
            '/apps/${app.appId}/versions/${version.versionCode}/download',
            _queryParams({
              'resolution': resolution,
            }),
          )
        : _resolveApiUri(package!.downloadUrl!);

    final response = await _getResponse(uri);
    if (response.statusCode != HttpStatus.ok) {
      final message = await _readError(response);
      throw AppStoreApiException(message, statusCode: response.statusCode);
    }

    final headerName = _filenameFromDisposition(
      response.headers.value('content-disposition'),
    );
    final fallbackBase = app.internalName.isEmpty
        ? '${app.appId}'
        : app.internalName;
    final fileName = _sanitizeMrpFileName(
      headerName ?? '${fallbackBase}_${version.versionCode}.mrp',
    );
    final file = File(
      '${destinationDir.path}${Platform.pathSeparator}$fileName',
    );
    final tempFile = File('${file.path}.download');

    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await response.pipe(tempFile.openWrite());
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    return DownloadedMrp(file: file, version: version);
  }

  Uri resolveAssetUri(String pathOrUrl) => _resolveApiUri(pathOrUrl);

  Future<PagedResult<AppStoreApp>> _fetchAppPage(
    String path,
    Map<String, String> query,
  ) async {
    final json = await _getJson(path, query);
    return _readPagedResult(json, AppStoreApp.fromJson);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _getResponse(_buildUri(path, query));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppStoreApiException(
        _messageFromJsonBody(body),
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) {
      throw const AppStoreApiException('服务端返回格式无效');
    }
    return data;
  }

  Future<HttpClientResponse> _getResponse(Uri uri) async {
    final timestamp = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final nonce = _createNonce();
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('X-App-Key', config.key);
    request.headers.set('X-App-Timestamp', timestamp);
    request.headers.set('X-App-Nonce', nonce);
    request.headers.set(
      'X-App-Signature',
      _signature(method: 'GET', uri: uri, timestamp: timestamp, nonce: nonce),
    );
    return request.close();
  }

  Uri _buildUri(String path, Map<String, String> query) {
    final base = config.baseUri;
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final child = path.startsWith('/') ? path : '/$path';
    final mergedQuery = <String, String>{...base.queryParameters, ...query};
    return base.replace(path: '$prefix$child', queryParameters: mergedQuery);
  }

  Uri _resolveApiUri(String pathOrUrl) {
    final parsed = Uri.parse(pathOrUrl);
    if (parsed.hasScheme) {
      return parsed;
    }

    final base = config.baseUri;
    final path = parsed.path.startsWith('/')
        ? parsed.path
        : '${base.path.endsWith('/') ? base.path : '${base.path}/'}${parsed.path}';
    return base.replace(path: path, query: parsed.query);
  }

  String _signature({
    required String method,
    required Uri uri,
    required String timestamp,
    required String nonce,
  }) {
    final message = [
      method.toUpperCase(),
      uri.path,
      _canonicalQuery(uri),
      timestamp,
      nonce,
      _emptyBodySha256,
    ].join('\n');
    final hmac = Hmac(sha256, utf8.encode(config.secret));
    return hmac.convert(utf8.encode(message)).toString();
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

  String _createNonce() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${base64UrlEncode(bytes).replaceAll('=', '')}';
  }
}

PagedResult<T> _readPagedResult<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) itemFromJson,
) {
  final itemsJson = json['items'];
  return PagedResult<T>(
    items: itemsJson is List
        ? itemsJson.whereType<Map<String, dynamic>>().map(itemFromJson).toList()
        : const [],
    total: _readInt(json['total']),
    page: _readInt(json['page'], fallback: 1),
    pageSize: _readInt(json['page_size'], fallback: 20),
  );
}

Map<String, String> _queryParams(Map<String, String?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        entry.key: entry.value!,
  };
}

Future<String> _readError(HttpClientResponse response) async {
  final body = await response.transform(utf8.decoder).join();
  return _messageFromJsonBody(body);
}

String _messageFromJsonBody(String body) {
  if (body.trim().isEmpty) {
    return '请求失败';
  }
  try {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) {
      final error = _nullableString(json['error']);
      if (error != null && error.isNotEmpty) {
        return error;
      }
    }
  } catch (_) {
    // Use the raw body preview below.
  }
  return body.length > 120 ? '${body.substring(0, 120)}...' : body;
}

String? _filenameFromDisposition(String? disposition) {
  if (disposition == null || disposition.isEmpty) {
    return null;
  }
  final starMatch = RegExp(
    r"filename\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(disposition);
  if (starMatch != null) {
    return Uri.decodeComponent(starMatch.group(1)!);
  }
  final quotedMatch = RegExp(
    r'filename="([^"]+)"',
    caseSensitive: false,
  ).firstMatch(disposition);
  if (quotedMatch != null) {
    return quotedMatch.group(1);
  }
  final plainMatch = RegExp(
    r'filename=([^;]+)',
    caseSensitive: false,
  ).firstMatch(disposition);
  return plainMatch?.group(1)?.trim();
}

String _sanitizeMrpFileName(String value) {
  var name = value
      .split('/')
      .last
      .split(r'\')
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim();
  if (name.isEmpty) {
    name = 'download.mrp';
  }
  if (!name.toLowerCase().endsWith('.mrp')) {
    name = '$name.mrp';
  }
  return name;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _readString(dynamic value) => _nullableString(value) ?? '';

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}
