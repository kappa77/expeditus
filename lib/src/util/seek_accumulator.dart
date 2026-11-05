import 'dart:async';

/// Accumulates rapid seek requests and emits a single seek after [debounce].
///
/// This is what makes three quick "+10 s" presses become one "+30 s" seek
/// instead of three seeks computed from the same stale position.
class SeekAccumulator {
  SeekAccumulator({
    required this.debounce,
    required this.onSeek,
  });

  final Duration debounce;
  final void Function(Duration target) onSeek;

  Duration? _target;
  Timer? _timer;

  Duration? get pending => _target;

  void add(Duration delta, {required Duration base, Duration? max}) {
    var next = (_target ?? base) + delta;
    if (next < Duration.zero) next = Duration.zero;
    if (max != null && max > Duration.zero && next > max) next = max;
    _target = next;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final target = _target;
    _target = null;
    if (target != null) onSeek(target);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _target = null;
  }

  void dispose() => cancel();
}
