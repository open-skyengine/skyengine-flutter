import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/keypad_mode.dart';

const localMrpDatabaseFileName = 'local_mrp.db';

class LocalMrpRecord {
  final String path;
  final String hash;
  final String? resolution;
  final DateTime addedAt;
  final KeypadMode? keypadMode;

  LocalMrpRecord({
    required this.path,
    required this.hash,
    this.resolution,
    DateTime? addedAt,
    this.keypadMode,
  }) : addedAt = addedAt ?? DateTime.now();

  factory LocalMrpRecord.fromMap(Map<String, Object?> map) {
    return LocalMrpRecord(
      path: map['path']! as String,
      hash: map['hash']! as String,
      resolution: map['resolution'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at']! as int),
      keypadMode: parseKeypadMode(map['keypad_mode'] as String?),
    );
  }
}

class LocalMrpDatabase {
  LocalMrpDatabase({
    DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePathProvider,
  }) : _databaseFactory = databaseFactory,
       _databasePathProvider = databasePathProvider;

  final DatabaseFactory? _databaseFactory;
  final Future<String> Function()? _databasePathProvider;
  Database? _database;

  Future<void> open({
    Future<Iterable<LocalMrpRecord>> Function()? initialRecordsProvider,
  }) async {
    if (_database != null) {
      return;
    }

    var created = false;
    final factory = _databaseFactory ?? _defaultDatabaseFactory();
    final path = await (_databasePathProvider ?? _defaultDatabasePath)();
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE local_mrp_files (
              path TEXT PRIMARY KEY,
              hash TEXT NOT NULL,
              resolution TEXT,
              added_at INTEGER NOT NULL,
              keypad_mode TEXT
            )
          ''');
          await database.execute(
            'CREATE INDEX local_mrp_files_hash_idx ON local_mrp_files(hash)',
          );
          created = true;
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await database.execute(
              'ALTER TABLE local_mrp_files '
              'ADD COLUMN added_at INTEGER NOT NULL DEFAULT 0',
            );
            await database.update('local_mrp_files', {
              'added_at': DateTime.now().millisecondsSinceEpoch,
            }, where: 'added_at = 0');
          }
          if (oldVersion < 3) {
            await database.execute(
              'ALTER TABLE local_mrp_files ADD COLUMN keypad_mode TEXT',
            );
          }
        },
      ),
    );
    _database = database;

    if (created && initialRecordsProvider != null) {
      final initialRecords = await initialRecordsProvider();
      final batch = database.batch();
      for (final record in initialRecords) {
        batch.insert(
          'local_mrp_files',
          _toMap(record),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  Future<List<LocalMrpRecord>> records() async {
    final rows = await _requireDatabase().query(
      'local_mrp_files',
      orderBy: 'added_at DESC, path COLLATE NOCASE',
    );
    return rows.map(LocalMrpRecord.fromMap).toList();
  }

  Future<LocalMrpRecord?> recordForPath(String path) async {
    final rows = await _requireDatabase().query(
      'local_mrp_files',
      where: 'path = ?',
      whereArgs: [_normalizePath(path)],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalMrpRecord.fromMap(rows.single);
  }

  Future<LocalMrpRecord?> recordForHash(String hash) async {
    final rows = await _requireDatabase().query(
      'local_mrp_files',
      where: 'hash = ?',
      whereArgs: [hash],
    );
    for (final row in rows) {
      final record = LocalMrpRecord.fromMap(row);
      if (await File(record.path).exists()) {
        return record;
      }
    }
    return null;
  }

  Future<void> upsert({
    required String path,
    required String hash,
    String? resolution,
    DateTime? addedAt,
    KeypadMode? keypadMode,
  }) async {
    final normalizedPath = _normalizePath(path);
    await _requireDatabase().transaction((transaction) async {
      var effectiveResolution = resolution;
      var effectiveAddedAt = addedAt ?? DateTime.now();
      var effectiveKeypadMode = keypadMode;
      final rows = await transaction.query(
        'local_mrp_files',
        columns: ['resolution', 'added_at', 'keypad_mode'],
        where: 'path = ?',
        whereArgs: [normalizedPath],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        effectiveResolution ??= rows.single['resolution'] as String?;
        effectiveAddedAt = DateTime.fromMillisecondsSinceEpoch(
          rows.single['added_at']! as int,
        );
        effectiveKeypadMode ??= parseKeypadMode(
          rows.single['keypad_mode'] as String?,
        );
      }
      await transaction.insert('local_mrp_files', {
        'path': normalizedPath,
        'hash': hash,
        'resolution': effectiveResolution,
        'added_at': effectiveAddedAt.millisecondsSinceEpoch,
        'keypad_mode': effectiveKeypadMode?.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> updateResolution(String path, String resolution) async {
    await _requireDatabase().update(
      'local_mrp_files',
      {'resolution': resolution},
      where: 'path = ?',
      whereArgs: [_normalizePath(path)],
    );
  }

  Future<void> updateKeypadMode(String path, KeypadMode keypadMode) async {
    await _requireDatabase().update(
      'local_mrp_files',
      {'keypad_mode': keypadMode.name},
      where: 'path = ?',
      whereArgs: [_normalizePath(path)],
    );
  }

  Future<void> delete(String path) async {
    await _requireDatabase().delete(
      'local_mrp_files',
      where: 'path = ?',
      whereArgs: [_normalizePath(path)],
    );
  }

  Future<int> deleteMissingFiles() async {
    final allRecords = await records();
    final missingPaths = <String>[];
    for (final record in allRecords) {
      if (!await File(record.path).exists()) {
        missingPaths.add(record.path);
      }
    }
    if (missingPaths.isEmpty) {
      return 0;
    }

    final batch = _requireDatabase().batch();
    for (final path in missingPaths) {
      batch.delete('local_mrp_files', where: 'path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
    return missingPaths.length;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('LocalMrpDatabase.open() must be called first');
    }
    return database;
  }

  static Map<String, Object?> _toMap(LocalMrpRecord record) {
    return {
      'path': _normalizePath(record.path),
      'hash': record.hash,
      'resolution': record.resolution,
      'added_at': record.addedAt.millisecondsSinceEpoch,
      'keypad_mode': record.keypadMode?.name,
    };
  }

  static String _normalizePath(String path) => File(path).absolute.path;
}

DatabaseFactory _defaultDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return sqflite.databaseFactory;
}

Future<String> _defaultDatabasePath() async {
  final directory = await getApplicationSupportDirectory();
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return '${directory.path}${Platform.pathSeparator}$localMrpDatabaseFileName';
}
