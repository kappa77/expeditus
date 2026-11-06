import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models.dart';

class AppDatabase {
  AppDatabase({this.pathOverride});

  /// Used by integration tests to point at a temporary database.
  final String? pathOverride;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final path = pathOverride ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'expeditus.sqlite',
        );
    await Directory(p.dirname(path)).create(recursive: true);

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return _db!;
  }

  Future<void> open() async {
    await database;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<List<Channel>> getChannels() async {
    final db = await database;
    final rows = await db.query('channels', orderBy: 'title COLLATE NOCASE');
    return rows.map(Channel.fromMap).toList();
  }

  Future<void> upsertChannel(Channel channel) async {
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO channels (
        id, title, handle, added_at, last_checked, muted, show_in_latest,
        default_playback_rate, error
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = CASE
          WHEN excluded.title <> '' THEN excluded.title
          ELSE channels.title
        END,
        handle = COALESCE(excluded.handle, channels.handle)
      ''',
      [
        channel.id,
        channel.title,
        channel.handle,
        channel.addedAt,
        channel.lastChecked,
        channel.muted ? 1 : 0,
        channel.showInLatest ? 1 : 0,
        channel.defaultPlaybackRate,
        channel.error,
      ],
    );
  }

  Future<void> updateChannelFetch(
    String id, {
    required String title,
    required int lastChecked,
    String? error,
  }) async {
    final db = await database;
    await db.update(
      'channels',
      {
        if (title.trim().isNotEmpty) 'title': title,
        'last_checked': lastChecked,
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setChannelMuted(String id, bool muted) async {
    final db = await database;
    await db.update(
      'channels',
      {'muted': muted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setChannelShowInLatest(String id, bool visible) async {
    final db = await database;
    await db.update(
      'channels',
      {'show_in_latest': visible ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setChannelPlaybackRate(String id, double? rate) async {
    final db = await database;
    await db.update(
      'channels',
      {'default_playback_rate': rate},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteChannel(String id) async {
    final db = await database;
    await db.delete('channels', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertVideo(VideoItem video) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      '''
      INSERT INTO videos (
        id, channel_id, title, description, published_at, first_seen_at,
        duration_seconds, status, queued, queued_at, progress_seconds,
        fetched_at, source
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        published_at = excluded.published_at,
        duration_seconds = COALESCE(excluded.duration_seconds, videos.duration_seconds),
        fetched_at = excluded.fetched_at,
        source = CASE
          WHEN excluded.source = 'rss' THEN 'rss'
          ELSE videos.source
        END
      ''',
      [
        video.id,
        video.channelId,
        video.title,
        video.description,
        video.publishedAt,
        video.firstSeenAt ?? now,
        video.durationSeconds,
        video.status,
        video.queued ? 1 : 0,
        video.queued ? (video.queuedAt ?? now) : null,
        video.progressSeconds,
        now,
        video.source,
      ],
    );
  }

  /// One row per channel: the most recent video.
  Future<List<VideoItem>> latestPerChannel() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY channel_id
                   ORDER BY published_at DESC, id DESC
                 ) AS rn
          FROM videos
        )
        WHERE rn = 1
      )
      AND c.muted = 0
      AND c.show_in_latest = 1
      ORDER BY v.published_at DESC
    ''');
    return rows.map(VideoItem.fromMap).toList();
  }

  /// All videos ever seen in the feeds, newest first, one row per video id.
  Future<List<VideoItem>> rssHistory() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.source = 'rss'
      ORDER BY COALESCE(v.first_seen_at, v.published_at) DESC,
               v.published_at DESC
    ''');
    return rows.map(VideoItem.fromMap).toList();
  }

  /// The explicit watch later list, ordered by when each video was saved.
  Future<List<VideoItem>> queue() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.queued = 1
      ORDER BY COALESCE(v.queued_at, v.published_at) DESC, v.published_at DESC
    ''');
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> watchLater() => queue();

  Future<List<VideoItem>> videosForChannel(String channelId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.channel_id = ?
      ORDER BY v.published_at DESC
      LIMIT 50
      ''',
      [channelId],
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<void> setStatus(
    String videoId,
    String status, {
    int? watchedAt,
  }) async {
    final db = await database;
    final values = <String, Object?>{'status': status};
    if (watchedAt != null) values['watched_at'] = watchedAt;
    await db.update(
      'videos',
      values,
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<void> setQueued(String videoId, bool queued) async {
    final db = await database;
    await db.update(
      'videos',
      {
        'queued': queued ? 1 : 0,
        'queued_at':
            queued ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<void> setProgress(String videoId, int seconds) async {
    final db = await database;
    await db.update(
      'videos',
      {'progress_seconds': seconds},
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<List<VideoItem>> historyForChannel(String channelId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.channel_id = ? AND v.watched_at IS NOT NULL
      ORDER BY v.watched_at DESC
      ''',
      [channelId],
    );
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<List<VideoItem>> downloadedVideos() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, c.title AS channel_title
      FROM videos v
      JOIN channels c ON c.id = v.channel_id
      WHERE v.local_path IS NOT NULL AND v.download_status = 'ready'
      ORDER BY v.downloaded_at DESC
    ''');
    return rows.map(VideoItem.fromMap).toList();
  }

  Future<void> setChapters(
    String videoId,
    List<VideoChapter> chapters,
  ) async {
    final db = await database;
    await db.update(
      'videos',
      {
        'chapters': jsonEncode(chapters.map((chapter) => chapter.toJson()).toList()),
        'chapters_fetched': 1,
      },
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<int> addBookmark(
    String videoId,
    int positionSeconds,
    String note,
  ) async {
    final db = await database;
    return db.insert(
      'bookmarks',
      {
        'video_id': videoId,
        'position_seconds': positionSeconds,
        'note': note,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<VideoBookmark>> bookmarksForVideo(String videoId) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'video_id = ?',
      whereArgs: [videoId],
      orderBy: 'position_seconds ASC',
    );
    return rows.map(VideoBookmark.fromMap).toList();
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setDownload(
    String videoId, {
    required String status,
    String? localPath,
    String? error,
    int? downloadedAt,
  }) async {
    final db = await database;
    final values = <String, Object?>{
      'download_status': status,
      'download_error': error,
    };
    if (status == 'none') {
      values['local_path'] = null;
      values['downloaded_at'] = null;
    } else {
      if (localPath != null) values['local_path'] = localPath;
      if (downloadedAt != null) values['downloaded_at'] = downloadedAt;
    }
    await db.update(
      'videos',
      values,
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  /// The separate local MP4 library, newest addition first.
  Future<List<LocalVideo>> localVideos() async {
    final db = await database;
    final rows = await db.query(
      'local_videos',
      orderBy: 'added_at DESC, title COLLATE NOCASE',
    );
    return rows.map(LocalVideo.fromMap).toList();
  }

  /// Adds a file to the local library. Re-adding the same path refreshes its
  /// metadata but keeps the original added time, so the list does not jump.
  Future<void> upsertLocalVideo(LocalVideo video) async {
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO local_videos (path, title, added_at, duration_seconds)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(path) DO UPDATE SET
        title = excluded.title,
        duration_seconds = COALESCE(
          excluded.duration_seconds,
          local_videos.duration_seconds
        )
      ''',
      [video.path, video.title, video.addedAt, video.durationSeconds],
    );
  }

  /// Removes an entry from the local library; the file itself is untouched.
  Future<void> deleteLocalVideo(String path) async {
    final db = await database;
    await db.delete('local_videos', where: 'path = ?', whereArgs: [path]);
  }

  Future<void> setKeywords(String videoId, List<String> keywords) async {
    final db = await database;
    await db.update(
      'videos',
      {
        'keywords': jsonEncode(keywords),
        'keywords_fetched': 1,
      },
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }
}

