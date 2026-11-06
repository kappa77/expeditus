import 'dart:convert';

import 'package:expeditus/src/models/app_update.dart';
import 'package:expeditus/src/util/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _releaseJson({
  String tag = 'v1.2.0',
  bool draft = false,
  bool prerelease = false,
}) {
  return {
    'tag_name': tag,
    'name': 'Expeditus 1.2.0',
    'body': 'Novità della release',
    'html_url': 'https://github.com/kappa77/expeditus/releases/tag/$tag',
    'published_at': '2026-11-06T10:00:00Z',
    'draft': draft,
    'prerelease': prerelease,
    'assets': [
      {
        'name': 'ExpeditusSetup-1.2.0.exe',
        'browser_download_url':
            'https://github.com/kappa77/expeditus/releases/download/$tag/ExpeditusSetup-1.2.0.exe',
        'size': 42000000,
        'digest': 'sha256:abc123',
      },
      {
        'name': 'SHA256SUMS.txt',
        'browser_download_url':
            'https://github.com/kappa77/expeditus/releases/download/$tag/SHA256SUMS.txt',
        'size': 120,
      },
    ],
  };
}

void main() {
  test('legge una release GitHub e seleziona l’installer Windows', () {
    final release = AppRelease.fromJson(_releaseJson().cast<String, dynamic>());

    expect(release, isNotNull);
    expect(release!.version, AppVersion.parse('1.2.0'));
    expect(release.notes, 'Novità della release');
    expect(release.pageUrl, contains('/releases/tag/v1.2.0'));
    expect(release.publishedAt, isNotNull);
    expect(release.prerelease, isFalse);

    final asset = release.assetForWindows();
    expect(asset, isNotNull);
    expect(asset!.name, 'ExpeditusSetup-1.2.0.exe');
    expect(asset.size, 42000000);
    expect(asset.sha256, 'abc123');
  });

  test('ignora le release draft e accetta il build metadata', () {
    expect(
      AppRelease.fromJson(_releaseJson(draft: true).cast<String, dynamic>()),
      isNull,
    );

    final release = AppRelease.fromJson(
      _releaseJson(tag: '1.2.0+10').cast<String, dynamic>(),
    );
    expect(release!.version.canonical, '1.2.0');
    expect(release.isNewerThan(AppVersion.parse('1.1.9')), isTrue);
  });

  test('non sceglie file di checksum come installer', () {
    final json = _releaseJson();
    json['assets'] = [
      {
        'name': 'SHA256SUMS.txt',
        'browser_download_url': 'https://example.com/SHA256SUMS.txt',
        'size': 10,
      },
    ];
    final release = AppRelease.fromJson(json.cast<String, dynamic>());
    expect(release!.assetForWindows(), isNull);
  });

  test('fromJsonString tollera JSON non valido', () {
    expect(AppRelease.fromJsonString('non-json'), isNull);
    expect(AppRelease.fromJsonString(jsonEncode(_releaseJson())), isNotNull);
  });
}
