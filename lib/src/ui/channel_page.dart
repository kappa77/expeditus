import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/playback_rates.dart';
import 'player_page.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key, required this.channel, required this.state});

  final Channel channel;
  final AppState state;

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _search = TextEditingController();
  late final TabController _tabs;

  List<VideoItem> _videos = const [];
  List<VideoItem> _history = const [];
  bool _loading = true;
  bool _loadingTags = false;
  bool _tagsRun = false;
  String _filter = 'all';
  String _query = '';
  String? _error;

  Channel get _channel {
    for (final item in widget.state.channels) {
      if (item.id == widget.channel.id) return item;
    }
    return widget.channel;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final videos = await widget.state.channelVideos(widget.channel.id);
      final history = await widget.state.channelHistory(widget.channel.id);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _history = history;
        _loading = false;
        _error = null;
      });
      unawaited(_fetchTags());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reload() async {
    final videos = await widget.state.channelVideos(widget.channel.id);
    final history = await widget.state.channelHistory(widget.channel.id);
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _history = history;
    });
    unawaited(_fetchTags());
  }

  Future<void> _fetchTags() async {
    if (_tagsRun) return;
    _tagsRun = true;
    _loadingTags = true;
    if (mounted) setState(() {});

    final attempted = <String>{};
    try {
      while (mounted) {
        final missing = _videos
            .where(
              (video) =>
                  !video.keywordsFetched && !attempted.contains(video.id),
            )
            .toList();
        if (missing.isEmpty) break;

        for (var i = 0; i < missing.length; i += 3) {
          final batch = missing.skip(i).take(3);
          await Future.wait(
            batch.map((video) async {
              attempted.add(video.id);
              final updated = await widget.state.fetchVideoTags(video);
              if (!mounted || !updated.keywordsFetched) return;
              setState(() {
                _videos = _videos
                    .map((item) => item.id == updated.id ? updated : item)
                    .toList();
              });
            }),
          );
        }
      }
    } finally {
      _tagsRun = false;
      _loadingTags = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _play(VideoItem video) async {
    await widget.state.markSeen(video);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(video: video, state: widget.state),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _toggleWatched(VideoItem video) async {
    await widget.state.toggleWatched(video);
    if (mounted) await _reload();
  }

  Future<void> _toggleQueued(VideoItem video) async {
    await widget.state.toggleQueued(video);
    if (mounted) await _reload();
  }

  Future<void> _toggleMute() async {
    await widget.state.toggleMute(widget.channel.id);
    if (mounted) setState(() {});
  }

  Future<void> _toggleShowInLatest() async {
    await widget.state.toggleShowInLatest(widget.channel.id);
    if (mounted) setState(() {});
  }

  Future<void> _refreshOnly() async {
    await widget.state.refreshChannel(widget.channel.id);
    if (mounted) await _reload();
  }

  Future<void> _setDefaultRate(double? rate) async {
    await widget.state.setChannelPlaybackRate(widget.channel.id, rate);
    if (mounted) setState(() {});
  }

  Future<void> _download(VideoItem video) async {
    await widget.state.downloadVideo(video);
    if (mounted) await _reload();
  }

  Future<void> _deleteDownload(VideoItem video) async {
    await widget.state.deleteDownload(video);
    if (mounted) await _reload();
  }

  Future<void> _openExternal(VideoItem video) async {
    await launchUrl(Uri.parse(video.url), mode: LaunchMode.externalApplication);
  }

  List<VideoItem> get _filtered {
    final query = _query.trim().toLowerCase();
    final muted = _channel.muted;
    return _videos.where((video) {
      if (muted && video.isNew) return false;
      switch (_filter) {
        case 'unwatched':
          if (video.isWatched) return false;
        case 'watched':
          if (!video.isWatched) return false;
        case 'queue':
          if (!video.queued) return false;
      }
      if (query.isEmpty) return true;
      return _matches(video, query);
    }).toList();
  }

  List<VideoItem> get _filteredHistory {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _history;
    return _history.where((video) => _matches(video, query)).toList();
  }

  static bool _matches(VideoItem video, String query) {
    return video.title.toLowerCase().contains(query) ||
        video.description.toLowerCase().contains(query) ||
        video.keywords.any((tag) => tag.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final channel = _channel;
        final filtered = _filtered;
        final filteredHistory = _filteredHistory;
        final visibleArchive = channel.muted
            ? _videos.where((video) => !video.isNew).toList()
            : _videos;
        final size = MediaQuery.sizeOf(context);
        final compact = size.width < 700 || size.height < 480;

        return ExpeditusDownloadProgress(
          progress: widget.state.downloadProgress,
          child: Scaffold(
            key: const Key('channel-page'),
            body: SafeArea(
              child: Column(
                children: [
                  _ChannelHeader(
                    channel: channel,
                    videos: _videos,
                    loadingTags: _loadingTags,
                    muted: channel.muted,
                    showInLatest: channel.showInLatest,
                    defaultPlaybackRate: channel.defaultPlaybackRate,
                    refreshing: widget.state.refreshing,
                    compact: compact,
                    search: _search,
                    onSearch: (value) => setState(() => _query = value),
                    onClear: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    onToggleMute: _toggleMute,
                    onToggleShowInLatest: _toggleShowInLatest,
                    onSetDefaultRate: _setDefaultRate,
                    onRefresh: _refreshOnly,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: ExpeditusColors.border),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      labelColor: ExpeditusColors.accent,
                      unselectedLabelColor: ExpeditusColors.muted,
                      indicatorColor: ExpeditusColors.accent,
                      tabs: const [
                        Tab(text: 'Video'),
                        Tab(text: 'Cronologia'),
                      ],
                    ),
                  ),
                  if (_loadingTags) const LinearProgressIndicator(minHeight: 1),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? _Message(
                            icon: Icons.error_outline_rounded,
                            title: 'Errore',
                            body: _error!,
                          )
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _VideosTab(
                                videos: filtered,
                                allVideos: visibleArchive,
                                filter: _filter,
                                query: _query,
                                muted: channel.muted,
                                compact: compact,
                                onFilter: (value) =>
                                    setState(() => _filter = value),
                                onPlay: _play,
                                onToggleWatched: _toggleWatched,
                                onToggleQueued: _toggleQueued,
                                onDownload: _download,
                                onDeleteDownload: _deleteDownload,
                                onOpenExternal: _openExternal,
                              ),
                              _HistoryTab(
                                videos: filteredHistory,
                                query: _query,
                                compact: compact,
                                onPlay: _play,
                                onToggleWatched: _toggleWatched,
                                onToggleQueued: _toggleQueued,
                                onDownload: _download,
                                onDeleteDownload: _deleteDownload,
                                onOpenExternal: _openExternal,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.channel,
    required this.videos,
    required this.loadingTags,
    required this.muted,
    required this.showInLatest,
    required this.defaultPlaybackRate,
    required this.refreshing,
    required this.compact,
    required this.search,
    required this.onSearch,
    required this.onClear,
    required this.onToggleMute,
    required this.onToggleShowInLatest,
    required this.onSetDefaultRate,
    required this.onRefresh,
    required this.onBack,
  });

  final Channel channel;
  final List<VideoItem> videos;
  final bool loadingTags;
  final bool muted;
  final bool showInLatest;
  final double? defaultPlaybackRate;
  final bool refreshing;
  final bool compact;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShowInLatest;
  final ValueChanged<double?> onSetDefaultRate;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final last = channel.lastChecked == null
        ? 'mai aggiornato'
        : 'aggiornato ${relativeTime(DateTime.fromMillisecondsSinceEpoch(channel.lastChecked!))}';

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 18, compact ? 8 : 18, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ExpeditusColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('channel-back'),
                tooltip: 'Indietro',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${videos.length} video · $last'
                      '${muted ? ' · RSS silenziato' : ''}'
                      '${showInLatest ? '' : ' · fuori dalle novità'}',
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('channel-refresh-only'),
                tooltip: 'Aggiorna solo questo canale',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              if (loadingTags) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Carico tag…',
                    style: TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              width: double.infinity,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: search,
                builder: (context, value, _) => TextField(
                  key: const Key('channel-page-search'),
                  controller: search,
                  onChanged: onSearch,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cerca nel canale, anche nei tag…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 48,
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Cancella ricerca',
                            onPressed: onClear,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Tooltip(
                message: muted
                    ? 'Riattiva l’RSS: i nuovi video torneranno a essere proposti.'
                    : 'Silenzia l’RSS: nessun nuovo video verrà proposto. '
                          'Archivio e cronologia restano disponibili.',
                child: FilterChip(
                  key: const Key('channel-mute-rss'),
                  selected: muted,
                  onSelected: (_) => onToggleMute(),
                  showCheckmark: false,
                  avatar: Icon(
                    muted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_active_outlined,
                    size: 16,
                    color: muted
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                  ),
                  label: Text(muted ? 'RSS silenziato' : 'Silenzia RSS'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: muted
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                  ),
                  selectedColor: ExpeditusColors.accentSoft,
                  backgroundColor: ExpeditusColors.surface,
                  side: BorderSide(
                    color: muted
                        ? ExpeditusColors.accent
                        : ExpeditusColors.border,
                  ),
                ),
              ),
              Tooltip(
                message: showInLatest
                    ? 'Nascondi l’ultimo video di questo canale dalla lista delle novità.'
                    : 'Mostra l’ultimo video di questo canale nella lista delle novità.',
                child: FilterChip(
                  key: const Key('channel-show-in-latest'),
                  selected: showInLatest,
                  onSelected: (_) => onToggleShowInLatest(),
                  showCheckmark: false,
                  avatar: Icon(
                    showInLatest
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 16,
                    color: showInLatest
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                  ),
                  label: const Text('Mostra in novità'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: showInLatest
                        ? ExpeditusColors.accent
                        : ExpeditusColors.muted,
                  ),
                  selectedColor: ExpeditusColors.accentSoft,
                  backgroundColor: ExpeditusColors.surface,
                  side: BorderSide(
                    color: showInLatest
                        ? ExpeditusColors.accent
                        : ExpeditusColors.border,
                  ),
                ),
              ),
              Tooltip(
                message: 'Velocità predefinita quando apri i video di questo canale.',
                child: PopupMenuButton<double?>(
                  key: const Key('channel-playback-rate'),
                  tooltip: 'Velocità predefinita del canale',
                  onSelected: (value) => onSetDefaultRate(
                    value == null || value < 0 ? null : value,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem<double?>(
                      value: -1.0,
                      child: Text('Globale'),
                    ),
                    for (final rate in playbackRates)
                      PopupMenuItem<double?>(
                        value: rate,
                        child: Text('${rate.toStringAsFixed(2)}×'),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: defaultPlaybackRate == null
                          ? ExpeditusColors.surface
                          : ExpeditusColors.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: defaultPlaybackRate == null
                            ? ExpeditusColors.border
                            : ExpeditusColors.accent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 16,
                          color: defaultPlaybackRate == null
                              ? ExpeditusColors.muted
                              : ExpeditusColors.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          defaultPlaybackRate == null
                              ? 'Velocità globale'
                              : 'Velocità ${defaultPlaybackRate!.toStringAsFixed(2)}×',
                          style: TextStyle(
                            fontSize: 11,
                            color: defaultPlaybackRate == null
                                ? ExpeditusColors.muted
                                : ExpeditusColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideosTab extends StatelessWidget {
  const _VideosTab({
    required this.videos,
    required this.allVideos,
    required this.filter,
    required this.query,
    required this.muted,
    required this.compact,
    required this.onFilter,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onDownload,
    required this.onDeleteDownload,
    required this.onOpenExternal,
  });

  final List<VideoItem> videos;
  final List<VideoItem> allVideos;
  final String filter;
  final String query;
  final bool muted;
  final bool compact;
  final ValueChanged<String> onFilter;
  final Future<void> Function(VideoItem) onPlay;
  final Future<void> Function(VideoItem) onToggleWatched;
  final Future<void> Function(VideoItem) onToggleQueued;
  final Future<void> Function(VideoItem) onDownload;
  final Future<void> Function(VideoItem) onDeleteDownload;
  final Future<void> Function(VideoItem) onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final all = allVideos.length;
    final unwatched = allVideos.where((video) => !video.isWatched).length;
    final watched = allVideos.where((video) => video.isWatched).length;
    final queued = allVideos.where((video) => video.queued).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _FilterChip(
                key: const Key('channel-filter-all'),
                label: 'Tutti',
                count: all,
                selected: filter == 'all',
                onTap: () => onFilter('all'),
              ),
              _FilterChip(
                key: const Key('channel-filter-unwatched'),
                label: 'Non visti',
                count: unwatched,
                selected: filter == 'unwatched',
                onTap: () => onFilter('unwatched'),
              ),
              _FilterChip(
                key: const Key('channel-filter-watched'),
                label: 'Visti',
                count: watched,
                selected: filter == 'watched',
                onTap: () => onFilter('watched'),
              ),
              KeyedSubtree(
                key: const Key('channel-filter-watch-later'),
                child: _FilterChip(
                  key: const Key('channel-filter-queue'),
                  label: 'Guarda più tardi',
                  count: queued,
                  selected: filter == 'queue',
                  onTap: () => onFilter('queue'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: videos.isEmpty
              ? _Message(
                  icon: muted
                      ? Icons.notifications_off_outlined
                      : query.trim().isEmpty
                      ? Icons.video_library_outlined
                      : Icons.search_off_rounded,
                  title: muted
                      ? 'RSS silenziato'
                      : query.trim().isEmpty
                      ? 'Nessun video'
                      : 'Nessun risultato',
                  body: muted
                      ? 'Le novità non vengono proposte. Riattiva l’RSS dal pulsante in alto per vederle.'
                      : query.trim().isEmpty
                      ? 'Questo canale non ha video nel feed RSS corrente.'
                      : 'Nessun video corrisponde al filtro o al termine cercato.',
                )
              : _VideoList(
                  videos: videos,
                  history: false,
                  compact: compact,
                  onPlay: onPlay,
                  onToggleWatched: onToggleWatched,
                  onToggleQueued: onToggleQueued,
                  onDownload: onDownload,
                  onDeleteDownload: onDeleteDownload,
                  onOpenExternal: onOpenExternal,
                ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.videos,
    required this.query,
    required this.compact,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onDownload,
    required this.onDeleteDownload,
    required this.onOpenExternal,
  });

  final List<VideoItem> videos;
  final String query;
  final bool compact;
  final Future<void> Function(VideoItem) onPlay;
  final Future<void> Function(VideoItem) onToggleWatched;
  final Future<void> Function(VideoItem) onToggleQueued;
  final Future<void> Function(VideoItem) onDownload;
  final Future<void> Function(VideoItem) onDeleteDownload;
  final Future<void> Function(VideoItem) onOpenExternal;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return _Message(
        icon: query.trim().isEmpty
            ? Icons.history_rounded
            : Icons.search_off_rounded,
        title: query.trim().isEmpty ? 'Cronologia vuota' : 'Nessun risultato',
        body: query.trim().isEmpty
            ? 'I video che apri o segni come visti appariranno qui.'
            : 'Nessun video della cronologia corrisponde al termine cercato.',
      );
    }
    return _VideoList(
      videos: videos,
      history: true,
      compact: compact,
      onPlay: onPlay,
      onToggleWatched: onToggleWatched,
      onToggleQueued: onToggleQueued,
      onDownload: onDownload,
      onDeleteDownload: onDeleteDownload,
      onOpenExternal: onOpenExternal,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ExpeditusColors.accentSoft
              : ExpeditusColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ExpeditusColors.accent : ExpeditusColors.border,
          ),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '$label $count',
            style: TextStyle(
              color: selected ? ExpeditusColors.accent : ExpeditusColors.muted,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoList extends StatelessWidget {
  const _VideoList({
    required this.videos,
    required this.history,
    required this.compact,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onDownload,
    required this.onDeleteDownload,
    required this.onOpenExternal,
  });

  final List<VideoItem> videos;
  final bool history;
  final bool compact;
  final Future<void> Function(VideoItem) onPlay;
  final Future<void> Function(VideoItem) onToggleWatched;
  final Future<void> Function(VideoItem) onToggleQueued;
  final Future<void> Function(VideoItem) onDownload;
  final Future<void> Function(VideoItem) onDeleteDownload;
  final Future<void> Function(VideoItem) onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? currentMonth;
    for (final video in videos) {
      final date = history && video.watchedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(video.watchedAt!)
          : video.published;
      final rawMonth = DateFormat('MMMM yyyy', 'it_IT').format(date);
      final month = rawMonth.isEmpty
          ? rawMonth
          : rawMonth[0].toUpperCase() + rawMonth.substring(1);
      if (month != currentMonth) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Text(
              month.toUpperCase(),
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        );
        currentMonth = month;
      }
      children.add(
        _ChannelVideoTile(
          video: video,
          history: history,
          compact: compact,
          onPlay: () => onPlay(video),
          onToggleWatched: () => onToggleWatched(video),
          onToggleQueued: () => onToggleQueued(video),
          onDownload: () => onDownload(video),
          onDeleteDownload: () => onDeleteDownload(video),
          onOpenExternal: () => onOpenExternal(video),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}

class _ChannelVideoTile extends StatelessWidget {
  const _ChannelVideoTile({
    required this.video,
    required this.history,
    required this.compact,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onDownload,
    required this.onDeleteDownload,
    required this.onOpenExternal,
  });

  final VideoItem video;
  final bool history;
  final bool compact;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;
  final VoidCallback onToggleQueued;
  final VoidCallback onDownload;
  final VoidCallback onDeleteDownload;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final dimmed = video.isWatched;
    final dateLabel = history && video.watchedAt != null
        ? 'aperto ${relativeTime(DateTime.fromMillisecondsSinceEpoch(video.watchedAt!))}'
        : shortDate(video.published);
    final progress = ExpeditusDownloadProgress.of(context, video.id);
    final visibleTags = video.keywords.take(compact ? 4 : 8);
    final hiddenTags = video.keywords.length - visibleTags.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('channel-video-${video.id}'),
          onTap: onPlay,
          borderRadius: BorderRadius.circular(8),
          hoverColor: ExpeditusColors.surfaceHover,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: ExpeditusColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ExpeditusColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 44,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: dimmed
                        ? ExpeditusColors.muted.withValues(alpha: 0.4)
                        : ExpeditusColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              color: ExpeditusColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                          if (video.durationSeconds != null)
                            Text(
                              formatDuration(video.durationSeconds),
                              style: const TextStyle(
                                color: ExpeditusColors.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          if (video.isWatched)
                            const _Badge('Visto', ExpeditusColors.green),
                          if (video.watchLater)
                            const _Badge(
                              'Guarda più tardi',
                              ExpeditusColors.accent,
                            ),
                          if (video.isDownloaded)
                            const _Badge('Offline', ExpeditusColors.green),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dimmed
                              ? ExpeditusColors.textDim
                              : ExpeditusColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (video.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          video.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (video.keywords.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in visibleTags)
                              Tooltip(
                                message: tag,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ExpeditusColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: ExpeditusColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ExpeditusColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            if (hiddenTags > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+$hiddenTags',
                                  style: const TextStyle(
                                    color: ExpeditusColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (compact)
                  _CompactChannelActions(
                    video: video,
                    progress: progress,
                    onPlay: onPlay,
                    onToggleWatched: onToggleWatched,
                    onToggleQueued: onToggleQueued,
                    onDownload: onDownload,
                    onDeleteDownload: onDeleteDownload,
                    onOpenExternal: onOpenExternal,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('channel-play-${video.id}'),
                        tooltip: 'Guarda',
                        onPressed: onPlay,
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: ExpeditusColors.accent,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('channel-watched-${video.id}'),
                        tooltip: video.isWatched
                            ? 'Segna da vedere'
                            : 'Segna visto',
                        onPressed: onToggleWatched,
                        icon: Icon(
                          video.isWatched
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          color: video.isWatched
                              ? ExpeditusColors.green
                              : ExpeditusColors.muted,
                          size: 19,
                        ),
                      ),
                      KeyedSubtree(
                        key: ValueKey('channel-watch-later-${video.id}'),
                        child: IconButton(
                          key: ValueKey('channel-queue-${video.id}'),
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
                            size: 19,
                          ),
                        ),
                      ),
                      if (progress != null)
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          key: ValueKey('channel-download-${video.id}'),
                          tooltip: video.isDownloaded
                              ? 'Rimuovi il download'
                              : 'Salva in locale',
                          onPressed: video.isDownloaded
                              ? onDeleteDownload
                              : onDownload,
                          icon: Icon(
                            video.isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            color: video.isDownloaded
                                ? ExpeditusColors.green
                                : video.downloadStatus == 'error'
                                ? ExpeditusColors.red
                                : ExpeditusColors.muted,
                            size: 19,
                          ),
                        ),
                      IconButton(
                        key: ValueKey('channel-open-${video.id}'),
                        tooltip: 'Apri su YouTube',
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      ),
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

class _CompactChannelActions extends StatelessWidget {
  const _CompactChannelActions({
    required this.video,
    required this.progress,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onDownload,
    required this.onDeleteDownload,
    required this.onOpenExternal,
  });

  final VideoItem video;
  final double? progress;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;
  final VoidCallback onToggleQueued;
  final VoidCallback onDownload;
  final VoidCallback onDeleteDownload;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    if (progress != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(value: progress, strokeWidth: 2),
          ),
        ),
      );
    }
    return PopupMenuButton<int>(
      key: ValueKey('channel-actions-${video.id}'),
      tooltip: 'Azioni video',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220),
      onSelected: (index) {
        switch (index) {
          case 0:
            onPlay();
          case 1:
            onToggleWatched();
          case 2:
            onToggleQueued();
          case 3:
            video.isDownloaded ? onDeleteDownload() : onDownload();
          case 4:
            onOpenExternal();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              const Icon(Icons.play_arrow_rounded, size: 20),
              const SizedBox(width: 12),
              const Text('Riproduci'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(
                video.isWatched
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(video.isWatched ? 'Segna da vedere' : 'Segna visto'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(
                video.watchLater
                    ? Icons.watch_later_rounded
                    : Icons.watch_later_outlined,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                video.watchLater
                    ? 'Rimuovi da Guarda più tardi'
                    : 'Guarda più tardi',
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(
                video.isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                video.isDownloaded ? 'Rimuovi il download' : 'Salva in locale',
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 4,
          child: Row(
            children: const [
              Icon(Icons.open_in_new_rounded, size: 20),
              SizedBox(width: 12),
              Text('Apri su YouTube'),
            ],
          ),
        ),
      ],
      icon: const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.more_vert_rounded, size: 22),
      ),
    );
  }
}

/// Injects the live download progress without making every tile depend on
/// AppState directly.
class ExpeditusDownloadProgress extends InheritedWidget {
  const ExpeditusDownloadProgress({
    super.key,
    required this.progress,
    required super.child,
  });

  final Map<String, double> progress;

  static double? of(BuildContext context, String videoId) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ExpeditusDownloadProgress>();
    return scope?.progress[videoId];
  }

  @override
  bool updateShouldNotify(ExpeditusDownloadProgress oldWidget) {
    return oldWidget.progress != progress;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ExpeditusColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
