import 'dart:io';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:crypto/crypto.dart';

class LocalMrpFile {
  final String path;
  final String fileName;
  final MrpMetadata metadata;

  const LocalMrpFile({
    required this.path,
    required this.fileName,
    required this.metadata,
  });

  String get displayName => metadata.name.isEmpty
      ? fileNameWithoutExtension(fileName)
      : metadata.name;

  String get vendorAndVersion {
    final parts = [
      if (metadata.vendor.isNotEmpty) metadata.vendor,
      if (metadata.version != null) '版本 ${metadata.version}',
    ];
    return parts.isEmpty ? fileName : parts.join(' · ');
  }
}

class MrpMetadata {
  final String fileHeaderName;
  final String name;
  final String vendor;
  final String description;
  final int? appId;
  final int? version;
  final int? screenWidth;
  final int? screenHeight;
  final bool validHeader;

  const MrpMetadata({
    this.fileHeaderName = '',
    this.name = '',
    this.vendor = '',
    this.description = '',
    this.appId,
    this.version,
    this.screenWidth,
    this.screenHeight,
    this.validHeader = false,
  });
}

class LocalMrpFiles {
  final Set<String> _hiddenMrpPaths = {};

  List<LocalMrpFile> scan(String mrpDirPath) {
    final dir = Directory(mrpDirPath);
    final files = dir
        .listSync()
        .where(
          (e) =>
              e is File &&
              e.path.toLowerCase().endsWith('.mrp') &&
              !_hiddenMrpPaths.contains(fileListKey(e.path)),
        )
        .toList();
    return readFiles(files.map((file) => file.path));
  }

  List<LocalMrpFile> readFiles(Iterable<String> paths) {
    final files = paths.map(readFile).whereType<LocalMrpFile>().toList();
    files.sort((a, b) => fileName(a.path).compareTo(fileName(b.path)));
    return files;
  }

  LocalMrpFile? readFile(String path) {
    final file = File(path);
    if (!file.existsSync() || !path.toLowerCase().endsWith('.mrp')) {
      return null;
    }
    return LocalMrpFile(
      path: file.absolute.path,
      fileName: fileName(path),
      metadata: readMetadata(path),
    );
  }

  void hide(String path) {
    _hiddenMrpPaths.add(fileListKey(path));
  }

  void unhide(String path) {
    _hiddenMrpPaths.remove(fileListKey(path));
  }

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    final existed = await file.exists();
    if (existed) {
      await file.delete();
    }
    unhide(path);
    return existed;
  }

  String fileListKey(String path) => File(path).absolute.path;

  String fileName(String path) => path.split(Platform.pathSeparator).last;

  Future<String> calculateHash(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  MrpMetadata readMetadata(String path) {
    try {
      final file = File(path);
      final raf = file.openSync();
      final bytes = raf.readSync(_mrpHeaderLength);
      raf.closeSync();
      if (bytes.length < _mrpHeaderLength || !_hasMrpgMagic(bytes)) {
        return const MrpMetadata();
      }

      return MrpMetadata(
        fileHeaderName: _readMrpString(bytes, 16, 12),
        name: _readMrpString(bytes, 28, 24),
        appId: _readInt32Le(bytes, 68),
        version: _readInt32Le(bytes, 72),
        vendor: _readMrpString(bytes, 88, 40),
        description: _readMrpString(bytes, 128, 64),
        screenWidth: _readUint16Le(bytes, 204),
        screenHeight: _readUint16Le(bytes, 206),
        validHeader: true,
      );
    } catch (_) {
      return const MrpMetadata();
    }
  }
}

String fileNameWithoutExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}

const int _mrpHeaderLength = 208;

bool _hasMrpgMagic(Uint8List bytes) {
  return bytes[0] == 0x4d &&
      bytes[1] == 0x52 &&
      bytes[2] == 0x50 &&
      bytes[3] == 0x47;
}

String _readMrpString(Uint8List bytes, int offset, int length) {
  final end = offset + length;
  var zero = offset;
  while (zero < end && bytes[zero] != 0) {
    zero++;
  }
  final raw = bytes.sublist(offset, zero);
  if (raw.isEmpty) {
    return '';
  }
  return gbk.decode(raw, allowMalformed: true).trim();
}

int _readInt32Le(Uint8List bytes, int offset) {
  return ByteData.sublistView(
    bytes,
    offset,
    offset + 4,
  ).getInt32(0, Endian.little);
}

int _readUint16Le(Uint8List bytes, int offset) {
  return ByteData.sublistView(
    bytes,
    offset,
    offset + 2,
  ).getUint16(0, Endian.little);
}
