import 'dart:io';

import 'package:expeditus/src/app.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  late Directory temp;
  late AppDatabase db;
  late AppState state;
  late File localFile;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_local_ui_');
    db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
    localFile = File(p.join(temp.path, 'Intervista_al_mare.mp4'));
    await localFile.writeAsBytes([0]);

    state = AppState(db);
    await state.init();
    await state.completeOnboarding();
    final result = await state.addLocalVideos([localFile.path]);
    expect(result.added, 1);
  });

  tearDown(() async {
    state.dispose();
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets('i video locali hanno una lista separata e ricercabile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ExpeditusApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-local')), findsOneWidget);
    expect(find.text('Intervista_al_mare'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-local')));
    await tester.pumpAndSettle();

    expect(find.text('Intervista_al_mare'), findsOneWidget);
    expect(find.text('VIDEO LOCALE'), findsOneWidget);
    expect(find.byKey(const Key('add-local-video-button')), findsOneWidget);
    expect(find.byKey(const Key('import-button')), findsNothing);
    expect(find.byKey(const Key('refresh-button')), findsNothing);

    await tester.enterText(find.byKey(const Key('search-field')), 'mare');
    await tester.pump();
    expect(find.text('Intervista_al_mare'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('search-field')),
      'inesistente',
    );
    await tester.pump();
    expect(find.text('Nessun risultato'), findsOneWidget);
    expect(find.text('Intervista_al_mare'), findsNothing);
  });
}
