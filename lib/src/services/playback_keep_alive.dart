import 'package:flutter/services.dart';

import '../util/platform.dart';

/// Keeps the Android process alive while a video is playing in the background.
///
/// Playback itself is performed by libmpv in the Flutter process. On Android a
/// foreground service with a low-priority notification stops the OS from
/// killing that process when the user switches apps. Desktop playback needs no
/// service, so the methods are no-ops there.
///
/// Each player page owns a token. Multiple pages (for example during a quick
/// back-and-forth) keep the service alive until the last one releases it.
abstract final class PlaybackKeepAlive {
  static const MethodChannel _channel = MethodChannel('expeditus/playback');
  static final Set<Object> _tokens = {};

  /// Starts (or refreshes) the foreground service with the current title.
  static Future<void> begin(Object token, String title) async {
    if (!isAndroid || !_tokens.add(token)) return;
    try {
      await _channel.invokeMethod<void>('start', {'title': title});
    } catch (_) {
      // Background playback is best-effort: the player keeps running even if
      // Android refuses to start the service (for example an OEM restriction).
    }
  }

  /// Releases [token]; the service stops when no page needs it anymore.
  static Future<void> end(Object token) async {
    if (!isAndroid || !_tokens.remove(token)) return;
    if (_tokens.isNotEmpty) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Ignore: the service is best-effort.
    }
  }
}
