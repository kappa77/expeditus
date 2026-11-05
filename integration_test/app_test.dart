import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/app.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/services/import_service.dart';
import 'package:expeditus/src/services/rss_service.dart';
import 'package:expeditus/src/services/sponsorblock_service.dart';
import 'package:expeditus/src/services/video_download_service.dart';
import 'package:expeditus/src/services/video_tags_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('importa due canali e usa il feed come una inbox', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(ExpeditusApp(state: harness.state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-version')), findsOneWidget);
    expect(find.text('La tua casella è vuota'), findsOneWidget);

    // Import via the paste flow, which is the part of the dialog that does not
    // depend on a native file picker.
    await tester.tap(find.byKey(const Key('import-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-dialog')), findsOneWidget);

    await tester.tap(find.text('Incolla canali'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-paste-field')),
      '@testchannel\n@otherchannel',
    );
    await tester.tap(find.byKey(const Key('import-submit')));

    await _pumpUntil(
      tester,
      () => harness.state.latest.length == 2,
      reason: 'i due canali devono comparire nel feed',
    );
    await tester.pumpAndSettle();

    // One row per channel: only the latest upload of each channel.
    expect(find.text('Video A due'), findsOneWidget);
    expect(find.text('Video B uno'), findsOneWidget);
    expect(find.text('Video A uno'), findsNothing);

    // Local search only searches the subscriptions we have.
    await tester.enterText(
      find.byKey(const Key('search-field')),
      'B uno',
    );
    await tester.pump();
    expect(find.text('Video B uno'), findsOneWidget);
    expect(find.text('Video A due'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-field')), '');
    await tester.pump();

    // Keyboard flow: select, mark watched, then queue.
    await tester.tap(find.byKey(const Key('video-row-bb1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await _pumpUntil(
      tester,
      () => harness.state.latest.any(
        (video) => video.id == 'bb1' && video.isWatched,
      ),
      reason: 'M deve segnare il video come visto',
    );
    expect(harness.state.newCount, 1);

    await tester.tap(find.byKey(const Key('video-row-bb1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await _pumpUntil(
      tester,
      () => harness.state.queueItems.length == 1,
      reason: 'S deve aggiungere il video alla coda',
    );

    await tester.tap(find.byKey(const Key('nav-queue')));
    await tester.pumpAndSettle();
    expect(find.text('Video B uno'), findsOneWidget);
    expect(find.text('Video A due'), findsNothing);

    // Focus mode: descriptions disappear from the feed.
    await tester.tap(find.byKey(const Key('nav-latest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-hide-descriptions')));
    await _pumpUntil(
      tester,
      () => harness.state.hideDescriptions,
      reason: 'l’interruttore deve aggiornare lo stato',
    );
    await tester.ensureVisible(find.text('Fatto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fatto'));
    await tester.pumpAndSettle();
    expect(find.text('Descrizione A due'), findsNothing);
  });

  testWidgets('dettaglio canale: video passati, filtro e tag', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(ExpeditusApp(state: harness.state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incolla canali'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-paste-field')),
      '@testchannel\n@otherchannel',
    );
    await tester.tap(find.byKey(const Key('import-submit')));
    await _pumpUntil(
      tester,
      () => harness.state.latest.length == 2,
      reason: 'i due canali devono essere importati',
    );
    await tester.pumpAndSettle();

    // The channel name in the feed opens the channel archive.
    await tester.tap(find.byKey(Key('channel-link-$_channelA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('channel-page')), findsOneWidget);

    // The latest upload and the older one are both here.
    expect(find.text('Video A due'), findsOneWidget);
    expect(find.text('Video A uno'), findsOneWidget);

    // Tags are fetched lazily and shown under the videos.
    await _pumpUntil(
      tester,
      () => find.text('demo').evaluate().isNotEmpty,
      reason: 'i tag del video devono comparire',
    );
    expect(find.text('news'), findsOneWidget);

    // Term filter, including tags.
    await tester.enterText(
      find.byKey(const Key('channel-page-search')),
      'uno',
    );
    await tester.pump();
    expect(find.text('Video A uno'), findsOneWidget);
    expect(find.text('Video A due'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('channel-page-search')),
      'demo',
    );
    await tester.pump();
    expect(find.text('Video A uno'), findsOneWidget);
    expect(find.text('Video A due'), findsNothing);

    // Status filter.
    await tester.enterText(
      find.byKey(const Key('channel-page-search')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('channel-watched-aa1')));
    await _pumpUntil(
      tester,
      () => find.text('Visti 1').evaluate().isNotEmpty,
      reason: 'il conteggio dei visti deve aggiornarsi',
    );
    await tester.tap(find.byKey(const Key('channel-filter-watched')));
    await tester.pump();
    expect(find.text('Video A uno'), findsOneWidget);
    expect(find.text('Video A due'), findsNothing);

    // Second tab: watched history for this channel.
    await tester.tap(find.text('Cronologia'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('channel-video-aa1')), findsOneWidget);
    expect(find.byKey(const Key('channel-video-aa2')), findsNothing);
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    // RSS mute: new items disappear from the channel page, history remains.
    await tester.tap(find.byKey(const Key('channel-filter-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('channel-mute-rss')));
    await tester.pump();
    expect(find.byKey(const Key('channel-video-aa2')), findsNothing);
    expect(find.byKey(const Key('channel-video-aa1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('channel-mute-rss')));
    await tester.pump();
    expect(find.byKey(const Key('channel-video-aa2')), findsOneWidget);

    // Offline download through the fake downloader.
    await tester.tap(find.byKey(const Key('channel-download-aa1')));
    await _pumpUntil(
      tester,
      () => harness.state.savedCount == 1,
      reason: 'il download deve salvare il video',
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);

    // "Mostra in novità" controls the latest feed independently.
    await tester.tap(find.byKey(const Key('channel-show-in-latest')));
    await _pumpUntil(
      tester,
      () => harness.state.latest.every((video) => video.channelId != _channelA),
      reason: 'il canale deve sparire dalla lista delle novità',
    );
    await tester.tap(find.byKey(const Key('channel-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('channel-page')), findsNothing);
    expect(find.byKey(const Key('video-row-aa2')), findsNothing);
    expect(find.byKey(const Key('video-row-bb1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Video A uno'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-latest')));
    await tester.pumpAndSettle();

    // The archive is still reachable from the Canali list; re-enable the feed.
    await tester.tap(find.byKey(const Key('nav-channels')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('channel-row-$_channelA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('channel-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('channel-show-in-latest')));
    await _pumpUntil(
      tester,
      () => harness.state.latest.any((video) => video.channelId == _channelA),
      reason: 'il canale deve tornare nella lista delle novità',
    );
    await tester.tap(find.byKey(const Key('channel-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-latest')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('video-row-aa2')), findsOneWidget);
  });

  testWidgets('primo avvio: pagina di ricerca canale', (tester) async {
    final harness = await _Harness.create(completeOnboarding: false);
    addTearDown(harness.dispose);

    await tester.pumpWidget(ExpeditusApp(state: harness.state));
    await tester.pumpAndSettle();

    expect(find.text('Benvenuto.'), findsOneWidget);
    expect(find.byKey(const Key('channel-search-field')), findsOneWidget);

    await tester.tap(find.text('Salta per ora'));
    await tester.pumpAndSettle();
    expect(find.text('La tua casella è vuota'), findsOneWidget);
  });

  testWidgets('lo stream non disponibile è un errore recuperabile', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      ExpeditusApp(
        state: harness.state,
        playerResolver: (_) async => throw Exception('test stream error'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incolla canali'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-paste-field')),
      '@testchannel',
    );
    await tester.tap(find.byKey(const Key('import-submit')));
    await _pumpUntil(
      tester,
      () => harness.state.latest.isNotEmpty,
      reason: 'il canale deve essere importato',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('video-row-aa2')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('player-page')).evaluate().isNotEmpty,
      reason: 'Invio deve aprire il player',
    );
    await _pumpUntil(
      tester,
      () => find.text('Stream non disponibile').evaluate().isNotEmpty,
      reason: 'l’errore dello stream deve essere mostrato',
    );

    expect(find.text('Apri su YouTube'), findsOneWidget);
    expect(find.byKey(const Key('seek-back-button')), findsOneWidget);
    expect(find.byKey(const Key('seek-forward-button')), findsOneWidget);

    // Playback speed: 0.25×–3.50× in 0.25 steps.
    await tester.tap(find.byKey(const Key('speed-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.25×'));
    await _pumpUntil(
      tester,
      () => harness.state.playbackRate == 1.25,
      reason: 'la velocità scelta deve essere applicata',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-page')), findsNothing);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String? reason,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail(reason ?? 'Timeout in attesa della condizione');
}

class _Harness {
  _Harness({
    required this.state,
    required this.db,
    required this.temp,
  });

  final AppState state;
  final AppDatabase db;
  final Directory temp;

  static Future<_Harness> create({bool completeOnboarding = true}) async {
    final temp = await Directory.systemTemp.createTemp('expeditus_e2e_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
    await db.open();

    final client = MockClient(_handleRequest);
    final state = AppState(
      db,
      rss: RssService(client: client),
      resolver: YouTubeResolver(client: client),
      sponsorBlock: SponsorBlockService(client: client),
      tags: _FakeTags(),
      downloader: _FakeDownloader(
        Directory(p.join(temp.path, 'downloads')),
      ),
    );
    await state.init();
    if (completeOnboarding) {
      await state.completeOnboarding();
    }
    return _Harness(state: state, db: db, temp: temp);
  }

  Future<void> dispose() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (state.refreshing && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    state.dispose();
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  }
}

Future<http.Response> _handleRequest(http.Request request) async {
  if (request.url.host == 'www.youtube.com' &&
      request.url.path == '/feeds/videos.xml') {
    final channelId = request.url.queryParameters['channel_id'];
    if (channelId == _channelA) {
      return _xml(_feed(
        channelId: _channelA,
        channelTitle: 'Canale A',
        videos: const [
          _VideoFixture(
            id: 'aa1',
            title: 'Video A uno',
            description: 'Descrizione A uno',
            published: '2026-11-01T10:00:00+00:00',
          ),
          _VideoFixture(
            id: 'aa2',
            title: 'Video A due',
            description: 'Descrizione A due',
            published: '2026-11-03T10:00:00+00:00',
          ),
        ],
      ));
    }
    if (channelId == _channelB) {
      return _xml(_feed(
        channelId: _channelB,
        channelTitle: 'Canale B',
        videos: const [
          _VideoFixture(
            id: 'bb1',
            title: 'Video B uno',
            description: 'Descrizione B uno',
            published: '2026-11-02T10:00:00+00:00',
          ),
        ],
      ));
    }
    return http.Response('not found', 404);
  }

  if (request.url.host == 'www.youtube.com' &&
      request.url.path.startsWith('/@')) {
    if (request.url.path == '/@testchannel') {
      return _html(_channelPage(_channelA, 'Canale A'));
    }
    if (request.url.path == '/@otherchannel') {
      return _html(_channelPage(_channelB, 'Canale B'));
    }
  }

  return http.Response('not found', 404);
}

final _channelA = 'UC${'a' * 22}';
final _channelB = 'UC${'b' * 22}';

http.Response _xml(String body) {
  return http.Response(
    body,
    200,
    headers: {'content-type': 'application/xml; charset=utf-8'},
  );
}

http.Response _html(String body) {
  return http.Response(
    body,
    200,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

String _channelPage(String id, String title) {
  return '<html><script>'
      '{"externalId":"$id",'
      '"channelMetadataRenderer":{"title":"$title"}}'
      '</script></html>';
}

String _feed({
  required String channelId,
  required String channelTitle,
  required List<_VideoFixture> videos,
}) {
  final entries = videos.map((video) {
    return '''
  <entry>
    <id>yt:video:${video.id}</id>
    <yt:videoId>${video.id}</yt:videoId>
    <yt:channelId>$channelId</yt:channelId>
    <title>${_escape(video.title)}</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=${video.id}"/>
    <published>${video.published}</published>
    <media:description>${_escape(video.description)}</media:description>
  </entry>''';
  }).join();

  return '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <link rel="self" href="https://www.youtube.com/feeds/videos.xml?channel_id=$channelId"/>
  <id>yt:channel:$channelId</id>
  <yt:channelId>$channelId</yt:channelId>
  <title>${_escape(channelTitle)}</title>
  <link rel="alternate" href="https://www.youtube.com/channel/$channelId"/>
  <author>
    <name>${_escape(channelTitle)}</name>
    <uri>https://www.youtube.com/channel/$channelId</uri>
  </author>
  <published>2026-11-03T12:00:00+00:00</published>
  $entries
</feed>''';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _VideoFixture {
  const _VideoFixture({
    required this.id,
    required this.title,
    required this.description,
    required this.published,
  });

  final String id;
  final String title;
  final String description;
  final String published;
}


class _FakeTags implements VideoTagsProvider {
  @override
  Future<List<String>> fetch(String videoId) async {
    switch (videoId) {
      case 'aa1':
        return const ['demo', 'storia'];
      case 'aa2':
        return const ['news'];
      default:
        return const [];
    }
  }

  @override
  void close() {}
}


class _FakeDownloader implements VideoDownloader {
  _FakeDownloader(this.directory);

  final Directory directory;

  @override
  Future<String> download(
    String videoId, {
    void Function(double progress)? onProgress,
  }) async {
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '$videoId.mp4'));
    await file.writeAsBytes(const [0, 1, 2, 3]);
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return file.path;
  }

  @override
  Future<void> delete(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  void close() {}
}
