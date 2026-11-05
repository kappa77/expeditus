import 'dart:convert';

class Channel {
  const Channel({
    required this.id,
    required this.title,
    required this.addedAt,
    this.handle,
    this.lastChecked,
    this.muted = false,
    this.error,
  });

  final String id;
  final String title;
  final String? handle;
  final int addedAt;
  final int? lastChecked;
  final bool muted;
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
    this.durationSeconds,
    this.status = 'new',
    this.queued = false,
    this.progressSeconds = 0,
    this.keywords = const [],
    this.keywordsFetched = false,
    this.watchedAt,
    this.localPath,
    this.downloadStatus = 'none',
    this.downloadedAt,
    this.downloadError,
  });

  final String id;
  final String channelId;
  final String channelTitle;
  final String title;
  final String description;

  /// Milliseconds since epoch.
  final int publishedAt;

  final int? durationSeconds;

  /// One of: new, seen, watched.
  final String status;

  final bool queued;
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

  bool get isDownloaded => localPath != null && downloadStatus == 'ready';
  bool get isDownloading => downloadStatus == 'downloading';

  bool get isNew => status == 'new';
  bool get isWatched => status == 'watched';
  bool get isSeen => status == 'seen' || status == 'watched';

  DateTime get published => DateTime.fromMillisecondsSinceEpoch(publishedAt);

  String get url => 'https://www.youtube.com/watch?v=$id';

  VideoItem copyWith({
    String? title,
    String? description,
    int? publishedAt,
    int? durationSeconds,
    String? status,
    bool? queued,
    int? progressSeconds,
    List<String>? keywords,
    bool? keywordsFetched,
    int? watchedAt,
    String? localPath,
    String? downloadStatus,
    int? downloadedAt,
    String? downloadError,
  }) {
    return VideoItem(
      id: id,
      channelId: channelId,
      channelTitle: channelTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      publishedAt: publishedAt ?? this.publishedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      queued: queued ?? this.queued,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      keywords: keywords ?? this.keywords,
      keywordsFetched: keywordsFetched ?? this.keywordsFetched,
      watchedAt: watchedAt ?? this.watchedAt,
      localPath: localPath ?? this.localPath,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      downloadError: downloadError ?? this.downloadError,
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
      durationSeconds: map['duration_seconds'] as int?,
      status: (map['status'] as String?) ?? 'new',
      queued: (map['queued'] as int?) == 1,
      progressSeconds: (map['progress_seconds'] as int?) ?? 0,
      keywords: _parseKeywords(map['keywords']),
      keywordsFetched: (map['keywords_fetched'] as int?) == 1,
      watchedAt: map['watched_at'] as int?,
      localPath: map['local_path'] as String?,
      downloadStatus: (map['download_status'] as String?) ?? 'none',
      downloadedAt: map['downloaded_at'] as int?,
      downloadError: map['download_error'] as String?,
    );
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
