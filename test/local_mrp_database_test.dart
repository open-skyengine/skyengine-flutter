import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/local_mrp_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('stores path, hash, and resolution', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final mrp = await File(
      '${tempDir.path}${Platform.pathSeparator}demo.mrp',
    ).writeAsString('MRP-DATA');
    final database = _databaseFor(tempDir);

    try {
      await database.open(
        initialRecordsProvider: () async => [
          LocalMrpRecord(path: mrp.path, hash: 'initial-hash'),
        ],
      );
      await database.updateResolution(mrp.path, '320x480');

      final record = await database.recordForPath(mrp.path);
      expect(record?.path, mrp.absolute.path);
      expect(record?.hash, 'initial-hash');
      expect(record?.resolution, '320x480');
      expect((await database.recordForHash('initial-hash'))?.path, mrp.path);
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('upsert refreshes hash without clearing resolution', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final mrp = await File(
      '${tempDir.path}${Platform.pathSeparator}demo.mrp',
    ).writeAsString('MRP-DATA');
    final database = _databaseFor(tempDir);

    try {
      await database.open();
      await database.upsert(
        path: mrp.path,
        hash: 'old-hash',
        resolution: '240x320',
      );
      await database.upsert(path: mrp.path, hash: 'new-hash');

      final record = await database.recordForPath(mrp.path);
      expect(record?.hash, 'new-hash');
      expect(record?.resolution, '240x320');
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('startup cleanup deletes records whose files no longer exist', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final mrp = await File(
      '${tempDir.path}${Platform.pathSeparator}missing.mrp',
    ).writeAsString('MRP-DATA');
    final database = _databaseFor(tempDir);

    try {
      await database.open(
        initialRecordsProvider: () async => [
          LocalMrpRecord(path: mrp.path, hash: 'hash'),
        ],
      );
      await mrp.delete();

      expect(await database.deleteMissingFiles(), 1);
      expect(await database.records(), isEmpty);
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'initial files are imported only when the database is created',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'skyengine_local_database_test_',
      );
      final first = await File(
        '${tempDir.path}${Platform.pathSeparator}first.mrp',
      ).writeAsString('FIRST');
      final second = await File(
        '${tempDir.path}${Platform.pathSeparator}second.mrp',
      ).writeAsString('SECOND');
      var database = _databaseFor(tempDir);

      try {
        await database.open(
          initialRecordsProvider: () async => [
            LocalMrpRecord(path: first.path, hash: 'first'),
          ],
        );
        await database.close();

        database = _databaseFor(tempDir);
        await database.open(
          initialRecordsProvider: () async => [
            LocalMrpRecord(path: second.path, hash: 'second'),
          ],
        );

        expect((await database.records()).map((record) => record.path), [
          first.absolute.path,
        ]);
      } finally {
        await database.close();
        await tempDir.delete(recursive: true);
      }
    },
  );
}

LocalMrpDatabase _databaseFor(Directory directory) {
  return LocalMrpDatabase(
    databaseFactory: databaseFactoryFfi,
    databasePathProvider: () async =>
        '${directory.path}${Platform.pathSeparator}$localMrpDatabaseFileName',
  );
}
