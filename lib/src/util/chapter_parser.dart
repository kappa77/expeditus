import '../models.dart';

class ChapterParser {
  static final _timestampLine = RegExp(
    r'^\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s*[-–—:]?\s*(.+?)\s*$',
  );

  static List<VideoChapter> parse(String description) {
    final chapters = <VideoChapter>[];
    final seen = <int>{};
    for (final rawLine in description.split('\n')) {
      final match = _timestampLine.firstMatch(rawLine.trim());
      if (match == null) continue;
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      if (minutes > 59 || seconds > 59) continue;
      final title = match.group(4)!.trim();
      if (title.isEmpty) continue;
      final start = hours * 3600 + minutes * 60 + seconds;
      if (!seen.add(start)) continue;
      chapters.add(VideoChapter(startSeconds: start, title: title));
      if (chapters.length >= 100) break;
    }
    chapters.sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    return chapters.length >= 2 ? chapters : const [];
  }
}