/// Creates every table and index at the current schema with IF NOT EXISTS.
/// Used both for fresh databases and before migrations so a partially created
/// database can still be upgraded.
Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS channels (
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
  await db.execute('''
    CREATE TABLE IF NOT EXISTS videos (
      id TEXT PRIMARY KEY,
      channel_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      published_at INTEGER NOT NULL,
      first_seen_at INTEGER,
      duration_seconds INTEGER,
      status TEXT NOT NULL DEFAULT 'new',
      queued INTEGER NOT NULL DEFAULT 0,
      queued_at INTEGER,
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
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_videos_channel ON videos(channel_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_videos_published ON videos(published_at DESC)',
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS bookmarks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      video_id TEXT NOT NULL,
      position_seconds INTEGER NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_videos (
      path TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      added_at INTEGER NOT NULL,
      duration_seconds INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

Future<bool> _hasColumn(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info("$table")');
  return rows.any((row) => row['name'] == column);
}

/// Adds a column only when it is missing, so an interrupted migration can be
/// retried without "duplicate column name" errors.
Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String definition,
) async {
  if (await _hasColumn(db, table, column)) return;
  await db.execute('ALTER TABLE "$table" ADD COLUMN "$column" $definition');
}

/// Idempotent schema migrations.
///
/// The schema is ensured first, then every migration step checks for existing
/// columns/tables before changing them. Backfills only touch rows that still
/// need a value, so replaying a migration never overwrites user data.
Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
  await _createSchema(db);

  if (oldVersion < 2) {
    await _addColumnIfMissing(db, 'videos', 'keywords', 'TEXT');
    await _addColumnIfMissing(
      db,
      'videos',
      'keywords_fetched',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (oldVersion < 3) {
    await _addColumnIfMissing(db, 'videos', 'watched_at', 'INTEGER');
    await _addColumnIfMissing(db, 'videos', 'local_path', 'TEXT');
    await _addColumnIfMissing(
      db,
      'videos',
      'download_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(db, 'videos', 'downloaded_at', 'INTEGER');
    await _addColumnIfMissing(db, 'videos', 'download_error', 'TEXT');
  }
  if (oldVersion < 4) {
    await _addColumnIfMissing(
      db,
      'channels',
      'show_in_latest',
      'INTEGER NOT NULL DEFAULT 1',
    );
  }
  if (oldVersion < 5) {
    await _addColumnIfMissing(
      db,
      'channels',
      'default_playback_rate',
      'REAL',
    );
    await _addColumnIfMissing(db, 'videos', 'chapters', 'TEXT');
    await _addColumnIfMissing(
      db,
      'videos',
      'chapters_fetched',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT NOT NULL,
        position_seconds INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
      )
    ''');
  }
  if (oldVersion < 6) {
    await _addColumnIfMissing(db, 'videos', 'first_seen_at', 'INTEGER');
    await _addColumnIfMissing(
      db,
      'videos',
      'source',
      "TEXT NOT NULL DEFAULT 'rss'",
    );
    await db.execute(
      'UPDATE videos SET first_seen_at = COALESCE(fetched_at, published_at, 0) '
      'WHERE first_seen_at IS NULL',
    );
  }
  if (oldVersion < 7) {
    await _addColumnIfMissing(db, 'videos', 'queued_at', 'INTEGER');
    await db.execute(
      'UPDATE videos SET queued_at = COALESCE(fetched_at, published_at, 0) '
      'WHERE queued = 1 AND queued_at IS NULL',
    );
  }
  if (oldVersion < 8) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_videos (
        path TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        duration_seconds INTEGER
      )
    ''');
  }
}
