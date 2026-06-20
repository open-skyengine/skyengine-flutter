import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}

Future<File> _writeMrpFile(Directory dir, String name) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsString('MRP-DATA');
  return file;
}

List<String> _names(List<FileSystemEntity> files) {
  return files
      .map((file) => file.path.split(Platform.pathSeparator).last)
      .toList();
}
