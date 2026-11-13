import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// Keeps a pause point independently of the native decoder's clock and renews
/// remote media before resuming a long pause. The standard video controls call
/// these overrides too, including in fullscreen.
class ResumablePlayer extends Player {
  ResumablePlayer({
    super.configuration,
    super.platformPlayer,
    required this.refreshMedia,
    required this.onRefreshError,
    required this.canPlay,
    required this.canRefresh,
    DateTime Function()? clock,
    this.refreshAfter = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now {
    _positionSubscription = stream.position.listen(_onPosition);
  }

  final Future<Media> Function(Duration position) refreshMedia;
  final void Function(Object error) onRefreshError;
  final bool Function() canPlay;
  final bool Function() canRefresh;
  final DateTime Function() _clock;
  final Duration refreshAfter;
  late final StreamSubscription<Duration> _positionSubscription;
  Media? _media;
  Duration _position = Duration.zero;
  Duration? _pendingPosition;
  DateTime? _pausedAt;
  Future<void>? _playRequest;
  int _playGeneration = -1;
  int _generation = 0;
  bool _disposed = false;
  bool _opening = false;
  bool _stopped = false;

  Duration get position => _position;
  bool get isOpening => _opening;

  void _onPosition(Duration value) {
    if (_disposed || _opening || _stopped || _pausedAt != null) return;
    final target = _pendingPosition;
    if (target != null) {
      // On a busy device the first position notification can arrive several
      // seconds after the seek. Accept forward progress without accepting the
      // reset-to-zero events emitted while the native media is being replaced.
      if (value < target - const Duration(seconds: 1) ||
          value > target + const Duration(seconds: 10)) {
        return;
      }
      _pendingPosition = null;
    } else if (value == Duration.zero && _position > Duration.zero) {
      // A decoder reset is not an explicit seek to the beginning.
      return;
    }
    _position = value;
  }

  bool get _needsRefresh {
    final media = _media;
    if (media == null || !canRefresh()) return false;
    final uri = Uri.parse(media.uri);
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final now = _clock();
    final pausedAt = _pausedAt;
    if (pausedAt != null && now.difference(pausedAt) >= refreshAfter) {
      return true;
    }
    // Progressive URLs use a query parameter; HLS URLs also use /expire/N/.
    var expiry = int.tryParse(uri.queryParameters['expire'] ?? '');
    final parts = uri.pathSegments;
    final index = parts.indexOf('expire');
    if (expiry == null && index >= 0 && index + 1 < parts.length) {
      expiry = int.tryParse(parts[index + 1]);
    }
    return expiry != null &&
        now.add(const Duration(seconds: 30)).millisecondsSinceEpoch >=
            expiry * 1000;
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _opening = true;
    _stopped = false;
    _media = playable is Media ? playable : null;
    _position = _media?.start ?? Duration.zero;
    _pendingPosition = _position > Duration.zero ? _position : null;
    _pausedAt = _clock();
    try {
      await super.open(playable, play: false);
      if (_disposed || generation != _generation) return;
      if (play && canPlay()) {
        _pausedAt = null;
        await super.play();
      }
    } finally {
      if (generation == _generation) _opening = false;
    }
  }

  @override
  Future<void> playOrPause() => state.playing ? pause() : play();

  @override
  Future<void> play() {
    if (_disposed || !canPlay()) return Future.value();
    final pending = _playRequest;
    if (pending != null) {
      return _playGeneration == _generation
          ? pending
          : pending.then((_) => play());
    }
    _playGeneration = _generation;
    return _playRequest = _resume(_generation).whenComplete(() {
      _playRequest = null;
    });
  }

  Future<void> _resume(int generation) async {
    final target = state.completed ? Duration.zero : _position;
    try {
      if (_needsRefresh) {
        _opening = true;
        await super.pause();
        if (_disposed || generation != _generation) return;
        final media = await refreshMedia(target);
        if (_disposed || generation != _generation) return;
        _media = media;
        _pendingPosition = target;
        await super.open(media, play: false);
      } else if (_pausedAt != null &&
          (state.position - target).inMilliseconds.abs() > 500) {
        _pendingPosition = target;
        await super.seek(target);
      }
      if (_disposed || generation != _generation || !canPlay()) return;
      _position = target;
      _pausedAt = null;
      _opening = false;
      await super.play();
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _pausedAt ??= _clock();
        onRefreshError(error);
      }
    } finally {
      if (generation == _generation) _opening = false;
    }
  }

  @override
  Future<void> pause() {
    ++_generation;
    _opening = false;
    _pausedAt ??= _clock();
    return super.pause();
  }

  @override
  Future<void> seek(Duration duration) async {
    ++_generation;
    _opening = false;
    _position = duration;
    _pendingPosition = duration;
    await super.seek(duration);
  }

  @override
  Future<void> stop() {
    ++_generation;
    _opening = false;
    _stopped = true;
    _pausedAt ??= _clock();
    return super.stop();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    await _positionSubscription.cancel();
    await super.dispose();
  }
}
