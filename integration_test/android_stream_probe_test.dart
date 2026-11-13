import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Compare extractor clients on the device without logging signed URLs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: extractor latency by client', (tester) async {
    var successes = 0;
    for (final (name, client, watchPage) in [
      ('ios-fast', YoutubeApiClient.ios, false),
      ('ios-full', YoutubeApiClient.ios, true),
      ('android-fast', YoutubeApiClient.androidSdkless, false),
      ('android-full', YoutubeApiClient.androidSdkless, true),
    ]) {
      final youtube = YoutubeExplode();
      final timer = Stopwatch()..start();
      try {
        final manifest = await youtube.videos.streamsClient
            .getManifest(
              'aqz-KE-bpKQ',
              ytClients: [client],
              requireWatchPage: watchPage,
            )
            .timeout(const Duration(seconds: 10));
        successes++;
        debugPrint(
          'STREAM_CLIENT_PROBE client=$name ms=${timer.elapsedMilliseconds} hls=${manifest.hls.length} muxed=${manifest.muxed.length} video=${manifest.video.length}',
        );
      } catch (error) {
        debugPrint(
          'STREAM_CLIENT_PROBE client=$name ms=${timer.elapsedMilliseconds} error=${error.runtimeType}',
        );
      } finally {
        youtube.close();
      }
    }
    expect(successes, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
