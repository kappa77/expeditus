import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class RssEntry {
  const RssEntry({
    required this.videoId,
    required this.title,
    required this.description,
    required this.publishedAt,
  });

  final String videoId;
  final String title;
  final String description;
  final DateTime publishedAt;
}

class RssFeed {
  const RssFeed({
    required this.channelId,
    required this.channelTitle,
    required this.entries,
  });

  final String channelId;
  final String channelTitle;
  final List<RssEntry> entries;
}

class RssException implements Exception {
  const RssException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Expeditus/1.0';

  Future<RssFeed> fetch(String channelId) async {
    final uri = Uri.https(
      'www.youtube.com',
      '/feeds/videos.xml',
      {'channel_id': channelId},
    );
    final response = await _client
        .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/xml'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw RssException('HTTP ${response.statusCode}');
    }
    return parse(response.body, expectedChannelId: channelId);
  }

  static RssFeed parse(String xml, {String? expectedChannelId}) {
    final document = XmlDocument.parse(xml);
    final feed = document.rootElement;
    final channelTitle = _childText(feed, 'title') ??
        _authorName(feed) ??
        '';
    final channelId =
        _childText(feed, 'channelId') ?? expectedChannelId ?? '';

    final entries = <RssEntry>[];
    for (final element in feed.children.whereType<XmlElement>()) {
      if (element.name.local != 'entry') continue;
      final link = _linkHref(element);
      final videoId = _childText(element, 'videoId') ??
          _videoIdFromLink(link);
      final title = _childText(element, 'title');
      if (videoId == null || videoId.isEmpty || title == null || title.isEmpty) {
        continue;
      }
      final description = _childText(element, 'description') ??
          _childText(element, 'summary') ??
          '';
      final publishedRaw = _childText(element, 'published');
      final publishedAt =
          DateTime.tryParse(publishedRaw ?? '') ?? DateTime.now();
      entries.add(
        RssEntry(
          videoId: videoId,
          title: title,
          description: _cleanDescription(description),
          publishedAt: publishedAt,
        ),
      );
    }

    return RssFeed(
      channelId: channelId,
      channelTitle: channelTitle,
      entries: entries,
    );
  }

  static String? _childText(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) {
        final text = child.innerText.trim();
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  static String? _authorName(XmlElement element) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == 'author') {
        return _childText(child, 'name');
      }
    }
    return null;
  }

  static String? _linkHref(XmlElement element) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == 'link') {
        final href = child.getAttribute('href');
        if (href != null && href.isNotEmpty) return href;
      }
    }
    return null;
  }

  static String? _videoIdFromLink(String? link) {
    if (link == null) return null;
    return Uri.tryParse(link)?.queryParameters['v'];
  }

  static String _cleanDescription(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void close() => _client.close();
}
