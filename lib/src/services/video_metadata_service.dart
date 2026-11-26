import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Duration and tags read from a video's public watch page.
class VideoMetadata {
  const VideoMetadata({required this.keywords, this.durationSeconds});

  final List<String> keywords;

  /// `null` for live streams or videos whose length is not exposed.
  final int? durationSeconds;
}

abstract class VideoMetadataProvider {
  Future<VideoMetadata> fetch(String videoId);

  void close();
}

/// Reads YouTube's public watch page for the video duration and
/// `videoDetails.keywords`.
///
/// Neither value is present in the RSS feed, so this is one request per video,
/// done lazily and cached in SQLite. Many videos have no keywords at all.
class VideoMetadataService implements VideoMetadataProvider {
  VideoMetadataService({YoutubeExplode? youtube})
    : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  bool _closed = false;

  @override
  Future<VideoMetadata> fetch(String videoId) async {
    if (_closed) return const VideoMetadata(keywords: []);
    final video = await _youtube.videos.get(videoId);
    final duration = video.duration;
    final seconds = duration == null || duration.inSeconds <= 0
        ? null
        : duration.inSeconds;

    final seen = <String>{};
    final tags = <String>[];
    for (final keyword in video.keywords) {
      final value = keyword.trim();
      if (value.isEmpty) continue;
      if (!seen.add(value.toLowerCase())) continue;
      tags.add(value);
      if (tags.length >= 20) break;
    }
    return VideoMetadata(durationSeconds: seconds, keywords: tags);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
