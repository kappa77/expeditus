import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models.dart';
import '../services/import_service.dart';
import '../services/rss_service.dart';
import '../services/sponsorblock_service.dart';
import '../services/video_tags_service.dart';

double _snapPlaybackRate(double value) {
  final clamped = value.clamp(0.25, 3.5).toDouble();
  final steps = ((clamped - 0.25) / 0.25).round();
  return 0.25 + steps * 0.25;
}

class AppState extends ChangeNotifier {
  AppState(
    this.db, {
    RssService? rss,
    YouTubeResolver? resolver,
    SponsorBlockService? sponsorBlock,
    VideoTagsProvider? tags,
  })  : rss = rss ?? RssService(),
        resolver = resolver ?? YouTubeResolver(),
        sponsorBlock = sponsorBlock ?? SponsorBlockService(),
        tags = tags ?? VideoTagsService();

  final AppDatabase db;
  final RssService rss;
  final YouTubeResolver resolver;
  final SponsorBlockService sponsorBlock;
  final VideoTagsProvider tags;

  List<Channel> channels = [];
  List<VideoItem> latest = [];
  List<VideoItem> queueItems = [];
  List<VideoItem> visible = [];

  String view = 'latest';
  String search = '';
  int selected = 0;

  bool loading = true;
  bool refreshing = false;
  String? error;
  DateTime? lastRefresh;

  bool hideDescriptions = false;
  bool sponsorBlockEnabled = true;
  Set<String> sponsorCategories = {'sponsor', 'selfpromo'};
  int refreshMinutes = 30;
  double playbackRate = 1.0;

  bool importing = false;
  String? importStatus;
  final List<String> importErrors = [];

  Timer? _timer;
  bool _disposed = false;
  final Set<String> _seenInSession = {};
  final Set<String> _watchedInSession = {};

  int get newCount => latest.where((video) => video.isNew).length;
  int get queueCount => queueItems.length;
  int get latestCount => latest.length;

  VideoItem? get selectedVideo {
    if (visible.isEmpty) return null;
    final index = selected.clamp(0, visible.length - 1);
    return visible[index];
  }

  Future<void> init() async {
    final settings = await db.getSettings();
    hideDescriptions = settings['hideDescriptions'] == '1';
    sponsorBlockEnabled = settings['sponsorBlockEnabled'] != '0';
    refreshMinutes = int.tryParse(settings['refreshMinutes'] ?? '') ?? 30;
    refreshMinutes = refreshMinutes.clamp(5, 240);
    playbackRate = _snapPlaybackRate(
      double.tryParse(settings['playbackRate'] ?? '') ?? 1.0,
    );
    final rawCategories = settings['sponsorCategories'];
    if (rawCategories != null) {
      try {
        sponsorCategories = (jsonDecode(rawCategories) as List)
            .map((e) => e.toString())
            .toSet();
      } catch (_) {
        // Keep defaults if the stored value is malformed.
      }
    }

    channels = await db.getChannels();
    await reload();
    loading = false;
    _notify();
    _startTimer();
    unawaited(refresh(force: false));
  }

  Future<void> reload() async {
    channels = await db.getChannels();
    latest = await db.latestPerChannel();
    queueItems = await db.queue();
    _applyFilter();
    _notify();
  }

  void setView(String next) {
    view = next;
    selected = 0;
    _applyFilter();
    _notify();
  }

  void setSearch(String value) {
    search = value;
    selected = 0;
    _applyFilter();
    _notify();
  }

  void select(int index) {
    if (visible.isEmpty) return;
    selected = index.clamp(0, visible.length - 1);
    _notify();
  }

  void moveSelection(int delta) {
    if (visible.isEmpty) return;
    selected = (selected + delta).clamp(0, visible.length - 1);
    _notify();
  }

