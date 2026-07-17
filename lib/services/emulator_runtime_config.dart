import 'local_mrp_files.dart';

/// The runtime settings that are applied before an MRP starts.
///
/// This is deliberately separate from [EmulatorSettings], which contains
/// user-editable emulator preferences. A remote config provider can replace
/// the built-in provider without changing the player or FFI boundary.
class EmulatorRuntimeConfig {
  /// The value accepted by `vmrp_api_set_device_date`.
  ///
  /// `host` keeps the normal device date for applications without an
  /// application-specific override.
  final String deviceDate;

  const EmulatorRuntimeConfig({this.deviceDate = 'host'});
}

/// Identifies an MRP using both its host file name and the package name from
/// the MRP header. The latter survives downloads that rename the package.
class EmulatorAppIdentity {
  final String path;
  final String fileName;
  final String? packageName;

  const EmulatorAppIdentity({
    required this.path,
    required this.fileName,
    this.packageName,
  });

  factory EmulatorAppIdentity.fromMrpPath(String path) {
    final localFiles = LocalMrpFiles();
    final fileName = localFiles.fileName(path);
    final metadata = localFiles.readMetadata(path);
    return EmulatorAppIdentity(
      path: path,
      fileName: fileName,
      packageName: metadata.fileHeaderName.isEmpty
          ? null
          : metadata.fileHeaderName,
    );
  }

  /// Candidate names used by config providers, normalized without `.mrp`.
  Iterable<String> get configKeys sync* {
    final seen = <String>{};
    for (final value in [fileName, packageName]) {
      final key = normalizeEmulatorAppKey(value);
      if (key != null && seen.add(key)) {
        yield key;
      }
    }
  }
}

/// Converts a package/file name into a stable config key.
String? normalizeEmulatorAppKey(String? value) {
  if (value == null) {
    return null;
  }
  var normalized = value.trim().replaceAll('\\', '/').toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  final slash = normalized.lastIndexOf('/');
  if (slash >= 0) {
    normalized = normalized.substring(slash + 1);
  }
  if (normalized.endsWith('.mrp')) {
    normalized = normalized.substring(0, normalized.length - 4);
  }
  return normalized.isEmpty ? null : normalized;
}

/// Resolves runtime settings for an MRP.
///
/// A cloud-backed implementation can fetch and cache the same result while
/// retaining this contract.
abstract interface class EmulatorRuntimeConfigProvider {
  Future<EmulatorRuntimeConfig> resolve(EmulatorAppIdentity app);
}

/// Current local fallback configuration.
///
/// Keep application-specific values in this data table rather than in the
/// player startup flow. The table can later be populated by a remote source.
class BuiltInEmulatorRuntimeConfigProvider
    implements EmulatorRuntimeConfigProvider {
  static const Map<String, EmulatorRuntimeConfig> configs = {
    'gtxzj': EmulatorRuntimeConfig(deviceDate: '2011-01-01'),
  };

  const BuiltInEmulatorRuntimeConfigProvider();

  @override
  Future<EmulatorRuntimeConfig> resolve(EmulatorAppIdentity app) async {
    for (final key in app.configKeys) {
      final config = configs[key] ?? _configForDelimitedKey(key);
      if (config != null) {
        return config;
      }
    }
    return const EmulatorRuntimeConfig();
  }

  EmulatorRuntimeConfig? _configForDelimitedKey(String key) {
    // App-store downloads commonly use names such as `gtxzj_7.mrp`, while
    // some handset dumps use an id prefix such as `123-gtxzj.mrp`.
    final parts = key.split(RegExp(r'[-_]'));
    for (final part in parts) {
      if (part == 'gtxzj') {
        return configs['gtxzj'];
      }
    }
    return null;
  }
}

/// Resolves the local built-in rules for a path without exposing file parsing
/// to callers that only need the resulting runtime settings.
Future<EmulatorRuntimeConfig> emulatorRuntimeConfigForMrp(
  String mrpPath, {
  EmulatorRuntimeConfigProvider provider =
      const BuiltInEmulatorRuntimeConfigProvider(),
}) {
  return provider.resolve(EmulatorAppIdentity.fromMrpPath(mrpPath));
}
