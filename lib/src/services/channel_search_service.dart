import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ChannelSearchResult {
  const ChannelSearchResult({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

/// Searches YouTube channels by keyword without an API key.
///
/// It uses YouTube's public search page through `youtube_explode_dart`.
/// No login, no quota, but also no guarantee: YouTube can change the page.
class ChannelSearchService {
  ChannelSearchService({YoutubeExplode? youtube})
      : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  bool _closed = false;

  Future<List<ChannelSearchResult>> search(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _closed) return const [];

    final results = await _youtube.search.searchContent(
      trimmed,
      filter: TypeFilters.channel,
    );

    final channels = <ChannelSearchResult>[];
    for (final item in results) {
      if (item is! SearchChannel) continue;
      channels.add(
        ChannelSearchResult(
          id: item.id.value,
          name: item.name,
          description: item.description
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        ),
      );
      if (channels.length >= limit) break;
    }
    return channels;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
