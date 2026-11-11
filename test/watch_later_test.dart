import 'dart:io';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_watch_later_');
    db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
    await db.upsertChannel(
      const Channel(id: 'c1', title: 'Canale', addedAt: 1),
    );
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  VideoItem video(String id, int publishedAt) {
    return VideoItem(
      id: id,
      channelId: 'c1',
      channelTitle: 'Canale',
      title: 'Video $id',
      description: '',
      publishedAt: publishedAt,
    );
  }

  test(
    'la lista è ordinata per data di salvataggio, non di pubblicazione',
    () async {
      await db.upsertVideo(video('nuovo-ma-pubblicato-dopo', 200));
      await db.upsertVideo(video('vecchio-ma-salvato-dopo', 100));

      await db.setQueued('nuovo-ma-pubblicato-dopo', true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.setQueued('vecchio-ma-salvato-dopo', true);

      final saved = await db.watchLater();
      expect(saved.map((item) => item.id), [
        'vecchio-ma-salvato-dopo',
        'nuovo-ma-pubblicato-dopo',
      ]);
      expect(saved.every((item) => item.watchLater), isTrue);
      expect(saved.every((item) => item.watchLaterAt != null), isTrue);
    },
  );

  test('un refresh del feed non cambia la data di salvataggio', () async {
    final item = video('a1', 100);
    await db.upsertVideo(item);
    await db.setQueued('a1', true);

    final before = (await db.watchLater()).single.watchLaterAt;
    expect(before, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.upsertVideo(item.copyWith(title: 'Titolo aggiornato dal feed'));

    final after = (await db.watchLater()).single;
    expect(after.title, 'Titolo aggiornato dal feed');
    expect(after.watchLaterAt, before);
  });

  test('rimuovere dalla lista azzera appartenenza e data', () async {
    await db.upsertVideo(video('a1', 100));
    await db.setQueued('a1', true);
    expect(await db.watchLater(), hasLength(1));

    await db.setQueued('a1', false);
    expect(await db.watchLater(), isEmpty);

    final stored = (await db.videosForChannel('c1')).single;
    expect(stored.watchLater, isFalse);
    expect(stored.watchLaterAt, isNull);
  });

  test('la posizione più recente resta disponibile nella sessione', () async {
    final item = video('a1', 100);
    await db.upsertVideo(item);
    final state = AppState(db);
    addTearDown(state.dispose);

    expect(state.progressFor(item), 0);
    await state.saveProgress(item.id, 137);

    // The feed may still hold the old VideoItem, but the player must resume
    // from the newest position immediately.
    expect(state.progressFor(item), 137);
    expect((await db.videosForChannel('c1')).single.progressSeconds, 137);
  });
}
