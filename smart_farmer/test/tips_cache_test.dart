import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_farmer/features/tips/tips_repository.dart';
import 'package:smart_farmer/features/tips/local_tips_cache.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalTipsCache cache;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tips (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT 'General',
              createdAt TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    cache = LocalTipsCache(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  Tip _makeTip({
    String id = 't1',
    String title = 'Water crops early',
    String body = 'Watering in the morning reduces evaporation.',
    String category = 'Irrigation',
    DateTime? createdAt,
  }) {
    return Tip(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt ?? DateTime(2026, 1, 15),
    );
  }

  // ── Tip model tests ──

  group('Tip model', () {
    test('toMap produces correct keys', () {
      final tip = _makeTip();
      final map = tip.toMap();
      expect(map['id'], 't1');
      expect(map['title'], 'Water crops early');
      expect(map['category'], 'Irrigation');
      expect(map['createdAt'], isA<String>());
    });

    test('fromMap round-trips correctly', () {
      final tip = _makeTip();
      final restored = Tip.fromMap(tip.toMap());
      expect(restored.id, tip.id);
      expect(restored.title, tip.title);
      expect(restored.body, tip.body);
      expect(restored.category, tip.category);
    });
  });

  // ── Cache tests ──

  group('LocalTipsCache', () {
    test('replaceAll stores and getCachedTips retrieves tips', () async {
      final tips = [
        _makeTip(id: 't1', category: 'Maize'),
        _makeTip(id: 't2', category: 'Beans'),
      ];
      await cache.replaceAll(tips);

      final result = await cache.getCachedTips();
      expect(result.length, 2);
    });

    test('getCachedTips filters by category', () async {
      final tips = [
        _makeTip(id: 't1', category: 'Maize'),
        _makeTip(id: 't2', category: 'Beans'),
        _makeTip(id: 't3', category: 'Maize'),
      ];
      await cache.replaceAll(tips);

      final maize = await cache.getCachedTips(category: 'Maize');
      expect(maize.length, 2);

      final beans = await cache.getCachedTips(category: 'Beans');
      expect(beans.length, 1);
    });

    test('getCachedCategories returns distinct sorted list', () async {
      final tips = [
        _makeTip(id: 't1', category: 'Beans'),
        _makeTip(id: 't2', category: 'Maize'),
        _makeTip(id: 't3', category: 'Beans'),
      ];
      await cache.replaceAll(tips);

      final cats = await cache.getCachedCategories();
      expect(cats, ['Beans', 'Maize']);
    });

    test('replaceAll clears old data', () async {
      await cache.replaceAll([_makeTip(id: 't1')]);
      expect((await cache.getCachedTips()).length, 1);

      await cache.replaceAll([_makeTip(id: 't2'), _makeTip(id: 't3')]);
      final result = await cache.getCachedTips();
      expect(result.length, 2);
      expect(result.every((t) => t.id != 't1'), true);
    });

    test('empty cache returns empty list', () async {
      final result = await cache.getCachedTips();
      expect(result, isEmpty);
    });
  });
}
