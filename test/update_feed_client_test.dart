import 'dart:convert';

import 'package:expeditus/src/models/app_update.dart';
import 'package:expeditus/src/services/update_feed_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _releaseBody({String tag = 'v1.2.0'}) {
  return jsonEncode({
    'tag_name': tag,
    'name': 'Expeditus 1.2.0',
    'body': 'Note',
    'html_url': 'https://github.com/kappa77/expeditus/releases/tag/$tag',
    'published_at': '2026-11-06T10:00:00Z',
    'draft': false,
    'prerelease': false,
    'assets': [
      {
        'name': 'ExpeditusSetup-1.2.0.exe',
        'browser_download_url':
            'https://github.com/kappa77/expeditus/releases/download/$tag/ExpeditusSetup-1.2.0.exe',
        'size': 1000,
      },
    ],
  });
}

const _feedUrl =
    'https://api.github.com/repos/kappa77/expeditus/releases/latest';

void main() {
  test('legge una release e usa ETag e token nelle richieste', () async {
    final requests = <http.BaseRequest>[];
    final client = UpdateFeedClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          _releaseBody(),
          200,
          headers: {'etag': '"release-1"'},
        );
      }),
    );

    final result = await client.fetch(
      feedUrl: _feedUrl,
      token: 'token-di-test',
      etag: '"old"',
      clock: () => DateTime(2026, 11, 6, 12),
    );

    expect(result.release.version.canonical, '1.2.0');
    expect(result.fromCache, isFalse);
    expect(result.etag, '"release-1"');
    expect(requests.single.headers['If-None-Match'], '"old"');
    expect(requests.single.headers['Authorization'], 'Bearer token-di-test');
    expect(result.checkedAt, DateTime(2026, 11, 6, 12));
  });

  test('su 304 usa la copia locale', () async {
    final client = UpdateFeedClient(
      httpClient: MockClient((_) async => http.Response('', 304)),
    );

    final result = await client.fetch(
      feedUrl: _feedUrl,
      etag: '"same"',
      cachedBody: _releaseBody(),
    );

    expect(result.fromCache, isTrue);
    expect(result.release.version.canonical, '1.2.0');
  });

  test('se la rete fallisce usa la copia locale', () async {
    final client = UpdateFeedClient(
      httpClient: MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );

    final result = await client.fetch(
      feedUrl: _feedUrl,
      cachedBody: _releaseBody(),
    );

    expect(result.fromCache, isTrue);
    expect(result.release.version.canonical, '1.2.0');
  });

  test('se non c’è cache, gli errori di rete sono esposti', () async {
    final client = UpdateFeedClient(
      httpClient: MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      client.fetch(feedUrl: _feedUrl),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.kind,
          'kind',
          UpdateFailureKind.network,
        ),
      ),
    );
  });

  test('mappa 404, 429 e JSON non valido su errori leggibili', () async {
    final notFound = UpdateFeedClient(
      httpClient: MockClient((_) async => http.Response('', 404)),
    );
    await expectLater(
      notFound.fetch(feedUrl: _feedUrl),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.kind,
          'kind',
          UpdateFailureKind.notFound,
        ),
      ),
    );

    final rateLimited = UpdateFeedClient(
      httpClient: MockClient((_) async => http.Response('', 429)),
    );
    await expectLater(
      rateLimited.fetch(feedUrl: _feedUrl),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.kind,
          'kind',
          UpdateFailureKind.rateLimited,
        ),
      ),
    );

    final invalid = UpdateFeedClient(
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );
    await expectLater(
      invalid.fetch(feedUrl: _feedUrl),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.kind,
          'kind',
          UpdateFailureKind.invalidFeed,
        ),
      ),
    );
  });

  test('rifiuta feed HTTP non locali', () async {
    final client = UpdateFeedClient(
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    await expectLater(
      client.fetch(feedUrl: 'http://example.com/latest.json'),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.kind,
          'kind',
          UpdateFailureKind.invalidFeed,
        ),
      ),
    );
  });

  test('non inoltra il token a un host di redirect diverso', () async {
    final seen = <http.BaseRequest>[];
    final client = UpdateFeedClient(
      httpClient: MockClient((request) async {
        seen.add(request);
        if (request.url.host == 'api.github.com') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.example/release.json'},
          );
        }
        return http.Response(_releaseBody(), 200);
      }),
    );

    final result = await client.fetch(feedUrl: _feedUrl, token: 'segreto');

    expect(result.release.version.canonical, '1.2.0');
    expect(seen, hasLength(2));
    expect(seen.first.headers['Authorization'], 'Bearer segreto');
    expect(seen.last.headers.containsKey('Authorization'), isFalse);
  });
}
