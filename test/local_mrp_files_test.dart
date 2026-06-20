import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:skyengine/local_mrp_files.dart';

void main() {
  test(
    'hide removes an MRP from local scans without deleting the file',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'skyengine_local_files_test_',
      );
      final mrpFile = await _writeMrpFile(tempDir, 'demo.mrp');

      try {
        final localFiles = LocalMrpFiles();

        expect(_names(localFiles.scan(tempDir.path)), ['demo.mrp']);

        localFiles.hide(mrpFile.path);

        expect(localFiles.scan(tempDir.path), isEmpty);
        expect(await mrpFile.exists(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('deleteFile removes the backing MRP and clears hidden state', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_files_test_',
    );
    final mrpFile = await _writeMrpFile(tempDir, 'demo.mrp');

    try {
      final localFiles = LocalMrpFiles()..hide(mrpFile.path);

      expect(await localFiles.deleteFile(mrpFile.path), isTrue);

      expect(await mrpFile.exists(), isFalse);
      expect(localFiles.scan(tempDir.path), isEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('scan returns only visible MRP files sorted by name', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_files_test_',
    );

    try {
      await _writeMrpFile(tempDir, 'b.mrp');
      await _writeMrpFile(tempDir, 'a.mrp');
      await File(
        '${tempDir.path}${Platform.pathSeparator}readme.txt',
      ).writeAsString('ignored');

      final localFiles = LocalMrpFiles();

      expect(_names(localFiles.scan(tempDir.path)), ['a.mrp', 'b.mrp']);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('scan parses MRP metadata for display', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_files_test_',
    );

    try {
      await _writeMrpFile(
        tempDir,
        'renamed.mrp',
        appName: '冒泡幻想',
        vendor: '斯凯网络',
        version: 7,
        fileHeaderName: 'mx.mrp',
      );

      final file = LocalMrpFiles().scan(tempDir.path).single;

      expect(file.fileName, 'renamed.mrp');
      expect(file.displayName, '冒泡幻想');
      expect(file.vendorAndVersion, '斯凯网络 · 版本 7');
      expect(file.metadata.fileHeaderName, 'mx.mrp');
      expect(file.metadata.validHeader, isTrue);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}

Future<File> _writeMrpFile(
  Directory dir,
  String name, {
  String? appName,
  String? vendor,
  int version = 1,
  String fileHeaderName = 'demo.mrp',
}) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  if (appName == null && vendor == null) {
    await file.writeAsString('MRP-DATA');
  } else {
    await file.writeAsBytes(
      _mrpHeader(
        fileHeaderName: fileHeaderName,
        appName: appName ?? '',
        vendor: vendor ?? '',
        version: version,
      ),
    );
  }
  return file;
}

List<String> _names(List<LocalMrpFile> files) {
  return files.map((file) => file.fileName).toList();
}

Uint8List _mrpHeader({
  required String fileHeaderName,
  required String appName,
  required String vendor,
  required int version,
}) {
  final bytes = Uint8List(208);
  bytes.setAll(0, 'MRPG'.codeUnits);
  _writeGbkField(bytes, 16, 12, fileHeaderName);
  _writeGbkField(bytes, 28, 24, appName);
  ByteData.sublistView(bytes).setInt32(68, 1001, Endian.little);
  ByteData.sublistView(bytes).setInt32(72, version, Endian.little);
  _writeGbkField(bytes, 88, 40, vendor);
  _writeGbkField(bytes, 128, 64, '测试说明');
  ByteData.sublistView(bytes).setUint16(204, 240, Endian.little);
  ByteData.sublistView(bytes).setUint16(206, 320, Endian.little);
  return bytes;
}

void _writeGbkField(Uint8List bytes, int offset, int length, String value) {
  final encoded = gbk_bytes.encode(value);
  bytes.setAll(offset, encoded.take(length));
}
