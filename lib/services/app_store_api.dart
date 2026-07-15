import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

const String kDefaultAppStoreBaseUrl = 'https://mrp.jysafe.cn/api/app/v1';
const String kDefaultAppStoreKey = 'dev-app-key';
const String kDefaultAppStoreSecret = 'dev-app-secret-change-me';

const _emptyBodySha256 =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

typedef DownloadProgressCallback =
    void Function(int downloadedBytes, int totalBytes);

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

class AppStoreEmulatorVersion {
  final int id;
  final String platform;
  final int versionCode;
  final String version;
  final String changelog;
  final String? downloadUrl;
  final int fileSize;
  final String checksum;
  final bool forceUpdate;

  const AppStoreEmulatorVersion({
    required this.id,
    required this.platform,
    required this.versionCode,
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.fileSize,
    required this.checksum,
    required this.forceUpdate,
  });

  factory AppStoreEmulatorVersion.fromJson(Map<String, dynamic> json) {
    return AppStoreEmulatorVersion(
      id: _readInt(json['id']),
      platform: _readString(json['platform']),
      versionCode: _readInt(json['version_code']),
      version: _readString(json['version']),
      changelog: _readString(json['changelog']),
      downloadUrl: _nullableString(json['download_url']),
      fileSize: _readInt(json['file_size']),
      checksum: _readString(json['checksum']),
      forceUpdate: _readBool(json['force_update']),
    );
  }
}

class AppStoreEmulatorUpdate {
  final bool updateAvailable;
  final AppStoreEmulatorVersion? latest;

  const AppStoreEmulatorUpdate({
    required this.updateAvailable,
    required this.latest,
  });

  factory AppStoreEmulatorUpdate.fromJson(Map<String, dynamic> json) {
    final latestJson = json['latest'];
    return AppStoreEmulatorUpdate(
      updateAvailable: _readBool(json['update_available']),
      latest: latestJson is Map<String, dynamic>
          ? AppStoreEmulatorVersion.fromJson(latestJson)
          : null,
    );
  }
}

class AppStoreHostMapping {
  final String domain;
  final String ip;

  const AppStoreHostMapping({required this.domain, required this.ip});

  factory AppStoreHostMapping.fromJson(Map<String, dynamic> json) {
    return AppStoreHostMapping(
      domain: _readString(json['domain']),
      ip: _readString(json['ip']),
    );
  }
}

class AppStoreConfig {
  final List<AppStoreHostMapping> hosts;

  const AppStoreConfig({required this.hosts});

