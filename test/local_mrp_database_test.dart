import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/models/keypad_mode.dart';
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
          LocalMrpRecord(
            path: mrp.path,
            hash: 'initial-hash',
            keypadMode: KeypadMode.numeric,
          ),
        ],
      );
      await database.updateResolution(mrp.path, '320x480');

      final record = await database.recordForPath(mrp.path);
      expect(record?.path, mrp.absolute.path);
      expect(record?.hash, 'initial-hash');
      expect(record?.resolution, '320x480');
      expect(record?.addedAt, isNotNull);
      expect(record?.keypadMode, KeypadMode.numeric);
      expect((await database.recordForHash('initial-hash'))?.path, mrp.path);
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'upsert refreshes hash without clearing resolution or added time',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'skyengine_local_database_test_',
      );
      final mrp = await File(
        '${tempDir.path}${Platform.pathSeparator}demo.mrp',
      ).writeAsString('MRP-DATA');
      final database = _databaseFor(tempDir);

      try {
        await database.open();
        final originalAddedAt = DateTime(2026, 7, 30, 12);
        await database.upsert(
          path: mrp.path,
          hash: 'old-hash',
          resolution: '240x320',
          addedAt: originalAddedAt,
          keypadMode: KeypadMode.joystick,
        );
        await database.upsert(
          path: mrp.path,
          hash: 'new-hash',
          addedAt: DateTime(2026, 7, 31, 12),
        );

        final record = await database.recordForPath(mrp.path);
        expect(record?.hash, 'new-hash');
        expect(record?.resolution, '240x320');
        expect(
          record?.addedAt.millisecondsSinceEpoch,
          originalAddedAt.millisecondsSinceEpoch,
        );
        expect(record?.keypadMode, KeypadMode.joystick);
      } finally {
        await database.close();
        await tempDir.delete(recursive: true);
      }
    },
  );

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

  test('records are ordered by added time descending', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final older = await File(
      '${tempDir.path}${Platform.pathSeparator}older.mrp',
    ).writeAsString('OLDER');
    final newer = await File(
      '${tempDir.path}${Platform.pathSeparator}newer.mrp',
    ).writeAsString('NEWER');
    final database = _databaseFor(tempDir);

    try {
      await database.open();
      await database.upsert(
        path: older.path,
        hash: 'older',
        addedAt: DateTime(2026, 7, 30, 12),
      );
      await database.upsert(
        path: newer.path,
        hash: 'newer',
        addedAt: DateTime(2026, 7, 31, 12),
      );

      expect((await database.records()).map((record) => record.path), [
        newer.absolute.path,
        older.absolute.path,
      ]);
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('version 1 database is migrated with an added time', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final mrp = await File(
      '${tempDir.path}${Platform.pathSeparator}legacy.mrp',
    ).writeAsString('LEGACY');
    final databasePath =
        '${tempDir.path}${Platform.pathSeparator}$localMrpDatabaseFileName';
    final beforeMigration = DateTime.now().millisecondsSinceEpoch;
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE local_mrp_files (
              path TEXT PRIMARY KEY,
              hash TEXT NOT NULL,
              resolution TEXT
            )
          ''');
        },
      ),
    );
    await legacyDatabase.insert('local_mrp_files', {
      'path': mrp.absolute.path,
      'hash': 'legacy-hash',
      'resolution': null,
    });
    await legacyDatabase.close();
    final database = _databaseFor(tempDir);

    try {
      await database.open();

      final record = await database.recordForPath(mrp.path);
      expect(record?.hash, 'legacy-hash');
      expect(record?.keypadMode, isNull);
      expect(
        record?.addedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(beforeMigration),
      );
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('version 2 database is migrated with keypad mode support', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'skyengine_local_database_test_',
    );
    final mrp = await File(
      '${tempDir.path}${Platform.pathSeparator}version2.mrp',
    ).writeAsString('VERSION-2');
    final databasePath =
        '${tempDir.path}${Platform.pathSeparator}$localMrpDatabaseFileName';
    final addedAt = DateTime(2026, 7, 31, 12).millisecondsSinceEpoch;
    final version2Database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE local_mrp_files (
              path TEXT PRIMARY KEY,
              hash TEXT NOT NULL,
              resolution TEXT,
              added_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    await version2Database.insert('local_mrp_files', {
      'path': mrp.absolute.path,
      'hash': 'version2-hash',
      'resolution': null,
      'added_at': addedAt,
    });
    await version2Database.close();
    final database = _databaseFor(tempDir);

    try {
      await database.open();
      await database.updateKeypadMode(mrp.path, KeypadMode.full);

      final record = await database.recordForPath(mrp.path);
      expect(record?.keypadMode, KeypadMode.full);
      expect(record?.addedAt.millisecondsSinceEpoch, addedAt);
    } finally {
      await database.close();
      await tempDir.delete(recursive: true);
    }
  });
}

LocalMrpDatabase _databaseFor(Directory directory) {
  return LocalMrpDatabase(
    databaseFactory: databaseFactoryFfi,
    databasePathProvider: () async =>
        '${directory.path}${Platform.pathSeparator}$localMrpDatabaseFileName',
  );
}
