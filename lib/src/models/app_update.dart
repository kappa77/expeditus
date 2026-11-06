import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../util/app_version.dart';

enum UpdateFailureKind {
  network,
  unauthorized,
  notFound,
  rateLimited,
  invalidFeed,
  server,
}

class UpdateException implements Exception {
  const UpdateException(
    this.message, {
    this.kind = UpdateFailureKind.network,
    this.statusCode,
  });

  final String message;
  final UpdateFailureKind kind;
  final int? statusCode;

  @override
  String toString() => message;
}

/// One downloadable file attached to a release.
@immutable
class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    this.size,
    this.sha256,
  });

  final String name;
  final String url;
  final int? size;
  final String? sha256;

  String get safeFileName {
    final urlName = Uri.tryParse(url)?.pathSegments.isNotEmpty == true
        ? Uri.parse(url).pathSegments.last
        : '';
    final candidate = name.trim().isNotEmpty ? name : urlName;
    var cleaned = candidate.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').trim();
    while (cleaned.startsWith('.')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.isEmpty) cleaned = 'expeditus-update.bin';
    if (cleaned.length > 180) {
      final dot = cleaned.lastIndexOf('.');
      final extension = dot > 0 ? cleaned.substring(dot) : '';
      final maxBase = 160 - extension.length;
      cleaned = '${cleaned.substring(0, maxBase > 1 ? maxBase : 1)}$extension';
    }
    return cleaned;
  }

  @override
  String toString() => 'UpdateAsset($name, $url)';
}

/// A release returned by the GitHub Releases API.
@immutable
class AppRelease {
  const AppRelease({
    required this.version,
    this.tagName = '',
    this.name = '',
    this.notes = '',
    this.pageUrl = '',
    this.publishedAt,
    this.assets = const [],
    this.prerelease = false,
    this.draft = false,
  });

  final AppVersion version;
  final String tagName;
  final String name;
  final String notes;
  final String pageUrl;
  final DateTime? publishedAt;
  final List<UpdateAsset> assets;
  final bool prerelease;
  final bool draft;

  bool isNewerThan(AppVersion current) => version.isNewerThan(current);

  String get displayName =>
      name.trim().isEmpty ? 'v${version.canonical}' : name;

  /// Selects the Windows installer, ignoring checksum and signature files.
  UpdateAsset? assetForWindows() {
    UpdateAsset? best;
    var bestScore = -1;
    for (final asset in assets) {
      final score = _windowsScore(asset.name);
      if (score > bestScore) {
        best = asset;
        bestScore = score;
      }
    }
    return best;
  }

  static int _windowsScore(String rawName) {
    final name = rawName.toLowerCase();
    if (name.isEmpty) return -1;
    if (RegExp(r'(sha256|sha512|checksum|\.sig$|\.asc$)').hasMatch(name)) {
      return -1;
    }

    final isExe = name.endsWith('.exe');
    final isZip = name.endsWith('.zip');
    var score = isExe
        ? 100
        : isZip
        ? 40
        : -1;
    if (score < 0) return -1;

    if (name.contains('expeditussetup')) score += 30;
    if (name.contains('expeditus')) score += 10;
    if (name.contains('setup') || name.contains('installer')) score += 10;
    if (name.contains('windows')) score += 8;
    if (name.contains('x64') ||
        name.contains('amd64') ||
        name.contains('x86_64')) {
      score += 5;
    }
    return score;
  }

  /// Parses GitHub's `releases/latest` payload.
  static AppRelease? fromJson(Map<String, dynamic> json) {
    String readString(Object? value) => value is String ? value.trim() : '';

    final draft = json['draft'] == true;
    if (draft) return null;

    final tagName = readString(json['tag_name']);
    final version = AppVersion.tryParse(
      tagName.isNotEmpty
          ? tagName
          : readString(json['version']).isNotEmpty
          ? readString(json['version'])
          : readString(json['name']),
    );
    if (version == null) return null;

    final rawAssets = json['assets'];
    final assets = <UpdateAsset>[];
    if (rawAssets is List) {
      for (final rawAsset in rawAssets) {
        if (rawAsset is! Map) continue;
        final asset = rawAsset.cast<String, dynamic>();
        final name = readString(asset['name']);
        final url = readString(asset['browser_download_url']).isNotEmpty
            ? readString(asset['browser_download_url'])
            : readString(asset['url']);
        if (name.isEmpty || url.isEmpty) continue;
        final rawSize = asset['size'];
        final size = rawSize is int
            ? rawSize
            : int.tryParse(rawSize?.toString() ?? '');
        final rawDigest = readString(asset['digest']);
        final sha = rawDigest.startsWith('sha256:')
            ? rawDigest.substring('sha256:'.length)
            : readString(asset['sha256']);
        assets.add(
          UpdateAsset(
            name: name,
            url: url,
            size: size != null && size > 0 ? size : null,
            sha256: sha.isEmpty ? null : sha,
          ),
        );
      }
    }

    DateTime? publishedAt;
    final rawDate = readString(json['published_at']).isNotEmpty
        ? readString(json['published_at'])
        : readString(json['publishedAt']);
    if (rawDate.isNotEmpty) publishedAt = DateTime.tryParse(rawDate)?.toLocal();

    final pageUrl = readString(json['html_url']).isNotEmpty
        ? readString(json['html_url'])
        : readString(json['releaseUrl']);

    return AppRelease(
      version: version,
      tagName: tagName,
      name: readString(json['name']),
      notes: readString(json['body']).isNotEmpty
          ? readString(json['body'])
          : readString(json['notes']),
      pageUrl: pageUrl,
      publishedAt: publishedAt,
      assets: List<UpdateAsset>.unmodifiable(assets),
      prerelease: json['prerelease'] == true,
    );
  }

  static AppRelease? fromJsonString(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Outcome of one release check.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.checkedAt,
    this.release,
    this.isNewer = false,
    this.asset,
    this.fromCache = false,
    this.etag,
    this.rawBody,
    this.error,
  });

  final AppRelease? release;
  final bool isNewer;
  final UpdateAsset? asset;
  final DateTime checkedAt;
  final bool fromCache;
  final String? etag;
  final String? rawBody;
  final String? error;

  bool get hasError => error != null;
}
