import 'dart:io';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_watch_later_');
    db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
    await db.upsertChannel(
      const Channel(id: 'c1', title: 'Canale', addedAt: 1),
    );
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  VideoItem video(String id, int publishedAt) {
    return VideoItem(
      id: id,
      channelId: 'c1',
      channelTitle: 'Canale',
      title: 'Video $id',
      description: '',
      publishedAt: publishedAt,
    );
  }

  test(
    'la lista è ordinata per data di salvataggio, non di pubblicazione',
    () async {
      await db.upsertVideo(video('nuovo-ma-pubblicato-dopo', 200));
      await db.upsertVideo(video('vecchio-ma-salvato-dopo', 100));

      await db.setQueued('nuovo-ma-pubblicato-dopo', true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.setQueued('vecchio-ma-salvato-dopo', true);

      final saved = await db.watchLater();
      expect(saved.map((item) => item.id), [
        'vecchio-ma-salvato-dopo',
        'nuovo-ma-pubblicato-dopo',
      ]);
      expect(saved.every((item) => item.watchLater), isTrue);
      expect(saved.every((item) => item.watchLaterAt != null), isTrue);
    },
  );

  test('un refresh del feed non cambia la data di salvataggio', () async {
    final item = video('a1', 100);
    await db.upsertVideo(item);
    await db.setQueued('a1', true);

    final before = (await db.watchLater()).single.watchLaterAt;
    expect(before, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.upsertVideo(item.copyWith(title: 'Titolo aggiornato dal feed'));

    final after = (await db.watchLater()).single;
    expect(after.title, 'Titolo aggiornato dal feed');
    expect(after.watchLaterAt, before);
  });

  test('rimuovere dalla lista azzera appartenenza e data', () async {
    await db.upsertVideo(video('a1', 100));
    await db.setQueued('a1', true);
    expect(await db.watchLater(), hasLength(1));

    await db.setQueued('a1', false);
    expect(await db.watchLater(), isEmpty);

    final stored = (await db.videosForChannel('c1')).single;
    expect(stored.watchLater, isFalse);
    expect(stored.watchLaterAt, isNull);
  });

  test('la migrazione da v6 conserva gli elementi in watch later', () async {
    final legacyPath = p.join(temp.path, 'legacy.sqlite');
    sqfliteFfiInit();
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (legacyDb, _) async {
          await legacyDb.execute('''
            CREATE TABLE channels (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL DEFAULT '',
              handle TEXT,
              added_at INTEGER NOT NULL,
              last_checked INTEGER,
              muted INTEGER NOT NULL DEFAULT 0,
              show_in_latest INTEGER NOT NULL DEFAULT 1,
              default_playback_rate REAL,
              error TEXT
            )
          ''');
          await legacyDb.execute('''
            CREATE TABLE videos (
              id TEXT PRIMARY KEY,
              channel_id TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              published_at INTEGER NOT NULL,
              first_seen_at INTEGER,
              duration_seconds INTEGER,
              status TEXT NOT NULL DEFAULT 'new',
              queued INTEGER NOT NULL DEFAULT 0,
              progress_seconds INTEGER NOT NULL DEFAULT 0,
              fetched_at INTEGER NOT NULL,
              keywords TEXT,
              keywords_fetched INTEGER NOT NULL DEFAULT 0,
              watched_at INTEGER,
              local_path TEXT,
              download_status TEXT NOT NULL DEFAULT 'none',
              downloaded_at INTEGER,
              download_error TEXT,
              chapters TEXT,
              chapters_fetched INTEGER NOT NULL DEFAULT 0,
              source TEXT NOT NULL DEFAULT 'rss',
              FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
            )
          ''');
          await legacyDb.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await legacy.insert('channels', {
      'id': 'c1',
      'title': 'Canale',
      'added_at': 1,
    });
    await legacy.insert('videos', {
      'id': 'a1',
      'channel_id': 'c1',
      'title': 'Video salvato prima della migrazione',
      'description': '',
      'published_at': 100,
      'status': 'seen',
      'queued': 1,
      'fetched_at': 123,
    });
    await legacy.close();

    final upgraded = AppDatabase(pathOverride: legacyPath);
    await upgraded.open();
    final saved = await upgraded.watchLater();
    expect(saved.single.id, 'a1');
    expect(saved.single.watchLaterAt, 123);
    await upgraded.close();
  });
}
