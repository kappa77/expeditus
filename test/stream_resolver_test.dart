import 'dart:async';

import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

HlsMuxedStreamInfo _hls(int height, {int? bitrate}) =>
    HlsMuxedStreamInfo.fromJson(_videoJson(height, bitrate: bitrate));

MuxedStreamInfo _muxed(int height) => MuxedStreamInfo.fromJson({
  ..._videoJson(height),
  'container': {'name': 'mp4'},
});

Map<String, dynamic> _videoJson(int height, {int? bitrate}) => {
  'videoId': {'value': 'dQw4w9WgXcQ'},
  'tag': height,
  'url': 'https://example.com/$height.m3u8',
  'container': {'name': 'm3u8'},
  'size': {'totalBytes': 1000},
  'bitrate': {'bitsPerSecond': bitrate ?? height * 1000},
  'audioCodec': 'mp4a',
  'videoCodec': 'avc1',
  'qualityLabel': '${height}p',
  'videoQuality': 'unknown',
  'videoResolution': {'width': height * 16 ~/ 9, 'height': height},
  'framerate': {'framesPerSecond': 30},
  'codec': 'video/mp4',
};

class _Request implements StreamManifestRequest {
  _Request(this.result);

  final Future<StreamManifest> Function() result;
  int closes = 0;
  YoutubeApiClient? client;
  bool? watchPage;

  @override
  Future<StreamManifest> load(
    String videoId,
    YoutubeApiClient client, {
    required bool requireWatchPage,
  }) {
    this.client = client;
    watchPage = requireWatchPage;
    return result();
  }

  @override
  void close() => closes++;
}

