import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models.dart';
import '../util/chapter_parser.dart';

abstract class VideoChaptersProvider {
  Future<List<VideoChapter>> fetch(String videoId);

  void close();
}

/// Fetches the full video description and extracts timestamped chapters.
class VideoChaptersService implements VideoChaptersProvider {
  VideoChaptersService({YoutubeExplode? youtube})
      : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  bool _closed = false;

  @override
  Future<List<VideoChapter>> fetch(String videoId) async {
    if (_closed) return const [];
    final video = await _youtube.videos.get(videoId);
    return ChapterParser.parse(video.description);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
