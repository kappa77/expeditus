import 'package:flutter/services.dart';

import '../util/platform.dart';

/// Keeps the Android process alive while a video download is running.
///
/// The actual download still runs in Dart. On Android a foreground service with
/// a low-priority notification is enough to stop the OS from killing the
/// process when the user switches apps. On desktop this is a no-op.
abstract final class DownloadKeepAlive {
  static const MethodChannel _channel = MethodChannel('expeditus/downloads');
  static int _active = 0;

  static Future<void> begin() async {
    if (!isAndroid) return;
    _active++;
    if (_active != 1) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      // The download must not fail just because the service could not start.
    }
  }

  static Future<void> end() async {
    if (!isAndroid) return;
    if (_active == 0) return;
    _active--;
    if (_active != 0) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Ignore: the service is best-effort.
    }
  }
}
