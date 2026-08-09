import 'package:flutter_test/flutter_test.dart';
import 'package:skyengine/services/search_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('search history is deduplicated, bounded, and clearable', () async {
    final service = SearchHistoryService(
      databaseFactory: databaseFactoryFfi,
      databasePathProvider: () async => inMemoryDatabasePath,
    );
    await service.open();

    for (var index = 0; index <= kMaxSearchHistoryEntries; index += 1) {
      await service.add('term-$index');
    }
    await service.add('term-10');

    final entries = await service.entries();
    expect(entries, hasLength(kMaxSearchHistoryEntries));
    expect(entries.first, 'term-10');
    expect(entries.where((term) => term == 'term-10'), hasLength(1));
    expect(entries, isNot(contains('term-0')));

    await service.clear();
    expect(await service.entries(), isEmpty);
    await service.close();
  });
}
