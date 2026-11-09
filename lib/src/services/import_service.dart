import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

class TakeoutParser {
  static final _channelId = RegExp(r'^UC[\w-]{22}$');

  static List<ImportedChannel> parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final rows = csv.decode(normalized).where((row) => row.isNotEmpty).toList();
    if (rows.isEmpty) return const [];

    var idIndex = -1;
    var titleIndex = -1;
    var start = 0;

    for (var i = 0; i < rows.length && i < 3; i++) {
      final cells = rows[i].map((e) => e.toString().toLowerCase()).toList();
      final id = cells.indexWhere((cell) => cell.contains('channel id'));
      if (id >= 0) {
        idIndex = id;
        titleIndex = cells.indexWhere((cell) => cell.contains('channel title'));
        start = i + 1;
        break;
      }
    }

    final result = <String, ImportedChannel>{};
    for (var i = start; i < rows.length; i++) {
      final cells = rows[i].map((e) => e.toString().trim()).toList();
      String? id;
      if (idIndex >= 0 && idIndex < cells.length) {
        final candidate = cells[idIndex];
        if (_channelId.hasMatch(candidate)) id = candidate;
      }
      if (id == null) {
        for (final cell in cells) {
          if (_channelId.hasMatch(cell)) {
            id = cell;
            break;
          }
        }
      }
      if (id == null) continue;

      var title = '';
      if (titleIndex >= 0 && titleIndex < cells.length) {
        title = cells[titleIndex];
      }
      if (title.isEmpty || title.toLowerCase() == 'channel title') {
        for (final cell in cells) {
          if (cell == id) continue;
          if (cell.startsWith('http')) continue;
          if (cell.isEmpty) continue;
          if (cell.toLowerCase() == 'channel title') continue;
          title = cell;
        }
      }
      result[id] = ImportedChannel(id: id, title: title);
    }
    return result.values.toList();
  }
}

class YouTubeResolver {
  YouTubeResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _channelId = RegExp(r'UC[\w-]{22}');
  static final _externalId = RegExp(r'"externalId":"(UC[\w-]{22})"');
  static final _canonicalChannel = RegExp(
    r'youtube\.com/channel/(UC[\w-]{22})',
  );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0 Safari/537.36';

  Future<ImportedChannel> resolve(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) {
      throw const FormatException('Empty line');
    }

    final direct = _channelId.firstMatch(input)?.group(0);
    if (direct != null) {
      return ImportedChannel(id: direct);
    }

    final uri = _toUri(input);
    if (uri == null) {
      throw FormatException('Unrecognized channel: $input');
    }

    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'en-US,en;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw FormatException('HTTP ${response.statusCode} for $input');
    }

    final body = response.body;
    final id =
        _externalId.firstMatch(body)?.group(1) ??
        _canonicalChannel.firstMatch(body)?.group(1);
    if (id == null) {
      throw FormatException('Channel ID not found for $input');
    }

    return ImportedChannel(id: id, title: _channelTitle(body));
  }

  static String _channelTitle(String body) {
    final match = RegExp(
      r'"channelMetadataRenderer":\{"title":"((?:[^"\\]|\\.)*)"',
    ).firstMatch(body);
    if (match == null) return '';
    try {
      return jsonDecode('"${match.group(1)}"') as String;
    } catch (_) {
      return match.group(1) ?? '';
    }
  }

  static Uri? _toUri(String input) {
    if (input.contains('watch?v=') || input.contains('youtu.be/')) {
      throw FormatException('This is a video, not a channel: $input');
    }
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return Uri.tryParse(input);
    }
    if (input.startsWith('@')) {
      return Uri.tryParse('https://www.youtube.com/$input');
    }
    if (input.contains('youtube.com/')) {
      return Uri.tryParse('https://$input');
    }
    if (RegExp(r'^[\w.\-]+$').hasMatch(input)) {
      return Uri.tryParse('https://www.youtube.com/@$input');
    }
    return null;
  }

  void close() => _client.close();
}
