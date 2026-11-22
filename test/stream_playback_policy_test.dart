import 'package:expeditus/src/services/stream_playback_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android prebuffer e cache sono espliciti e prudenti', () {
    final properties = const StreamPlaybackPolicy(android: true).properties;
    expect(properties['cache-pause-initial'], 'yes');
    expect(properties['cache-pause-wait'], '4');
    expect(properties['cache-on-disk'], 'no');
    expect(properties['cache-secs'], '45');
    expect(properties['demuxer-max-bytes'], '24MiB');
    expect(properties['demuxer-max-back-bytes'], '8MiB');
    expect(properties['network-timeout'], '10');
    expect(properties['stream-lavf-o'], contains('reconnect_streamed=1'));
  });

  test('desktop usa una cache più ampia', () {
    final properties = const StreamPlaybackPolicy(android: false).properties;
    expect(properties['cache-secs'], '90');
    expect(properties['demuxer-max-bytes'], '64MiB');
    expect(properties['demuxer-max-back-bytes'], '16MiB');
  });

  test('una proprietà sconosciuta non blocca le altre', () async {
    final properties = const StreamPlaybackPolicy(android: true).properties;
    final applied = <String>[];
    await const StreamPlaybackPolicy(android: true).apply((name, value) async {
      applied.add(name);
      if (name == 'cache') throw StateError('unsupported');
    });
    expect(applied, properties.keys.toList());
  });
}
