import 'dart:io';

import 'package:expeditus/src/app.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/models/app_update.dart';
import 'package:expeditus/src/services/rss_service.dart';
import 'package:expeditus/src/services/update_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

/// Cattura screenshot reali dell'app sul dispositivo Android connesso.
///
/// Da eseguire con:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/visual_screenshot_test.dart \
///     -d `<device-id>`
///
/// Gli screenshot vengono salvati dal driver nella cartella `screenshots/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot home in portrait e landscape', (tester) async {
    await initializeDateFormatting('it_IT');

    final temp = await Directory.systemTemp.createTemp('expeditus_visual_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
    await db.open();

    final client = MockClient(
      (_) async => http.Response(_emptyFeed, 200, headers: {
        'content-type': 'application/xml; charset=utf-8',
      }),
    );

    final now = DateTime(2025, 3, 14).millisecondsSinceEpoch;
    await db.upsertChannel(
      Channel(id: 'UCaaaaaaaaaaaaaaaaaaaaaa', title: 'Canale A', addedAt: now),
    );
    await db.upsertChannel(
      Channel(id: 'UCbbbbbbbbbbbbbbbbbbbbbb', title: 'Canale B', addedAt: now),
    );
    await db.upsertVideo(
      VideoItem(
        id: 'video-a1',
        channelId: 'UCaaaaaaaaaaaaaaaaaaaaaa',
        channelTitle: 'Canale A',
        title: 'Video A',
        description: 'Descrizione A',
        publishedAt: now,
      ),
    );
    await db.upsertVideo(
      VideoItem(
        id: 'video-b1',
        channelId: 'UCbbbbbbbbbbbbbbbbbbbbbb',
        channelTitle: 'Canale B',
        title: 'Video B',
        description: 'Descrizione B',
        publishedAt: now,
      ),
    );

    final state = AppState(
      db,
      rss: RssService(client: client),
      updateChecker: _NoopUpdateChecker(),
    );
    await state.init();
    await state.completeOnboarding();
    while (state.refreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    addTearDown(() async {
      state.dispose();
      await db.close();
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });

    await tester.pumpWidget(ExpeditusApp(state: state));
    await tester.pumpAndSettle();

    // Portrait: forza l'orientamento e cattura.
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-portrait');

    // Landscape: ruota e cattura il rail di icone.
    await SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-landscape');
  });
}

const _emptyFeed = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
</feed>''';

class _NoopUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateCheckResult> check({
    String? etag,
    String? cachedBody,
    bool bypassCache = false,
  }) async {
    return UpdateCheckResult(checkedAt: DateTime.now());
  }

  @override
  void close() {}
}
