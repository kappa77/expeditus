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
import '../../l10n/generated/app_localizations.dart';
import '../util/cast_error_text.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import '../util/platform.dart';
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

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final Player _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<SponsorSegment> _segments = const [];
  Duration? _duration;
  final ValueNotifier<Duration> _uiPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> _uiDuration = ValueNotifier(null);
  late final Listenable _footerListenable = Listenable.merge([
    _uiPosition,
    _uiDuration,
  ]);
  bool _ready = false;
  late bool _watched = widget.video.isWatched;
  late bool _queued = widget.video.watchLater;
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
  int _videoEpoch = 0;
  String? _error;
  String? _errorDetails;
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
    WidgetsBinding.instance.addObserver(this);
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
        _uiDuration.value = value;
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) _markWatched();
      }),
    );
    _uiPosition.value = Duration.zero;
    _uiDuration.value = null;
    _lastProgressSave = DateTime.now();
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

    // Accessing localizations is not allowed before the first build, and
    // _open needs the current locale for its user-facing labels.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
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
    if (widget.video.isLocal) {
      if (mounted) setState(() => _chaptersLoaded = true);
      return;
    }
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
    if (widget.video.isLocal) return;
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
    if (widget.video.isLocal) return;
    final note = await showBookmarkNoteDialog(context);
    if (note == null || note.isEmpty) return;
    await widget.state.addBookmark(
      widget.video.id,
      _player.state.position.inSeconds,
      note,
    );
    if (mounted) _toast(context.l10n.bookmarkSaved);
  }

  Future<void> _open() async {
    final l10n = context.l10n;
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
          quality = widget.video.isLocal
              ? l10n.localFileLabel
              : l10n.offlineLabel;
          kind = 'file';
          localPathUsed = localFile.path;
        }
      }

      if (mediaUri == null && widget.video.isLocal) {
        throw Exception(l10n.localFileNotFound(localPath ?? ''));
      }

      if (mediaUri == null) {
        final resolve = widget.resolver ?? StreamResolver.resolve;
        final stream = await resolve(widget.video.id);
        mediaUri = stream.url;
        quality = stream.kind == 'audio'
            ? l10n.audioOnlyQuality
            : stream.quality;
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
      final saved = widget.video.progressSeconds;
      if (!widget.video.isLocal && saved > 5) {
        final total = _player.state.duration;
        if (total == Duration.zero || saved < total.inSeconds - 10) {
          await _player.seek(Duration(seconds: saved));
          if (mounted) _toast(l10n.resumedFrom(formatDuration(saved)));
        }
      }
      setState(() => _ready = true);
      if (widget.state.castController.isConnected) {
        // Mute immediately, before the cast-friendly stream is resolved, so
        // the local audio never overlaps the renderer.
        if (!_castMuted) _volumeBeforeCast = _player.state.volume;
        await _player.setVolume(0);
        _castMuted = true;
        if (mounted) setState(() {});
      }
      if (!widget.video.isLocal) {
        await widget.state.markSeen(widget.video);
      }
      if (widget.state.castController.isConnected) {
        await _startCasting();
      }
      if (!widget.video.isLocal) {
        await _loadSponsorSegments();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e, context.l10n);
          _errorDetails = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadSponsorSegments() async {
    if (widget.video.isLocal) return;
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
    _uiPosition.value = position;
    if (!widget.video.isLocal) {
      final now = DateTime.now();
      if (now.difference(_lastProgressSave).inSeconds >= 5) {
        _lastProgressSave = now;
        unawaited(
          widget.state.saveProgress(widget.video.id, position.inSeconds),
        );
      }
    }
    final cast = widget.state.castController;
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
            unawaited(cast.seekForwardTo(segment.end));
          }
          _toast(context.l10n.sponsorSkipped);
        }
        break;
      }
    }
  }

  void _markWatched() {
    if (widget.video.isLocal) return;
    if (_watchedSent) return;
    _watchedSent = true;
    if (!_watched && mounted) {
      setState(() => _watched = true);
    }
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
      unawaited(_resumeLocalAtCastPosition(cast));
    }
    final failure = cast.error;
    final castError = failure == null
        ? null
        : castFailureText(context.l10n, failure);
    if (castError != null && castError != _lastCastError) {
      _lastCastError = castError;
      if (_castMuted) {
        // Keep local audio muted while the TV is connected. The user can
        // explicitly switch to local playback from the poster.
        _toast(
          castError,
          action: SnackBarAction(
            label: context.l10n.retry,
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

  /// Resumes the muted local player at the renderer's current position.
  ///
  /// The renderer starts while local playback is paused, so resuming from the
  /// original position would leave the local clock behind the TV for the rest
  /// of the video.
  Future<void> _resumeLocalAtCastPosition(CastController cast) async {
    final remote = await cast.getRemotePosition();
    if (!mounted || !_castMuted || !cast.remotePlaying) return;
    if (remote != null && remote > Duration.zero) {
      await _player.seek(remote);
      if (!mounted) return;
    }
    if (!_player.state.playing) {
      unawaited(_player.play());
    }
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
      final failure = cast.error;
      final message = failure == null
          ? context.l10n.castSendFailed
          : castFailureText(context.l10n, failure);
      if (_lastCastError != message) {
        _lastCastError = message;
        _toast(
          message,
          action: SnackBarAction(
            label: context.l10n.retry,
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
    final l10n = context.l10n;
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
      final failure = cast.error;
      final message = failure == null
          ? l10n.castStartFailed
          : castFailureText(l10n, failure);
      if (!cast.isConnected) {
        await _restoreLocalAudio();
      }
      if (_lastCastError != message) {
        _lastCastError = message;
        _toast(
          message,
          action: SnackBarAction(
            label: l10n.retry,
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
      final failure = cast.error;
      final message = failure == null
          ? context.l10n.permissionNotGranted
          : castFailureText(context.l10n, failure);
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
    if (mounted) _toast(context.l10n.castStopped);
  }

  Future<void> _retry() async {
    final cast = widget.state.castController;
    if (cast.isCasting && cast.currentVideo?.id == widget.video.id) {
      await cast.stopPlayback(expectedVideoId: widget.video.id);
    }
    setState(() {
      _error = null;
      _errorDetails = null;
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
    if (widget.video.isLocal) return;
    await launchUrl(
      Uri.parse(widget.video.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !widget.video.isLocal) {
      unawaited(
        widget.state.saveProgress(
          widget.video.id,
          _player.state.position.inSeconds,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    if (!widget.video.isLocal) {
      unawaited(
        widget.state.saveProgress(
          widget.video.id,
          _player.state.position.inSeconds,
        ),
      );
    }
    _uiPosition.dispose();
    _uiDuration.dispose();
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
        details: _errorDetails,
        local: widget.video.isLocal,
        onRetry: _retry,
        onOpenExternal: _openExternal,
      );
    }
    if (!_ready) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 14),
            Text(
              widget.video.isLocal
                  ? context.l10n.openingFile
                  : context.l10n.resolvingStream,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12,
              ),
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
        MaterialVideoControlsTheme(
          normal: const MaterialVideoControlsThemeData(
            seekBarPositionColor: ExpeditusColors.accent,
            seekBarThumbColor: ExpeditusColors.accent,
            seekBarBufferColor: ExpeditusColors.border,
            seekBarColor: ExpeditusColors.border,
            seekBarHeight: 3,
          ),
          fullscreen: const MaterialVideoControlsThemeData(
            seekBarPositionColor: ExpeditusColors.accent,
            seekBarThumbColor: ExpeditusColors.accent,
            seekBarBufferColor: ExpeditusColors.border,
            seekBarColor: ExpeditusColors.border,
            seekBarHeight: 3,
          ),
          child: Video(
            key: ValueKey('player-video-$_videoEpoch'),
            controller: _controller!,
            controls: MaterialVideoControls,
            fit: BoxFit.contain,
            onExitFullscreen: () async {
              // MediaKit hides the system UI and locks landscape while the
              // fullscreen route is open. Restore both, then recreate the
              // texture so the surface returns to the in-page stage.
              await SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.edgeToEdge,
              );
              await SystemChrome.setPreferredOrientations(
                DeviceOrientation.values,
              );
              await Future<void>.delayed(const Duration(milliseconds: 250));
              if (mounted) setState(() => _videoEpoch++);
            },
          ),
        ),
        if (showCastCover)
          Positioned.fill(
            child: CastWaitingCover(
              video: widget.video,
              deviceName:
                  cast.connectedDeviceName ?? context.l10n.deviceFallback,
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 860 || size.height < 480;
    final veryShort = size.height < 480;
    return Scaffold(
      key: const Key('player-page'),
      backgroundColor: Colors.black,
      appBar: _buildAppBar(cast, compact),
      body: Column(
        children: [
          Expanded(child: _buildStage(cast)),
          if (!veryShort)
            SafeArea(
              top: false,
              child: AnimatedBuilder(
                animation: _footerListenable,
                builder: (context, _) => _PlayerFooter(
                  video: widget.video,
                  watched: _watched,
                  queued: _queued,
                  compact: compact,
                  quality: _quality,
                  castStatus: cast.isConnected
                      ? _castMuted
                            ? context.l10n.castFooterMuted(
                                cast.connectedDeviceName ??
                                    context.l10n.deviceFallback,
                              )
                            : context.l10n.castFooter(
                                cast.connectedDeviceName ??
                                    context.l10n.deviceFallback,
                              )
                      : null,
                  position: _uiPosition.value,
                  duration: _uiDuration.value,
                  sponsorSegments: _segments.length,
                  sponsorEnabled: widget.state.sponsorBlockEnabled,
                  onOpenExternal: _openExternal,
                  onToggleWatched: _toggleWatched,
                  onToggleQueued: _toggleQueued,
                  onSeekBack: () => _seekBy(-10),
                  onSeekForward: () => _seekBy(10),
                  onSeek: _seekTo,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CastController cast, bool compact) {
    final local = widget.video.isLocal;
    return AppBar(
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
      actions: compact
          ? [
              PopupMenuButton<_PlayerAction>(
                key: const Key('player-menu'),
                tooltip: context.l10n.videoActions,
                onSelected: _onPlayerAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PlayerAction.speed,
                    child: _menuRow(
                      Icons.speed_rounded,
                      context.l10n.playerSpeedMenu(
                        '${_rate.toStringAsFixed(2)}×',
                      ),
                    ),
                  ),
                  if (!local)
                    PopupMenuItem(
                      value: _PlayerAction.chapters,
                      child: _menuRow(
                        Icons.format_list_bulleted_rounded,
                        context.l10n.chaptersAndBookmarks,
                      ),
                    ),
                  if (!local)
                    PopupMenuItem(
                      value: _PlayerAction.bookmark,
                      child: _menuRow(
                        Icons.bookmark_add_outlined,
                        context.l10n.addBookmark,
                      ),
                    ),
                  if (supportsDlnaCast)
                    PopupMenuItem(
                      value: _PlayerAction.cast,
                      child: _menuRow(
                        Icons.cast_rounded,
                        cast.isConnected
                            ? context.l10n.castedTo(
                                cast.connectedDeviceName ??
                                    context.l10n.deviceFallback,
                              )
                            : context.l10n.castToDevice,
                      ),
                    ),
                  if (!local)
                    PopupMenuItem(
                      value: _PlayerAction.watched,
                      child: _menuRow(
                        _watched
                            ? Icons.check_circle_rounded
                            : Icons.check_circle_outline_rounded,
                        _watched
                            ? context.l10n.markUnwatched
                            : context.l10n.markWatched,
                      ),
                    ),
                  if (!local)
                    PopupMenuItem(
                      value: _PlayerAction.queued,
                      child: _menuRow(
                        _queued
                            ? Icons.watch_later_rounded
                            : Icons.watch_later_outlined,
                        _queued
                            ? context.l10n.removeFromWatchLater
                            : context.l10n.navWatchLater,
                      ),
                    ),
                  if (!local)
                    PopupMenuItem(
                      value: _PlayerAction.external,
                      child: _menuRow(
                        Icons.open_in_new_rounded,
                        context.l10n.openOnYouTube,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ]
          : [
              if (supportsDlnaCast)
                IconButton(
                  key: const Key('cast-button'),
                  tooltip: cast.isConnected
                      ? context.l10n.castedTo(
                          cast.connectedDeviceName ??
                              context.l10n.deviceFallback,
                        )
                      : context.l10n.castToDevice,
                  onPressed: _openCastDialog,
                  icon: Icon(
                    cast.isConnected
                        ? Icons.cast_connected_rounded
                        : Icons.cast_rounded,
                    color: cast.isConnected ? ExpeditusColors.accent : null,
                  ),
                ),
              if (!local) ...[
                IconButton(
                  key: const Key('chapters-button'),
                  tooltip: context.l10n.chaptersAndBookmarks,
                  onPressed: _showOutline,
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                ),
                IconButton(
                  key: const Key('bookmark-add-button'),
                  tooltip: context.l10n.addBookmark,
                  onPressed: _addBookmark,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
              ],
              PopupMenuButton<double>(
                key: const Key('speed-button'),
                tooltip: context.l10n.playbackSpeed,
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
              if (!local) ...[
                IconButton(
                  tooltip: _watched
                      ? context.l10n.markUnwatched
                      : context.l10n.markWatched,
                  onPressed: _toggleWatched,
                  icon: Icon(
                    _watched
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _watched
                        ? ExpeditusColors.green
                        : ExpeditusColors.muted,
                  ),
                ),
                IconButton(
                  tooltip: _queued
                      ? context.l10n.removeFromWatchLater
                      : context.l10n.navWatchLater,
                  onPressed: _toggleQueued,
                  icon: Icon(
                    _queued
                        ? Icons.watch_later_rounded
                        : Icons.watch_later_outlined,
                    color: _queued
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.openOnYouTubeWithKey,
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ],
              const SizedBox(width: 8),
            ],
    );
  }

  static Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }

  void _onPlayerAction(_PlayerAction action) {
    switch (action) {
      case _PlayerAction.speed:
        unawaited(_showSpeedSheet());
      case _PlayerAction.chapters:
        unawaited(_showOutline());
      case _PlayerAction.bookmark:
        unawaited(_addBookmark());
      case _PlayerAction.cast:
        unawaited(_openCastDialog());
      case _PlayerAction.watched:
        _toggleWatched();
      case _PlayerAction.queued:
        _toggleQueued();
      case _PlayerAction.external:
        unawaited(_openExternal());
    }
  }

  Future<void> _showSpeedSheet() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  context.l10n.playbackSpeed,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final rate in playbackRates)
                ListTile(
                  title: Text('${rate.toStringAsFixed(2)}×'),
                  trailing: rate == _rate
                      ? const Icon(
                          Icons.check_rounded,
                          color: ExpeditusColors.accent,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(rate),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _setRate(selected);
  }

  void _toggleWatched() {
    setState(() => _watched = !_watched);
    unawaited(widget.state.toggleWatched(widget.video));
    _toast(
      _watched ? context.l10n.markedWatched : context.l10n.markedUnwatched,
    );
  }

  void _toggleQueued() {
    setState(() => _queued = !_queued);
    unawaited(widget.state.toggleQueued(widget.video));
    _toast(
      _queued
          ? context.l10n.addedToWatchLater
          : context.l10n.removedFromWatchLater,
    );
  }

  void _seekTo(Duration target) {
    if (!_ready) return;
    final total = _duration;
    final clamped = total == null
        ? target
        : Duration(
            milliseconds: target.inMilliseconds.clamp(0, total.inMilliseconds),
          );
    _uiPosition.value = clamped;
    unawaited(_player.seek(clamped));
    final cast = widget.state.castController;
    if (cast.isCasting && _castMuted) {
      unawaited(cast.seekTo(clamped));
    }
  }

  static String _friendlyError(Object error, AppLocalizations l10n) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('sign in') || lower.contains('bot')) {
      return l10n.youtubeVerificationRequired;
    }
    if (lower.contains('unavailable') ||
        lower.contains('private') ||
        lower.contains('removed') ||
        lower.contains('does not exist')) {
      return l10n.videoUnavailable;
    }
    if (lower.contains('no muxed stream') ||
        lower.contains('no playable stream')) {
      return l10n.noDownloadableFormat;
    }
    return l10n.playbackFailed;
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({
    required this.message,
    required this.local,
    required this.onRetry,
    required this.onOpenExternal,
    this.details,
  });

  final String message;
  final String? details;
  final bool local;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              minHeight: constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: ExpeditusColors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  local
                      ? l10n.playerErrorFileTitle
                      : l10n.playerErrorStreamTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
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
                if (details != null && details!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.technicalDetails,
                        style: const TextStyle(
                          color: ExpeditusColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      children: [
                        SelectableText(
                          details!,
                          style: const TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.retry),
                    ),
                    if (!local) ...[
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(l10n.openOnYouTube),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerFooter extends StatefulWidget {
  const _PlayerFooter({
    required this.video,
    required this.watched,
    required this.queued,
    required this.compact,
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
    required this.onSeek,
  });

  final VideoItem video;
  final bool watched;
  final bool queued;
  final bool compact;
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
  final ValueChanged<Duration> onSeek;

  @override
  State<_PlayerFooter> createState() => _PlayerFooterState();
}

class _PlayerFooterState extends State<_PlayerFooter> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final video = widget.video;
    final duration = widget.duration;
    final displayedPosition = _dragFraction != null && duration != null
        ? Duration(
            milliseconds: (duration.inMilliseconds * _dragFraction!).round(),
          )
        : widget.position;
    final progress = duration != null && duration.inMilliseconds > 0
        ? (displayedPosition.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final currentLabel = displayedPosition.inSeconds <= 0
        ? '0:00'
        : formatDuration(displayedPosition.inSeconds);
    final totalLabel = duration == null || duration.inSeconds <= 0
        ? '--:--'
        : formatDuration(duration.inSeconds);
    final timeLabel = '$currentLabel / $totalLabel';
    final description = video.description.trim();

    return Container(
      width: double.infinity,
      color: ExpeditusColors.surface,
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 16 : 24,
        widget.compact ? 10 : 14,
        widget.compact ? 16 : 24,
        widget.compact ? 8 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  (video.isLocal ? l10n.localVideoLabel : video.channelTitle)
                      .toUpperCase(),
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
              if (widget.castStatus != null)
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
                          widget.castStatus!,
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
              else if (widget.quality != null)
                Text(
                  video.isLocal
                      ? l10n.localFileMp4
                      : video.isDownloaded
                      ? l10n.offlineMp4
                      : l10n.directStreamQuality(widget.quality ?? ''),
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
              maxLines: widget.compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (widget.compact)
            _buildCompactControls(timeLabel, progress, duration)
          else
            _buildDesktopControls(timeLabel, progress),
        ],
      ),
    );
  }

  Widget _buildCompactControls(
    String timeLabel,
    double progress,
    Duration? duration,
  ) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Text(
              timeLabel,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 10.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(
          height: 34,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: progress,
              onChanged: duration == null
                  ? null
                  : (value) => setState(() => _dragFraction = value),
              onChangeStart: duration == null
                  ? null
                  : (value) => setState(() => _dragFraction = value),
              onChangeEnd: duration == null
                  ? null
                  : (value) {
                      setState(() => _dragFraction = null);
                      widget.onSeek(
                        Duration(
                          milliseconds: (duration.inMilliseconds * value)
                              .round(),
                        ),
                      );
                    },
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              key: const Key('seek-back-button'),
              tooltip: l10n.seekBack10,
              onPressed: widget.onSeekBack,
              icon: const Icon(Icons.replay_10_rounded, size: 21),
            ),
            IconButton(
              key: const Key('seek-forward-button'),
              tooltip: l10n.seekForward10,
              onPressed: widget.onSeekForward,
              icon: const Icon(Icons.forward_10_rounded, size: 21),
            ),
            const Spacer(),
            if (!widget.video.isLocal && widget.sponsorEnabled)
              Flexible(
                child: Text(
                  widget.sponsorSegments > 0
                      ? l10n.sponsorBlockCount(widget.sponsorSegments)
                      : l10n.sponsorBlockActive,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: widget.sponsorSegments > 0
                        ? ExpeditusColors.green
                        : ExpeditusColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopControls(String timeLabel, double progress) {
    final l10n = context.l10n;
    final video = widget.video;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
                timeLabel,
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
            tooltip: l10n.seekBack10Key,
            onPressed: widget.onSeekBack,
            icon: const Icon(Icons.replay_10_rounded, size: 20),
          ),
        ),
        Expanded(
          flex: 1,
          child: IconButton(
            key: const Key('seek-forward-button'),
            tooltip: l10n.seekForward10Key,
            onPressed: widget.onSeekForward,
            icon: const Icon(Icons.forward_10_rounded, size: 20),
          ),
        ),
        if (!video.isLocal)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.sponsorEnabled
                  ? Text(
                      widget.sponsorSegments > 0
                          ? l10n.sponsorBlockSegments(widget.sponsorSegments)
                          : l10n.sponsorBlockActive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.sponsorSegments > 0
                            ? ExpeditusColors.green
                            : ExpeditusColors.muted,
                        fontSize: 10.5,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        if (!video.isLocal) ...[
          Expanded(
            flex: 1,
            child: IconButton(
              tooltip: widget.watched ? l10n.markUnwatched : l10n.markWatched,
              onPressed: widget.onToggleWatched,
              icon: Icon(
                widget.watched
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: widget.watched
                    ? ExpeditusColors.green
                    : ExpeditusColors.muted,
                size: 18,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              tooltip: widget.queued
                  ? l10n.removeFromWatchLater
                  : l10n.navWatchLater,
              onPressed: widget.onToggleQueued,
              icon: Icon(
                widget.queued
                    ? Icons.watch_later_rounded
                    : Icons.watch_later_outlined,
                color: widget.queued
                    ? ExpeditusColors.accent
                    : ExpeditusColors.muted,
                size: 18,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              tooltip: l10n.openOnYouTube,
              onPressed: widget.onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
            ),
          ),
        ],
      ],
    );
  }
}

enum _PlayerAction {
  speed,
  chapters,
  bookmark,
  cast,
  watched,
  queued,
  external,
}
