import 'package:intl/intl.dart';

String relativeTime(DateTime? date) {
  if (date == null) return 'mai';
  final diff = DateTime.now().difference(date);
  if (diff.isNegative) return 'adesso';
  if (diff.inMinutes < 1) return 'ora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) return '${diff.inHours} h fa';
  if (diff.inDays == 1) return 'ieri';
  if (diff.inDays < 7) return '${diff.inDays} g fa';
  return DateFormat('d MMM', 'it_IT').format(date);
}

String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '$m:${two(s)}';
}

String shortDate(DateTime date) {
  final now = DateTime.now();
  if (now.year == date.year) {
    return DateFormat('d MMM', 'it_IT').format(date);
  }
  return DateFormat('d MMM yyyy', 'it_IT').format(date);
}
