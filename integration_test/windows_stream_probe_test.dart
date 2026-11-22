import 'dart:async';
import 'dart:io';

import 'package:expeditus/l10n/generated/app_localizations.dart';
import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/services/resumable_player.dart';
import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:expeditus/src/services/video_chapters_service.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:expeditus/src/theme.dart';
import 'package:expeditus/src/ui/player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

/// Live Windows stream probe. It opens a real YouTube video, reads the
/// effective mpv cache properties, and logs position, buffering, errors and
/// recovery events once per second. Run explicitly:
///
/// flutter test integration_test/windows_stream_probe_test.dart -d windows
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  const probeVideoId = String.fromEnvironment(
    'PROBE_VIDEO_ID',
    defaultValue: 'aqz-KE-bpKQ',
  );
  const probeSeconds = int.fromEnvironment('PROBE_SECONDS', defaultValue: 45);
  const probeStart = int.fromEnvironment(
    'PROBE_START_SECONDS',
    defaultValue: 0,
  );

  testWidgets('Windows: real stream stability probe', (tester) async {
    MediaKit.ensureInitialized();
    await initializeDateFormatting('it_IT');
    final temp = await Directory.systemTemp.createTemp('expeditus_stream_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'probe.sqlite'));
    await db.open();
    const channel = Channel(
      id: 'stream-probe',
      title: 'Stream probe',
      addedAt: 1,
    );
    final video = VideoItem(
      id: probeVideoId,
      channelId: channel.id,
      channelTitle: channel.title,
      title: 'Stream probe $probeVideoId',
      description: '',
      publishedAt: 0,
      durationSeconds: null,
      progressSeconds: probeStart,
    );
    await db.upsertChannel(channel);
    await db.upsertVideo(video);
    final state = AppState(db, chapterService: _NoChapters());
    state.sponsorBlockEnabled = false;
    final resolver = StreamResolver(languageCode: 'it');
    final errors = <String>[];
    final recoveryEvents = <String>[];

    Future<void> closePage() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    addTearDown(() async {
      await closePage();
      resolver.close();
      state.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: expeditusTheme(),
        home: PlayerPage(
          video: video,
          state: state,
          resolver: (id) async {
            final stream = await resolver.resolveVideo(id);
            debugPrint(
              'STREAM_PROBE resolved kind=${stream.kind} '
              'quality=${stream.quality} audioLanguage=${stream.audioLanguage} '
              'audio=${stream.audioUrl != null}',
            );
            return stream;
          },
        ),
      ),
    );
    await _waitFor(() => find.byType(Video).evaluate().isNotEmpty);
    final controller = tester
        .widget<Video>(find.byType(Video).first)
        .controller;
    final player = controller.player as ResumablePlayer;
    final logSubscription = player.stream.log.listen((log) {
      if (log.level == 'error' || log.level == 'fatal') {
        errors.add('${log.prefix}: ${log.text}');
      }
    });
    void recoveryListener() {
      final status = player.recovery.value;
      if (status.isReconnecting) {
        recoveryEvents.add('attempt ${status.attempt}/${status.maxAttempts}');
      }
    }

    player.recovery.addListener(recoveryListener);
    addTearDown(() async {
      player.recovery.removeListener(recoveryListener);
      await logSubscription.cancel();
    });

    await _waitFor(
      () =>
          player.state.position > const Duration(seconds: 1) &&
          player.state.width != null &&
          player.state.height != null,
    );
    await controller.waitUntilFirstFrameRendered.timeout(
      const Duration(seconds: 30),
    );
    final native = player.platform! as NativePlayer;
    for (final property in [
      'cache',
      'cache-on-disk',
      'cache-pause',
      'cache-pause-initial',
      'cache-pause-wait',
      'cache-secs',
      'demuxer-max-bytes',
      'demuxer-max-back-bytes',
      'network-timeout',
    ]) {
      final value = await native.getProperty(property);
      debugPrint('STREAM_PROBE property $property=$value');
    }
    debugPrint(
      'STREAM_PROBE firstFrame position=${player.position.inMilliseconds} '
      'decoded=${player.state.width}x${player.state.height}',
    );
    debugPrint('STREAM_PROBE videoTracks=${player.state.tracks.video}');
    debugPrint('STREAM_PROBE audioTracks=${player.state.tracks.audio}');
    debugPrint('STREAM_PROBE selectedVideo=${player.state.track.video}');
    debugPrint('STREAM_PROBE selectedAudio=${player.state.track.audio}');

    final start = player.position;
    var lastPosition = player.position;
    var lastChange = DateTime.now();
    var maxGap = Duration.zero;
    var stalls = 0;
    for (var second = 1; second <= probeSeconds; second++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final now = DateTime.now();
      final position = player.position;
      if ((position - lastPosition).abs() > const Duration(milliseconds: 100)) {
        lastPosition = position;
        lastChange = now;
      }
      final gap = now.difference(lastChange);
      if (gap > maxGap) maxGap = gap;
      final stalled = gap > const Duration(seconds: 5);
      if (stalled) stalls++;
      if (second % 5 == 0 || stalled) {
        final recovery = player.recovery.value;
        debugPrint(
          'STREAM_PROBE t=${second}s pos=${position.inSeconds} '
          'playing=${player.state.playing} buffering=${player.state.buffering} '
          'buffer=${player.state.buffer.inSeconds}s '
          'recovery=${recovery.phase.name}/${recovery.attempt} '
          'gap=${gap.inSeconds}s errors=${errors.length}',
        );
      }
    }
    final advanced = player.position - start;
    debugPrint(
      'STREAM_PROBE summary advanced=${advanced.inSeconds}s maxGap=${maxGap.inSeconds}s '
      'stalls=$stalls recoveryEvents=$recoveryEvents errors=$errors',
    );

    expect(
      errors.where((error) => error.contains('file cache')),
      isEmpty,
      reason: 'on-disk cache must be disabled',
    );
    expect(
      recoveryEvents,
      isEmpty,
      reason: 'healthy playback must not recover',
    );
    expect(stalls, 0, reason: 'position must keep advancing');
    expect(advanced.inSeconds, greaterThan(probeSeconds - 15));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _waitFor(bool Function() predicate) async {
  final timer = Stopwatch()..start();
  while (!predicate()) {
    if (timer.elapsed > const Duration(seconds: 60)) {
      throw TimeoutException('Native playback condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class _NoChapters implements VideoChaptersProvider {
  @override
  Future<List<VideoChapter>> fetch(String videoId) async => const [];

  @override
  void close() {}
}
