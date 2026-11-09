import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/dlna/dlna_metadata.dart';
import '../services/dlna/dlna_models.dart';
import '../services/dlna/dlna_transport.dart';
import '../services/dlna/media_server.dart';
import '../services/dlna/network_profile.dart';
import '../services/dlna/ssdp_discovery.dart';
import '../services/dlna/windows_firewall.dart';
import '../services/stream_resolver.dart';

enum CastConnectionState { disconnected, connecting, connected }

enum CastPlaybackState { idle, starting, playing, paused, stopped, error }

enum CastFailureKind {
  connect,
  send,
  discovery,
  action,
  firewallDenied,
  networkProfile,
  unresponsive,
  noStream,
}

/// A cast failure that the UI can localize without knowing about the
/// controller or the transport implementation.
class CastFailure {
  const CastFailure(this.kind, {this.deviceName, this.details});

  final CastFailureKind kind;
  final String? deviceName;
  final String? details;
}

typedef CastTransportFactory = DlnaTransport Function(DlnaDevice device);
typedef CastStreamResolver = Future<ResolvedStream> Function(String videoId);

/// Owns the DLNA session: discovery, the connected renderer, media publishing
/// and best-effort transport polling.
///
/// The controller is intentionally independent of the player: the player asks
/// it to cast a video, mirrors local play/pause events, and reports its
/// position for drift correction.
class CastController extends ChangeNotifier {
  CastController({
    DlnaDiscovery? discovery,
    CastTransportFactory? transportFactory,
    CastMediaServer? mediaServer,
    CastStreamResolver? resolver,
    FirewallService? firewall,
    NetworkProfileService? networkProfile,
    this.discoveryTimeout = const Duration(seconds: 4),
  }) : discovery = discovery ?? SsdpDlnaDiscovery(),
       _transportFactory =
           transportFactory ?? ((device) => DlnaSoapTransport(device)),
       server = mediaServer ?? MediaServer(),
       _resolver = resolver ?? StreamResolver.resolveForCasting,
       firewall = firewall ?? WindowsFirewallService(),
       networkProfile = networkProfile ?? WindowsNetworkProfileService();

  final DlnaDiscovery discovery;
  final CastTransportFactory _transportFactory;
  final CastMediaServer server;
  final CastStreamResolver _resolver;
  final FirewallService firewall;
  final NetworkProfileService networkProfile;
  final Duration discoveryTimeout;

  List<DlnaDevice> devices = const [];
  bool discovering = false;
  bool hasDiscovered = false;
  CastFailure? discoveryError;

  CastConnectionState connection = CastConnectionState.disconnected;
  DlnaDevice? device;
  DlnaTransport? _transport;

  CastPlaybackState playback = CastPlaybackState.idle;
  CastFailure? error;
  VideoItem? currentVideo;

  /// True when the renderer did not reach the local media server and Windows
  /// Firewall likely needs an inbound rule for this executable.
  bool firewallRequired = false;
  bool firewallBusy = false;
  Uri? _currentMediaUri;
  bool _firewallChecked = false;

  /// True when the active Windows network is "Public", so DLNA discovery is
  /// blocked. The user can switch it to "Private" from the cast dialog.
  bool networkProfileRequired = false;
  bool networkProfileBusy = false;
  bool _networkProfileChecked = false;

  Timer? _pollTimer;
  int _pollFailures = 0;
  int _castGeneration = 0;
  DateTime? _lastSync;
  bool _syncInFlight = false;
  Future<void>? _pendingStop;
  bool _disposed = false;

  bool get isConnected =>
      connection == CastConnectionState.connected && device != null;

  bool get isConnecting => connection == CastConnectionState.connecting;

  bool get isCasting => isConnected && currentVideo != null;

  bool get remotePlaying => playback == CastPlaybackState.playing;

