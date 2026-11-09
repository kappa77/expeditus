import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models.dart';

class LinkedVideo {
  const LinkedVideo({required this.channel, required this.video});

  final ImportedChannel channel;
  final VideoItem video;
}

/// Resolves a YouTube video URL/ID and returns the video plus its channel.
class VideoLinkService {
  VideoLinkService({YoutubeExplode? youtube})
    : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  bool _closed = false;

  Future<LinkedVideo> resolve(String input) async {
    if (_closed) throw StateError('Video link service is closed');
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Enter a video link.');
    }

    final video = await _youtube.videos.get(trimmed);
    final published = video.publishDate ?? video.uploadDate ?? DateTime.now();
    final keywords = video.keywords.toList();

    return LinkedVideo(
      channel: ImportedChannel(id: video.channelId.value, title: video.author),
      video: VideoItem(
        id: video.id.value,
        channelId: video.channelId.value,
        channelTitle: video.author,
        title: video.title,
        description: video.description,
        publishedAt: published.millisecondsSinceEpoch,
        durationSeconds: video.duration?.inSeconds,
        keywords: keywords,
        keywordsFetched: true,
        queued: true,
        source: 'link',
      ),
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