  void _applyFilter() {
    Iterable<VideoItem> source;
    switch (view) {
      case 'new':
        source = latest.where((video) => video.isNew);
      case 'queue':
        source = queueItems;
      default:
        source = latest;
    }

    final query = search.trim().toLowerCase();
    if (query.isNotEmpty) {
      source = source.where((video) {
        return video.title.toLowerCase().contains(query) ||
            video.channelTitle.toLowerCase().contains(query) ||
            video.description.toLowerCase().contains(query);
      });
    }

    visible = source.toList();
    if (visible.isEmpty) {
      selected = 0;
    } else if (selected >= visible.length) {
      selected = visible.length - 1;
    }
  }

  Future<void> _refreshChannel(Channel channel, int now) async {
    try {
      final feed = await rss.fetch(channel.id);
      final channelTitle = feed.channelTitle.trim().isNotEmpty
          ? feed.channelTitle
          : channel.title;
      for (final entry in feed.entries) {
        await db.upsertVideo(
          VideoItem(
            id: entry.videoId,
            channelId: channel.id,
            channelTitle: channelTitle,
            title: entry.title,
            description: entry.description,
            publishedAt: entry.publishedAt.millisecondsSinceEpoch,
          ),
        );
      }
      await db.updateChannelFetch(
        channel.id,
        title: channelTitle,
        lastChecked: now,
        error: null,
      );
    } catch (e) {
      await db.updateChannelFetch(
        channel.id,
        title: channel.title,
        lastChecked: now,
        error: _shortError(e),
      );
      rethrow;
    }
  }

  Future<void> refresh({bool force = true}) async {
    if (refreshing || _disposed) return;
    if (!force &&
        lastRefresh != null &&
        DateTime.now().difference(lastRefresh!) <
            const Duration(minutes: 10)) {
      return;
    }

    channels = await db.getChannels();
    if (channels.isEmpty) {
      await reload();
      return;
    }

    refreshing = true;
    error = null;
    _notify();

    final now = DateTime.now().millisecondsSinceEpoch;
    final targets = channels.where((channel) => !channel.muted).toList();
    final failures = <String>[];
    const batchSize = 8;

    for (var i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      await Future.wait(
        batch.map((channel) async {
          try {
            await _refreshChannel(channel, now);
          } catch (e) {
            failures.add(
              '${channel.displayTitle}: ${_shortError(e)}',
            );
          }
        }),
      );
    }

    lastRefresh = DateTime.now();
    refreshing = false;
    error = failures.isEmpty
        ? null
        : '${failures.length} canali non aggiornati';
    await reload();
    _notify();
  }

  /// Adds a channel found through the YouTube search and immediately fetches
  /// its RSS feed. Returns a human-readable error, or null on success.
  Future<String?> addChannel(ImportedChannel channel) async {
    if (_disposed) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.upsertChannel(
      Channel(id: channel.id, title: channel.title, addedAt: now),
    );
    await reload();

    while (refreshing && !_disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_disposed) return null;

    final stored = channels.firstWhere(
      (item) => item.id == channel.id,
      orElse: () => Channel(
        id: channel.id,
        title: channel.title,
        addedAt: now,
      ),
    );

    try {
      await _refreshChannel(
        stored,
        DateTime.now().millisecondsSinceEpoch,
      );
      await reload();
      return null;
    } catch (e) {
      await reload();
      return _shortError(e);
    }
  }

  Future<void> markSeen(VideoItem video) async {
    if (!video.isNew || _seenInSession.contains(video.id)) return;
    _seenInSession.add(video.id);
    await db.setStatus(video.id, 'seen');
    await reload();
  }

  Future<void> markWatched(VideoItem video) async {
    if (video.isWatched || _watchedInSession.contains(video.id)) return;
    _watchedInSession.add(video.id);
    await db.setStatus(video.id, 'watched');
    await reload();
  }

  Future<void> toggleWatched(VideoItem video) async {
    _watchedInSession.remove(video.id);
    final next = video.isWatched ? 'seen' : 'watched';
    await db.setStatus(video.id, next);
    await reload();
  }

  Future<void> toggleQueued(VideoItem video) async {
    await db.setQueued(video.id, !video.queued);
    await reload();
  }

