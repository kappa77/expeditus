import 'dart:io';

import 'package:expeditus/src/app.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/models/app_update.dart';
import 'package:expeditus/src/services/rss_service.dart';
import 'package:expeditus/src/services/update_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

/// Regressione visiva del layout responsivo.
///
/// - Su un telefono (lato corto < 600dp) il layout usa AppBar, drawer e
///   bottom navigation, sia in portrait sia in landscape (dimensioni del
///   moto g 30: 720x1600 @ 1.75x => ~411x914 / ~914x411 logici).
/// - Su un desktop la sidebar resta completa con le etichette.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('telefono: shell compatto in portrait e landscape', (tester) async {
    final harness = (await tester.runAsync(_Harness.create))!;
    addTearDown(harness.dispose);

    tester.view.devicePixelRatio = 1.75;
    tester.view.physicalSize = const Size(720, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ExpeditusApp(state: harness.state));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phone_home_portrait.png'),
    );

    tester.view.physicalSize = const Size(1600, 720);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phone_home_landscape.png'),
    );
  });

  testWidgets('desktop: sidebar completa con etichette', (tester) async {
    final harness = (await tester.runAsync(_Harness.create))!;
    addTearDown(harness.dispose);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ExpeditusApp(state: harness.state));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_home.png'),
    );
  });
}

class _Harness {
  _Harness({required this.state, required this.db, required this.temp});

  final AppState state;
  final AppDatabase db;
  final Directory temp;

  static Future<_Harness> create() async {
    final temp = await Directory.systemTemp.createTemp('expeditus_golden_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'expeditus.sqlite'));
    await db.open();

    // Nessuna rete: il feed RSS ritorna sempre vuoto.
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

    // Attende il refresh automatico partito da init(), così lo stato è
    // deterministico prima di scattare la golden.
    while (state.refreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    return _Harness(state: state, db: db, temp: temp);
  }

  Future<void> dispose() async {
    state.dispose();
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  }
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
