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
    temp = await Directory.systemTemp.createTemp('expeditus_local_videos_');
    db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  LocalVideo video(
    String path, {
    String title = 'Video',
    int addedAt = 100,
    int? durationSeconds,
  }) {
    return LocalVideo(
      path: path,
      title: title,
      addedAt: addedAt,
      durationSeconds: durationSeconds,
    );
  }

  test('la libreria locale è separata e ordinata per aggiunta', () async {
    await db.upsertChannel(
      const Channel(id: 'c1', title: 'Canale', addedAt: 1),
    );
    await db.upsertVideo(
      const VideoItem(
        id: 'yt1',
        channelId: 'c1',
        channelTitle: 'Canale',
        title: 'YouTube',
        description: '',
        publishedAt: 100,
      ),
    );

    await db.upsertLocalVideo(
      video('/video/vecchio.mp4', title: 'Vecchio', addedAt: 100),
    );
    await db.upsertLocalVideo(
      video('/video/nuovo.mp4', title: 'Nuovo', addedAt: 200),
    );

    final local = await db.localVideos();
    expect(local.map((item) => item.title), ['Nuovo', 'Vecchio']);
    expect((await db.latestPerChannel()).single.title, 'YouTube');
    expect(await db.rssHistory(), hasLength(1));
    expect(await db.watchLater(), isEmpty);
  });

  test(
    'riaggiungere lo stesso file aggiorna i metadati senza spostarlo',
    () async {
      await db.upsertLocalVideo(
        video('/video/a.mp4', title: 'Titolo vecchio', addedAt: 100),
      );
      await db.upsertLocalVideo(
        video(
          '/video/a.mp4',
          title: 'Titolo nuovo',
          addedAt: 999,
          durationSeconds: 42,
        ),
      );

      final local = (await db.localVideos()).single;
      expect(local.title, 'Titolo nuovo');
      expect(local.addedAt, 100);
      expect(local.durationSeconds, 42);
    },
  );

  test('AppState aggiunge e rimuove un video locale', () async {
    final file = File(p.join(temp.path, 'Vacanze_2026.mp4'));
    await file.writeAsBytes([0]);

    final state = AppState(db);
    addTearDown(state.dispose);

    final result = await state.addLocalVideos([file.path]);

    expect(result.added, 1);
    expect(result.errors, isEmpty);
    expect(state.localCount, 1);
    expect(state.localVideos.single.title, 'Vacanze_2026');

    state.setView('local');
    final item = state.visible.single;
    expect(item.isLocal, isTrue);
    expect(item.localPath, file.path);
    expect(item.title, 'Vacanze_2026');

    await state.removeLocalVideo(item);
    expect(state.localCount, 0);
    expect(state.visible, isEmpty);
    expect(await file.exists(), isTrue);
  });

  test('rimuovere dalla libreria non cancella il file', () async {
    final file = File(p.join(temp.path, 'video.mp4'));
    await file.writeAsBytes([0]);
    await db.upsertLocalVideo(video(file.path));

    await db.deleteLocalVideo(file.path);

    expect(await db.localVideos(), isEmpty);
    expect(await file.exists(), isTrue);
  });
}
