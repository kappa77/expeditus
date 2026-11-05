import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import 'player_page.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key, required this.channel, required this.state});

  final Channel channel;
  final AppState state;

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final TextEditingController _search = TextEditingController();

  List<VideoItem> _videos = const [];
  bool _loading = true;
  bool _loadingTags = false;
  bool _tagsRun = false;
  String _filter = 'all';
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final videos = await widget.state.channelVideos(widget.channel.id);
      if (!mounted) return;
      setState(() {
        _videos = videos;
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
    if (!mounted) return;
    setState(() => _videos = videos);
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

  Future<void> _openExternal(VideoItem video) async {
    await launchUrl(Uri.parse(video.url), mode: LaunchMode.externalApplication);
  }

  List<VideoItem> get _filtered {
    final query = _query.trim().toLowerCase();
    return _videos.where((video) {
      switch (_filter) {
        case 'unwatched':
          if (video.isWatched) return false;
        case 'watched':
          if (!video.isWatched) return false;
        case 'queue':
          if (!video.queued) return false;
      }
      if (query.isEmpty) return true;
      return video.title.toLowerCase().contains(query) ||
          video.description.toLowerCase().contains(query) ||
          video.keywords.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      key: const Key('channel-page'),
      body: Column(
        children: [
          _ChannelHeader(
            channel: widget.channel,
            videos: _videos,
            loadingTags: _loadingTags,
            filter: _filter,
            search: _search,
            onFilter: (value) => setState(() => _filter = value),
            onSearch: (value) => setState(() => _query = value),
            onBack: () => Navigator.of(context).pop(),
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
                : _videos.isEmpty
                ? const _Message(
                    icon: Icons.video_library_outlined,
                    title: 'Nessun video passato',
                    body: 'Questo canale non ha video nel feed RSS corrente.',
                  )
                : filtered.isEmpty
                ? const _Message(
                    icon: Icons.search_off_rounded,
                    title: 'Nessun risultato',
                    body: 'Nessun video corrisponde al filtro o al termine cercato.',
                  )
                : _VideoList(
                    videos: filtered,
                    onPlay: _play,
                    onToggleWatched: _toggleWatched,
                    onToggleQueued: _toggleQueued,
                    onOpenExternal: _openExternal,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.channel,
    required this.videos,
    required this.loadingTags,
    required this.filter,
    required this.search,
    required this.onFilter,
    required this.onSearch,
    required this.onBack,
  });

  final Channel channel;
  final List<VideoItem> videos;
  final bool loadingTags;
  final String filter;
  final TextEditingController search;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final all = videos.length;
    final unwatched = videos.where((video) => !video.isWatched).length;
    final watched = videos.where((video) => video.isWatched).length;
    final queued = videos.where((video) => video.queued).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 24, 14),
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$all video · aggiornato '
                      '${relativeTime(channel.lastChecked == null ? null : DateTime.fromMillisecondsSinceEpoch(channel.lastChecked!))}',
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (loadingTags) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Carico tag…',
                  style: TextStyle(color: ExpeditusColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  key: const Key('channel-page-search'),
                  controller: search,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Cerca nel canale, anche nei tag…',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
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
              _FilterChip(
                key: const Key('channel-filter-queue'),
                label: 'In coda',
                count: queued,
                selected: filter == 'queue',
                onTap: () => onFilter('queue'),
              ),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? ExpeditusColors.accentSoft : ExpeditusColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ExpeditusColors.accent : ExpeditusColors.border,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: selected ? ExpeditusColors.accent : ExpeditusColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _VideoList extends StatelessWidget {
  const _VideoList({
    required this.videos,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onOpenExternal,
  });

  final List<VideoItem> videos;
  final Future<void> Function(VideoItem) onPlay;
  final Future<void> Function(VideoItem) onToggleWatched;
  final Future<void> Function(VideoItem) onToggleQueued;
  final Future<void> Function(VideoItem) onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? currentMonth;
    for (final video in videos) {
      final rawMonth = DateFormat('MMMM yyyy', 'it_IT').format(video.published);
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
          onPlay: () => onPlay(video),
          onToggleWatched: () => onToggleWatched(video),
          onToggleQueued: () => onToggleQueued(video),
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
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    required this.onOpenExternal,
  });

  final VideoItem video;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;
  final VoidCallback onToggleQueued;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final dimmed = video.isWatched;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      Row(
                        children: [
                          Text(
                            shortDate(video.published),
                            style: const TextStyle(
                              color: ExpeditusColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                          if (video.durationSeconds != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatDuration(video.durationSeconds),
                              style: const TextStyle(
                                color: ExpeditusColors.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                          if (video.isWatched) ...[
                            const SizedBox(width: 8),
                            const _Badge('Visto', ExpeditusColors.green),
                          ],
                          if (video.queued) ...[
                            const SizedBox(width: 8),
                            const _Badge('In coda', ExpeditusColors.accent),
                          ],
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
                            for (final tag in video.keywords.take(8))
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
                            if (video.keywords.length > 8)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+${video.keywords.length - 8}',
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
                    IconButton(
                      key: ValueKey('channel-queue-${video.id}'),
                      tooltip: video.queued ? 'Togli dalla coda' : 'In coda',
                      onPressed: onToggleQueued,
                      icon: Icon(
                        video.queued
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: video.queued
                            ? ExpeditusColors.accent
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
