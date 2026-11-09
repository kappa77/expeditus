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

class StreamResolver {
  static Future<ResolvedStream> resolve(String videoId) async {
    final youtube = YoutubeExplode();
    try {
      final manifest = await youtube.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidSdkless],
      );

      final hlsMuxed = manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
      if (hlsMuxed.isNotEmpty) {
        final stream = hlsMuxed.withHighestBitrate();
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
    } finally {
      youtube.close();
    }
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
