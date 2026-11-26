import 'dart:async';
import 'dart:io';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/services/video_metadata_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeMetadata implements VideoMetadataProvider {
  _FakeMetadata(this.metadata);

  final VideoMetadata metadata;
  final List<String> calls = [];

  @override
  Future<VideoMetadata> fetch(String videoId) async {
    calls.add(videoId);
    return metadata;
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_metadata_');
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

  const video = VideoItem(
    id: 'a1',
    channelId: 'c1',
    channelTitle: 'Canale',
    title: 'Video',
    description: '',
    publishedAt: 100,
  );

  test('la durata letta dalla watch page viene salvata e restituita', () async {
    await db.upsertVideo(video);
    final fake = _FakeMetadata(
      const VideoMetadata(durationSeconds: 754, keywords: ['demo']),
    );
    final state = AppState(db, metadata: fake);
    addTearDown(state.dispose);

    final updated = await state.fetchVideoMetadata(video);

    expect(updated.durationSeconds, 754);
    expect(updated.durationFetched, isTrue);
    expect(updated.keywords, ['demo']);
    expect(updated.keywordsFetched, isTrue);

    final stored = (await db.videosForChannel('c1')).single;
    expect(stored.durationSeconds, 754);
    expect(stored.durationFetched, isTrue);
    expect(stored.keywords, ['demo']);
    expect(stored.keywordsFetched, isTrue);
  });

  test('una durata sconosciuta viene memorizzata come già tentata', () async {
    await db.upsertVideo(video);
    final fake = _FakeMetadata(const VideoMetadata(keywords: []));
    final state = AppState(db, metadata: fake);
    addTearDown(state.dispose);

    final updated = await state.fetchVideoMetadata(video);

    expect(updated.durationSeconds, isNull);
    expect(updated.durationFetched, isTrue);
    expect((await db.videosForChannel('c1')).single.durationFetched, isTrue);
  });

  test('un refresh RSS non cancella la durata già recuperata', () async {
    await db.upsertVideo(
      video.copyWith(durationSeconds: 754, durationFetched: true),
    );

    await db.upsertVideo(video);

    final stored = (await db.videosForChannel('c1')).single;
    expect(stored.durationSeconds, 754);
    expect(stored.durationFetched, isTrue);
  });

  test('le righe visibili richiedono la durata una volta sola', () async {
    await db.upsertVideo(video);
    final fake = _FakeMetadata(
      const VideoMetadata(durationSeconds: 132, keywords: ['news']),
    );
    final state = AppState(db, metadata: fake);
    addTearDown(state.dispose);
    state.latest = [video];
    state.visible = [video];

    final done = Completer<void>();
    state.addListener(() {
      if (!done.isCompleted && state.latest.single.durationFetched) {
        done.complete();
      }
    });

    state.requestVideoMetadata(video);
    state.requestVideoMetadata(video);
    await done.future.timeout(const Duration(seconds: 2));

    expect(fake.calls, ['a1']);
    expect(state.latest.single.durationSeconds, 132);
    expect(state.visible.single.durationSeconds, 132);
  });
}
