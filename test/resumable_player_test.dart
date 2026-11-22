import 'dart:async';

import 'package:expeditus/src/services/resumable_player.dart';
import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _Decoder extends PlatformPlayer {
  _Decoder() : super(configuration: const PlayerConfiguration());

  final opened = <Media>[];
  final seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  AudioTrack? selectedAudio;
  Completer<void>? opening;
  bool get hasPositionListener => positionController.hasListener;

  void report(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  void reportError(String prefix, String text) {
    logController.add(PlayerLog(prefix: prefix, level: 'error', text: text));
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
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    selectedAudio = track;
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

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

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
      stallAfter: null,
      recoveryDelays: const [Duration.zero],
      refreshMedia: (position, attempt) async {
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
      // Three failed attempts plus the successful retry.
      expect(refreshed, hasLength(4));
      expect(decoder.state.playing, isTrue);
    },
  );

  test(
    'accetta il progresso oltre dieci secondi dal punto di ripresa',
    () async {
      await player.open(
        Media('https://example.com/video', start: const Duration(seconds: 137)),
      );
      decoder.report(const Duration(seconds: 160));
      await _flush();
      expect(player.position, const Duration(seconds: 160));
    },
  );

  test(
    'un keyframe indietro viene accettato dopo il tempo di assestamento',
    () async {
      await player.open(
        Media('https://example.com/video', start: const Duration(seconds: 300)),
      );
      decoder.report(const Duration(seconds: 100));
      await _flush();
      expect(player.position, const Duration(seconds: 300));

      now = now.add(const Duration(seconds: 11));
      decoder.report(const Duration(seconds: 101));
      await _flush();
      expect(player.position, const Duration(seconds: 101));
    },
  );

  test('lo stallo della posizione rinnova lo stream e riprende', () async {
    final watchdogDecoder = _Decoder();
    final watchdog = ResumablePlayer(
      platformPlayer: watchdogDecoder,
      clock: () => now,
      canPlay: () => true,
      canRefresh: () => true,
      onRefreshError: errors.add,
      stallAfter: const Duration(seconds: 5),
      startupGrace: Duration.zero,
      recoveryDelays: const [Duration.zero],
      refreshMedia: (position, attempt) async {
        refreshed.add(position);
        return Media('https://example.com/renewed.m3u8', start: position);
      },
    );
    addTearDown(watchdog.dispose);
    await watchdog.open(Media('https://example.com/video.m3u8'));
    watchdogDecoder.report(const Duration(seconds: 10));
    await _flush();
    watchdog.debugCheckHealth(); // consume the zero-length startup grace

    now = now.add(const Duration(seconds: 6));
    watchdog.debugCheckHealth();
    await _settle();

    expect(refreshed, [const Duration(seconds: 10)]);
    expect(watchdogDecoder.opened, hasLength(2));
    expect(watchdogDecoder.state.playing, isTrue);
    expect(watchdog.position, const Duration(seconds: 10));
    expect(errors, isEmpty);
  });

  test(
    'un errore di rete transitorio non interrompe la riproduzione',
    () async {
      final watchdogDecoder = _Decoder();
      final watchdog = ResumablePlayer(
        platformPlayer: watchdogDecoder,
        clock: () => now,
        canPlay: () => true,
        canRefresh: () => true,
        onRefreshError: errors.add,
        stallAfter: const Duration(seconds: 5),
        startupGrace: Duration.zero,
        recoveryDelays: const [Duration.zero],
        refreshMedia: (position, attempt) async {
          refreshed.add(position);
          return Media('https://example.com/renewed.m3u8', start: position);
        },
      );
      addTearDown(watchdog.dispose);
      await watchdog.open(Media('https://example.com/video.m3u8'));
      watchdogDecoder.report(const Duration(seconds: 10));
      await _flush();
      watchdog.debugCheckHealth();

      watchdogDecoder.reportError('ffmpeg', 'error: tcp: connection reset');
      await _flush();
      now = now.add(const Duration(seconds: 1));
      watchdogDecoder.report(const Duration(seconds: 11));
      await _flush();

      now = now.add(const Duration(seconds: 6));
      watchdog.debugCheckHealth();
      await _settle();

      expect(refreshed, isEmpty);
      expect(errors, isEmpty);
      expect(watchdogDecoder.opened, hasLength(1));
      expect(watchdogDecoder.state.playing, isTrue);
    },
  );

  test(
    'un errore del decoder video rinnova anche con audio che avanza',
    () async {
      final watchdogDecoder = _Decoder();
      final watchdog = ResumablePlayer(
        platformPlayer: watchdogDecoder,
        clock: () => now,
        canPlay: () => true,
        canRefresh: () => true,
        onRefreshError: errors.add,
        stallAfter: null,
        decoderRecoveryDelay: Duration.zero,
        recoveryDelays: const [Duration.zero],
        refreshMedia: (position, attempt) async {
          refreshed.add(position);
          return Media('https://example.com/renewed.m3u8', start: position);
        },
      );
      addTearDown(watchdog.dispose);
      await watchdog.open(Media('https://example.com/video.m3u8'));
      watchdogDecoder.report(const Duration(seconds: 10));
      await _flush();
      now = now.add(const Duration(seconds: 3));
      watchdogDecoder.reportError('vd', 'error: decoding frame failed');
      await _settle();

      expect(refreshed, [const Duration(seconds: 10)]);
      expect(watchdogDecoder.opened, hasLength(2));
      expect(watchdogDecoder.state.playing, isTrue);
      expect(errors, isEmpty);
    },
  );

  test('un recovery fallito mostra un solo errore dopo i tentativi', () async {
    final watchdogDecoder = _Decoder();
    var attempts = 0;
    final watchdog = ResumablePlayer(
      platformPlayer: watchdogDecoder,
      clock: () => now,
      canPlay: () => true,
      canRefresh: () => true,
      onRefreshError: errors.add,
      stallAfter: const Duration(seconds: 5),
      startupGrace: Duration.zero,
      recoveryAttempts: 2,
      recoveryDelays: const [Duration.zero],
      refreshMedia: (position, attempt) async {
        attempts++;
        throw StateError('offline');
      },
    );
    addTearDown(watchdog.dispose);
    await watchdog.open(Media('https://example.com/video.m3u8'));
    watchdogDecoder.report(const Duration(seconds: 10));
    await _flush();
    watchdog.debugCheckHealth();

    now = now.add(const Duration(seconds: 6));
    watchdog.debugCheckHealth();
    await _settle();

    expect(attempts, 2);
    expect(errors, hasLength(1));
    expect(watchdogDecoder.state.playing, isFalse);
    expect(watchdog.position, const Duration(seconds: 10));
    expect(watchdog.recovery.value.phase, StreamRecoveryPhase.failed);
  });

  test('la pausa lunga riprova una risoluzione fallita', () async {
    final retryDecoder = _Decoder();
    var attempts = 0;
    final retryPlayer = ResumablePlayer(
      platformPlayer: retryDecoder,
      clock: () => now,
      canPlay: () => true,
      canRefresh: () => true,
      onRefreshError: errors.add,
      stallAfter: null,
      recoveryAttempts: 2,
      recoveryDelays: const [Duration.zero],
      refreshMedia: (position, attempt) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return Media('https://example.com/renewed.m3u8', start: position);
      },
    );
    addTearDown(retryPlayer.dispose);
    await retryPlayer.open(Media('https://example.com/video.m3u8'));
    retryDecoder.report(const Duration(seconds: 30));
    await _flush();
    await retryPlayer.pause();
    now = now.add(const Duration(hours: 1));

    await retryPlayer.play();
    await _settle();

    expect(attempts, 2);
    expect(errors, isEmpty);
    expect(retryDecoder.opened, hasLength(2));
    expect(retryDecoder.state.playing, isTrue);
  });

  test('un video-only riceve la traccia audio esterna', () async {
    await player.open(
      Media(
        'https://example.com/video.mp4',
        extras: {
          externalAudioUrlExtra: 'https://example.com/audio.m4a',
          externalAudioLanguageExtra: 'it',
        },
      ),
    );
    await _flush();

    expect(decoder.selectedAudio?.id, 'https://example.com/audio.m4a');
    expect(decoder.selectedAudio?.uri, isTrue);
    expect(decoder.selectedAudio?.language, 'it');
    expect(decoder.opened, hasLength(1));
    expect(decoder.state.playing, isTrue);
  });

  test('un errore della cache su disco non invalida lo stream', () async {
    await player.open(Media('https://example.com/video.m3u8'));
    decoder.report(const Duration(seconds: 10));
    await _flush();

    decoder.reportError('lavf', 'Failed to create file cache.');
    await _flush();
    await player.pause();
    await player.play();
    await _settle();

    expect(refreshed, isEmpty);
    expect(decoder.opened, hasLength(1));
    expect(decoder.state.playing, isTrue);
  });

  test('un errore di avvio non rinnova un video che sta avanzando', () async {
    final watchdogDecoder = _Decoder();
    final watchdog = ResumablePlayer(
      platformPlayer: watchdogDecoder,
      clock: () => now,
      canPlay: () => true,
      canRefresh: () => true,
      onRefreshError: errors.add,
      stallAfter: const Duration(seconds: 5),
      startupGrace: const Duration(seconds: 30),
      recoveryDelays: const [Duration.zero],
      refreshMedia: (position, attempt) async {
        refreshed.add(position);
        return Media('https://example.com/renewed.m3u8', start: position);
      },
    );
    addTearDown(watchdog.dispose);
    await watchdog.open(Media('https://example.com/video.m3u8'));
    watchdogDecoder.report(const Duration(seconds: 10));
    await _flush();

    now = now.add(const Duration(seconds: 1));
    watchdogDecoder.reportError('ffmpeg', 'error: tcp: connection reset');
    await _flush();
    now = now.add(const Duration(seconds: 1));
    watchdogDecoder.report(const Duration(seconds: 11));
    await _flush();
    now = now.add(const Duration(seconds: 8));
    watchdogDecoder.report(const Duration(seconds: 12));
    await _flush();

    now = now.add(const Duration(seconds: 2));
    watchdog.debugCheckHealth();
    await _settle();

    expect(refreshed, isEmpty);
    expect(errors, isEmpty);
    expect(watchdogDecoder.opened, hasLength(1));
    expect(watchdogDecoder.state.playing, isTrue);
  });
}
