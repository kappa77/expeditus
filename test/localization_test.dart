import 'dart:io';

import 'package:expeditus/l10n/generated/app_localizations.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le quattro lingue caricano e usano i plurali corretti', () async {
    final it = await AppLocalizations.delegate.load(const Locale('it'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    final es = await AppLocalizations.delegate.load(const Locale('es'));

    expect(it.navLatest, 'Ultimi');
    expect(en.navLatest, 'Latest');
    expect(de.navLatest, 'Neueste');
    expect(es.navLatest, 'Recientes');

    expect(it.videosLabel(1), '1 video');
    expect(it.videosLabel(3), '3 video');
    expect(en.videosLabel(3), '3 videos');
    expect(de.videosLabel(3), '3 Videos');
    expect(es.videosLabel(3), '3 vídeos');
    expect(de.channelsImportedCount(2), '2 Kanäle importiert');
    expect(es.channelsNotUpdated(2), '2 canales no actualizados');
  });

  test('la lingua scelta viene salvata e applicata', () async {
    final temp = await Directory.systemTemp.createTemp('expeditus_locale_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
    addTearDown(() async {
      await db.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final state = AppState(db);
    expect(state.localeCode, 'it');
    expect(state.locale, const Locale('it'));

    await state.setLocale('de');
    expect(state.localeCode, 'de');
    expect(state.locale, const Locale('de'));
    expect(await db.getSettings(), containsPair('locale', 'de'));

    await state.setLocale('system');
    expect(state.localeCode, 'system');
    expect(state.locale, isNull);
    state.dispose();
  });
}
