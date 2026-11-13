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

/// Live native-player regression on the connected Android device. This takes
/// several minutes and uses YouTube; run explicitly, outside the host suite:
/// flutter test integration_test/android_playback_test.dart -d DEVICE
///
/// During phase=long-pause the device may be sent Home and foregrounded again
/// to exercise a real Activity/surface transition in addition to the lifecycle
/// checks performed by the test itself. No production database is opened.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Android: stream, long pause, background and resource cycles', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await initializeDateFormatting('it_IT');
    final temp = await Directory.systemTemp.createTemp('expeditus_playback_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'probe.sqlite'));
    await db.open();
    const channel = Channel(
      id: 'playback-probe',
      title: 'Playback test',
      addedAt: 1,
    );
    final video = VideoItem(
      id: 'aqz-KE-bpKQ',
      channelId: channel.id,
      channelTitle: channel.title,
      title: 'Big Buck Bunny — playback regression',
      description: '',
      publishedAt: 0,
      durationSeconds: 596,
      progressSeconds: 60,
    );
    await db.upsertChannel(channel);
    await db.upsertVideo(video);
    await db.setProgress(video.id, 60);
    final state = AppState(db, chapterService: _NoChapters());
    state.sponsorBlockEnabled = false;
    final resolver = StreamResolver();
    ResolvedStream? resolved;
    var resolutions = 0;
    var useCachedStream = false;

    Future<ResolvedStream> resolve(String id) async {
      if (useCachedStream && resolved != null) return resolved!;
      final timer = Stopwatch()..start();
      resolutions++;
      final result = await resolver.resolveVideo(id, maxHeight: 720);
      resolved = result;
      debugPrint(
        'PLAYBACK_PROBE resolve=$resolutions ms=${timer.elapsedMilliseconds} quality=${result.quality}',
      );
      return result;
    }

    Future<void> closePage() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // media_kit defers native mpv destruction for five seconds.
      await Future<void>.delayed(const Duration(seconds: 6));
    }

    addTearDown(() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await closePage();
      resolver.close();
      state.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });

    Future<ResumablePlayer> openPage() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: expeditusTheme(),
          home: PlayerPage(video: video, state: state, resolver: resolve),
        ),
      );
      await _waitFor(() => find.byType(Video).evaluate().isNotEmpty);
      final controller = tester
          .widget<Video>(find.byType(Video).first)
          .controller;
      final player = controller.player as ResumablePlayer;
      await _waitFor(
        () =>
            player.state.width != null &&
            player.state.height != null &&
            player.state.position.inSeconds >= 60,
      );
      await controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 30),
      );
      return player;
    }

    final startup = Stopwatch()..start();
    final player = await openPage();
    debugPrint(
      'PLAYBACK_PROBE firstFrameMs=${startup.elapsedMilliseconds} decoded=${player.state.width}x${player.state.height}',
    );
    expect(player.state.position.inSeconds, inInclusiveRange(60, 68));

    await player.pause();
    final shortPause = player.position;
    // Exercise the real backend losing its clock, bypassing the wrapper only
    // for this fault injection. The stable pause point must survive.
    await player.platform!.seek(Duration.zero);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(player.position, shortPause);
    await player.playOrPause();
    await _waitFor(
      () =>
          player.state.playing &&
          (player.state.position - shortPause).inMilliseconds.abs() < 3000,
    );
    expect(resolutions, 1);
    debugPrint(
      'PLAYBACK_PROBE shortPauseRestoredMs=${player.state.position.inMilliseconds}',
    );

    await player.pause();
    final longPause = player.position;
    debugPrint(
      'PLAYBACK_PROBE phase=long-pause positionMs=${longPause.inMilliseconds}',
    );
    await Future<void>.delayed(const Duration(seconds: 125));
    expect(player.state.playing, isFalse);
    expect(player.position, longPause);
    final resumeTimer = Stopwatch()..start();
    await player.playOrPause();
    await _waitFor(
      () =>
          player.state.playing &&
          (player.state.position - longPause).inMilliseconds.abs() < 3000,
    );
    expect(resolutions, 2);
    debugPrint(
      'PLAYBACK_PROBE longPauseResumeMs=${resumeTimer.elapsedMilliseconds} positionMs=${player.state.position.inMilliseconds}',
    );

    if (const bool.fromEnvironment('HOST_LIFECYCLE_PROBE')) {
      debugPrint('PLAYBACK_PROBE phase=playing-background');
      await _waitFor(() => !player.state.playing);
      final realPause = player.position;
      await _waitFor(() => player.state.playing);
      expect(
        (player.position - realPause).inMilliseconds.abs(),
        lessThan(3000),
      );
      debugPrint('PLAYBACK_PROBE realPlayingBackground=passed');
    }

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _waitFor(() => !player.state.playing);
    final automaticPause = player.position;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _waitFor(() => player.state.playing);
    expect(
      (player.position - automaticPause).inMilliseconds.abs(),
      lessThan(3000),
    );

    await player.pause();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(player.state.playing, isFalse);
    debugPrint('PLAYBACK_PROBE lifecycle=passed');
    await closePage();

    // Reuse a valid URL to measure native resource release without repeatedly
    // hitting YouTube's extractor. Each cycle creates a real page and decoder.
    useCachedStream = true;
    final rss = <int>[];
    for (var cycle = 0; cycle < 8; cycle++) {
      final current = await openPage();
      await Future<void>.delayed(const Duration(seconds: 2));
      await current.pause();
      await closePage();
      rss.add(ProcessInfo.currentRss);
      debugPrint(
        'PLAYBACK_PROBE cycle=${cycle + 1} rssMiB=${(rss.last / 1048576).toStringAsFixed(1)}',
      );
    }
    debugPrint(
      'PLAYBACK_PROBE completed rssMiB=${rss.map((v) => (v / 1048576).toStringAsFixed(1)).join(',')}',
    );
  }, timeout: const Timeout(Duration(minutes: 12)));
}

Future<void> _waitFor(bool Function() predicate) async {
  final timer = Stopwatch()..start();
  while (!predicate()) {
    if (timer.elapsed > const Duration(seconds: 55)) {
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
