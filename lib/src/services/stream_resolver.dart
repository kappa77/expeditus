import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Extras keys used by the player to attach a separate audio stream to a
/// video-only rendition.
const externalAudioUrlExtra = 'expeditus.externalAudioUrl';
const externalAudioLanguageExtra = 'expeditus.externalAudioLanguage';

class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.quality,
    required this.kind,
    this.audioUrl,
    this.audioLanguage,
  });

  final Uri url;
  final String quality;
  final String kind;

  /// Separate audio URL for a video-only rendition. YouTube sometimes offers
  /// no muxed/HLS stream for a video, but still exposes video-only and
  /// audio-only tracks separately.
  final Uri? audioUrl;
  final String? audioLanguage;

  String get mimeType => mimeTypeForStreamKind(kind);
}

YoutubeApiClient localizeYoutubeClient(
  YoutubeApiClient client,
  String? languageCode,
) {
  final code = languageCode?.trim().toLowerCase();
  if (code == null || code.isEmpty || code == 'en') return client;
  final payload =
      jsonDecode(jsonEncode(client.payload)) as Map<String, dynamic>;
  final context = payload['context'] as Map<String, dynamic>;
  final node = context['client'] as Map<String, dynamic>;
  node['hl'] = code;
  node['gl'] = switch (code) {
    'it' => 'IT',
    'de' => 'DE',
    'es' => 'ES',
    'fr' => 'FR',
    'pt' => 'PT',
    'ja' => 'JP',
    'ko' => 'KR',
    _ => 'US',
  };
  return YoutubeApiClient(payload, client.apiUrl, headers: client.headers);
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
    this.languageCode,
    this.requestTimeout = const Duration(seconds: 12),
    this.hlsPreferenceWindow = const Duration(milliseconds: 750),
  }) : _requestFactory = requestFactory ?? _YoutubeManifestRequest.new,
       _android = android ?? Platform.isAndroid;

  final StreamManifestRequest Function() _requestFactory;
  final bool _android;

  /// Preferred YouTube language/region. It makes YouTube mark the original
  /// audio track as default instead of the English auto-dub.
  final String? languageCode;

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

  Future<ResolvedStream> resolveVideo(
    String videoId, {
    int? maxHeight,
    bool preferMuxed = false,
  }) async {
    maxHeight ??= _android ? 720 : null;
    if (_closed) throw StateError('Stream resolver closed');
    if (_android && !preferMuxed) {
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
          preferMuxed: preferMuxed,
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
    bool preferMuxed = false,
    Set<StreamManifestRequest>? pending,
  }) async {
    if (_closed) throw StateError('Stream resolver closed');
    final request = _requestFactory();
    final localizedClient = localizeYoutubeClient(client, languageCode);
    final result = Completer<StreamManifest>();
    _active[request] = result;
    pending?.add(request);
    try {
      request
          .load(videoId, localizedClient, requireWatchPage: requireWatchPage)
          .then(
            (manifest) {
              if (!result.isCompleted) result.complete(manifest);
            },
            onError: (Object error, StackTrace stack) {
              if (!result.isCompleted) result.completeError(error, stack);
            },
          );
      final manifest = await result.future.timeout(requestTimeout);
      return selectStream(
        manifest,
        maxHeight: maxHeight,
        preferMuxed: preferMuxed,
        preferredLanguage: languageCode,
      );
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
    bool preferMuxed = false,
    String? preferredLanguage,
  }) {
    if (preferMuxed && manifest.muxed.isNotEmpty) {
      final stream = manifest.muxed.withHighestBitrate();
      return ResolvedStream(
        url: stream.url,
        quality: '${stream.qualityLabel} · muxed',
        kind: 'muxed',
      );
    }

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

    final fallback = _selectSplitStream(
      manifest,
      maxHeight: maxHeight,
      preferredLanguage: preferredLanguage,
    );
    if (fallback != null) return fallback;

    if (manifest.audioOnly.isNotEmpty) {
      final stream = _selectAudio(
        manifest.audioOnly,
        preferredLanguage: preferredLanguage,
      );
      return ResolvedStream(url: stream.url, quality: 'audio', kind: 'audio');
    }

    throw Exception('No playable stream for this video.');
  }

  static ResolvedStream? _selectSplitStream(
    StreamManifest manifest, {
    required int? maxHeight,
    required String? preferredLanguage,
  }) {
    if (manifest.videoOnly.isEmpty || manifest.audioOnly.isEmpty) return null;

    final video = _selectVideo(manifest.videoOnly, maxHeight: maxHeight);
    final audio = _selectAudio(
      manifest.audioOnly,
      preferredLanguage: preferredLanguage,
    );
    final language = audio.audioTrack?.id.split('.').first;
    return ResolvedStream(
      url: video.url,
      quality: '${video.qualityLabel} · video+audio',
      kind: 'video',
      audioUrl: audio.url,
      audioLanguage: language,
    );
  }

  static VideoOnlyStreamInfo _selectVideo(
    List<VideoOnlyStreamInfo> streams, {
    required int? maxHeight,
  }) {
    final eligible = maxHeight == null
        ? streams.toList()
        : streams
              .where((stream) => stream.videoResolution.height <= maxHeight)
              .toList();
    final fits = eligible.isNotEmpty;
    final candidates = fits ? eligible : streams.toList();
    candidates.sort((a, b) {
      final resolution = b.videoResolution.height.compareTo(
        a.videoResolution.height,
      );
      if (resolution != 0) return fits ? resolution : -resolution;
      final codec = _videoCodecRank(b).compareTo(_videoCodecRank(a));
      if (codec != 0) return codec;
      return b.bitrate.compareTo(a.bitrate);
    });
    return candidates.first;
  }

  static int _videoCodecRank(VideoOnlyStreamInfo stream) {
    final codec = stream.videoCodec.toLowerCase();
    if (codec.startsWith('avc1') || codec.contains('h264')) return 3;
    if (codec.startsWith('vp9') || codec.contains('vp09')) return 2;
    if (codec.startsWith('av01')) return 1;
    return 0;
  }

  static AudioOnlyStreamInfo _selectAudio(
    List<AudioOnlyStreamInfo> streams, {
    required String? preferredLanguage,
  }) {
    final preferred = preferredLanguage?.toLowerCase();
    int score(AudioOnlyStreamInfo stream) {
      final track = stream.audioTrack;
      final name = (track?.displayName ?? '').toLowerCase();
      final id = (track?.id ?? '').toLowerCase();
      var value = 0;
      if (name.contains('original')) value += 100;
      if (track?.audioIsDefault == true) value += 50;
      if (preferred != null &&
          preferred.isNotEmpty &&
          (id == preferred ||
              id.startsWith('$preferred.') ||
              id.startsWith('$preferred-'))) {
        value += 40;
      }
      if (stream.audioCodec.startsWith('mp4a')) value += 10;
      return value;
    }

    final sorted = streams.toList()
      ..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        return b.bitrate.compareTo(a.bitrate);
      });
    return sorted.first;
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