void main() {
  test('Android non aspetta il client iOS bloccato e lo chiude', () async {
    final stalled = Completer<StreamManifest>();
    final ios = _Request(() => stalled.future);
    final android = _Request(() async => StreamManifest([_muxed(360)]));
    final requests = [ios, android];
    var index = 0;
    final resolver = StreamResolver(
      android: true,
      hlsPreferenceWindow: const Duration(milliseconds: 10),
      requestFactory: () => requests[index++],
    );
    addTearDown(resolver.close);
    final stream = await resolver.resolveVideo('dQw4w9WgXcQ');
    expect(stream.quality, '360p · muxed');
    expect(index, 2);
    expect(ios.closes, 1);
    expect(android.closes, 1);
    expect(android.watchPage, isFalse);
    stalled.completeError(StateError('canceled'));
    await Future<void>.delayed(Duration.zero);
  });

  test('Android preferisce HLS se arriva entro la finestra breve', () async {
    final ios = _Request(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return StreamManifest([_hls(720)]);
    });
    final android = _Request(() async => StreamManifest([_muxed(360)]));
    final requests = [ios, android];
    var index = 0;
    final resolver = StreamResolver(
      android: true,
      hlsPreferenceWindow: const Duration(seconds: 1),
      requestFactory: () => requests[index++],
    );
    addTearDown(resolver.close);
    expect((await resolver.resolveVideo('dQw4w9WgXcQ')).quality, '720p · HLS');
    expect(requests.every((r) => r.closes == 1), isTrue);
  });

  test(
    'Android usa il risultato valido anche se il primo client fallisce',
    () async {
      final requests = [
        _Request(() async => throw StateError('ios failed')),
        _Request(() async => StreamManifest([_muxed(360)])),
      ];
      var index = 0;
      final resolver = StreamResolver(
        android: true,
        requestFactory: () => requests[index++],
      );
      addTearDown(resolver.close);
      expect((await resolver.resolveVideo('dQw4w9WgXcQ')).kind, 'muxed');
      expect(index, 2);
    },
  );

  test('Android ripiega sulla pagina completa solo dopo entrambi i percorsi rapidi', () async {
    final requests = [
      _Request(() async => throw StateError('ios failed')),
      _Request(() async => throw StateError('android failed')),
      _Request(() async => StreamManifest([_hls(720)])),
    ];
    var index = 0;
    final resolver = StreamResolver(
      android: true,
      requestFactory: () => requests[index++],
    );
    addTearDown(resolver.close);
    expect((await resolver.resolveVideo('dQw4w9WgXcQ')).kind, 'hls');
    expect(index, 3);
    expect(requests.last.watchPage, isTrue);
    expect(requests.every((r) => r.closes == 1), isTrue);
  });

  test('chiudere il resolver Android cancella entrambi i tentativi', () async {
    final pending = [Completer<StreamManifest>(), Completer<StreamManifest>()];
    final requests = pending.map((p) => _Request(() => p.future)).toList();
    var index = 0;
    final resolver = StreamResolver(
      android: true,
      requestFactory: () => requests[index++],
    );
    final resolving = resolver.resolveVideo('dQw4w9WgXcQ');
    final assertion = expectLater(resolving, throwsStateError);
    resolver.close();
    await assertion;
    expect(index, 2);
    expect(requests.every((r) => r.closes == 1), isTrue);
    for (final result in pending) {
      result.completeError(StateError('canceled'));
    }
    await Future<void>.delayed(Duration.zero);
  });

  test('il primo stream valido evita tutte le estrazioni successive', () async {
    final requests = <_Request>[];
    final resolver = StreamResolver(
      requestFactory: () {
        final request = _Request(() async => StreamManifest([_hls(720)]));
        requests.add(request);
        return request;
      },
    );
    addTearDown(resolver.close);

    final stream = await resolver.resolveVideo('dQw4w9WgXcQ');
    expect(stream.quality, '720p · HLS');
    expect(requests, hasLength(1));
    expect(requests.single.client, same(YoutubeApiClient.ios));
    expect(requests.single.watchPage, isFalse);
    expect(requests.single.closes, 1);
  });

  test('se il percorso veloce fallisce usa la pagina completa', () async {
    final fast = _Request(() async => throw StateError('fast unavailable'));
    final fallback = _Request(() async => StreamManifest([_hls(720)]));
    final requests = [fast, fallback];
    var index = 0;
    final resolver = StreamResolver(requestFactory: () => requests[index++]);
    addTearDown(resolver.close);

    expect((await resolver.resolveVideo('dQw4w9WgXcQ')).kind, 'hls');
    expect(index, 2);
    expect(fallback.watchPage, isTrue);
    expect(fast.closes, 1);
    expect(fallback.closes, 1);
  });

  test('un manifest vuoto passa al client Android dopo iOS', () async {
    final requests = <_Request>[];
    final resolver = StreamResolver(
      requestFactory: () {
        final count = requests.length;
        final request = _Request(
          () async => StreamManifest(count == 2 ? [_hls(480)] : []),
        );
        requests.add(request);
        return request;
      },
    );
    addTearDown(resolver.close);
    expect((await resolver.resolveVideo('dQw4w9WgXcQ')).quality, '480p · HLS');
    expect(requests, hasLength(3));
    expect(requests.last.client, same(YoutubeApiClient.androidSdkless));
    expect(requests.every((r) => r.closes == 1), isTrue);
  });

  test('il timeout chiude il client prima di provare il successivo', () async {
    final stalled = Completer<StreamManifest>();
    final slow = _Request(() => stalled.future);
    final fallback = _Request(() async => StreamManifest([_hls(720)]));
    var count = 0;
    final resolver = StreamResolver(
      requestTimeout: const Duration(milliseconds: 10),
      requestFactory: () {
        if (count++ == 0) return slow;
        expect(slow.closes, 1);
        return fallback;
      },
    );
    addTearDown(resolver.close);
    expect((await resolver.resolveVideo('dQw4w9WgXcQ')).kind, 'hls');
    // A late failure from the canceled extraction must be consumed.
    stalled.completeError(StateError('request closed'));
    await Future<void>.delayed(Duration.zero);
    expect(count, 2);
    expect(slow.closes, 1);
  });

  test(
    'chiudere il player annulla subito la risoluzione senza fallback',
    () async {
      final pending = Completer<StreamManifest>();
      final request = _Request(() => pending.future);
      var count = 0;
      final resolver = StreamResolver(
        requestFactory: () {
          count++;
          return request;
        },
      );
      final resolving = resolver.resolveVideo('dQw4w9WgXcQ');
      final assertion = expectLater(resolving, throwsStateError);
      resolver.close();
      resolver.close();
      await assertion;
      expect(request.closes, 1);
      expect(count, 1);
      pending.completeError(StateError('closed'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'tutti gli errori rilasciano i client e il resolver resta riusabile',
    () async {
      final requests = <_Request>[];
      final resolver = StreamResolver(
        requestFactory: () {
          final request = _Request(() async => throw StateError('offline'));
          requests.add(request);
          return request;
        },
      );
      addTearDown(resolver.close);
      await expectLater(resolver.resolveVideo('dQw4w9WgXcQ'), throwsStateError);
      await expectLater(resolver.resolveVideo('dQw4w9WgXcQ'), throwsStateError);
      expect(requests, hasLength(6));
      expect(requests.every((r) => r.closes == 1), isTrue);
    },
  );

  test('su mobile sceglie HLS entro 720p mantenendo audio e video', () {
    final manifest = StreamManifest([_hls(360), _hls(1080), _hls(720)]);
    final stream = StreamResolver.selectStream(manifest, maxHeight: 720);
    expect(stream.quality, '720p · HLS');
    expect(stream.url.path, '/720.m3u8');
  });

  test('su desktop conserva la qualità più alta', () {
    final stream = StreamResolver.selectStream(
      StreamManifest([_hls(360), _hls(1080), _hls(720)]),
    );
    expect(stream.quality, '1080p · HLS');
  });

  test('la risoluzione conta prima del bitrate dichiarato', () {
    final stream = StreamResolver.selectStream(
      StreamManifest([_hls(360, bitrate: 5000000), _hls(720)]),
      maxHeight: 720,
    );
    expect(stream.quality, '720p · HLS');
  });

  test('360p rimane 360p anche se il tetto è 720p', () {
    final stream = StreamResolver.selectStream(
      StreamManifest([_hls(360)]),
      maxHeight: 720,
    );
    expect(stream.quality, '360p · HLS');
  });

  test('senza rendition sotto il tetto sceglie quella meno pesante', () {
    final stream = StreamResolver.selectStream(
      StreamManifest([_hls(2160), _hls(1080)]),
      maxHeight: 720,
    );
    expect(stream.quality, '1080p · HLS');
  });
}
