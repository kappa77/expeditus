import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.quality,
    required this.kind,
  });

  final Uri url;
  final String quality;
  final String kind;

  String get mimeType => mimeTypeForStreamKind(kind);
}

String mimeTypeForStreamKind(String kind) {
  switch (kind) {
    case 'hls':
      return 'application/vnd.apple.mpegurl';
    case 'audio':
      return 'audio/mp4';
    default:
      return 'video/mp4';
  }
}

/// One extraction attempt. Closing it aborts its HTTP requests, including the
/// extractor's internal retries, rather than only abandoning a timed-out Future.
abstract class StreamManifestRequest {
  Future<StreamManifest> load(
    String videoId,
    YoutubeApiClient client, {
    required bool requireWatchPage,
  });

  void close();
}

class _YoutubeManifestRequest implements StreamManifestRequest {
  final _youtube = YoutubeExplode();

  @override
  Future<StreamManifest> load(
    String videoId,
    YoutubeApiClient client, {
    required bool requireWatchPage,
  }) => _youtube.videos.streamsClient.getManifest(
    videoId,
    ytClients: [client],
    requireWatchPage: requireWatchPage,
  );

  @override
  void close() => _youtube.close();
}

class StreamResolver {
  StreamResolver({
    StreamManifestRequest Function()? requestFactory,
    bool? android,
    this.requestTimeout = const Duration(seconds: 12),
    this.hlsPreferenceWindow = const Duration(milliseconds: 750),
  }) : _requestFactory = requestFactory ?? _YoutubeManifestRequest.new,
       _android = android ?? Platform.isAndroid;

  final StreamManifestRequest Function() _requestFactory;
  final bool _android;
  final Duration requestTimeout;
  final Duration hlsPreferenceWindow;
  final Map<StreamManifestRequest, Completer<StreamManifest>> _active = {};
  bool _closed = false;

  static Future<ResolvedStream> resolve(String videoId) async {
    final resolver = StreamResolver();
    try {
      return await resolver.resolveVideo(videoId);
    } finally {
      resolver.close();
    }
  }

  Future<ResolvedStream> resolveVideo(String videoId, {int? maxHeight}) async {
    maxHeight ??= _android ? 720 : null;
    if (_closed) throw StateError('Stream resolver closed');
    if (_android) {
      final fast = await _resolveAndroidFast(videoId, maxHeight: maxHeight);
      if (fast != null) return fast;
    }
    // getManifest with several clients waits for ALL of them. Return as soon
    // as one client supplies usable media, and use the others only as fallback.
    final attempts = [
      if (!_android) (YoutubeApiClient.ios, false),
      (YoutubeApiClient.ios, true),
      (YoutubeApiClient.androidSdkless, true),
    ];
    Object? lastError;
    for (final (client, requireWatchPage) in attempts) {
      if (_closed) throw StateError('Stream resolver closed');
      try {
        return await _attempt(
          videoId,
          client,
          requireWatchPage: requireWatchPage,
          maxHeight: maxHeight,
        );
      } catch (error) {
        if (_closed) rethrow;
        lastError = error;
      }
    }
    throw lastError ?? Exception('No playable stream for this video.');
  }

  Future<ResolvedStream?> _resolveAndroidFast(
    String videoId, {
    int? maxHeight,
  }) async {
    final pending = <StreamManifestRequest>{};
    Future<ResolvedStream?> attempt(YoutubeApiClient client) async {
      try {
        return await _attempt(
          videoId,
          client,
          requireWatchPage: false,
          maxHeight: maxHeight,
          pending: pending,
        );
      } catch (_) {
        return null;
      }
    }

    final ios = attempt(YoutubeApiClient.ios);
    final android = attempt(YoutubeApiClient.androidSdkless);
    try {
      final first = await Future.any([ios, android]);
      if (_closed) throw StateError('Stream resolver closed');
      if (first == null || first.kind == 'audio') {
        final candidates = (await Future.wait([ios, android])).nonNulls
            .toList();
        if (_closed) throw StateError('Stream resolver closed');
        for (final kind in ['hls', 'muxed', 'audio']) {
          for (final stream in candidates) {
            if (stream.kind == kind) return stream;
          }
        }
        return null;
      }
      if (first.kind == 'hls') return first;
      // Android often returns MP4 quickly while iOS retries failing requests.
      // Give a nearby HLS result a short preference window, then cancel the
      // slower extraction instead of making a usable stream wait for it.
      final preferred = await ios.timeout(
        hlsPreferenceWindow,
        onTimeout: () => null,
      );
      if (_closed) throw StateError('Stream resolver closed');
      return preferred?.kind == 'hls' ? preferred : first;
    } finally {
      for (final request in pending.toList()) {
        final result = _active.remove(request);
        if (result == null) continue;
        if (!result.isCompleted) {
          result.completeError(StateError('Stream attempt cancelled'));
        }
        request.close();
      }
    }
  }