  factory AppStoreConfig.fromJson(Map<String, dynamic> json) {
    final hostsJson = json['hosts'];
    return AppStoreConfig(
      hosts: hostsJson is List
          ? hostsJson
                .whereType<Map<String, dynamic>>()
                .map(AppStoreHostMapping.fromJson)
                .where((host) => host.domain.isNotEmpty && host.ip.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class DownloadedMrp {
  final File file;
  final AppStoreVersion version;
  final bool alreadyDownloaded;

  const DownloadedMrp({
    required this.file,
    required this.version,
    this.alreadyDownloaded = false,
  });
}

class DownloadedEmulatorApk {
  final File file;
  final AppStoreEmulatorVersion version;
  final bool alreadyDownloaded;

  const DownloadedEmulatorApk({
    required this.file,
    required this.version,
    this.alreadyDownloaded = false,
  });
}

class AppStoreEmulatorDownloadRequest {
  final Uri uri;
  final File target;
  final Map<String, String> headers;
  final int expectedSize;
  final String checksum;
  final bool alreadyDownloaded;

  const AppStoreEmulatorDownloadRequest({
    required this.uri,
    required this.target,
    required this.headers,
    required this.expectedSize,
    required this.checksum,
    required this.alreadyDownloaded,
  });
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
    DownloadProgressCallback? onProgress,
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

    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    final downloadedFile = await _findDownloadedFile(
      app: app,
      version: version,
      package: package,
      destinationDir: destinationDir,
      resolution: resolution,
    );
    if (downloadedFile != null) {
      return DownloadedMrp(
        file: downloadedFile,
        version: version,
        alreadyDownloaded: true,
      );
    }

    final uri = package?.downloadUrl == null
        ? _buildUri(
            '/apps/${app.appId}/versions/${version.versionCode}/download',
            _queryParams({'resolution': resolution}),
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

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await _writeResponseToFile(
        response,
        tempFile,
        totalBytes: package != null && package.fileSize > 0
            ? package.fileSize
            : response.contentLength,
        onProgress: onProgress,
      );
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

    try {
      await _recordDownloadedFile(
        app: app,
        version: version,
        package: package,
        destinationDir: destinationDir,
        resolution: resolution,
        file: file,
      );
    } catch (_) {
      // The file is valid even if local cache metadata cannot be updated.
    }

    return DownloadedMrp(file: file, version: version);
  }

  Future<AppStoreEmulatorUpdate> checkEmulatorUpdate({
    int? versionCode,
    String platform = 'android',
  }) async {
    final json = await _getJson(
      '/emulator/updates',
      _queryParams({
        'platform': platform,
        if (versionCode != null) 'version_code': '$versionCode',
      }),
    );
    return AppStoreEmulatorUpdate.fromJson(json);
  }

  Future<DownloadedEmulatorApk> downloadEmulatorVersion({
    required AppStoreEmulatorVersion version,
    required Directory destinationDir,
    DownloadProgressCallback? onProgress,
  }) async {
    final downloadRequest = await prepareEmulatorVersionDownload(
      version: version,
      destinationDir: destinationDir,
    );
    if (downloadRequest.alreadyDownloaded) {
      return DownloadedEmulatorApk(
        file: downloadRequest.target,
        version: version,
        alreadyDownloaded: true,
      );
    }

    final response = await _getResponse(downloadRequest.uri);
    if (response.statusCode != HttpStatus.ok) {
      final message = await _readError(response);
      throw AppStoreApiException(message, statusCode: response.statusCode);
    }

    final tempFile = File('${downloadRequest.target.path}.download');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await _writeResponseToFile(
        response,
        tempFile,
        totalBytes: version.fileSize > 0
            ? version.fileSize
            : response.contentLength,
        onProgress: onProgress,
      );
      if (!await _hasExpectedEmulatorApkContents(tempFile, version)) {
        throw const AppStoreApiException('下载的更新包不完整或校验失败');
      }
      if (await downloadRequest.target.exists()) {
        await downloadRequest.target.delete();
      }
      await tempFile.rename(downloadRequest.target.path);
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    return DownloadedEmulatorApk(
      file: downloadRequest.target,
      version: version,
    );
  }

  Future<AppStoreEmulatorDownloadRequest> prepareEmulatorVersionDownload({
    required AppStoreEmulatorVersion version,
    required Directory destinationDir,
  }) async {
    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    final target = File(
      '${destinationDir.path}${Platform.pathSeparator}'
      '${_emulatorApkFileName(version)}',
    );
    await _deleteStaleEmulatorApks(destinationDir, keep: target);

    final downloadedApk = await _findDownloadedEmulatorApk(
      version: version,
      target: target,
    );
    final uri = version.downloadUrl == null
        ? _buildUri('/emulator/versions/${version.id}/download', const {})
        : _resolveApiUri(version.downloadUrl!);

    return AppStoreEmulatorDownloadRequest(
      uri: uri,
      target: downloadedApk ?? target,
      headers: _signedGetHeaders(uri),
      expectedSize: version.fileSize,
      checksum: version.checksum,
      alreadyDownloaded: downloadedApk != null,
    );
  }

  Future<void> cleanupInstalledEmulatorUpdates({
    required Directory destinationDir,
    required int installedVersionCode,
  }) async {
    if (!await destinationDir.exists()) {
      return;
    }

    await for (final entity in destinationDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final fileName = _fileNameFromPath(entity.path);
      final cachedVersionCode = _emulatorVersionCodeFromFileName(fileName);
      final isIncompleteDownload = fileName.toLowerCase().endsWith(
        '.apk.download',
      );
      final isUntrustedLegacyApk =
          fileName.toLowerCase().endsWith('.apk') && cachedVersionCode == null;
      final isInstalledApk =
          cachedVersionCode != null &&
          cachedVersionCode <= installedVersionCode;
      if (isIncompleteDownload || isUntrustedLegacyApk || isInstalledApk) {
        await entity.delete();
      }
    }
  }

  Future<void> _writeResponseToFile(
    HttpClientResponse response,
    File file, {
    required int totalBytes,
    DownloadProgressCallback? onProgress,
  }) async {
    final sink = file.openWrite();
    var downloadedBytes = 0;
    var closed = false;
    onProgress?.call(downloadedBytes, totalBytes);
    try {
      await for (final chunk in response) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(downloadedBytes, totalBytes);
      }
      await sink.close();
      closed = true;
    } catch (_) {
      if (!closed) {
        await sink.close();
      }
      rethrow;
    }
  }

  Future<AppStoreConfig> fetchConfig() async {
    final json = await _getJson('/config', const {});
    return AppStoreConfig.fromJson(json);
  }

  Uri resolveAssetUri(String pathOrUrl) => _resolveApiUri(pathOrUrl);

  Future<File?> _findDownloadedFile({
    required AppStoreApp app,
    required AppStoreVersion version,
    required AppStorePackage? package,
    required Directory destinationDir,
    required String resolution,
  }) async {
    final indexedFileName = await _readDownloadedFileName(
      app: app,
      version: version,
      destinationDir: destinationDir,
      resolution: resolution,
    );
    if (indexedFileName != null) {
      final file = File(
        '${destinationDir.path}${Platform.pathSeparator}$indexedFileName',
      );
      if (await _isCompleteDownloadedFile(file, package)) {
        return file;
      }
    }

    for (final fileName in _downloadedFileNameCandidates(
      app: app,
      version: version,
      package: package,
    )) {
      final file = File(
        '${destinationDir.path}${Platform.pathSeparator}$fileName',
      );
      if (await _isCompleteDownloadedFile(file, package)) {
        return file;
      }
    }
    return _findLegacyDownloadedFile(
      app: app,
      package: package,
      destinationDir: destinationDir,
    );
  }

  Future<File?> _findLegacyDownloadedFile({
    required AppStoreApp app,
    required AppStorePackage? package,
    required Directory destinationDir,
  }) async {
    final prefixes = _legacyDownloadedFilePrefixes(app);
    if (prefixes.isEmpty) {
      return null;
    }
    await for (final entity in destinationDir.list(followLinks: false)) {
      if (entity is! File ||
          !await _isCompleteDownloadedFile(entity, package)) {
        continue;
      }
      final name = entity.uri.pathSegments.last.toLowerCase();
      if (prefixes.any(name.startsWith)) {
        return entity;
      }
    }
    return null;
  }

  Future<String?> _readDownloadedFileName({
    required AppStoreApp app,
    required AppStoreVersion version,
    required Directory destinationDir,
    required String resolution,
  }) async {
    final index = await _readDownloadIndex(destinationDir);
    final entry = index[_downloadIndexKey(app, version, resolution)];
    if (entry is Map<String, dynamic>) {
      return _nullableString(entry['file_name']);
    }
    return null;
  }

  Future<void> _recordDownloadedFile({
    required AppStoreApp app,
    required AppStoreVersion version,
    required AppStorePackage? package,
    required Directory destinationDir,
    required String resolution,
    required File file,
  }) async {
    final index = await _readDownloadIndex(destinationDir);
    index[_downloadIndexKey(app, version, resolution)] = {
      'file_name': _fileNameFromPath(file.path),
      if (package != null) 'file_size': package.fileSize,
      if (package != null && package.checksum.isNotEmpty)
        'checksum': package.checksum,
    };
    await _writeDownloadIndex(destinationDir, index);
  }

  Future<Map<String, dynamic>> _readDownloadIndex(
    Directory destinationDir,
  ) async {
    final file = _downloadIndexFile(destinationDir);
    if (!await file.exists()) {
      return {};
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map<String, dynamic>) {
        final downloads = data['downloads'];
        if (downloads is Map<String, dynamic>) {
          return downloads;
        }
      }
    } catch (_) {
      // Ignore invalid local cache metadata and fall back to file probing.
    }
    return {};
  }

  Future<void> _writeDownloadIndex(
    Directory destinationDir,
    Map<String, dynamic> downloads,
  ) async {
    final file = _downloadIndexFile(destinationDir);
    await file.writeAsString(jsonEncode({'downloads': downloads}));
  }

  Future<bool> _isCompleteDownloadedFile(
    File file,
    AppStorePackage? package,
  ) async {
    if (!await file.exists()) {
      return false;
    }
    if (!file.path.toLowerCase().endsWith('.mrp')) {
      return false;
    }
    final length = await file.length();
    if (length <= 0) {
      return false;
    }
    final expectedSize = package?.fileSize ?? 0;
    return expectedSize <= 0 || length == expectedSize;
  }

  Future<bool> _isCompleteDownloadedEmulatorApk(
    File file,
    AppStoreEmulatorVersion version,
  ) async {
    if (!await file.exists()) {
      return false;
    }
    if (!file.path.toLowerCase().endsWith('.apk')) {
      return false;
    }
    return _hasExpectedEmulatorApkContents(file, version);
  }

  Future<bool> _hasExpectedEmulatorApkContents(
    File file,
    AppStoreEmulatorVersion version,
  ) async {
    if (!await file.exists()) {
      return false;
    }
    final length = await file.length();
    if (length <= 0) {
      return false;
    }
    if (version.fileSize > 0 && length != version.fileSize) {
      return false;
    }
    return _matchesChecksum(file, version.checksum);
  }

  Future<bool> _matchesChecksum(File file, String checksum) async {
    final match = RegExp(
      r'^(?:(sha256|md5)[:=])?([0-9a-f]+)$',
      caseSensitive: false,
    ).firstMatch(checksum.trim());
    if (match == null) {
      return true;
    }

    final expected = match.group(2)!.toLowerCase();
    final algorithmName = match.group(1)?.toLowerCase();
    final Hash? algorithm = switch (algorithmName) {
      'sha256' => sha256,
      'md5' => md5,
      null when expected.length == 64 => sha256,
      null when expected.length == 32 => md5,
      _ => null,
    };
    if (algorithm == null) {
      return true;
    }

    final actual = await algorithm.bind(file.openRead()).first;
    return actual.toString() == expected;
  }

  Future<File?> _findDownloadedEmulatorApk({
    required AppStoreEmulatorVersion version,
    required File target,
  }) async {
    return await _isCompleteDownloadedEmulatorApk(target, version)
        ? target
        : null;
  }

  Future<void> _deleteStaleEmulatorApks(
    Directory destinationDir, {
    required File keep,
  }) async {
    await for (final entity in destinationDir.list(followLinks: false)) {
      if (entity is! File || entity.path == keep.path) {
        continue;
      }
      final name = entity.path.toLowerCase();
      if (name.endsWith('.apk') || name.endsWith('.apk.download')) {
        await entity.delete();
      }
    }
  }

  Iterable<String> _downloadedFileNameCandidates({
    required AppStoreApp app,
    required AppStoreVersion version,
    required AppStorePackage? package,
  }) sync* {
    final fallbackBase = app.internalName.isEmpty
        ? '${app.appId}'
        : app.internalName;
    yield _sanitizeMrpFileName('${fallbackBase}_${version.versionCode}.mrp');

    final packageName = _filenameFromDownloadPath(package?.downloadUrl);
    if (packageName != null) {
      yield _sanitizeMrpFileName(packageName);
    }
  }

  File _downloadIndexFile(Directory destinationDir) {
    return File(
      '${destinationDir.path}${Platform.pathSeparator}.app_store_downloads.json',
    );
  }

  String _downloadIndexKey(
    AppStoreApp app,
    AppStoreVersion version,
    String resolution,
  ) {
    return '${app.appId}:${version.versionCode}:$resolution';
  }

  List<String> _legacyDownloadedFilePrefixes(AppStoreApp app) {
    return {
      '${app.appId}'.toLowerCase(),
      if (app.internalName.isNotEmpty) app.internalName.toLowerCase(),
    }.toList();
  }

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
    final headers = _signedGetHeaders(uri);
    final request = await _httpClient.getUrl(uri);
    headers.forEach(request.headers.set);
    return request.close();
  }

  Map<String, String> _signedGetHeaders(Uri uri) {
    final timestamp = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final nonce = _createNonce();
    return {
      HttpHeaders.acceptHeader: 'application/json',
      'X-App-Key': config.key,
      'X-App-Timestamp': timestamp,
      'X-App-Nonce': nonce,
      'X-App-Signature': _signature(
        method: 'GET',
        uri: uri,
        timestamp: timestamp,
        nonce: nonce,
      ),
    };
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

String? _filenameFromDownloadPath(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) {
    return null;
  }
  final path = Uri.parse(pathOrUrl).path;
  final name = path.split('/').last.trim();
  return name.toLowerCase().endsWith('.mrp') ? name : null;
}

String _fileNameFromPath(String path) =>
    path.split(Platform.pathSeparator).last;

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

String _sanitizeApkFileName(String value) {
  var name = value
      .split('/')
      .last
      .split(r'\')
      .last
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim();
  if (name.isEmpty) {
    name = 'skyengine-update.apk';
  }
  if (!name.toLowerCase().endsWith('.apk')) {
    name = '$name.apk';
  }
  return name;
}

String _emulatorApkFileName(AppStoreEmulatorVersion version) {
  return _sanitizeApkFileName(
    'skyengine-v${version.versionCode}-id${version.id}.apk',
  );
}

int? _emulatorVersionCodeFromFileName(String fileName) {
  final match = RegExp(
    r'^skyengine-v([0-9]+)-id[0-9]+\.apk$',
    caseSensitive: false,
  ).firstMatch(fileName);
  return match == null ? null : int.tryParse(match.group(1)!);
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

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
