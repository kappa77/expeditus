import 'dart:async';

import 'package:expeditus/src/services/resumable_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _Decoder extends PlatformPlayer {
  _Decoder() : super(configuration: const PlayerConfiguration());

  final opened = <Media>[];
  final seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  Completer<void>? opening;
  bool get hasPositionListener => positionController.hasListener;

  void report(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add(playable as Media);
    report(Duration.zero);
    state = state.copyWith(playing: play, completed: false);
    playingController.add(play);
    await opening?.future;
  }

  @override
  Future<void> play() async {
    plays++;
    state = state.copyWith(playing: true);
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
    report(duration);
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(playing: false);
    report(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _Decoder decoder;
  late ResumablePlayer player;
  late DateTime now;
  late List<Duration> refreshed;
  late List<Object> errors;
  late bool foreground;
  late bool refreshAllowed;
  Completer<Media>? refreshResult;

  setUp(() {
    decoder = _Decoder();
    now = DateTime.utc(2026, 11, 13, 10);
    refreshed = [];
    errors = [];
    foreground = true;
    refreshAllowed = true;
    refreshResult = null;
    player = ResumablePlayer(
      platformPlayer: decoder,
      clock: () => now,
      canPlay: () => foreground,
      canRefresh: () => refreshAllowed,
      onRefreshError: errors.add,
      refreshMedia: (position) async {
        refreshed.add(position);
        return refreshResult?.future ??
            Media('https://example.com/renewed.m3u8', start: position);
      },
    );
  });

  tearDown(() async {
    if (!decoder.disposed) await player.dispose();
  });

  Future<void> pausedAt137({String? uri}) async {
    await player.open(Media(uri ?? 'https://example.com/video.m3u8'));
    decoder.report(const Duration(milliseconds: 137450));
    await _flush();
    await player.pause();
  }

  test('una pausa lunga rinnova lo stream al millisecondo fermato', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 7));
    decoder.report(Duration.zero);
    await _flush();

    await player.playOrPause();

    expect(refreshed, [const Duration(milliseconds: 137450)]);
    expect(decoder.opened.last.start, const Duration(milliseconds: 137450));
    expect(player.position, const Duration(milliseconds: 137450));
    expect(decoder.state.playing, isTrue);
    expect(errors, isEmpty);
  });

  test(
    'una pausa breve ripristina il decoder senza estrarre di nuovo',
    () async {
      await pausedAt137();
      now = now.add(const Duration(seconds: 20));
      decoder.report(const Duration(seconds: 4));
      await _flush();

      expect(player.position, const Duration(milliseconds: 137450));
      await player.play();

      expect(refreshed, isEmpty);
      expect(decoder.seeks, [const Duration(milliseconds: 137450)]);
    },
  );

  for (final path in ['video?expire=1', 'expire/1/video.m3u8']) {
    test('rinnova un URL scaduto: $path', () async {
      await pausedAt137(uri: 'https://example.com/$path');
      await player.play();
      expect(refreshed, [const Duration(milliseconds: 137450)]);
    });
  }

  test('gli eventi di reset non cancellano il punto di ripresa', () async {
    await player.open(
      Media('https://example.com/video', start: const Duration(seconds: 137)),
    );
    decoder.report(const Duration(seconds: 2));
    await _flush();
    expect(player.position, const Duration(seconds: 137));
    decoder.report(const Duration(seconds: 138));
    await _flush();
    expect(player.position, const Duration(seconds: 138));
  });

  test('un seek esplicito a zero resta valido', () async {
    await pausedAt137();
    await player.seek(Duration.zero);
    now = now.add(const Duration(hours: 1));
    await player.play();
    expect(refreshed, [Duration.zero]);
    expect(player.position, Duration.zero);
  });

  test('accetta il primo aggiornamento tardivo dopo la ripresa', () async {
    await player.open(
      Media('https://example.com/video', start: const Duration(seconds: 137)),
    );
    decoder.report(const Duration(seconds: 140));
    await _flush();
    expect(player.position, const Duration(seconds: 140));
  });

  test('un seek durante la pausa aggiorna il punto di ripresa', () async {
    await pausedAt137();
    await player.seek(const Duration(seconds: 30));
    now = now.add(const Duration(hours: 1));
    await player.play();
    expect(refreshed, [const Duration(seconds: 30)]);
  });

  test('file locali e clock del cast non rinnovano gli URL', () async {
    await pausedAt137(uri: 'file:///C:/video.mp4');
    now = now.add(const Duration(hours: 7));
    await player.play();
    expect(refreshed, isEmpty);

    await pausedAt137();
    refreshAllowed = false;
    now = now.add(const Duration(hours: 7));
    await player.play();
    expect(refreshed, isEmpty);
  });

  test('più richieste di play condividono un solo rinnovo', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 1));
    refreshResult = Completer<Media>();
    final first = player.play();
    final second = player.play();
    await _flush();
    expect(refreshed, hasLength(1));
    refreshResult!.complete(
      Media('https://example.com/new', start: player.position),
    );
    await Future.wait([first, second]);
    expect(decoder.opened, hasLength(2));
    expect(decoder.plays, 2); // initial open and one resume
  });

  test('chiudere durante il rinnovo non riapre il decoder', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 1));
    refreshResult = Completer<Media>();
    final resuming = player.play();
    await _flush();
    await player.dispose();
    refreshResult!.complete(Media('https://example.com/new'));
    await resuming;
    expect(decoder.opened, hasLength(1));
    expect(decoder.disposed, isTrue);
    expect(decoder.hasPositionListener, isFalse);
    expect(errors, isEmpty);
  });

  test('una pausa durante il rinnovo annulla la ripresa', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 1));
    refreshResult = Completer<Media>();
    final resuming = player.play();
    await _flush();
    await player.pause();
    refreshResult!.complete(Media('https://example.com/new'));
    await resuming;
    expect(decoder.opened, hasLength(1));
    expect(decoder.state.playing, isFalse);
    expect(player.position, const Duration(milliseconds: 137450));
  });

  test('un seek durante il rinnovo conserva la nuova posizione', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 1));
    refreshResult = Completer<Media>();
    final resuming = player.play();
    await _flush();
    await player.seek(const Duration(seconds: 30));
    refreshResult!.complete(Media('https://example.com/new'));
    await resuming;
    expect(decoder.opened, hasLength(1));
    expect(player.position, const Duration(seconds: 30));
  });

  test(
    'un nuovo play dopo una pausa durante il rinnovo non viene perso',
    () async {
      await pausedAt137();
      now = now.add(const Duration(hours: 1));
      refreshResult = Completer<Media>();
      final canceled = player.play();
      await _flush();
      await player.pause();
      final resumed = player.play();
      final result = refreshResult!;
      refreshResult = null;
      result.complete(Media('https://example.com/old'));
      await Future.wait([canceled, resumed]);
      expect(refreshed, hasLength(2));
      expect(decoder.state.playing, isTrue);
    },
  );

  test('tornare in background durante il rinnovo non avvia audio', () async {
    await pausedAt137();
    now = now.add(const Duration(hours: 1));
    refreshResult = Completer<Media>();
    final resuming = player.play();
    await _flush();
    foreground = false;
    refreshResult!.complete(
      Media('https://example.com/new', start: player.position),
    );
    await resuming;
    expect(decoder.state.playing, isFalse);
  });

  test('un caricamento terminato in background resta in pausa', () async {
    decoder.opening = Completer<void>();
    final opening = player.open(Media('https://example.com/video'));
    await _flush();
    foreground = false;
    decoder.opening!.complete();
    await opening;
    expect(decoder.plays, 0);
    foreground = true;
    await player.play();
    expect(decoder.plays, 1);
  });

  test(
    'un rinnovo fallito conserva il punto e permette di riprovare',
    () async {
      await pausedAt137();
      now = now.add(const Duration(hours: 1));
      refreshResult = Completer<Media>();
      final resuming = player.play();
      await _flush();
      refreshResult!.completeError(StateError('offline'));
      await resuming;
      expect(errors, hasLength(1));
      expect(player.position, const Duration(milliseconds: 137450));
      expect(decoder.state.playing, isFalse);
      refreshResult = null;
      await player.play();
      expect(refreshed, hasLength(2));
      expect(decoder.state.playing, isTrue);
    },
  );
}
