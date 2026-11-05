import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/services/rss_service.dart';

void main() {
  const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <link rel="self" href="https://www.youtube.com/feeds/videos.xml?channel_id=UC1234567890123456789012"/>
  <id>yt:channel:UC1234567890123456789012</id>
  <yt:channelId>UC1234567890123456789012</yt:channelId>
  <title>Canale di prova</title>
  <author>
    <name>Canale di prova</name>
    <uri>https://www.youtube.com/channel/UC1234567890123456789012</uri>
  </author>
  <published>2026-11-03T12:00:00+00:00</published>
  <entry>
    <id>yt:video:video1</id>
    <yt:videoId>video1</yt:videoId>
    <yt:channelId>UC1234567890123456789012</yt:channelId>
    <title>Primo video</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=video1"/>
    <published>2026-11-03T10:00:00+00:00</published>
    <media:description>Una descrizione &amp; con HTML</media:description>
  </entry>
  <entry>
    <id>yt:video:video2</id>
    <yt:videoId>video2</yt:videoId>
    <yt:channelId>UC1234567890123456789012</yt:channelId>
    <title>Secondo video</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=video2"/>
    <published>2026-11-02T09:30:00+00:00</published>
  </entry>
</feed>''';

  test('legge titolo, canale, descrizione e data', () {
    final parsed = RssService.parse(feed);

    expect(parsed.channelId, 'UC1234567890123456789012');
    expect(parsed.channelTitle, 'Canale di prova');
    expect(parsed.entries, hasLength(2));

    final first = parsed.entries.first;
    expect(first.videoId, 'video1');
    expect(first.title, 'Primo video');
    expect(first.description, 'Una descrizione & con HTML');
    expect(
      first.publishedAt.toUtc(),
      DateTime.utc(2026, 11, 3, 10),
    );

    final second = parsed.entries.last;
    expect(second.videoId, 'video2');
    expect(second.description, isEmpty);
  });

  test('ignora le entry senza id o titolo', () {
    const broken = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015">
  <title>Canale</title>
  <entry>
    <yt:videoId>senza-titolo</yt:videoId>
  </entry>
  <entry>
    <title>Senza id</title>
    <published>2026-11-03T10:00:00+00:00</published>
  </entry>
</feed>''';

    final parsed = RssService.parse(broken);
    expect(parsed.entries, isEmpty);
  });
}
