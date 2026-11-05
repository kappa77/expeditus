import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/app.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/services/import_service.dart';
import 'package:expeditus/src/services/rss_service.dart';
import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

/// Live end-to-end test against a real channel.
///
/// It is skipped unless explicitly enabled, because it needs the network and
/// YouTube can change or rate-limit things:
///
///   flutter test integration_test/live_youtube_test.dart -d windows \
///     --dart-define=RUN_LIVE_TESTS=true
const _runLive = bool.fromEnvironment('RUN_LIVE_TESTS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
    '@antirez: import reale, RSS reale e stream reale',
    (tester) async {
      final resolver = YouTubeResolver();
      final rss = RssService();
      final temp = await Directory.systemTemp.createTemp('expeditus_live_');
      final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
      await db.open();
      final state = AppState(db);
      addTearDown(() async {
        state.dispose();
        resolver.close();
        rss.close();
        await db.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await state.init();
      await state.completeOnboarding();
      await tester.pumpWidget(ExpeditusApp(state: state));
      await tester.pumpAndSettle();

      // The resolver must turn the public handle into a channel id.
      final resolved = await resolver.resolve(
        'https://www.youtube.com/@antirez',
      );
      expect(resolved.id, isNotEmpty);
      expect(resolved.title.toLowerCase(), contains('sanfilippo'));

      // The RSS feed is the data source of the app. Check it independently
      // before checking the UI.
      final feed = await rss.fetch(resolved.id);
      expect(feed.channelTitle.toLowerCase(), contains('sanfilippo'));
      expect(feed.entries, isNotEmpty);
      expect(feed.entries.first.title, isNotEmpty);

      // Import through the same paste flow a user would use.
      await tester.tap(find.byKey(const Key('import-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incolla canali'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('import-paste-field')),
        'https://www.youtube.com/@antirez',
      );
      await tester.tap(find.byKey(const Key('import-submit')));

      await _pumpUntil(
        tester,
        () => state.latest.isNotEmpty,
        timeout: const Duration(seconds: 60),
        reason: 'il feed reale di @antirez deve arrivare',
      );
      await tester.pumpAndSettle();

      expect(state.channels, hasLength(1));
      expect(state.channels.single.id, resolved.id);
      expect(state.latest, hasLength(1));
      expect(state.latest.single.channelId, resolved.id);
      expect(state.latest.single.title, isNotEmpty);
      expect(find.text(state.latest.single.title), findsWidgets);
      expect(
        find.text(state.latest.single.channelTitle.toUpperCase()),
        findsWidgets,
      );

      // The stream resolver is what makes the player ad-free: it asks for a
      // direct media URL instead of loading the YouTube player.
      final stream = await StreamResolver.resolve(state.latest.single.id);
      expect(stream.url.host, contains('googlevideo.com'));
      expect(stream.quality, isNotEmpty);
    },
    skip: !_runLive,
  );

  testWidgets(
    '@antirez: link video, iscrizione automatica e coda',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp('expeditus_link_');
      final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
      await db.open();
      final state = AppState(db);
      addTearDown(() async {
        state.dispose();
        await db.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await state.init();
      await state.completeOnboarding();
      await tester.pumpWidget(ExpeditusApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('import-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link video'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('video-link-field')),
        'https://www.youtube.com/watch?v=q7WfJF_Owlk',
      );
      await tester.tap(find.byKey(const Key('video-link-submit')));

      await _pumpUntil(
        tester,
        () => state.channels.any(
          (channel) => channel.id == 'UCDDG9vOcmgwlslJJpCWjqOg',
        ),
        timeout: const Duration(seconds: 60),
        reason: 'il canale del video deve essere aggiunto',
      );
      await _pumpUntil(
        tester,
        () => state.queueItems.any((video) => video.id == 'q7WfJF_Owlk'),
        timeout: const Duration(seconds: 60),
        reason: 'il video del link deve finire in coda',
      );
      await tester.pumpAndSettle();
      expect(
        state.channels.any(
          (channel) => channel.id == 'UCDDG9vOcmgwlslJJpCWjqOg',
        ),
        isTrue,
      );
    },
    skip: !_runLive,
  );

  testWidgets(
    '@antirez: ricerca canale per parola e aggiunta',
    (tester) async {
      final temp = await Directory.systemTemp.createTemp('expeditus_search_');
      final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
      await db.open();
      final state = AppState(db);
      addTearDown(() async {
        state.dispose();
        await db.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await state.init();
      await state.completeOnboarding();
      await tester.pumpWidget(ExpeditusApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-channel-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('channel-search-field')),
        'antirez',
      );
      await tester.tap(find.byKey(const Key('channel-search-submit')));

      await _pumpUntil(
        tester,
        () => find.text('Salvatore Sanfilippo').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 45),
        reason: 'la ricerca per parola deve trovare il canale',
      );
      expect(
        find.byKey(
          const Key('channel-add-UCDDG9vOcmgwlslJJpCWjqOg'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const Key('channel-add-UCDDG9vOcmgwlslJJpCWjqOg'),
        ),
      );
      await _pumpUntil(
        tester,
        () => state.channels.any(
          (channel) => channel.id == 'UCDDG9vOcmgwlslJJpCWjqOg',
        ),
        timeout: const Duration(seconds: 30),
        reason: 'il canale trovato deve essere aggiunto',
      );
      await _pumpUntil(
        tester,
        () => state.latest.isNotEmpty,
        timeout: const Duration(seconds: 60),
        reason: 'il feed del canale aggiunto deve aggiornarsi',
      );
      await tester.pumpAndSettle();

      expect(
        state.latest.single.channelId,
        'UCDDG9vOcmgwlslJJpCWjqOg',
      );
      expect(find.text('Già presente'), findsOneWidget);
    },
    skip: !_runLive,
  );
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
