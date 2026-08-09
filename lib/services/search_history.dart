import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kMaxSearchHistoryEntries = 20;
const String _tableName = 'search_history';
const String _databaseFileName = 'app_store_search.db';

/// Persistent search terms for the app store, newest first.
class SearchHistoryService {
  SearchHistoryService({
    DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePathProvider,
  }) : _databaseFactory = databaseFactory,
       _databasePathProvider = databasePathProvider;

  final DatabaseFactory? _databaseFactory;
  final Future<String> Function()? _databasePathProvider;
  Database? _database;

  Future<void> open() async {
    if (_database != null) {
      return;
    }
    final factory = _databaseFactory ?? _defaultDatabaseFactory();
    final path = await (_databasePathProvider ?? _defaultDatabasePath)();
    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE $_tableName (
            term TEXT PRIMARY KEY,
            added_at INTEGER NOT NULL
          )
        '''),
      ),
    );
  }

  Future<List<String>> entries() async {
    final rows = await _requireDatabase().query(
      _tableName,
      columns: ['term'],
      orderBy: 'added_at DESC, term COLLATE NOCASE',
      limit: kMaxSearchHistoryEntries,
    );
    return rows.map((row) => row['term']! as String).toList();
  }

  Future<void> add(String term) async {
    final normalized = term.trim();
    if (normalized.isEmpty) {
      return;
    }
    final database = _requireDatabase();
    await database.transaction((transaction) async {
      final latestRows = await transaction.rawQuery(
        'SELECT MAX(added_at) AS latest FROM $_tableName',
      );
      final latest = latestRows.single['latest'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      await transaction.delete(
        _tableName,
        where: 'term = ?',
        whereArgs: [normalized],
      );
      await transaction.insert(_tableName, {
        'term': normalized,
        'added_at': now > latest ? now : latest + 1,
      });
      await transaction.execute(
        'DELETE FROM $_tableName WHERE term NOT IN ('
        'SELECT term FROM $_tableName ORDER BY added_at DESC LIMIT ?'
        ')',
        [kMaxSearchHistoryEntries],
      );
    });
  }

  Future<void> clear() async {
    await _requireDatabase().delete(_tableName);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('SearchHistoryService.open() must be called first');
    }
    return database;
  }
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
  return '${directory.path}${Platform.pathSeparator}$_databaseFileName';
}
