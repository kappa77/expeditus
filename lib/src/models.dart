import 'dart:convert';

class Channel {
  const Channel({
    required this.id,
    required this.title,
    required this.addedAt,
    this.handle,
    this.lastChecked,
    this.muted = false,
    this.showInLatest = true,
    this.defaultPlaybackRate,
    this.error,
  });

  final String id;
  final String title;
  final String? handle;
  final int addedAt;
  final int? lastChecked;
  final bool muted;
  final bool showInLatest;
  final double? defaultPlaybackRate;
  final String? error;

  String get displayTitle => title.trim().isEmpty ? id : title;

  factory Channel.fromMap(Map<String, Object?> map) {
    return Channel(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      handle: map['handle'] as String?,
      addedAt: (map['added_at'] as int?) ?? 0,
      lastChecked: map['last_checked'] as int?,
      muted: (map['muted'] as int?) == 1,
      showInLatest: (map['show_in_latest'] as int?) != 0,
      defaultPlaybackRate: (map['default_playback_rate'] as num?)?.toDouble(),
      error: map['error'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'handle': handle,
      'added_at': addedAt,
      'last_checked': lastChecked,
      'muted': muted ? 1 : 0,
      'show_in_latest': showInLatest ? 1 : 0,
      'default_playback_rate': defaultPlaybackRate,
      'error': error,
    };
  }
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.channelId,
    required this.channelTitle,
    required this.title,
    required this.description,
    required this.publishedAt,
    this.firstSeenAt,
    this.durationSeconds,
    this.status = 'new',
    this.queued = false,
    this.queuedAt,
    this.progressSeconds = 0,
    this.keywords = const [],
    this.keywordsFetched = false,
    this.watchedAt,
    this.localPath,
    this.downloadStatus = 'none',
    this.downloadedAt,
    this.downloadError,
    this.chapters = const [],
    this.chaptersFetched = false,
    this.source = 'rss',
  });

  final String id;
  final String channelId;
  final String channelTitle;
  final String title;
  final String description;

  /// Milliseconds since epoch.
  final int publishedAt;

  /// When this video first entered the local feed history.
  final int? firstSeenAt;

  final int? durationSeconds;

  /// One of: new, seen, watched.
  final String status;

  final bool queued;

  /// When the video was put in the explicit watch later list.
  final int? queuedAt;

  final int progressSeconds;

  /// YouTube search keywords for this video, when available.
  final List<String> keywords;

  /// True once a tag fetch has been attempted and stored, even if empty.
  final bool keywordsFetched;

  /// Milliseconds since epoch, set the first time the video is opened/watched.
  final int? watchedAt;

  final String? localPath;
  final String downloadStatus;
  final int? downloadedAt;
  final String? downloadError;

  /// Chapters parsed from the video description.
  final List<VideoChapter> chapters;

  /// True once a chapter lookup has been attempted and stored.
  final bool chaptersFetched;

  /// `rss` or `link`. Link-only videos are not part of the RSS history.
  final String source;

  bool get isDownloaded => localPath != null && downloadStatus == 'ready';
  bool get isDownloading => downloadStatus == 'downloading';

  bool get isNew => status == 'new';
  bool get isWatched => status == 'watched';

  /// Explicit watch later membership. The queue column is kept as the
  /// persisted flag for backward compatibility.
  bool get watchLater => queued;
  int? get watchLaterAt => queuedAt;
  bool get isSeen => status == 'seen' || status == 'watched';

  DateTime get published => DateTime.fromMillisecondsSinceEpoch(publishedAt);

  String get url => 'https://www.youtube.com/watch?v=$id';

  VideoItem copyWith({
    String? title,
    String? description,
    int? publishedAt,
    int? firstSeenAt,
    int? durationSeconds,
    String? status,
    bool? queued,
    int? queuedAt,
    int? progressSeconds,
    List<String>? keywords,
    bool? keywordsFetched,
    int? watchedAt,
    String? localPath,
    String? downloadStatus,
    int? downloadedAt,
    String? downloadError,
    List<VideoChapter>? chapters,
    bool? chaptersFetched,
    String? source,
  }) {
    return VideoItem(
      id: id,
      channelId: channelId,
      channelTitle: channelTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      publishedAt: publishedAt ?? this.publishedAt,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      queued: queued ?? this.queued,
      queuedAt: queuedAt ?? this.queuedAt,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      keywords: keywords ?? this.keywords,
      keywordsFetched: keywordsFetched ?? this.keywordsFetched,
      watchedAt: watchedAt ?? this.watchedAt,
      localPath: localPath ?? this.localPath,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      downloadError: downloadError ?? this.downloadError,
      chapters: chapters ?? this.chapters,
      chaptersFetched: chaptersFetched ?? this.chaptersFetched,
      source: source ?? this.source,
    );
  }

  factory VideoItem.fromMap(Map<String, Object?> map) {
    return VideoItem(
      id: map['id'] as String,
      channelId: map['channel_id'] as String,
      channelTitle: (map['channel_title'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      publishedAt: (map['published_at'] as int?) ?? 0,
      firstSeenAt: (map['first_seen_at'] as int?) ??
          (map['published_at'] as int?) ??
          0,
      durationSeconds: map['duration_seconds'] as int?,
      status: (map['status'] as String?) ?? 'new',
      queued: (map['queued'] as int?) == 1,
      queuedAt: map['queued_at'] as int?,
      progressSeconds: (map['progress_seconds'] as int?) ?? 0,
      keywords: _parseKeywords(map['keywords']),
      keywordsFetched: (map['keywords_fetched'] as int?) == 1,
      watchedAt: map['watched_at'] as int?,
      localPath: map['local_path'] as String?,
      downloadStatus: (map['download_status'] as String?) ?? 'none',
      downloadedAt: map['downloaded_at'] as int?,
      downloadError: map['download_error'] as String?,
      chapters: _parseChapters(map['chapters']),
      chaptersFetched: (map['chapters_fetched'] as int?) == 1,
      source: (map['source'] as String?) ?? 'rss',
    );
  }

  static List<VideoChapter> _parseChapters(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => VideoChapter.fromJson(entry))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String> _parseKeywords(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class ImportedChannel {
  const ImportedChannel({required this.id, this.title = ''});

  final String id;
  final String title;
}

class ImportResult {
  const ImportResult({
    required this.added,
    required this.skipped,
    this.errors = const [],
  });

  final int added;
  final int skipped;
  final List<String> errors;
}

class SponsorSegment {
  const SponsorSegment({
    required this.start,
    required this.end,
    required this.category,
  });

  final Duration start;
  final Duration end;
  final String category;
}


class VideoChapter {
  const VideoChapter({required this.startSeconds, required this.title});

  final int startSeconds;
  final String title;

  factory VideoChapter.fromJson(Map<dynamic, dynamic> json) {
    return VideoChapter(
      startSeconds: (json['start'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'start': startSeconds,
        'title': title,
      };
}

class VideoBookmark {
  const VideoBookmark({
    required this.id,
    required this.videoId,
    required this.positionSeconds,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String videoId;
  final int positionSeconds;
  final String note;
  final int createdAt;

  factory VideoBookmark.fromMap(Map<String, Object?> map) {
    return VideoBookmark(
      id: (map['id'] as int?) ?? 0,
      videoId: (map['video_id'] as String?) ?? '',
      positionSeconds: (map['position_seconds'] as int?) ?? 0,
      note: (map['note'] as String?) ?? '',
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }
}
