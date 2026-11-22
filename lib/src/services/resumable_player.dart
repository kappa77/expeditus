import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'stream_playback_policy.dart';
import 'stream_resolver.dart';

/// State exposed to the player page while a remote stream is being renewed.
enum StreamRecoveryPhase { idle, reconnecting, failed }

@immutable
class StreamRecoveryStatus {
  const StreamRecoveryStatus._(
    this.phase, {
    this.attempt = 0,
    this.maxAttempts = 0,
    this.error,
  });

  const StreamRecoveryStatus.idle() : this._(StreamRecoveryPhase.idle);

  const StreamRecoveryStatus.reconnecting({
    required int attempt,
    required int maxAttempts,
  }) : this._(
         StreamRecoveryPhase.reconnecting,
         attempt: attempt,
         maxAttempts: maxAttempts,
       );

  const StreamRecoveryStatus.failed(Object error)
    : this._(StreamRecoveryPhase.failed, error: error);

  final StreamRecoveryPhase phase;
  final int attempt;
  final int maxAttempts;
  final Object? error;

  bool get isReconnecting => phase == StreamRecoveryPhase.reconnecting;

  @override
  bool operator ==(Object other) =>
      other is StreamRecoveryStatus &&
      other.phase == phase &&
      other.attempt == attempt &&
      other.maxAttempts == maxAttempts &&
      other.error == error;

  @override
  int get hashCode => Object.hash(phase, attempt, maxAttempts, error);
}

