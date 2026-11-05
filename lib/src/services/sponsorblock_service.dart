import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class SponsorBlockService {
  SponsorBlockService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SponsorSegment>> fetch(
    String videoId,
    Set<String> categories,
  ) async {
    if (categories.isEmpty) return const [];
    final uri = Uri.https('sponsor.ajay.app', '/api/skipSegments', {
      'videoID': videoId,
      'categories': jsonEncode(categories.toList()..sort()),
    });
    final response = await _client.get(
      uri,
      headers: {'User-Agent': 'Expeditus/1.0'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    final segments = <SponsorSegment>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final actionType = item['actionType'];
      if (actionType != null && actionType != 'skip') continue;
      final segment = item['segment'];
      if (segment is! List || segment.length < 2) continue;
      final start = (segment[0] as num).toDouble();
      final end = (segment[1] as num).toDouble();
      if (end <= start) continue;
      segments.add(
        SponsorSegment(
          start: Duration(milliseconds: (start * 1000).round()),
          end: Duration(milliseconds: (end * 1000).round()),
          category: (item['category'] as String?) ?? 'sponsor',
        ),
      );
    }
    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  void close() => _client.close();
}