  Future<void> markAllSeen() async {
    for (final video in latest.where((video) => video.isNew).toList()) {
      _seenInSession.add(video.id);
      await db.setStatus(video.id, 'seen');
    }
    await reload();
  }

  Future<void> deleteChannel(String id) async {
    await db.deleteChannel(id);
    await reload();
  }

  Future<void> toggleMute(String id) async {
    final channel = channels.firstWhere((channel) => channel.id == id);
    await db.setChannelMuted(id, !channel.muted);
    await reload();
  }

  Future<ImportResult> importCsv(String content) async {
    final parsed = TakeoutParser.parse(content);
    return _import(parsed);
  }

  Future<ImportResult> importInputs(List<String> lines) async {
    final inputs = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (inputs.isEmpty) {
      return const ImportResult(added: 0, skipped: 0);
    }

    importing = true;
    importStatus = 'Risoluzione canali…';
    importErrors.clear();
    _notify();

    final parsed = <ImportedChannel>[];
    for (var i = 0; i < inputs.length; i++) {
      importStatus = 'Risoluzione ${i + 1}/${inputs.length}…';
      _notify();
      try {
        parsed.add(await resolver.resolve(inputs[i]));
      } catch (e) {
        importErrors.add('${inputs[i]}: ${_shortError(e)}');
      }
    }

    return _import(parsed, alreadyResolving: true);
  }

  Future<ImportResult> _import(
    List<ImportedChannel> parsed, {
    bool alreadyResolving = false,
  }) async {
    if (!alreadyResolving) {
      importing = true;
      importStatus = 'Importazione…';
      importErrors.clear();
      _notify();
    }

    final before = (await db.getChannels()).length;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final channel in parsed) {
      await db.upsertChannel(
        Channel(
          id: channel.id,
          title: channel.title,
          addedAt: now,
        ),
      );
    }

    await reload();
    importing = false;
    importStatus = null;
    _notify();

    if (parsed.isNotEmpty) {
      while (refreshing && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await refresh(force: true);
    }

    final after = (await db.getChannels()).length;
    final added = after - before;
    return ImportResult(
      added: added,
      skipped: parsed.length - added,
      errors: List.of(importErrors),
    );
  }

  Future<void> setHideDescriptions(bool value) async {
    hideDescriptions = value;
    await db.setSetting('hideDescriptions', value ? '1' : '0');
    _notify();
  }

  Future<void> setSponsorBlockEnabled(bool value) async {
    sponsorBlockEnabled = value;
    await db.setSetting('sponsorBlockEnabled', value ? '1' : '0');
    _notify();
  }

  Future<void> toggleSponsorCategory(String category) async {
    if (!sponsorCategories.remove(category)) {
      sponsorCategories.add(category);
    }
    await db.setSetting(
      'sponsorCategories',
      jsonEncode(sponsorCategories.toList()..sort()),
    );
    _notify();
  }

  Future<void> setRefreshMinutes(int minutes) async {
    refreshMinutes = minutes.clamp(5, 240);
    await db.setSetting('refreshMinutes', refreshMinutes.toString());
    _startTimer();
    _notify();
  }

  Future<void> setPlaybackRate(double value) async {
    playbackRate = _snapPlaybackRate(value);
    await db.setSetting('playbackRate', playbackRate.toString());
    _notify();
  }

  Future<List<VideoItem>> channelVideos(String channelId) {
    return db.videosForChannel(channelId);
  }

  /// Fetches tags for one video and caches them. Failures are non-fatal.
  Future<VideoItem> fetchVideoTags(VideoItem video) async {
    if (video.keywordsFetched) return video;
    try {
      final keywords = await tags.fetch(video.id);
      await db.setKeywords(video.id, keywords);
      return video.copyWith(
        keywords: keywords,
        keywordsFetched: true,
      );
    } catch (_) {
      return video;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: refreshMinutes),
      (_) => unawaited(refresh(force: false)),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _shortError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    rss.close();
    resolver.close();
    sponsorBlock.close();
    tags.close();
    super.dispose();
  }
}
