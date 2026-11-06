import 'dart:convert';

import 'package:expeditus/src/services/update_feed_client.dart';
import 'package:expeditus/src/services/update_service.dart';
import 'package:expeditus/src/util/app_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _body(String tag) {
  return jsonEncode({
    'tag_name': tag,
    'name': 'Expeditus $tag',
    'body': 'Note',
    'html_url': 'https://github.com/kappa77/expeditus/releases/tag/$tag',
    'assets': [
      {
        'name': 'ExpeditusSetup-$tag.exe',
        'browser_download_url':
            'https://github.com/kappa77/expeditus/releases/download/$tag/ExpeditusSetup-$tag.exe',
        'size': 1000,
      },
    ],
  });
}

void main() {
  test('segnala una release più nuova e sceglie l’installer', () async {
    final service = UpdateService(
      currentVersion: AppVersion.parse('1.0.8'),
      feedClient: UpdateFeedClient(
        httpClient: MockClient(
          (_) async => http.Response(_body('v1.0.9'), 200),
        ),
      ),
    );

    final result = await service.check();

    expect(result.hasError, isFalse);
    expect(result.isNewer, isTrue);
    expect(result.release!.version.canonical, '1.0.9');
    expect(result.asset!.name, 'ExpeditusSetup-v1.0.9.exe');
  });

  test('non segnala una release uguale o più vecchia', () async {
    final service = UpdateService(
      currentVersion: AppVersion.parse('1.0.9'),
      feedClient: UpdateFeedClient(
        httpClient: MockClient(
          (_) async => http.Response(_body('v1.0.8'), 200),
        ),
      ),
    );

    final result = await service.check();

    expect(result.isNewer, isFalse);
    expect(result.release!.version.canonical, '1.0.8');
  });

  test('restituisce un errore invece di lanciare', () async {
    final service = UpdateService(
      currentVersion: AppVersion.parse('1.0.8'),
      feedClient: UpdateFeedClient(
        httpClient: MockClient((_) async => http.Response('', 500)),
      ),
    );

    final result = await service.check();

    expect(result.hasError, isTrue);
    expect(result.release, isNull);
    expect(result.error, contains('500'));
  });

  test('il controllo manuale non invia l’ETag', () async {
    final requests = <http.BaseRequest>[];
    final service = UpdateService(
      currentVersion: AppVersion.parse('1.0.8'),
      feedClient: UpdateFeedClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(_body('v1.0.9'), 200);
        }),
      ),
    );

    await service.check(etag: '"cached"', bypassCache: true);

    expect(requests.single.headers.containsKey('If-None-Match'), isFalse);
  });
}
