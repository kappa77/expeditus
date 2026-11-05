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
}

class StreamResolver {
  static Future<ResolvedStream> resolve(String videoId) async {
    final youtube = YoutubeExplode();
    try {
      final manifest = await youtube.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidSdkless,
        ],
      );

      final hlsMuxed =
          manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
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
        return ResolvedStream(
          url: stream.url,
          quality: 'solo audio',
          kind: 'audio',
        );
      }

      throw Exception('Nessuno stream riproducibile per questo video.');
    } finally {
      youtube.close();
    }
  }
}
