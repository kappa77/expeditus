import 'package:youtube_explode_dart/youtube_explode_dart.dart';

abstract class VideoTagsProvider {
  Future<List<String>> fetch(String videoId);

  void close();
}

/// Reads YouTube's public `videoDetails.keywords` for a video.
///
/// This is one watch-page request per video, so it is done lazily and cached
/// in SQLite. Many videos have no keywords at all.
class VideoTagsService implements VideoTagsProvider {
  VideoTagsService({YoutubeExplode? youtube})
      : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  bool _closed = false;

  @override
  Future<List<String>> fetch(String videoId) async {
    if (_closed) return const [];
    final video = await _youtube.videos.get(videoId);
    final seen = <String>{};
    final tags = <String>[];
    for (final keyword in video.keywords) {
      final value = keyword.trim();
      if (value.isEmpty) continue;
      if (!seen.add(value.toLowerCase())) continue;
      tags.add(value);
      if (tags.length >= 20) break;
    }
    return tags;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
