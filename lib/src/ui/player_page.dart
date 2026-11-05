import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/stream_resolver.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/seek_accumulator.dart';

const _playbackRates = <double>[
  0.25,
  0.50,
  0.75,
  1.00,
  1.25,
  1.50,
  1.75,
  2.00,
  2.25,
  2.50,
  2.75,
  3.00,
  3.25,
  3.50,
];

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.video,
    required this.state,
    this.resolver,
  });

  final VideoItem video;
  final AppState state;

  /// Injection point for tests. Defaults to the real YouTube extractor.
  final Future<ResolvedStream> Function(String videoId)? resolver;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<SponsorSegment> _segments = const [];
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _ready = false;
  String? _error;
  String? _quality;
  int? _lastSkippedEndMs;
  bool _watchedSent = false;
  bool _speedMenuOpen = false;
  late double _rate;
  late final SeekAccumulator _seekAccumulator;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _player = Player();
    _rate = widget.state.playbackRate;
    _seekAccumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 300),
      onSeek: (target) {
        if (!mounted) return;
        setState(() {});
        unawaited(_player.seek(target));
      },
    );

    _subscriptions.add(_player.stream.position.listen(_onPosition));
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        _duration = value;
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) _markWatched();
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((message) {
        if (mounted) setState(() => _error = message);
      }),
    );

    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      Uri? mediaUri;
      String? quality;

      final localPath = widget.video.localPath;
      if (localPath != null) {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          mediaUri = Uri.file(localFile.path);
          quality = 'Offline';
        }
      }

      if (mediaUri == null) {
        final resolve = widget.resolver ?? StreamResolver.resolve;
        final stream = await resolve(widget.video.id);
        mediaUri = stream.url;
        quality = stream.quality;
      }

      if (!mounted) return;
      _quality = quality;
      final controller = VideoController(_player);
      _controller = controller;
      await _player.open(Media(mediaUri.toString()), play: true);
      if (!mounted) return;
      await _player.setRate(_rate);
      setState(() => _ready = true);
      await widget.state.markSeen(widget.video);
      await _loadSponsorSegments();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    }
  }

  Future<void> _loadSponsorSegments() async {
    if (!widget.state.sponsorBlockEnabled) return;
    try {
      final segments = await widget.state.sponsorBlock.fetch(
        widget.video.id,
        widget.state.sponsorCategories,
      );
      if (!mounted) return;
      setState(() => _segments = segments);
    } catch (_) {
      // SponsorBlock is optional: a failure must never block playback.
    }
  }

  void _onPosition(Duration position) {
    if (!mounted) return;
    _position = position;

    final duration = _duration;
    if (duration != null &&
        duration.inMilliseconds > 0 &&
        position.inMilliseconds > duration.inMilliseconds * 0.9) {
      _markWatched();
    }

    for (final segment in _segments) {
      if (position.inMilliseconds >= segment.start.inMilliseconds &&
          position.inMilliseconds < segment.end.inMilliseconds) {
        if (_lastSkippedEndMs != segment.end.inMilliseconds) {
          _lastSkippedEndMs = segment.end.inMilliseconds;
          _player.seek(segment.end);
          _toast('Sponsor saltato');
        }
        break;
      }
    }
  }

  void _markWatched() {
    if (_watchedSent) return;
    _watchedSent = true;
    unawaited(widget.state.markWatched(widget.video));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _ready = false;
      _lastSkippedEndMs = null;
    });
    await _player.stop();
    await _open();
  }

  Future<void> _openExternal() async {
    await launchUrl(
      Uri.parse(widget.video.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _seekAccumulator.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted || !_ready || _speedMenuOpen) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekBy(-10);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(10);
      return true;
    }
    return false;
  }

  void _seekBy(int seconds) {
    if (!_ready) return;
    _seekAccumulator.add(
      Duration(seconds: seconds),
      base: _player.state.position,
      max: _duration,
    );
    setState(() {});
  }

  void _setRate(double value) {
    final rate = value.clamp(0.25, 3.5).toDouble();
    setState(() => _rate = rate);
    if (_ready) unawaited(_player.setRate(rate));
    unawaited(widget.state.setPlaybackRate(rate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('player-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: ExpeditusColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<double>(
            key: const Key('speed-button'),
            tooltip: 'Velocità di riproduzione',
            initialValue: _rate,
            onOpened: () => _speedMenuOpen = true,
            onCanceled: () => _speedMenuOpen = false,
            onSelected: (rate) {
              _speedMenuOpen = false;
              _setRate(rate);
            },
            constraints: const BoxConstraints(maxHeight: 360),
            itemBuilder: (context) => [
              for (final rate in _playbackRates)
                PopupMenuItem<double>(
                  value: rate,
                  child: Text('${rate.toStringAsFixed(2)}×'),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed_rounded, size: 17),
                  const SizedBox(width: 4),
                  Text(
                    '${_rate.toStringAsFixed(2)}×',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: widget.video.isWatched ? 'Segna da vedere' : 'Segna visto',
            onPressed: () => widget.state.toggleWatched(widget.video),
            icon: Icon(
              widget.video.isWatched
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              color: widget.video.isWatched
                  ? ExpeditusColors.green
                  : ExpeditusColors.muted,
            ),
          ),
          IconButton(
            tooltip: widget.video.queued ? 'Togli dalla coda' : 'In coda',
            onPressed: () => widget.state.toggleQueued(widget.video),
            icon: Icon(
              widget.video.queued
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: widget.video.queued
                  ? ExpeditusColors.accent
                  : ExpeditusColors.muted,
            ),
          ),
          IconButton(
            tooltip: 'Apri su YouTube (O)',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? _PlayerError(
                    message: _error!,
                    onRetry: _retry,
                    onOpenExternal: _openExternal,
                  )
                : !_ready
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 14),
                        Text(
                          'Risoluzione dello stream…',
                          style: TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _controller == null
                ? const SizedBox.shrink()
                : Video(
                    controller: _controller!,
                    controls: MaterialVideoControls,
                    fit: BoxFit.contain,
                  ),
          ),
          _PlayerFooter(
            video: widget.video,
            quality: _quality,
            position: _seekAccumulator.pending ?? _position,
            duration: _duration,
            sponsorSegments: _segments.length,
            sponsorEnabled: widget.state.sponsorBlockEnabled,
            onOpenExternal: _openExternal,
            onToggleWatched: () => widget.state.toggleWatched(widget.video),
            onToggleQueued: () => widget.state.toggleQueued(widget.video),
            onSeekBack: () => _seekBy(-10),
            onSeekForward: () => _seekBy(10),
          ),
        ],
      ),
    );
  }

  static String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('Sign in') || text.contains('bot')) {
      return 'YouTube ha chiesto una verifica. Apri il video su YouTube per guardarlo.';
    }
    return text;
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({
    required this.message,
    required this.onRetry,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: ExpeditusColors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Stream non disponibile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Riprova'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Apri su YouTube'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerFooter extends StatelessWidget {
  const _PlayerFooter({
    required this.video,
    required this.quality,
    required this.position,
    required this.duration,
    required this.sponsorSegments,
    required this.sponsorEnabled,
    required this.onOpenExternal,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onSeekBack,
    required this.onSeekForward,
  });

  final VideoItem video;
  final String? quality;
  final Duration position;
  final Duration? duration;
  final int sponsorSegments;
  final bool sponsorEnabled;
  final VoidCallback onOpenExternal;
  final VoidCallback onToggleWatched;
  final VoidCallback onToggleQueued;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;

  @override
  Widget build(BuildContext context) {
    final description = video.description.trim();
    final progress = duration != null && duration!.inMilliseconds > 0
        ? (position.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      color: ExpeditusColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  video.channelTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExpeditusColors.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              if (quality != null)
                Text(
                  'Stream diretto · $quality',
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // One proportional column per element keeps the time text from
              // moving the rest of the row when its length changes.
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: ExpeditusColors.border,
                    color: ExpeditusColors.accent,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatDuration(position.inSeconds)} / '
                      '${duration == null ? '--:--' : formatDuration(duration!.inSeconds)}',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 10.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  key: const Key('seek-back-button'),
                  tooltip: 'Indietro 10 s (←)',
                  onPressed: onSeekBack,
                  icon: const Icon(Icons.replay_10_rounded, size: 20),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  key: const Key('seek-forward-button'),
                  tooltip: 'Avanti 10 s (→)',
                  onPressed: onSeekForward,
                  icon: const Icon(Icons.forward_10_rounded, size: 20),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: sponsorEnabled
                      ? Text(
                          sponsorSegments > 0
                              ? 'SponsorBlock · $sponsorSegments segmenti'
                              : 'SponsorBlock attivo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sponsorSegments > 0
                                ? ExpeditusColors.green
                                : ExpeditusColors.muted,
                            fontSize: 10.5,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  tooltip: video.isWatched ? 'Segna da vedere' : 'Segna visto',
                  onPressed: onToggleWatched,
                  icon: Icon(
                    video.isWatched
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: video.isWatched
                        ? ExpeditusColors.green
                        : ExpeditusColors.muted,
                    size: 18,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  tooltip: video.queued ? 'Togli dalla coda' : 'In coda',
                  onPressed: onToggleQueued,
                  icon: Icon(
                    video.queued
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: video.queued
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                    size: 18,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  tooltip: 'Apri su YouTube',
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
