import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

abstract class VideoDownloader {
  Future<String> download(
    String videoId, {
    void Function(double progress)? onProgress,
  });

  Future<void> delete(String filePath);

  void close();
}

/// Saves the best muxed stream to the application support directory.
///
/// Muxed streams are the simplest option that yields a single playable file
/// without bundling ffmpeg. YouTube usually limits them to 360p; HLS/adaptive
/// muxing would require an external tool.
class VideoDownloadService implements VideoDownloader {
  VideoDownloadService({
    YoutubeExplode? youtube,
    this.directoryProvider,
  }) : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  final Future<Directory> Function()? directoryProvider;
  bool _closed = false;

  @override
  Future<String> download(
    String videoId, {
    void Function(double progress)? onProgress,
  }) async {
    if (_closed) throw StateError('Download service is closed');

    final manifest = await _youtube.videos.streamsClient.getManifest(
      videoId,
      ytClients: [
        YoutubeApiClient.ios,
        YoutubeApiClient.androidSdkless,
      ],
    );

    if (manifest.muxed.isEmpty) {
      throw Exception('No muxed stream available for offline download.');
    }

    final stream = manifest.muxed.withHighestBitrate();
    final directory = await _downloadDirectory();
    final file = File(p.join(directory.path, '$videoId.mp4'));
    final total = stream.size.totalBytes;
    var received = 0;
    var lastBucket = -1;
    final sink = file.openWrite();

    try {
      await for (final chunk in _youtube.videos.streamsClient.get(stream)) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = (received / total).clamp(0.0, 1.0);
          final bucket = (progress * 100).floor();
          if (bucket != lastBucket) {
            lastBucket = bucket;
            onProgress?.call(progress);
          }
        }
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();
    return file.path;
  }

  Future<Directory> _downloadDirectory() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : Directory(
            p.join((await getApplicationSupportDirectory()).path, 'downloads'),
          );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<void> delete(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _youtube.close();
  }
}
