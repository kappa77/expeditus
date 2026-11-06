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
import '../state/cast_controller.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/playback_rates.dart';
import '../util/seek_accumulator.dart';
import 'cast_dialog.dart';
import 'cast_waiting_cover.dart';
import 'video_outline_dialog.dart';

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
  List<VideoChapter> _chapters = const [];
  bool _chaptersLoaded = false;
  Uri? _mediaUri;
  String? _streamKind;
  String? _localPath;
  bool _castMuted = false;
  double _volumeBeforeCast = 100;
  String? _lastCastError;
  DateTime? _castStartedAt;
  bool _castInFlight = false;
  bool _resumeLocalWhenRemoteStarts = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _player = Player();
    _rate = _initialPlaybackRate();
    _seekAccumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 300),
      onSeek: (target) {
        if (!mounted) return;
        setState(() {});
        unawaited(_player.seek(target));
        final cast = widget.state.castController;
        if (cast.isCasting && _castMuted) {
          unawaited(cast.seekTo(target));
        }
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
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        final startedAt = _castStartedAt;
        // Ignore the event produced by the player opening right before the
        // first cast: the renderer is already starting on its own.
        if (startedAt != null &&
            DateTime.now().difference(startedAt) <
                const Duration(milliseconds: 1500)) {
          return;
        }
        final cast = widget.state.castController;
        if (cast.isCasting && _castMuted) {
          unawaited(cast.mirrorLocalPlaying(playing));
        }
      }),
    );
    widget.state.castController.addListener(_onCastChanged);

    unawaited(_open());
    unawaited(_loadChapters());
  }

  double _initialPlaybackRate() {
    for (final channel in widget.state.channels) {
      if (channel.id == widget.video.channelId) {
        return channel.defaultPlaybackRate ?? widget.state.playbackRate;
      }
    }
    return widget.state.playbackRate;
  }

  Future<void> _loadChapters() async {
    if (widget.video.chapters.isNotEmpty) {
      if (mounted) {
        setState(() {
          _chapters = widget.video.chapters;
          _chaptersLoaded = true;
        });
      }
      return;
    }
    final chapters = await widget.state.fetchVideoChapters(widget.video);
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _chaptersLoaded = true;
    });
  }

  Future<void> _showOutline() async {
    if (!_chaptersLoaded) await _loadChapters();
    if (!mounted) return;
    final target = await showDialog<Duration>(
      context: context,
      builder: (_) => VideoOutlineDialog(
        video: widget.video,
        chapters: _chapters,
        position: _player.state.position,
        state: widget.state,
      ),
    );
    if (target != null && _ready) {
      await _player.seek(target);
      final cast = widget.state.castController;
      if (cast.isCasting && _castMuted) {
        unawaited(cast.seekTo(target));
      }
    }
  }

  Future<void> _addBookmark() async {
    final note = await showBookmarkNoteDialog(context);
    if (note == null || note.isEmpty) return;
    await widget.state.addBookmark(
      widget.video.id,
      _player.state.position.inSeconds,
      note,
    );
    _toast('Segnalibro salvato');
  }

  Future<void> _open() async {
    try {
      Uri? mediaUri;
      String? quality;
      String? kind;
      String? localPathUsed;

      final localPath = widget.video.localPath;
      if (localPath != null) {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          mediaUri = Uri.file(localFile.path);
          quality = 'Offline';
          kind = 'file';
          localPathUsed = localFile.path;
        }
      }

      if (mediaUri == null) {
        final resolve = widget.resolver ?? StreamResolver.resolve;
        final stream = await resolve(widget.video.id);
        mediaUri = stream.url;
        quality = stream.quality;
        kind = stream.kind;
      }

      if (!mounted) return;
      _quality = quality;
      _mediaUri = mediaUri;
      _streamKind = kind;
      _localPath = localPathUsed;
      final controller = VideoController(_player);
      _controller = controller;
      await _player.open(Media(mediaUri.toString()), play: true);
      if (!mounted) return;
      await _player.setRate(_rate);
      setState(() => _ready = true);
      if (widget.state.castController.isConnected) {
        // Mute immediately, before the cast-friendly stream is resolved, so
        // the local audio never overlaps the renderer.
        if (!_castMuted) _volumeBeforeCast = _player.state.volume;
        await _player.setVolume(0);
        _castMuted = true;
        if (mounted) setState(() {});
      }
      await widget.state.markSeen(widget.video);
      if (widget.state.castController.isConnected) {
        await _startCasting();
      }
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
    final cast = widget.state.castController;
    if (cast.isCasting && _castMuted) {
      unawaited(cast.syncTo(position));
    }

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
          if (cast.isCasting && _castMuted) {
            unawaited(cast.seekTo(segment.end));
          }
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

  void _toast(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: action == null ? 2 : 5),
        action: action,
      ),
    );
  }

  void _onCastChanged() {
    if (!mounted) return;
    final cast = widget.state.castController;
    if (cast.remotePlaying && _castMuted && _resumeLocalWhenRemoteStarts) {
      _resumeLocalWhenRemoteStarts = false;
      if (!_player.state.playing) {
        unawaited(_player.play());
      }
    }
    final castError = cast.error;
    if (castError != null && castError != _lastCastError) {
      _lastCastError = castError;
      if (_castMuted) {
        // Keep local audio muted while the TV is connected. The user can
        // explicitly switch to local playback from the poster.
        _toast(
          castError,
          action: SnackBarAction(
            label: 'Riprova',
            onPressed: () => unawaited(_startCasting()),
          ),
        );
      }
    }
    if (!cast.isConnected && _castMuted) {
      unawaited(_restoreLocalAudio());
    }
    setState(() {});
  }

  Future<void> _openCastDialog() async {
    final cast = widget.state.castController;
    final justConnected = await showCastDialog(context, cast);
    if (!mounted) return;
    if (justConnected == true &&
        cast.isConnected &&
        _ready &&
        _mediaUri != null) {
      await _startCasting();
    } else if (!cast.isConnected && _castMuted) {
      await _restoreLocalAudio();
    }
    if (mounted) setState(() {});
  }

  /// Sends the current video to the connected renderer.
  ///
  /// Local playback is paused (and muted) until the renderer confirms that it
  /// started; then both play from the same position. This avoids losing the
  /// first seconds on TVs with a slow handshake.
  Future<void> _startCasting() async {
    if (_castInFlight) return;
    _castInFlight = true;
    try {
      await _performCasting();
    } finally {
      _castInFlight = false;
    }
  }

  Future<void> _performCasting() async {
    final cast = widget.state.castController;
    final mediaUri = _mediaUri;
    if (!mounted || !cast.isConnected || mediaUri == null) return;

    final startAt = _player.state.position;
    if (!_castMuted) _volumeBeforeCast = _player.state.volume;
    await _player.setVolume(0);
    if (!mounted) return;
    _castMuted = true;
    _resumeLocalWhenRemoteStarts = true;
    _castStartedAt = DateTime.now();
    _lastCastError = null;
    if (_player.state.playing) {
      await _player.pause();
      if (!mounted) return;
    }
    setState(() {});

    final ok = await cast.castVideo(
      video: widget.video,
      fallbackUri: mediaUri,
      fallbackKind: _streamKind,
      localPath: _localPath,
      startAt: startAt,
    );
    if (!mounted) {
      unawaited(cast.stopPlayback(expectedVideoId: widget.video.id));
      return;
    }
    if (!ok) {
      if (!cast.isConnected) {
        await _restoreLocalAudio();
        return;
      }
      final message = cast.error ?? 'Invio al dispositivo non riuscito.';
      if (_lastCastError != message) {
        _lastCastError = message;
        _toast(
          message,
          action: SnackBarAction(
            label: 'Riprova',
            onPressed: () => unawaited(_startCasting()),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  /// Resumes playback on the renderer after the user pressed the poster's
  /// play button, or retries the whole handshake after an error.
  Future<void> _resumeCasting() async {
    final cast = widget.state.castController;
    if (!mounted || !cast.isConnected) return;
    if (cast.playback == CastPlaybackState.error ||
        cast.currentVideo?.id != widget.video.id ||
        _mediaUri == null) {
      await _startCasting();
      return;
    }

    if (!_castMuted) _volumeBeforeCast = _player.state.volume;
    await _player.setVolume(0);
    if (!mounted) return;
    final startAt = _player.state.position;
    _castMuted = true;
    _resumeLocalWhenRemoteStarts = true;
    _castStartedAt = DateTime.now();
    _lastCastError = null;
    if (_player.state.playing) {
      await _player.pause();
      if (!mounted) return;
    }
    // Align the device with the paused local position, then wait for the
    // renderer to confirm before resuming local playback.
    await cast.seekTo(startAt);
    final ok = await cast.play();
    if (!mounted) return;
    if (!ok) {
      final message = cast.error ?? 'Avvio sul dispositivo non riuscito.';
      if (!cast.isConnected) {
        await _restoreLocalAudio();
      }
      if (_lastCastError != message) {
        _lastCastError = message;
        _toast(
          message,
          action: SnackBarAction(
            label: 'Riprova',
            onPressed: () => unawaited(_startCasting()),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _restoreLocalAudio() async {
    if (!_castMuted) return;
    final resumeLocal = _resumeLocalWhenRemoteStarts;
    _resumeLocalWhenRemoteStarts = false;
    _castMuted = false;
    try {
      await _player.setVolume(_volumeBeforeCast.clamp(0, 100));
      if (resumeLocal && !_player.state.playing) {
        unawaited(_player.play());
      }
    } on Object {
      // The player may be closing.
    }
    if (mounted) setState(() {});
  }

  Future<void> _allowFirewallAndRetry() async {
    final cast = widget.state.castController;
    final allowed = await cast.allowFirewall();
    if (!mounted) return;
    if (!allowed) {
      final message = cast.error ?? 'Permesso non concesso.';
      if (_lastCastError != message) {
        _lastCastError = message;
        _toast(message);
      }
      return;
    }
    await _startCasting();
  }

  Future<void> _useLocalOnly() async {
    await widget.state.castController.disconnect();
    await _restoreLocalAudio();
    if (mounted) _toast('Trasmissione interrotta');
  }

  Future<void> _retry() async {
    final cast = widget.state.castController;
    if (cast.isCasting && cast.currentVideo?.id == widget.video.id) {
      await cast.stopPlayback(expectedVideoId: widget.video.id);
    }
    setState(() {
      _error = null;
      _ready = false;
      _lastSkippedEndMs = null;
      _mediaUri = null;
      _streamKind = null;
      _localPath = null;
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
    final cast = widget.state.castController;
    cast.removeListener(_onCastChanged);
    if (cast.currentVideo?.id == widget.video.id) {
      unawaited(cast.stopPlayback(expectedVideoId: widget.video.id));
    }
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

    Channel? channel;
    for (final item in widget.state.channels) {
      if (item.id == widget.video.channelId) {
        channel = item;
        break;
      }
    }
    if (channel?.defaultPlaybackRate != null) {
      unawaited(widget.state.setChannelPlaybackRate(channel!.id, rate));
    } else {
      unawaited(widget.state.setPlaybackRate(rate));
    }
  }

  Widget _buildStage(CastController cast) {
    if (_error != null) {
      return _PlayerError(
        message: _error!,
        onRetry: _retry,
        onOpenExternal: _openExternal,
      );
    }
    if (!_ready) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 14),
            Text(
              'Risoluzione dello stream…',
              style: TextStyle(color: ExpeditusColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_controller == null) return const SizedBox.shrink();

    final showCastCover =
        _castMuted && cast.isConnected && cast.isCasting && !cast.remotePlaying;
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _controller!,
          controls: MaterialVideoControls,
          fit: BoxFit.contain,
        ),
        if (showCastCover)
          Positioned.fill(
            child: CastWaitingCover(
              video: widget.video,
              deviceName: cast.connectedDeviceName ?? 'Dispositivo',
              starting: cast.playback == CastPlaybackState.starting,
              firewallRequired: cast.firewallRequired,
              firewallBusy: cast.firewallBusy,
              onPlay: _resumeCasting,
              onAllowFirewall: _allowFirewallAndRetry,
              onUseLocal: _useLocalOnly,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cast = widget.state.castController;
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
          IconButton(
            key: const Key('cast-button'),
            tooltip: cast.isConnected
                ? 'Trasmesso su ${cast.connectedDeviceName ?? 'dispositivo'}'
                : 'Trasmetti su dispositivo',
            onPressed: _openCastDialog,
            icon: Icon(
              cast.isConnected
                  ? Icons.cast_connected_rounded
                  : Icons.cast_rounded,
              color: cast.isConnected ? ExpeditusColors.accent : null,
            ),
          ),
          IconButton(
            key: const Key('chapters-button'),
            tooltip: 'Capitoli e segnalibri',
            onPressed: _showOutline,
            icon: const Icon(Icons.format_list_bulleted_rounded),
          ),
          IconButton(
            key: const Key('bookmark-add-button'),
            tooltip: 'Aggiungi segnalibro con nota',
            onPressed: _addBookmark,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
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
              for (final rate in playbackRates)
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
            tooltip: widget.video.watchLater
                ? 'Rimuovi da Guarda più tardi'
                : 'Guarda più tardi',
            onPressed: () => widget.state.toggleQueued(widget.video),
            icon: Icon(
              widget.video.watchLater
                  ? Icons.watch_later_rounded
                  : Icons.watch_later_outlined,
              color: widget.video.watchLater
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
          Expanded(child: _buildStage(cast)),
          _PlayerFooter(
            video: widget.video,
            quality: _quality,
            castStatus: cast.isConnected
                ? 'Cast · ${cast.connectedDeviceName ?? 'dispositivo'}'
                      '${_castMuted ? ' · muto qui' : ''}'
                : null,
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
    required this.castStatus,
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
  final String? castStatus;
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
              if (castStatus != null)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cast_connected_rounded,
                        size: 12,
                        color: ExpeditusColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          castStatus!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExpeditusColors.accent,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (quality != null)
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
                  tooltip: video.watchLater
                      ? 'Rimuovi da Guarda più tardi'
                      : 'Guarda più tardi',
                  onPressed: onToggleQueued,
                  icon: Icon(
                    video.watchLater
                        ? Icons.watch_later_rounded
                        : Icons.watch_later_outlined,
                    color: video.watchLater
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
