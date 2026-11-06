import '../models.dart';

/// Timestamp used to order the RSS history: when the video first entered the
/// local feed, with the publication time as a fallback.
int rssHistoryTime(VideoItem video) => video.firstSeenAt ?? video.publishedAt;

class RssChannelSummary {
  const RssChannelSummary({
    required this.channelId,
    required this.title,
    required this.count,
    required this.latest,
  });

  final String channelId;
  final String title;
  final int count;
  final int latest;
}

/// One summary per channel, ordered by the most recent video in that channel.
List<RssChannelSummary> summarizeRssChannels(Iterable<VideoItem> videos) {
  final byChannel = <String, RssChannelSummary>{};
  for (final video in videos) {
    final time = rssHistoryTime(video);
    final existing = byChannel[video.channelId];
    if (existing == null) {
      byChannel[video.channelId] = RssChannelSummary(
        channelId: video.channelId,
        title: video.channelTitle,
        count: 1,
        latest: time,
      );
      continue;
    }
    byChannel[video.channelId] = RssChannelSummary(
      channelId: existing.channelId,
      title: existing.title.trim().isEmpty
          ? video.channelTitle
          : existing.title,
      count: existing.count + 1,
      latest: time > existing.latest ? time : existing.latest,
    );
  }

  final summaries = byChannel.values.toList();
  summaries.sort((a, b) {
    final byTime = b.latest.compareTo(a.latest);
    if (byTime != 0) return byTime;
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return a.channelId.compareTo(b.channelId);
  });
  return summaries;
}

/// Groups the history by channel while preserving the input order inside each
/// group. Groups follow the order of [summarizeRssChannels].
List<VideoItem> groupRssHistoryByChannel(Iterable<VideoItem> videos) {
  final items = videos.toList();
  final groups = <String, List<VideoItem>>{};
  for (final video in items) {
    groups.putIfAbsent(video.channelId, () => []).add(video);
  }

  return [
    for (final summary in summarizeRssChannels(items))
      ...(groups[summary.channelId] ?? const <VideoItem>[]),
  ];
}
