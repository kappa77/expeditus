import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

String relativeTime(BuildContext context, DateTime? date) {
  final l10n = context.l10n;
  if (date == null) return l10n.relativeNever;
  final diff = DateTime.now().difference(date);
  if (diff.isNegative) return l10n.relativeNow;
  if (diff.inMinutes < 1) return l10n.relativeNow;
  if (diff.inMinutes < 60) return l10n.relativeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.relativeHours(diff.inHours);
  if (diff.inDays == 1) return l10n.relativeYesterday;
  if (diff.inDays < 7) return l10n.relativeDays(diff.inDays);
  return shortDate(context, date);
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

String shortDate(BuildContext context, DateTime date) {
  final locale = intlLocaleName(Localizations.localeOf(context));
  final now = DateTime.now();
  if (now.year == date.year) {
    return DateFormat('d MMM', locale).format(date);
  }
  return DateFormat('d MMM yyyy', locale).format(date);
}

String monthYear(BuildContext context, DateTime date) {
  final raw = DateFormat(
    'MMMM yyyy',
    intlLocaleName(Localizations.localeOf(context)),
  ).format(date);
  return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}

/// Maps Flutter locales to the regional variants used by `intl`.
String intlLocaleName(Locale locale) => switch (locale.languageCode) {
  'it' => 'it_IT',
  'de' => 'de_DE',
  'es' => 'es_ES',
  _ => 'en_US',
};