/// Keeps a pause point independently of the native decoder's clock, renews
/// remote media before resuming a long pause, and supervises the stream while
/// it is playing.
///
/// A remote stream can stop without an exception: the signed URL can expire,
/// the CDN can close the connection, the network can change, or the device can
/// sleep. The watchdog detects that the playback position has not advanced,
/// resolves a fresh URL and reopens the media at the same position.
class ResumablePlayer extends Player {
  ResumablePlayer({
    super.configuration,
    super.platformPlayer,
    required this.refreshMedia,
    required this.onRefreshError,
    required this.canPlay,
    required this.canRefresh,
    DateTime Function()? clock,
    Future<void> Function(Duration duration)? sleep,
    this.refreshAfter = const Duration(minutes: 2),
    this.stallAfter = const Duration(seconds: 20),
    this.startupGrace = const Duration(seconds: 30),
    this.seekGrace = const Duration(seconds: 20),
    this.recoveryGrace = const Duration(seconds: 15),
    this.recoveryAttempts = 3,
    this.recoveryDelays = const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
    ],
    this.decoderRecoveryDelay = const Duration(seconds: 2),
    this.playbackPolicy,
  }) : _clock = clock ?? DateTime.now,
       _sleep = sleep ?? _delayed {
    _lastAdvanceAt = _clock();
    _positionSubscription = stream.position.listen(_onPosition);
    _durationSubscription = stream.duration.listen(_onDuration);
    _logSubscription = stream.log.listen(_onLog);
    if (stallAfter != null) {
      _healthTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkHealth(),
      );
    }
  }

  static Future<void> _delayed(Duration duration) =>
      Future<void>.delayed(duration);

  final Future<Media> Function(Duration position, int attempt) refreshMedia;
  final void Function(Object error) onRefreshError;
  final bool Function() canPlay;
  final bool Function() canRefresh;
  final StreamPlaybackPolicy? playbackPolicy;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _sleep;
  final Duration refreshAfter;
  final Duration? stallAfter;
  final Duration startupGrace;
  final Duration seekGrace;
  final Duration recoveryGrace;
  final int recoveryAttempts;
  final List<Duration> recoveryDelays;
  final Duration decoderRecoveryDelay;

  /// UI-facing recovery state. Idle while normal playback is running.
  final ValueNotifier<StreamRecoveryStatus> recovery = ValueNotifier(
    const StreamRecoveryStatus.idle(),
  );

  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<PlayerLog> _logSubscription;
  Timer? _healthTimer;
  Timer? _decoderRecoveryTimer;

  Media? _media;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _pendingPosition;
  DateTime? _pendingSince;
  DateTime? _pausedAt;
  Future<void>? _playRequest;
  Future<void>? _recoveryFuture;
  int _playGeneration = -1;
  int _generation = 0;
  bool _disposed = false;
  bool _opening = false;
  bool _stopped = false;
  bool _policyApplied = false;
  bool _recovering = false;
  double _rate = 1;
  late DateTime _lastAdvanceAt;
  Duration _lastAdvancePosition = Duration.zero;
  Duration _recoveryProgressFloor = Duration.zero;
  DateTime? _graceUntil;
  DateTime? _lastErrorAt;
  String? _lastErrorText;
  DateTime? _lastRecoveryAt;
  DateTime? _mediaOpenedAt;
  DateTime? _lastDecoderRecoveryAt;
  Object? _lastRecoveryError;
  int _recoveriesSinceProgress = 0;
  int _decoderRecoveries = 0;

  Duration get position => _position;
  bool get isOpening => _opening;
  bool get isRecovering => _recovering;

  /// Whether the user expects the media to be playing, independently of a
  /// temporary buffering state or a native pause caused by an error.
  bool get isPlaybackIntended =>
      !_disposed &&
      !_stopped &&
      _media != null &&
      !state.completed &&
      (_pausedAt == null || _opening);

  Future<void> _applyExternalAudio(Playable playable) async {
    final media = playable is Media ? playable : null;
    final url = media?.extras?[externalAudioUrlExtra];
    if (url is! String || url.isEmpty) return;
    final language = media?.extras?[externalAudioLanguageExtra];
    await setAudioTrack(
      AudioTrack.uri(
        url,
        title: 'Original',
        language: language is String ? language : null,
      ),
    );
  }

  Future<void> _ensurePolicy() async {
    if (_policyApplied) return;
    _policyApplied = true;
    final policy = playbackPolicy;
    if (policy == null) return;
    final platform = this.platform;
    if (platform is! NativePlayer) return;
    await policy.apply((name, value) => platform.setProperty(name, value));
  }

  void _onDuration(Duration value) {
    if (_disposed || value <= Duration.zero) return;
    _duration = value;
  }

  void _onPosition(Duration value) {
    if (_disposed || _opening || _stopped || _pausedAt != null) return;
    final target = _pendingPosition;
    if (target != null) {
      final now = _clock();
      final since = _pendingSince ?? now;
      final resetToZero =
          value <= const Duration(seconds: 1) &&
          target > const Duration(seconds: 2);
      final behind = value < target - const Duration(seconds: 2);
      // Ignore a reset to zero for as long as the open/seek is settling.
      // A keyframe can land slightly behind the requested target; accept it
      // after a short timeout instead of freezing the clock forever.
      if (resetToZero) return;
      if (behind && now.difference(since) < const Duration(seconds: 10)) {
        return;
      }
      _pendingPosition = null;
      _pendingSince = null;
    } else if (value == Duration.zero && _position > Duration.zero) {
      // A decoder reset is not an explicit seek to the beginning.
      return;
    }
    if (value == _position) return;
    _position = value;
    _recordProgress(value);
  }

  void _recordProgress(Duration value) {
    final now = _clock();
    if ((value - _lastAdvancePosition).abs() <
        const Duration(milliseconds: 250)) {
      return;
    }
    _lastAdvancePosition = value;
    _lastAdvanceAt = now;
    if (_recoveriesSinceProgress > 0 && value >= _recoveryProgressFloor) {
      _recoveriesSinceProgress = 0;
    }
    final errorAt = _lastErrorAt;
    if (errorAt != null &&
        now.difference(errorAt) >= const Duration(seconds: 30)) {
      _lastErrorAt = null;
      _lastErrorText = null;
    }
  }

  void _onLog(PlayerLog log) {
    if (_disposed || (log.level != 'error' && log.level != 'fatal')) {
      return;
    }
    // libmpv may fail to create its optional on-disk cache while the media
    // continues to play normally. It is not a stream failure.
    if (log.prefix == 'lavf' && log.text.toLowerCase().contains('file cache')) {
      return;
    }
    final now = _clock();
    _lastErrorAt = now;
    _lastErrorText = '${log.prefix}: ${log.text}';
    if (_opening || _pausedAt != null || !isPlaybackIntended) return;
    if (!canRefresh()) return;
    if (log.prefix != 'vd' && log.prefix != 'ad') return;
    // Ignore teardown errors from the media that was just replaced.
    final openedAt = _mediaOpenedAt;
    if (openedAt != null &&
        now.difference(openedAt) < const Duration(seconds: 2)) {
      return;
    }
    // A video or audio decoder error can freeze the picture while the other
    // track keeps advancing. Reopen the media at the current position instead
    // of leaving a frozen frame behind the controls. Keep this bounded even
    // when the audio clock keeps advancing.
    final last = _lastDecoderRecoveryAt;
    if (last == null || now.difference(last) > const Duration(minutes: 2)) {
      _decoderRecoveries = 0;
    }
    if (_decoderRecoveries >= _attempts) {
      _failRecovery(StateError(_lastErrorText ?? 'Errore del decoder video.'));
      return;
    }
    _scheduleDecoderRecovery();
  }

  void _scheduleDecoderRecovery() {
    if (_decoderRecoveryTimer != null || _recovering) return;
    _decoderRecoveryTimer = Timer(decoderRecoveryDelay, () {
      _decoderRecoveryTimer = null;
      if (_disposed || _opening || _pausedAt != null || !isPlaybackIntended) {
        return;
      }
      _decoderRecoveries++;
      _lastDecoderRecoveryAt = _clock();
      unawaited(_recover());
    });
  }

  bool get _isAtEnd {
    final total = _duration;
    if (total <= Duration.zero) return true;
    final current = state.position > _position ? state.position : _position;
    return current >= total - const Duration(seconds: 3);
  }

  void _checkHealth() {
    if (_disposed ||
        stallAfter == null ||
        _opening ||
        _recovering ||
        _stopped) {
      return;
    }
    if (_media == null || _pausedAt != null || !canPlay()) return;
    final now = _clock();
    if (state.completed) {
      if (_isAtEnd) return;
      unawaited(_recover());
      return;
    }
    final grace = _graceUntil;
    if (grace != null) {
      if (now.isBefore(grace)) {
        final errorAt = _lastErrorAt;
        // A startup error that persists should not wait for the full grace.
        // Never reopen media that is already advancing: an HLS segment can
        // fail and be retried successfully after a non-fatal error.
        if (errorAt != null &&
            now.difference(errorAt) >= const Duration(seconds: 10) &&
            now.difference(_lastAdvanceAt) >= const Duration(seconds: 10)) {
          _graceUntil = null;
          unawaited(_recover());
        }
        return;
      }
      _graceUntil = null;
      _lastAdvanceAt = now;
      _lastAdvancePosition = _position;
      return;
    }
    final gap = now.difference(_lastAdvanceAt);
    // A very long gap usually means the process was suspended, not that the
    // stream stalled. Give playback a normal grace period after wake-up.
    if (gap > const Duration(minutes: 2)) {
      _lastAdvanceAt = now;
      _lastAdvancePosition = _position;
      return;
    }
    final errorAt = _lastErrorAt;
    final limit =
        errorAt != null && now.difference(errorAt) < const Duration(seconds: 30)
        ? const Duration(seconds: 10)
        : stallAfter!;
    if (gap >= limit) {
      unawaited(_recover());
    }
  }

  Future<void> _recover() async {
    if (_disposed ||
        _recovering ||
        _opening ||
        _pausedAt != null ||
        !canRefresh() ||
        (!isPlaybackIntended && !(state.completed && !_isAtEnd))) {
      return;
    }
    final now = _clock();
    final last = _lastRecoveryAt;
    if (last == null || now.difference(last) > const Duration(minutes: 2)) {
      _recoveriesSinceProgress = 0;
    }
    _lastRecoveryAt = now;
    if (_recoveriesSinceProgress >= _attempts) {
      _failRecovery(
        _lastRecoveryError ??
            StateError(_lastErrorText ?? 'La riproduzione non è ripartita.'),
      );
      return;
    }
    _recoveriesSinceProgress++;

    final generation = _generation;
    final target = state.position > _position ? state.position : _position;
    _recovering = true;
    _opening = true;
    _decoderRecoveryTimer?.cancel();
    _decoderRecoveryTimer = null;
    _setRecovery(
      StreamRecoveryStatus.reconnecting(attempt: 1, maxAttempts: _attempts),
    );
    try {
      await super.pause();
    } on Object {
      // The player may already be closing.
    }
    if (!_isCurrent(generation)) {
      _recovering = false;
      if (generation == _generation) _opening = false;
      return;
    }

    final future = _reloadAt(target, generation);
    _recoveryFuture = future;
    try {
      await future;
    } finally {
      if (identical(_recoveryFuture, future)) _recoveryFuture = null;
      _recovering = false;
    }
  }

  int get _attempts => recoveryAttempts < 1 ? 1 : recoveryAttempts;

  Future<bool> _reloadAt(Duration target, int generation) async {
    final attempts = _attempts;
    Object? lastError;
    _opening = true;
    try {
      for (var attempt = 1; attempt <= attempts; attempt++) {
        if (!_isCurrent(generation) || !canPlay()) return false;
        _setRecovery(
          StreamRecoveryStatus.reconnecting(
            attempt: attempt,
            maxAttempts: attempts,
          ),
        );
        Object? attemptError;
        try {
          final media = await refreshMedia(target, attempt);
          if (!_isCurrent(generation) || !canPlay()) return false;
          _media = media;
          _pendingPosition = target;
          _pendingSince = _clock();
          await super.open(media, play: false);
          if (!_isCurrent(generation)) return false;
          await _applyExternalAudio(media);
          if (!_isCurrent(generation)) return false;
          _mediaOpenedAt = _clock();
          await super.setRate(_rate);
          if (!_isCurrent(generation)) return false;
          _position = target;
          _pausedAt = null;
          _lastAdvancePosition = target;
          _recoveryProgressFloor = target + const Duration(seconds: 5);
          _lastAdvanceAt = _clock();
          _graceUntil = _clock().add(recoveryGrace);
          _lastErrorAt = null;
          _lastErrorText = null;
          _lastRecoveryError = null;
          if (!_isCurrent(generation) || !canPlay()) {
            _pausedAt ??= _clock();
            return false;
          }
          await super.play();
          if (!_isCurrent(generation)) return false;
          _setRecovery(const StreamRecoveryStatus.idle());
          return true;
        } catch (error) {
          attemptError = error;
        }
        if (!_isCurrent(generation)) return false;
        lastError = attemptError;
        _lastRecoveryError = attemptError;
        if (attempt < attempts) {
          _setRecovery(
            StreamRecoveryStatus.reconnecting(
              attempt: attempt + 1,
              maxAttempts: attempts,
            ),
          );
          await _sleep(_recoveryDelay(attempt));
          if (!_isCurrent(generation) || !canPlay()) return false;
        }
      }
      if (_isCurrent(generation)) {
        _failRecovery(
          lastError ?? StateError('La riproduzione non è ripartita.'),
        );
      }
      return false;
    } finally {
      if (generation == _generation) _opening = false;
    }
  }

  Duration _recoveryDelay(int attempt) {
    if (recoveryDelays.isEmpty) return Duration.zero;
    final index = attempt - 1;
    return recoveryDelays[index < recoveryDelays.length
        ? index
        : recoveryDelays.length - 1];
  }

  void _failRecovery(Object error) {
    if (_disposed) return;
    _recovering = false;
    _opening = false;
    _pausedAt ??= _clock();
    _lastRecoveryError = error;
    _setRecovery(StreamRecoveryStatus.failed(error));
    onRefreshError(error);
  }

  void _setRecovery(StreamRecoveryStatus status) {
    if (_disposed) return;
    recovery.value = status;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

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
    // A recent stream error makes the current URL suspect even when it has not
    // technically expired yet.
    if (_lastErrorAt != null) return true;
    // Progressive URLs use a query parameter; HLS URLs also use /expire/N/.
    var expiry = int.tryParse(uri.queryParameters['expire'] ?? '');
    final parts = uri.pathSegments;
    final index = parts.indexOf('expire');
    if (expiry == null && index >= 0 && index + 1 < parts.length) {
      expiry = int.tryParse(parts[index + 1]);
    }
    return expiry != null &&
        now.add(const Duration(minutes: 2)).millisecondsSinceEpoch >=
            expiry * 1000;
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (_disposed) return;
    await _ensurePolicy();
    if (_disposed) return;
    final generation = ++_generation;
    _opening = true;
    _stopped = false;
    _recovering = false;
    _recoveryFuture = null;
    _decoderRecoveryTimer?.cancel();
    _decoderRecoveryTimer = null;
    _media = playable is Media ? playable : null;
    _position = _media?.start ?? Duration.zero;
    _pendingPosition = _position > Duration.zero ? _position : null;
    _pendingSince = _clock();
    _pausedAt = _clock();
    _lastAdvancePosition = _position;
    _lastAdvanceAt = _clock();
    _graceUntil = _clock().add(startupGrace);
    _lastErrorAt = null;
    _lastErrorText = null;
    _lastRecoveryError = null;
    _recoveriesSinceProgress = 0;
    _recoveryProgressFloor = Duration.zero;
    _decoderRecoveries = 0;
    _lastDecoderRecoveryAt = null;
    _setRecovery(const StreamRecoveryStatus.idle());
    try {
      await super.open(playable, play: false);
      if (_disposed || generation != _generation) return;
      await _applyExternalAudio(playable);
      if (_disposed || generation != _generation) return;
      _mediaOpenedAt = _clock();
      if (play && canPlay()) {
        _pausedAt = null;
        _graceUntil = _clock().add(startupGrace);
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
    final recovering = _recoveryFuture;
    if (recovering != null) {
      return recovering.then((_) async {
        if (_disposed || !canPlay() || state.playing) return;
        if (recovery.value.phase == StreamRecoveryPhase.failed) return;
        if (_pausedAt != null) await play();
      });
    }
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
        await _reloadAt(target, generation);
        return;
      }
      if (_pausedAt != null &&
          (state.position - target).inMilliseconds.abs() > 500) {
        _pendingPosition = target;
        _pendingSince = _clock();
        await super.seek(target);
      }
      if (!_isCurrent(generation) || !canPlay()) return;
      _position = target;
      _pausedAt = null;
      _lastAdvancePosition = target;
      _lastAdvanceAt = _clock();
      _graceUntil = _clock().add(
        startupGrace < const Duration(seconds: 5)
            ? startupGrace
            : const Duration(seconds: 5),
      );
      if (!_isCurrent(generation) || !canPlay()) {
        _pausedAt ??= _clock();
        return;
      }
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
    _decoderRecoveryTimer?.cancel();
    _decoderRecoveryTimer = null;
    _recoveryFuture = null;
    _setRecovery(const StreamRecoveryStatus.idle());
    return super.pause();
  }

  @override
  Future<void> seek(Duration duration) async {
    ++_generation;
    _opening = false;
    _decoderRecoveryTimer?.cancel();
    _decoderRecoveryTimer = null;
    _recoveryFuture = null;
    _position = duration;
    _pendingPosition = duration;
    _pendingSince = _clock();
    _lastAdvancePosition = duration;
    _lastAdvanceAt = _clock();
    _recoveriesSinceProgress = 0;
    _recoveryProgressFloor = duration;
    _graceUntil = _clock().add(seekGrace);
    _setRecovery(const StreamRecoveryStatus.idle());
    await super.seek(duration);
  }

  @override
  Future<void> setRate(double rate) {
    _rate = rate;
    return super.setRate(rate);
  }

  @override
  Future<void> stop() {
    ++_generation;
    _opening = false;
    _stopped = true;
    _pausedAt ??= _clock();
    _decoderRecoveryTimer?.cancel();
    _decoderRecoveryTimer = null;
    _recoveryFuture = null;
    _setRecovery(const StreamRecoveryStatus.idle());
    return super.stop();
  }

  /// Resets the stall anchor after the application returns to the foreground.
  /// Without this, a long device sleep would look like a stalled stream.
  void notifyAppResumed() {
    if (_disposed) return;
    _lastAdvanceAt = _clock();
    _lastAdvancePosition = _position;
    _recoveriesSinceProgress = 0;
    _recoveryProgressFloor = _position;
    _graceUntil = _clock().add(const Duration(seconds: 3));
  }

  @visibleForTesting
  void debugCheckHealth() => _checkHealth();

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    _healthTimer?.cancel();
    _decoderRecoveryTimer?.cancel();
    await Future.wait([
      _positionSubscription.cancel(),
      _durationSubscription.cancel(),
      _logSubscription.cancel(),
    ]);
    await super.dispose();
    recovery.dispose();
  }
}
