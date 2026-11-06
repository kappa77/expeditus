import 'dart:io';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _settingsSql = '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''';

const _bookmarksSql = '''
  CREATE TABLE bookmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id TEXT NOT NULL,
    position_seconds INTEGER NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
  )
''';

const _v1ChannelsSql = '''
  CREATE TABLE channels (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL DEFAULT '',
    handle TEXT,
    added_at INTEGER NOT NULL,
    last_checked INTEGER,
    muted INTEGER NOT NULL DEFAULT 0,
    error TEXT
  )
''';

const _v1VideosSql = '''
  CREATE TABLE videos (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    published_at INTEGER NOT NULL,
    duration_seconds INTEGER,
    status TEXT NOT NULL DEFAULT 'new',
    queued INTEGER NOT NULL DEFAULT 0,
    progress_seconds INTEGER NOT NULL DEFAULT 0,
    fetched_at INTEGER NOT NULL,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
  )
''';

const _v6ChannelsSql = '''
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
''';

String _v6VideosSql({required bool includeQueuedAt}) =>
    '''
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
    ${includeQueuedAt ? 'queued_at INTEGER,' : ''}
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
''';

Future<Database> _createLegacyDb(
  String path, {
  required int version,
  required String channelsSql,
  required String videosSql,
  List<String> extraSql = const [],
}) async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        await db.execute(channelsSql);
        await db.execute(videosSql);
        await db.execute(_settingsSql);
        for (final sql in extraSql) {
          await db.execute(sql);
        }
      },
    ),
  );
}

Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info("$table")');
  return {for (final row in rows) row['name'] as String};
}

Map<String, Object?> _channelRow({int showInLatest = 1}) => {
  'id': 'c1',
  'title': 'Canale',
  'added_at': 1,
  if (showInLatest != 1) 'show_in_latest': showInLatest,
};

Map<String, Object?> _videoRow({int fetchedAt = 123, int? queuedAt}) => {
  'id': 'a1',
  'channel_id': 'c1',
  'title': 'Video',
  'description': '',
  'published_at': 100,
  'status': 'seen',
  'queued': 1,
  'fetched_at': fetchedAt,
  'queued_at': ?queuedAt,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('expeditus_migrations_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('da v6 a v7 aggiunge queued_at e conserva la lista', () async {
    final path = p.join(temp.path, 'v6.sqlite');
    final legacy = await _createLegacyDb(
      path,
      version: 6,
      channelsSql: _v6ChannelsSql,
      videosSql: _v6VideosSql(includeQueuedAt: false),
    );
    await legacy.insert('channels', _channelRow());
    await legacy.insert('videos', _videoRow());
    await legacy.close();

    final upgraded = AppDatabase(pathOverride: path);
    addTearDown(upgraded.close);
    await upgraded.open();

    final saved = await upgraded.watchLater();
    expect(saved.single.id, 'a1');
    expect(saved.single.watchLaterAt, 123);
  });

  test(
    'una migrazione v7 parziale non fallisce e preserva queued_at',
    () async {
      final path = p.join(temp.path, 'v6_partial.sqlite');
      final legacy = await _createLegacyDb(
        path,
        version: 6,
        channelsSql: _v6ChannelsSql,
        videosSql: _v6VideosSql(includeQueuedAt: true),
      );
      await legacy.insert('channels', _channelRow());
      await legacy.insert('videos', _videoRow(queuedAt: 999));
      await legacy.close();

      final upgraded = AppDatabase(pathOverride: path);
      addTearDown(upgraded.close);
      await upgraded.open();

      final saved = await upgraded.watchLater();
      expect(saved.single.watchLaterAt, 999);
    },
  );

  test('migrazioni parziali da v1 completano lo schema senza errori', () async {
    final path = p.join(temp.path, 'v1_partial.sqlite');
    final legacy = await _createLegacyDb(
      path,
      version: 1,
      channelsSql: _v1ChannelsSql,
      videosSql: _v1VideosSql,
      extraSql: const [
        'ALTER TABLE channels ADD COLUMN show_in_latest INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE videos ADD COLUMN keywords TEXT',
        'ALTER TABLE videos ADD COLUMN keywords_fetched INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE videos ADD COLUMN watched_at INTEGER',
        'ALTER TABLE videos ADD COLUMN chapters TEXT',
        _bookmarksSql,
      ],
    );
    await legacy.insert('channels', _channelRow(showInLatest: 0));
    await legacy.insert('videos', _videoRow());
    await legacy.close();

    final upgraded = AppDatabase(pathOverride: path);
    addTearDown(upgraded.close);
    await upgraded.open();

    final saved = await upgraded.watchLater();
    expect(saved.single.watchLaterAt, 123);
    final channels = await upgraded.getChannels();
    expect(channels.single.showInLatest, isFalse);
    await upgraded.close();

    final raw = await databaseFactoryFfi.openDatabase(path);
    addTearDown(raw.close);

    expect(
      await _columns(raw, 'videos'),
      containsAll(<String>[
        'id',
        'channel_id',
        'title',
        'description',
        'published_at',
        'first_seen_at',
        'duration_seconds',
        'status',
        'queued',
        'queued_at',
        'progress_seconds',
        'fetched_at',
        'keywords',
        'keywords_fetched',
        'watched_at',
        'local_path',
        'download_status',
        'downloaded_at',
        'download_error',
        'chapters',
        'chapters_fetched',
        'source',
      ]),
    );
    expect(
      await _columns(raw, 'channels'),
      containsAll(<String>[
        'id',
        'title',
        'handle',
        'added_at',
        'last_checked',
        'muted',
        'show_in_latest',
        'default_playback_rate',
        'error',
      ]),
    );

    final tables = await raw.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    expect(
      tables.map((row) => row['name']),
      containsAll(<String>['channels', 'videos', 'settings', 'bookmarks']),
    );

    final video = (await raw.query('videos')).single;
    expect(video['first_seen_at'], 123);
    expect(video['source'], 'rss');
    expect(video['download_status'], 'none');
    expect(video['queued_at'], 123);
  });

  test(
    'riaprire un database migrato con user_version 0 non fallisce',
    () async {
      final path = p.join(temp.path, 'reset_version.sqlite');
      final first = AppDatabase(pathOverride: path);
      await first.open();
      await first.upsertChannel(
        const Channel(id: 'c1', title: 'Canale', addedAt: 1),
      );
      await first.upsertVideo(
        const VideoItem(
          id: 'a1',
          channelId: 'c1',
          channelTitle: 'Canale',
          title: 'Video',
          description: '',
          publishedAt: 100,
        ),
      );
      await first.setQueued('a1', true);
      final before = (await first.watchLater()).single.watchLaterAt;
      expect(before, isNotNull);
      await first.close();

      final raw = await databaseFactoryFfi.openDatabase(path);
      await raw.execute('PRAGMA user_version = 0');
      await raw.close();

      final second = AppDatabase(pathOverride: path);
      addTearDown(second.close);
      await second.open();

      final after = (await second.watchLater()).single;
      expect(after.id, 'a1');
      expect(after.watchLaterAt, before);
    },
  );
}
