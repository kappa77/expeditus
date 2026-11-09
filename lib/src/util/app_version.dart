import 'package:flutter/foundation.dart';

/// Semantic version used to compare the running app with a GitHub release.
///
/// Accepted forms: `1.4`, `1.4.0`, `v1.4.0`, `1.4.0+5`,
/// `1.4.0-beta.2`. Build metadata (`+5`) is ignored for comparison.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._({
    required this.raw,
    required this.numbers,
    required this.preRelease,
  });

  final String raw;
  final List<int> numbers;
  final List<String> preRelease;

  static final RegExp _number = RegExp(r'^\d+$');

  static AppVersion? tryParse(String? value) {
    var text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }
    text = text.split('+').first;

    final dash = text.indexOf('-');
    final core = dash >= 0 ? text.substring(0, dash) : text;
    final suffix = dash >= 0 ? text.substring(dash + 1) : '';
    if (core.isEmpty) return null;

    final numbers = <int>[];
    for (final part in core.split('.')) {
      if (!_number.hasMatch(part)) return null;
      final parsed = int.tryParse(part);
      if (parsed == null) return null;
      numbers.add(parsed);
    }

    final preRelease = <String>[];
    if (suffix.isNotEmpty) {
      for (final part in suffix.split('.')) {
        if (part.isEmpty) return null;
        preRelease.add(part);
      }
    }

    return AppVersion._(
      raw: value!.trim(),
      numbers: List<int>.unmodifiable(numbers),
      preRelease: List<String>.unmodifiable(preRelease),
    );
  }

  static AppVersion parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid version: $value');
    }
    return parsed;
  }

  /// Normalizes `1.4` and `1.4.0` to the same comparable version.
  String get canonical {
    final core = numbers.join('.');
    return preRelease.isEmpty ? core : '$core-${preRelease.join('.')}';
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  bool isOlderThan(AppVersion other) => compareTo(other) < 0;

  @override
  int compareTo(AppVersion other) {
    final length = numbers.length > other.numbers.length
        ? numbers.length
        : other.numbers.length;
    for (var index = 0; index < length; index++) {
      final left = index < numbers.length ? numbers[index] : 0;
      final right = index < other.numbers.length ? other.numbers[index] : 0;
      if (left != right) return left.compareTo(right);
    }

    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;

    final count = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < count; index++) {
      final left = preRelease[index];
      final right = other.preRelease[index];
      final leftNumber = _number.hasMatch(left) ? int.tryParse(left) : null;
      final rightNumber = _number.hasMatch(right) ? int.tryParse(right) : null;
      if (leftNumber != null && rightNumber != null) {
        final comparison = leftNumber.compareTo(rightNumber);
        if (comparison != 0) return comparison;
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else {
        final comparison = left.compareTo(right);
        if (comparison != 0) return comparison;
      }
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode {
    final normalized = [...numbers];
    while (normalized.length > 1 && normalized.last == 0) {
      normalized.removeLast();
    }
    return Object.hash(Object.hashAll(normalized), Object.hashAll(preRelease));
  }

  @override
  String toString() => canonical;
}
