/// Network playback tuning applied to the native mpv instance before the
/// first media is opened.
///
/// media_kit enables mpv caching, but its defaults start playback after about
/// one second of buffered data and keep the same byte limit for the forward
/// and backward demuxer caches. These values trade a slightly longer startup
/// for enough read-ahead to survive short network interruptions.
class StreamPlaybackPolicy {
  const StreamPlaybackPolicy({required this.android});

  final bool android;

  Map<String, String> get properties {
    final forwardCache = android ? '24MiB' : '64MiB';
    final backwardCache = android ? '8MiB' : '16MiB';
    final cacheSeconds = android ? '45' : '90';
    return {
      'cache': 'yes',
      // The bundled libmpv cannot always create its on-disk cache file and
      // logs "Failed to create file cache" on every open. The forward cache is
      // large enough in memory, and keeping it there avoids that false error.
      'cache-on-disk': 'no',
      'cache-pause': 'yes',
      // Wait for a few seconds of media before the first frame and after a
      // seek. mpv defaults to no initial pause and one second after underrun.
      'cache-pause-initial': 'yes',
      'cache-pause-wait': '4',
      'cache-secs': cacheSeconds,
      'demuxer-max-bytes': forwardCache,
      'demuxer-max-back-bytes': backwardCache,
      // media_kit sets five seconds; allow a slow mobile network a little
      // more room before declaring a read dead.
      'network-timeout': '10',
      // Best effort: FFmpeg protocol reconnects for transient TCP/TLS drops.
      // Expired signed URLs still need a fresh resolution and are handled by
      // ResumablePlayer's watchdog.
      'stream-lavf-o':
          'reconnect=1,reconnect_streamed=1,'
          'reconnect_on_network_error=1,reconnect_delay_max=5,'
          'reconnect_max_retries=10',
    };
  }

  Future<void> apply(
    Future<void> Function(String name, String value) setProperty,
  ) async {
    for (final entry in properties.entries) {
      try {
        await setProperty(entry.key, entry.value);
      } on Object {
        // An older libmpv may not know every option. Playback must still work.
      }
    }
  }
}
