import 'package:flutter/services.dart';

/// Holds the Android `WifiManager.MulticastLock` while DLNA discovery runs.
///
/// Android filters out multicast (and some broadcast) traffic for battery
/// saving. SSDP `M-SEARCH` responses are usually unicast, but holding the
/// lock is required for a reliable discovery on many devices.
abstract class MulticastLock {
  Future<void> acquire();

  Future<void> release();
}

class AndroidMulticastLock implements MulticastLock {
  static const _channel = MethodChannel('com.kappa77.expeditus/multicast');

  @override
  Future<void> acquire() async {
    try {
      await _channel.invokeMethod<void>('acquire');
    } on Object {
      // Best effort: unicast responses may still arrive.
    }
  }

  @override
  Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } on Object {
      // Best effort.
    }
  }
}

class NoopMulticastLock implements MulticastLock {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}