  String? get connectedDeviceName {
    final name = device?.displayName.trim();
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> discover({bool force = false}) async {
    if (_disposed || discovering) return;
    if (!force && devices.isNotEmpty) return;

    discovering = true;
    discoveryError = null;
    _networkProfileChecked = false;
    _notify();
    try {
      final found = await discovery.discover(timeout: discoveryTimeout);
      if (_disposed) return;
      devices = List.unmodifiable(found);
      hasDiscovered = true;
      if (found.isEmpty) {
        unawaited(_inspectNetworkProfile());
      } else {
        networkProfileRequired = false;
      }
    } on Object catch (exception) {
      if (_disposed) return;
      discoveryError = CastFailure(
        CastFailureKind.discovery,
        details: _describe(exception),
      );
    } finally {
      if (!_disposed) {
        discovering = false;
        _notify();
      }
    }
  }

  Future<bool> connect(DlnaDevice next) async {
    if (_disposed || connection == CastConnectionState.connecting) {
      return false;
    }
    if (isConnected && device?.udn == next.udn) return true;

    _castGeneration++;
    _stopPolling();
    await _closeTransport();
    if (_disposed) return false;

    device = next;
    connection = CastConnectionState.connecting;
    playback = CastPlaybackState.idle;
    currentVideo = null;
    _currentMediaUri = null;
    firewallRequired = false;
    _firewallChecked = false;
    error = null;
    _notify();

    DlnaTransport? transport;
    try {
      transport = _transportFactory(next);
      await transport.getTransportInfo();
      if (_disposed) {
        await transport.close();
        return false;
      }
      _transport = transport;
      connection = CastConnectionState.connected;
      _notify();
      return true;
    } on Object catch (exception) {
      try {
        await transport?.close();
      } on Object {
        // Ignore cleanup failures.
      }
      if (_disposed) return false;
      _transport = null;
      connection = CastConnectionState.disconnected;
      device = null;
      playback = CastPlaybackState.idle;
      error = CastFailure(
        CastFailureKind.connect,
        deviceName: next.displayName,
        details: _describe(exception),
      );
      _notify();
      return false;
    }
  }

  /// Sends a video to the connected renderer.
  ///
  /// Local downloads are served from disk. Remote videos are resolved again
  /// with a cast-friendly format; [fallbackUri] is used if that resolution
  /// fails, and it is proxied through the local media server either way.
  Future<bool> castVideo({
    required VideoItem video,
    Uri? fallbackUri,
    String? fallbackKind,
    String? localPath,
    Duration startAt = Duration.zero,
  }) async {
    final transport = _transport;
    if (_disposed || !isConnected || transport == null) return false;

    final generation = ++_castGeneration;
    _stopPolling();
    currentVideo = video;
    _currentMediaUri = null;
    _firewallChecked = false;
    firewallRequired = false;
    playback = CastPlaybackState.starting;
    error = null;
    _notify();

    try {
      await server.start();
      if (_disposed || generation != _castGeneration) return false;
      server.clearMedia();

      Uri mediaUri;
      String mimeType;
      final file = localPath == null ? null : File(localPath);
      if (file != null && await file.exists()) {
        mediaUri = await server.publishFile(file, contentType: 'video/mp4');
        mimeType = 'video/mp4';
      } else {
        ResolvedStream? resolved;
        try {
          resolved = await _resolver(video.id);
        } on Object {
          resolved = null;
        }
        if (resolved != null) {
          final playlist = resolved.kind == 'hls';
          mimeType = resolved.mimeType;
          mediaUri = await server.publishRemote(
            resolved.url,
            contentType: mimeType,
            playlist: playlist,
          );
        } else {
          if (fallbackUri == null) {
            throw const _NoCastStream();
          }
          final playlist =
              fallbackKind == 'hls' ||
              fallbackUri.path.toLowerCase().endsWith('.m3u8');
          mimeType = mimeTypeForStreamKind(
            playlist ? 'hls' : (fallbackKind ?? 'muxed'),
          );
          mediaUri = await server.publishRemote(
            fallbackUri,
            contentType: mimeType,
            playlist: playlist,
          );
        }
      }

      _currentMediaUri = mediaUri;
      final pendingStop = _pendingStop;
      if (pendingStop != null) {
        try {
          await pendingStop;
        } on Object {
          // The previous renderer may already be gone.
        }
      }
      if (_disposed || generation != _castGeneration) return false;

      final metadata = buildDidlLiteMetadata(
        title: video.title,
        resourceUrl: mediaUri,
        mimeType: mimeType,
        albumArtUrl: Uri.tryParse(video.thumbnailUrl),
        itemId: video.id,
      );

      try {
        await transport.stop();
      } on Object {
        // Renderers often reject Stop when nothing is loaded.
      }
      await transport.setAvTransportUri(uri: mediaUri, metadata: metadata);
      if (startAt > Duration.zero) {
        try {
          await transport.seek(startAt);
        } on Object {
          // Seeking is optional; playback can still start from the beginning.
        }
      }
      await transport.play();

      if (_disposed || generation != _castGeneration) return false;
      playback = CastPlaybackState.starting;
      _startPolling();
      _notify();
      unawaited(_probeUntilPlaying(generation));
      return true;
    } on _NoCastStream {
      if (_disposed || generation != _castGeneration) return false;
      playback = CastPlaybackState.error;
      error = const CastFailure(CastFailureKind.noStream);
      _stopPolling();
      _notify();
      return false;
    } on Object catch (exception) {
      if (_disposed || generation != _castGeneration) return false;
      playback = CastPlaybackState.error;
      error = CastFailure(
        CastFailureKind.send,
        deviceName: device?.displayName,
        details: _describe(exception),
      );
      _stopPolling();
      _notify();
      return false;
    }
  }

  Future<bool> play() async {
    final transport = _transport;
    if (_disposed || !isConnected || transport == null) return false;
    try {
      await transport.play();
      if (_disposed) return false;
      error = null;
      playback = CastPlaybackState.starting;
      _startPolling();
      _notify();
      unawaited(_probeUntilPlaying(_castGeneration));
      return true;
    } on Object catch (exception) {
      _failAction(exception);
      return false;
    }
  }

  Future<bool> pause() async {
    final transport = _transport;
    if (_disposed || !isConnected || transport == null) return false;
    try {
      await transport.pause();
      if (_disposed) return false;
      playback = CastPlaybackState.paused;
      _notify();
      return true;
    } on Object catch (exception) {
      _failAction(exception);
      return false;
    }
  }

  /// Mirrors the local player state to the renderer. Errors are surfaced on
  /// the next user action instead of interrupting the local video.
  Future<void> mirrorLocalPlaying(bool playing) async {
    if (!isCasting) return;
    if (playing) {
      if (playback == CastPlaybackState.playing ||
          playback == CastPlaybackState.starting) {
        return;
      }
      await play();
    } else {
      if (playback == CastPlaybackState.paused ||
          playback == CastPlaybackState.stopped ||
          playback == CastPlaybackState.error) {
        return;
      }
      await pause();
    }
  }

  /// Seeks the renderer immediately, for local seeking and SponsorBlock skips.
  Future<bool> seekTo(Duration position) async {
    final transport = _transport;
    if (_disposed || !isCasting || transport == null) return false;
    try {
      await transport.seek(position);
      _lastSync = DateTime.now();
      return true;
    } on Object {
      return false;
    }
  }

  /// Corrects remote drift against the local player's clock. Called often by
  /// the player; the work is throttled and never throws.
  Future<void> syncTo(Duration localPosition) async {
    if (_disposed ||
        !isCasting ||
        playback != CastPlaybackState.playing ||
        _syncInFlight) {
      return;
    }
    final now = DateTime.now();
    final last = _lastSync;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastSync = now;
    _syncInFlight = true;
    try {
      final transport = _transport;
      if (transport == null) return;
      final remote = await transport.getPosition();
      if (_disposed || !isCasting) return;
      final drift = (remote - localPosition).abs();
      if (drift > const Duration(seconds: 4)) {
        await transport.seek(localPosition);
      }
    } on Object {
      // Drift correction is best effort.
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> stopPlayback({String? expectedVideoId}) async {
    if (expectedVideoId != null && currentVideo?.id != expectedVideoId) {
      return;
    }
    _castGeneration++;
    _stopPolling();
    currentVideo = null;
    _currentMediaUri = null;
    firewallRequired = false;
    _firewallChecked = false;
    playback = CastPlaybackState.idle;
    error = null;
    _notify();
    final transport = _transport;
    if (transport != null) {
      final stopFuture = _stopTransport(transport);
      _pendingStop = stopFuture;
      try {
        await stopFuture;
      } finally {
        if (identical(_pendingStop, stopFuture)) _pendingStop = null;
      }
    }
    // Keep the connection itself: the next video will cast again.
  }

  Future<void> disconnect() async {
    _castGeneration++;
    _stopPolling();
    currentVideo = null;
    _currentMediaUri = null;
    firewallRequired = false;
    firewallBusy = false;
    _firewallChecked = false;
    networkProfileRequired = false;
    networkProfileBusy = false;
    _networkProfileChecked = false;
    playback = CastPlaybackState.idle;
    device = null;
    connection = CastConnectionState.disconnected;
    error = null;
    _notify();
    await _closeTransport();
    await server.close();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    if (playback == CastPlaybackState.error) {
      playback = CastPlaybackState.stopped;
    }
    _notify();
  }

  /// Adds the inbound firewall rule through UAC, or verifies an existing one.
  Future<bool> allowFirewall() async {
    if (_disposed || firewallBusy) return false;
    firewallBusy = true;
    error = null;
    _notify();
    var allowed = false;
    try {
      final current = await firewall.status();
      allowed =
          current == FirewallStatus.allowed || await firewall.allowExpeditus();
    } on Object {
      allowed = false;
    }
    if (_disposed) return allowed;
    firewallBusy = false;
    firewallRequired = !allowed;
    if (!allowed) {
      error = const CastFailure(CastFailureKind.firewallDenied);
    }
    _notify();
    return allowed;
  }

  /// Switches the Windows network from Public to Private through UAC, or
  /// verifies that it is already Private.
  Future<bool> allowPrivateNetwork() async {
    if (_disposed || networkProfileBusy) return false;
    networkProfileBusy = true;
    error = null;
    _notify();
    var fixed = false;
    try {
      final current = await networkProfile.status();
      fixed =
          current == NetworkProfileStatus.private ||
          await networkProfile.makePrivate();
    } on Object {
      fixed = false;
    }
    if (_disposed) return fixed;
    networkProfileBusy = false;
    networkProfileRequired = !fixed;
    if (!fixed) {
      error = const CastFailure(CastFailureKind.networkProfile);
    } else {
      _networkProfileChecked = false;
    }
    _notify();
    return fixed;
  }

  Future<void> _inspectNetworkProfile() async {
    if (_networkProfileChecked) return;
    _networkProfileChecked = true;
    final status = await networkProfile.status();
    if (_disposed) return;
    final required = status == NetworkProfileStatus.public;
    if (required != networkProfileRequired) {
      networkProfileRequired = required;
      _notify();
    }
  }

  void clearDiscoveryError() {
    if (discoveryError == null) return;
    discoveryError = null;
    _notify();
  }

  Future<void> _stopTransport(DlnaTransport transport) async {
    try {
      await transport.stop();
    } on Object {
      // The renderer may have already stopped or gone away.
    }
  }

  Future<void> _closeTransport() async {
    final pending = _pendingStop;
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // Ignore the previous stop failure.
      }
    }
    final transport = _transport;
    _transport = null;
    if (transport == null) return;
    try {
      await transport.stop();
    } on Object {
      // Nothing is loaded, or the renderer is already gone.
    }
    try {
      await transport.close();
    } on Object {
      // Closing is best effort.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollFailures = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_pollTransport());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollFailures = 0;
  }

  Future<void> _probeUntilPlaying(int generation) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 400 : 800),
      );
      if (_disposed ||
          generation != _castGeneration ||
          _transport == null ||
          currentVideo == null) {
        return;
      }
      final mediaUri = _currentMediaUri;
      final requested = mediaUri != null && server.wasRequested(mediaUri);
      if (requested) {
        if (firewallRequired) {
          firewallRequired = false;
          _notify();
        }
      } else if (attempt >= 3 && !_firewallChecked) {
        _firewallChecked = true;
        unawaited(_inspectFirewall(generation));
      }
      try {
        final state = await _transport!.getTransportInfo();
        if (_disposed || generation != _castGeneration) return;
        switch (state) {
          case DlnaTransportState.playing:
            if (playback != CastPlaybackState.playing) {
              playback = CastPlaybackState.playing;
              _notify();
            }
            return;
          case DlnaTransportState.paused:
            if (playback != CastPlaybackState.paused) {
              playback = CastPlaybackState.paused;
              _notify();
            }
            return;
          case DlnaTransportState.stopped:
          case DlnaTransportState.noMedia:
            // Some renderers ignore Play until the URI is fully loaded. Give
            // them a few attempts, then expose the poster with a play button.
            if (attempt >= 4 && playback == CastPlaybackState.starting) {
              playback = CastPlaybackState.stopped;
              _notify();
              return;
            }
          case DlnaTransportState.transitioning:
          case DlnaTransportState.unknown:
            break;
        }
      } on Object {
        // A probe can fail while the renderer is still loading.
      }
    }
    if (_disposed || generation != _castGeneration) return;
    if (playback == CastPlaybackState.starting) {
      playback = CastPlaybackState.stopped;
      _notify();
    }
  }

  Future<void> _inspectFirewall(int generation) async {
    final status = await firewall.status();
    if (_disposed || generation != _castGeneration) return;
    if (status == FirewallStatus.missing &&
        currentVideo != null &&
        !firewallRequired) {
      firewallRequired = true;
      if (playback == CastPlaybackState.starting) {
        playback = CastPlaybackState.stopped;
      }
      _notify();
    }
  }

  Future<void> _pollTransport() async {
    final transport = _transport;
    if (_disposed || !isCasting || transport == null) return;
    try {
      final state = await transport.getTransportInfo();
      if (_disposed || !isCasting) return;
      _pollFailures = 0;
      if (state == DlnaTransportState.playing && firewallRequired) {
        firewallRequired = false;
        _notify();
      }
      final next = switch (state) {
        DlnaTransportState.playing => CastPlaybackState.playing,
        DlnaTransportState.paused => CastPlaybackState.paused,
        DlnaTransportState.stopped ||
        DlnaTransportState.noMedia => CastPlaybackState.stopped,
        DlnaTransportState.transitioning || DlnaTransportState.unknown => null,
      };
      if (next != null && next != playback) {
        playback = next;
        _notify();
      }
    } on Object {
      _pollFailures++;
      if (_pollFailures >= 3 &&
          playback != CastPlaybackState.error &&
          !_disposed) {
        _stopPolling();
        playback = CastPlaybackState.error;
        error = const CastFailure(CastFailureKind.unresponsive);
        _notify();
      }
    }
  }

  void _failAction(Object exception) {
    if (_disposed) return;
    playback = CastPlaybackState.error;
    error = CastFailure(CastFailureKind.action, details: _describe(exception));
    _notify();
  }

  static String _describe(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 220 ? '${text.substring(0, 220)}…' : text;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _castGeneration++;
    _stopPolling();
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      unawaited(() async {
        try {
          await transport.stop();
        } on Object {
          // The renderer may already be gone.
        }
        try {
          await transport.close();
        } on Object {
          // Closing is best effort.
        }
      }());
    }
    discovery.close();
    unawaited(server.close());
    super.dispose();
  }
}

class _NoCastStream implements Exception {
  const _NoCastStream();
}
