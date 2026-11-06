import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/util/rss_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

VideoItem _video({
  required String id,
  required String channelId,
  required String channelTitle,
  required int firstSeenAt,
  int? publishedAt,
}) {
  return VideoItem(
    id: id,
    channelId: channelId,
    channelTitle: channelTitle,
    title: 'Video $id',
    description: '',
    publishedAt: publishedAt ?? firstSeenAt,
    firstSeenAt: firstSeenAt,
  );
}

void main() {
  test('ordina i gruppi per attività recente e conserva l’ordine interno', () {
    final videos = [
      _video(
        id: 'a1',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 300,
      ),
      _video(
        id: 'b1',
        channelId: 'b',
        channelTitle: 'Canale B',
        firstSeenAt: 400,
      ),
      _video(
        id: 'a2',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 200,
      ),
      _video(
        id: 'c1',
        channelId: 'c',
        channelTitle: 'Canale C',
        firstSeenAt: 100,
      ),
    ];

    final grouped = groupRssHistoryByChannel(videos);
    expect(grouped.map((video) => video.id), ['b1', 'a1', 'a2', 'c1']);
  });

  test('il riepilogo conta i video e usa il primo timestamp utile', () {
    final videos = [
      _video(
        id: 'a1',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 300,
      ),
      _video(
        id: 'a2',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 200,
      ),
      _video(
        id: 'b1',
        channelId: 'b',
        channelTitle: 'Canale B',
        firstSeenAt: 400,
      ),
    ];

    final summaries = summarizeRssChannels(videos);
    expect(summaries.map((summary) => summary.channelId), ['b', 'a']);
    expect(summaries.first.count, 1);
    expect(summaries.last.count, 2);
    expect(summaries.last.latest, 300);
  });

  test('un solo canale resta un unico gruppo', () {
    final grouped = groupRssHistoryByChannel([
      _video(
        id: 'a1',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 200,
      ),
      _video(
        id: 'a2',
        channelId: 'a',
        channelTitle: 'Canale A',
        firstSeenAt: 100,
      ),
    ]);

    expect(grouped.map((video) => video.id), ['a1', 'a2']);
  });
}