  Future<ResolvedStream> _attempt(
    String videoId,
    YoutubeApiClient client, {
    required bool requireWatchPage,
    int? maxHeight,
    Set<StreamManifestRequest>? pending,
  }) async {
    if (_closed) throw StateError('Stream resolver closed');
    final request = _requestFactory();
    final result = Completer<StreamManifest>();
    _active[request] = result;
    pending?.add(request);
    try {
      request
          .load(videoId, client, requireWatchPage: requireWatchPage)
          .then(
            (manifest) {
              if (!result.isCompleted) result.complete(manifest);
            },
            onError: (Object error, StackTrace stack) {
              if (!result.isCompleted) result.completeError(error, stack);
            },
          );
      final manifest = await result.future.timeout(requestTimeout);
      return selectStream(manifest, maxHeight: maxHeight);
    } finally {
      pending?.remove(request);
      if (_active.remove(request) != null) request.close();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final entry in _active.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(StateError('Stream resolver closed'));
      }
      entry.key.close();
    }
    _active.clear();
  }

  static ResolvedStream selectStream(
    StreamManifest manifest, {
    int? maxHeight,
  }) {
    final hlsMuxed = manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
    if (hlsMuxed.isNotEmpty) {
      final eligible = maxHeight == null
          ? hlsMuxed
          : hlsMuxed
                .where((s) => s.videoResolution.height <= maxHeight)
                .toList();
      eligible.sort((a, b) {
        final resolution = b.videoResolution.height.compareTo(
          a.videoResolution.height,
        );
        return resolution != 0 ? resolution : b.bitrate.compareTo(a.bitrate);
      });
      // If no rendition fits the mobile budget, use the smallest one.
      final stream = eligible.isNotEmpty
          ? eligible.first
          : (hlsMuxed..sort(
                  (a, b) => a.videoResolution.height.compareTo(
                    b.videoResolution.height,
                  ),
                ))
                .first;
      return ResolvedStream(
        url: stream.url,
        quality: '${stream.qualityLabel} · HLS',
        kind: 'hls',
      );
    }

    if (manifest.muxed.isNotEmpty) {
      final stream = manifest.muxed.withHighestBitrate();
      return ResolvedStream(
        url: stream.url,
        quality: '${stream.qualityLabel} · muxed',
        kind: 'muxed',
      );
    }

    if (manifest.audioOnly.isNotEmpty) {
      final stream = manifest.audioOnly.withHighestBitrate();
      return ResolvedStream(url: stream.url, quality: 'audio', kind: 'audio');
    }

    throw Exception('No playable stream for this video.');
  }

  /// Resolves a stream for a DLNA renderer.
  ///
  /// A progressive muxed MP4 is the safest format for a TV: many renderers do
  /// not support YouTube's HLS variant. HLS is kept as a fallback and is
  /// proxied through the app's local media server.
  static Future<ResolvedStream> resolveForCasting(String videoId) async {
    final youtube = YoutubeExplode();
    try {
      final manifest = await youtube.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidSdkless],
      );

      if (manifest.muxed.isNotEmpty) {
        final stream = manifest.muxed.withHighestBitrate();
        return ResolvedStream(
          url: stream.url,
          quality: '${stream.qualityLabel} · muxed',
          kind: 'muxed',
        );
      }

      final hlsMuxed = manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
      if (hlsMuxed.isNotEmpty) {
        final stream = hlsMuxed.withHighestBitrate();
        return ResolvedStream(
          url: stream.url,
          quality: '${stream.qualityLabel} · HLS',
          kind: 'hls',
        );
      }

      if (manifest.audioOnly.isNotEmpty) {
        final stream = manifest.audioOnly.withHighestBitrate();
        return ResolvedStream(url: stream.url, quality: 'audio', kind: 'audio');
      }

      throw Exception('No playable stream for this video.');
    } finally {
      youtube.close();
    }
  }
}
