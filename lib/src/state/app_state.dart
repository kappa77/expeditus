import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models.dart';
import '../models/app_update.dart';
import '../services/import_service.dart';
import '../services/rss_service.dart';
import '../services/sponsorblock_service.dart';
import '../services/video_chapters_service.dart';
import '../services/video_download_service.dart';
import '../services/video_link_service.dart';
import '../services/update_service.dart';
import '../services/video_tags_service.dart';
import '../util/app_version.dart';
import '../util/chapter_parser.dart';
import '../util/rss_grouping.dart';
import '../version.dart';
import 'cast_controller.dart';

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
    VideoDownloader? downloader,
    VideoLinkService? videoLink,
    VideoChaptersProvider? chapterService,
    UpdateChecker? updateChecker,
    AppVersion? appVersion,
    CastController? castController,
  })  : rss = rss ?? RssService(),
        resolver = resolver ?? YouTubeResolver(),
        sponsorBlock = sponsorBlock ?? SponsorBlockService(),
        tags = tags ?? VideoTagsService(),
        downloader = downloader ?? VideoDownloadService(),
        videoLink = videoLink ?? VideoLinkService(),
        chapterService = chapterService ?? VideoChaptersService(),
        currentVersion = appVersion ?? _buildVersion(),
        updateChecker = updateChecker ??
            UpdateService(currentVersion: appVersion ?? _buildVersion()),
        castController = castController ?? CastController();

  final AppDatabase db;
  final RssService rss;
  final YouTubeResolver resolver;
  final SponsorBlockService sponsorBlock;
  final VideoTagsProvider tags;
  final VideoDownloader downloader;
  final VideoLinkService videoLink;
  final VideoChaptersProvider chapterService;
  final AppVersion currentVersion;
  final UpdateChecker updateChecker;
  final CastController castController;

  List<Channel> channels = [];
  List<VideoItem> latest = [];
  List<VideoItem> queueItems = [];
  List<VideoItem> saved = [];
  List<VideoItem> rssHistory = [];
  List<VideoItem> visible = [];
  final Map<String, double> downloadProgress = {};

  String view = 'latest';
  String search = '';

  /// When set, the RSS history view shows only this channel.
  String? rssChannel;

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
  bool onboardingSeen = false;

  AppRelease? latestRelease;
  DateTime? updateLastCheck;
  String? updateSkippedVersion;
  String? updateEtag;
  String? updateCachedRelease;
  String? updateError;
  bool updateChecking = false;
  bool updateFromCache = false;

  bool importing = false;
  String? importStatus;
  final List<String> importErrors = [];

  Timer? _timer;
  Timer? _updateTimer;
  bool _disposed = false;
  final Set<String> _seenInSession = {};
  final Set<String> _watchedInSession = {};
  final Set<String> _downloadsInProgress = {};

  int get newCount => latest.where((video) => video.isNew).length;
  int get queueCount => queueItems.length;
  int get watchLaterCount => queueItems.length;

  /// The explicit watch later list.
  List<VideoItem> get watchLaterItems => queueItems;
  int get latestCount => latest.length;
  int get savedCount => saved.length;
  int get rssHistoryCount => rssHistory.length;

  static const Duration _updateCheckInterval = Duration(hours: 6);
  static const _updateLastCheckKey = 'updateLastCheck';
  static const _updateSkippedVersionKey = 'updateSkippedVersion';
  static const _updateEtagKey = 'updateEtag';
  static const _updateCachedReleaseKey = 'updateCachedRelease';
  static const _updateLastErrorKey = 'updateLastError';

  bool get hasUpdate {
    final release = latestRelease;
    if (release == null || release.draft) return false;
    if (release.prerelease && !currentVersion.isPreRelease) return false;
    if (!release.isNewerThan(currentVersion)) return false;
    return updateSkippedVersion != release.version.canonical;
  }

  bool get updateSkipped =>
      latestRelease != null &&
      updateSkippedVersion == latestRelease!.version.canonical;

  String get currentVersionLabel => 'v${currentVersion.canonical}';

  static AppVersion _buildVersion() =>
      AppVersion.tryParse(kAppVersion) ?? AppVersion.parse('0.0.0');

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

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
    onboardingSeen = settings['onboardingSeen'] == '1';
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

    updateLastCheck =
        DateTime.tryParse(settings[_updateLastCheckKey] ?? '')?.toLocal();
    updateSkippedVersion = _nonEmpty(settings[_updateSkippedVersionKey]);
    updateEtag = _nonEmpty(settings[_updateEtagKey]);
    updateCachedRelease = _nonEmpty(settings[_updateCachedReleaseKey]);
    updateError = _nonEmpty(settings[_updateLastErrorKey]);
    if (updateCachedRelease != null) {
      latestRelease = AppRelease.fromJsonString(updateCachedRelease!);
    }
    final skipped = AppVersion.tryParse(updateSkippedVersion);
    if (skipped != null && !skipped.isNewerThan(currentVersion)) {
      updateSkippedVersion = null;
      await db.deleteSetting(_updateSkippedVersionKey);
    }

    channels = await db.getChannels();
    await reload();
    loading = false;
    _notify();
    _startTimer();
    _startUpdateTimer();
    unawaited(refresh(force: false));
  }

  Future<void> reload() async {
    channels = await db.getChannels();
    latest = await db.latestPerChannel();
    queueItems = await db.queue();
    saved = await db.downloadedVideos();
    rssHistory = await db.rssHistory();
    if (rssChannel != null &&
        !rssHistory.any((video) => video.channelId == rssChannel)) {
      rssChannel = null;
    }
    _applyFilter();
    _notify();
  }

  /// Checks GitHub Releases for a newer version.
  ///
  /// Automatic checks are throttled to one attempt every six hours; a manual
  /// check bypasses both the throttle and the ETag cache. A failed check never
  /// interrupts the app: [updateError] is exposed in the update dialog.
  Future<void> checkForUpdates({bool manual = false}) async {
    if (_disposed || updateChecking) return;
    if (!manual &&
        updateLastCheck != null &&
        DateTime.now().difference(updateLastCheck!) < _updateCheckInterval) {
      return;
    }

    updateChecking = true;
    updateError = null;
    _notify();

    UpdateCheckResult result;
    try {
      result = await updateChecker.check(
        etag: manual ? null : updateEtag,
        cachedBody: updateCachedRelease,
        bypassCache: manual,
      );
    } on Object catch (error) {
      result = UpdateCheckResult(
        checkedAt: DateTime.now(),
        error: 'Controllo aggiornamenti non riuscito: $error',
      );
    }
    if (_disposed) return;

    updateLastCheck = result.checkedAt.toLocal();
    updateFromCache = result.fromCache;
    updateError = result.error;
    if (result.release != null) {
      latestRelease = result.release;
      updateEtag = result.etag;
      if (result.rawBody != null) updateCachedRelease = result.rawBody;
    }

    final skipped = AppVersion.tryParse(updateSkippedVersion);
    if (skipped != null && !skipped.isNewerThan(currentVersion)) {
      updateSkippedVersion = null;
    }

    updateChecking = false;
    try {
      await _persistUpdateState();
    } on Object catch (error) {
      updateError = 'Impossibile salvare lo stato aggiornamenti: $error';
    }
    _notify();
  }

  Future<void> skipUpdateVersion() async {
    final release = latestRelease;
    if (release == null) return;
    updateSkippedVersion = release.version.canonical;
    try {
      await db.setSetting(_updateSkippedVersionKey, updateSkippedVersion!);
    } on Object catch (error) {
      updateError = 'Impossibile salvare la versione saltata: $error';
    }
    _notify();
  }

  Future<void> clearSkippedUpdateVersion() async {
    updateSkippedVersion = null;
    try {
      await db.deleteSetting(_updateSkippedVersionKey);
    } on Object catch (error) {
      updateError = 'Impossibile ripristinare la versione saltata: $error';
    }
    _notify();
  }

  Future<void> _persistUpdateState() async {
    await _writeUpdateSetting(
      _updateLastCheckKey,
      updateLastCheck?.toUtc().toIso8601String(),
    );
    await _writeUpdateSetting(_updateSkippedVersionKey, updateSkippedVersion);
    await _writeUpdateSetting(_updateEtagKey, updateEtag);
    await _writeUpdateSetting(_updateCachedReleaseKey, updateCachedRelease);
    await _writeUpdateSetting(_updateLastErrorKey, updateError);
  }

  Future<void> _writeUpdateSetting(String key, String? value) {
    if (value == null || value.trim().isEmpty) {
      return db.deleteSetting(key);
    }
    return db.setSetting(key, value);
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      _updateCheckInterval,
      (_) => unawaited(checkForUpdates()),
    );
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

  void setRssChannel(String? channelId) {
    rssChannel = channelId;
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
      case 'watch-later':
        source = watchLaterItems;
      case 'saved':
        source = saved;
      case 'rss':
        source = groupRssHistoryByChannel(rssHistory);
        if (rssChannel != null) {
          source = source.where((video) => video.channelId == rssChannel);
        }
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
    await completeOnboarding();

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
    await db.setStatus(
      video.id,
      'seen',
      watchedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await reload();
  }

  Future<void> markWatched(VideoItem video) async {
    if (video.isWatched || _watchedInSession.contains(video.id)) return;
    _watchedInSession.add(video.id);
    await db.setStatus(
      video.id,
      'watched',
      watchedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await reload();
  }

  Future<void> toggleWatched(VideoItem video) async {
    _watchedInSession.remove(video.id);
    final next = video.isWatched ? 'seen' : 'watched';
    await db.setStatus(
      video.id,
      next,
      watchedAt: next == 'watched'
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    );
    await reload();
  }

  Future<void> toggleQueued(VideoItem video) async {
    await db.setQueued(video.id, !video.queued);
    await reload();
  }

  Future<void> toggleWatchLater(VideoItem video) => toggleQueued(video);

  Future<void> markAllSeen() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final video in latest.where((video) => video.isNew).toList()) {
      _seenInSession.add(video.id);
      await db.setStatus(video.id, 'seen', watchedAt: now);
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

  Future<void> toggleShowInLatest(String id) async {
    final channel = channels.firstWhere((channel) => channel.id == id);
    await db.setChannelShowInLatest(id, !channel.showInLatest);
    await reload();
  }

  Future<void> setChannelPlaybackRate(String id, double? rate) async {
    await db.setChannelPlaybackRate(
      id,
      rate == null ? null : _snapPlaybackRate(rate),
    );
    await reload();
  }

  Future<void> refreshChannel(String id) async {
    if (refreshing || _disposed) return;
    final channel = channels.firstWhere((item) => item.id == id);
    refreshing = true;
    error = null;
    _notify();

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _refreshChannel(channel, now);
    } catch (e) {
      error = _shortError(e);
    }

    lastRefresh = DateTime.now();
    refreshing = false;
    await reload();
    _notify();
  }

  Future<List<VideoChapter>> fetchVideoChapters(VideoItem video) async {
    if (video.chapters.isNotEmpty || video.chaptersFetched) {
      return video.chapters;
    }

    final local = ChapterParser.parse(video.description);
    if (local.isNotEmpty) {
      await db.setChapters(video.id, local);
      return local;
    }

    try {
      final chapters = await chapterService.fetch(video.id);
      await db.setChapters(video.id, chapters);
      return chapters;
    } catch (_) {
      return const [];
    }
  }

  Future<List<VideoBookmark>> bookmarksForVideo(String videoId) {
    return db.bookmarksForVideo(videoId);
  }

  Future<void> addBookmark(
    String videoId,
    int positionSeconds,
    String note,
  ) async {
    await db.addBookmark(videoId, positionSeconds, note);
    _notify();
  }

  Future<void> deleteBookmark(int id) async {
    await db.deleteBookmark(id);
    _notify();
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
      await completeOnboarding();

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

  Future<void> completeOnboarding() async {
    if (onboardingSeen) return;
    onboardingSeen = true;
    await db.setSetting('onboardingSeen', '1');
    _notify();
  }

  Future<void> downloadVideo(VideoItem video) async {
    if (video.isDownloaded || _downloadsInProgress.contains(video.id)) {
      return;
    }
    _downloadsInProgress.add(video.id);
    downloadProgress[video.id] = 0;
    await db.setDownload(video.id, status: 'downloading');
    _notify();

    try {
      final path = await downloader.download(
        video.id,
        onProgress: (progress) {
          downloadProgress[video.id] = progress;
          _notify();
        },
      );
      await db.setDownload(
        video.id,
        status: 'ready',
        localPath: path,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await reload();
    } catch (e) {
      await db.setDownload(
        video.id,
        status: 'error',
        error: _shortError(e),
      );
      await reload();
    } finally {
      _downloadsInProgress.remove(video.id);
      downloadProgress.remove(video.id);
      _notify();
    }
  }

  Future<void> deleteDownload(VideoItem video) async {
    final path = video.localPath;
    if (path != null) {
      await downloader.delete(path);
    }
    await db.setDownload(video.id, status: 'none');
    await reload();
  }

  Future<LinkedVideo> importVideoLink(String input) async {
    final linked = await videoLink.resolve(input);
    await addChannel(linked.channel);
    await db.upsertVideo(linked.video);
    await db.setQueued(linked.video.id, true);
    await reload();
    return linked;
  }

  Future<List<VideoItem>> channelVideos(String channelId) {
    return db.videosForChannel(channelId);
  }

  Future<List<VideoItem>> channelHistory(String channelId) {
    return db.historyForChannel(channelId);
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
    _updateTimer?.cancel();
    updateChecker.close();
    rss.close();
    resolver.close();
    sponsorBlock.close();
    tags.close();
    downloader.close();
    videoLink.close();
    chapterService.close();
    castController.dispose();
    super.dispose();
  }
}
