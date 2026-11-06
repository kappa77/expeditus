import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/stream_resolver.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/rss_grouping.dart';
import '../version.dart';
import 'channel_page.dart';
import 'channels_view.dart';
import 'import_dialog.dart';
import 'player_page.dart';
import 'settings_dialog.dart';
import 'video_row.dart';

const double _rssHeaderHeight = 44;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, this.playerResolver});

  final AppState state;
  final Future<ResolvedStream> Function(String videoId)? playerResolver;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _listFocus = FocusNode(debugLabel: 'feed');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const double _rowHeight = 112;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _listFocus.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        if (state.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                state: state,
                onOpenImport: () => _openImport(),
                onSearchChannel: () => _openImport(initialTab: 2),
                onOpenSettings: _openSettings,
                onSelect: _selectView,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _Header(
                      state: state,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onSearch: state.setSearch,
                      onClearSearch: _clearSearch,
                      onRefresh: () => state.refresh(force: true),
                      onImport: () => _openImport(),
                      onMarkAllSeen: state.markAllSeen,
                    ),
                    Expanded(
                      child: state.view == 'channels'
                          ? ChannelsView(
                              state: state,
                              onOpenChannel: _openChannelById,
                            )
                          : _FeedView(
                              state: state,
                              listFocus: _listFocus,
                              scrollController: _scrollController,
                              onSelect: _ensureListFocus,
                              onPlay: _play,
                              onKey: _onKey,
                              onChannelTap: _openChannelById,
                            ),
                    ),
                    _StatusBar(state: state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _ensureListFocus() {
    if (!mounted) return;
    if (!_listFocus.hasFocus) _listFocus.requestFocus();
  }

  void _selectView(String view) {
    widget.state.setView(view);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && view != 'channels') _listFocus.requestFocus();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    widget.state.setSearch('');
    _searchFocus.unfocus();
    _listFocus.requestFocus();
  }

  Future<void> _openImport({int initialTab = 0}) async {
    final result = await showDialog<ImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(
        state: widget.state,
        initialTab: initialTab,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      final parts = <String>[];
      if (result.added > 0) parts.add('${result.added} canali importati');
      if (result.skipped > 0) parts.add('${result.skipped} già presenti');
      if (result.errors.isNotEmpty) {
        parts.add('${result.errors.length} errori');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? 'Nessun canale importato.' : parts.join(' · '),
          ),
        ),
      );
    }
    _listFocus.requestFocus();
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(state: widget.state),
    );
    if (mounted) _listFocus.requestFocus();
  }

  Future<void> _play(VideoItem video) async {
    await widget.state.markSeen(video);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          video: video,
          state: widget.state,
          resolver: widget.playerResolver,
        ),
      ),
    );
    if (mounted) _listFocus.requestFocus();
  }

  Future<void> _openExternal(VideoItem video) async {
    await launchUrl(
      Uri.parse(video.url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openChannelById(String channelId) async {
    Channel? channel;
    for (final item in widget.state.channels) {
      if (item.id == channelId) {
        channel = item;
        break;
      }
    }
    if (channel == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelPage(
          channel: channel!,
          state: widget.state,
        ),
      ),
    );
    if (mounted) _listFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;

    final state = widget.state;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyJ) {
      state.moveSelection(1);
      _scrollToSelected(state.selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyK) {
      state.moveSelection(-1);
      _scrollToSelected(state.selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      final video = state.selectedVideo;
      if (video != null) _play(video);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      final video = state.selectedVideo;
      if (video != null) state.toggleWatched(video);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyW) {
      final video = state.selectedVideo;
      if (video != null) state.toggleQueued(video);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      state.refresh(force: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyO) {
      final video = state.selectedVideo;
      if (video != null) _openExternal(video);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.slash) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (state.search.isNotEmpty) {
        _clearSearch();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected(int index) {
    if (!_scrollController.hasClients) return;
    var headers = 0;
    if (widget.state.view == 'rss') {
      String? currentChannel;
      final visible = widget.state.visible;
      for (var i = 0; i <= index && i < visible.length; i++) {
        final channelId = visible[i].channelId;
        if (channelId != currentChannel) {
          headers++;
          currentChannel = channelId;
        }
      }
    }
    final target = (index * _rowHeight + headers * _rssHeaderHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    required this.onOpenImport,
    required this.onSearchChannel,
    required this.onOpenSettings,
    required this.onSelect,
  });

  final AppState state;
  final VoidCallback onOpenImport;
  final VoidCallback onSearchChannel;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      color: ExpeditusColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ExpeditusColors.accent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    size: 17,
                    color: ExpeditusColors.background,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'EXPEDITUS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _NavItem(
            key: const Key('nav-latest'),
            label: 'Ultimi',
            icon: Icons.bolt_rounded,
            count: state.latestCount,
            selected: state.view == 'latest',
            onTap: () => onSelect('latest'),
          ),
          _NavItem(
            key: const Key('nav-new'),
            label: 'Nuovi',
            icon: Icons.fiber_new_rounded,
            count: state.newCount,
            selected: state.view == 'new',
            onTap: () => onSelect('new'),
          ),
          KeyedSubtree(
            key: const Key('nav-watch-later'),
            child: _NavItem(
              key: const Key('nav-queue'),
              label: 'Guarda più tardi',
              icon: state.view == 'queue'
                  ? Icons.watch_later_rounded
                  : Icons.watch_later_outlined,
              count: state.watchLaterCount,
              selected: state.view == 'queue',
              onTap: () => onSelect('queue'),
            ),
          ),
          _NavItem(
            key: const Key('nav-saved'),
            label: 'Salvati',
            icon: Icons.download_done_rounded,
            count: state.savedCount,
            selected: state.view == 'saved',
            onTap: () => onSelect('saved'),
          ),
          _NavItem(
            key: const Key('nav-rss-history'),
            label: 'Storico RSS',
            icon: Icons.history_rounded,
            count: state.rssHistoryCount,
            selected: state.view == 'rss',
            onTap: () => onSelect('rss'),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          _NavItem(
            key: const Key('nav-channels'),
            label: 'Canali',
            icon: Icons.subscriptions_outlined,
            count: state.channels.length,
            selected: state.view == 'channels',
            onTap: () => onSelect('channels'),
          ),
          _NavItem(
            key: const Key('nav-import'),
            label: 'Importa',
            icon: Icons.add_circle_outline_rounded,
            onTap: onOpenImport,
          ),
          _NavItem(
            key: const Key('nav-channel-search'),
            label: 'Cerca canale',
            icon: Icons.person_search_rounded,
            onTap: onSearchChannel,
          ),
          const Spacer(),
          TextButton.icon(
            key: const Key('settings-button'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Impostazioni'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: ExpeditusColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Solo ciò che hai scelto.\nNessuna raccomandazione.',
              style: TextStyle(
                color: ExpeditusColors.muted.withValues(alpha: 0.7),
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? ExpeditusColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? ExpeditusColors.accent : ExpeditusColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? ExpeditusColors.text : ExpeditusColors.textDim,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? ExpeditusColors.accentSoft
                        : ExpeditusColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? ExpeditusColors.accent
                          : ExpeditusColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.searchController,
    required this.searchFocus,
    required this.onSearch,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onImport,
    required this.onMarkAllSeen,
  });

  final AppState state;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final VoidCallback onImport;
  final VoidCallback onMarkAllSeen;

  @override
  Widget build(BuildContext context) {
    final title = switch (state.view) {
      'new' => 'Nuovi',
      'queue' => 'Guarda più tardi',
      'watch-later' => 'Guarda più tardi',
      'saved' => 'Salvati',
      'rss' => 'Storico RSS',
      'channels' => 'Canali',
      _ => 'Ultimi',
    };
    final subtitle = switch (state.view) {
      'new' => '${state.visible.length} video da vedere',
      'queue' => '${state.watchLaterCount} video da guardare',
      'watch-later' => '${state.watchLaterCount} video da guardare',
      'saved' => '${state.savedCount} video offline',
      'rss' => state.rssChannel == null && state.search.trim().isEmpty
          ? '${state.rssHistoryCount} video visti nel feed'
          : '${state.visible.length} video · ${state.rssHistoryCount} totali',
      'channels' => '${state.channels.length} iscrizioni',
      _ => '${state.latestCount} canali · ${state.newCount} nuovi',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (state.newCount > 0 &&
              state.view != 'channels' &&
              state.view != 'rss') ...[
            TextButton(
              onPressed: onMarkAllSeen,
              child: const Text('Segna letti'),
            ),
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: 260,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  onClearSearch();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: const Key('search-field'),
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onSearch,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Cerca nelle iscrizioni…',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('refresh-button'),
            tooltip: 'Aggiorna (R)',
            onPressed: state.refreshing ? null : onRefresh,
            icon: state.refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 2),
          FilledButton.icon(
            key: const Key('import-button'),
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Importa'),
          ),
        ],
      ),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({
    required this.state,
    required this.listFocus,
    required this.scrollController,
    required this.onSelect,
    required this.onPlay,
    required this.onKey,
    required this.onChannelTap,
  });

  final AppState state;
  final FocusNode listFocus;
  final ScrollController scrollController;
  final VoidCallback onSelect;
  final Future<void> Function(VideoItem) onPlay;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final ValueChanged<String> onChannelTap;

  @override
  Widget build(BuildContext context) {
    final showFilter = state.view == 'rss' && state.rssHistory.isNotEmpty;
    final filter = showFilter
        ? _RssChannelFilter(
            state: state,
            onSelect: (channelId) {
              state.setRssChannel(channelId);
              WidgetsBinding.instance.addPostFrameCallback((_) => onSelect());
            },
          )
        : null;

    if (state.visible.isEmpty) {
      if (filter == null) return _EmptyState(state: state);
      return Column(
        children: [
          filter,
          Expanded(child: _EmptyState(state: state)),
        ],
      );
    }

    final list = Focus(
      focusNode: listFocus,
      onKeyEvent: onKey,
      child: Scrollbar(
        controller: scrollController,
        child: state.view == 'rss' ? _buildRssList() : _buildFlatList(),
      ),
    );

    if (filter == null) return list;
    return Column(
      children: [
        filter,
        Expanded(child: list),
      ],
    );
  }

  Widget _buildFlatList() {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 24),
      itemCount: state.visible.length,
      itemBuilder: (context, index) {
        return _videoRow(state.visible[index], index);
      },
    );
  }

  Widget _buildRssList() {
    final entries = _rssEntries();
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is _RssGroupHeaderEntry) {
          return _RssGroupHeader(entry: entry);
        }
        final videoEntry = entry as _RssVideoEntry;
        return _videoRow(videoEntry.video, videoEntry.index);
      },
    );
  }

  Widget _videoRow(VideoItem video, int index) {
    return VideoRow(
      key: ValueKey(video.id),
      video: video,
      selected: index == state.selected,
      hideDescription: state.hideDescriptions,
      onTap: () {
        state.select(index);
        onSelect();
      },
      onPlay: () => onPlay(video),
      onToggleWatched: () => state.toggleWatched(video),
      onToggleQueued: () => state.toggleQueued(video),
      onChannelTap: () => onChannelTap(video.channelId),
      showWatchLaterDate: state.view == 'queue' ||
          state.view == 'watch-later',
    );
  }

  List<_RssEntry> _rssEntries() {
    final counts = <String, int>{};
    for (final video in state.visible) {
      counts[video.channelId] = (counts[video.channelId] ?? 0) + 1;
    }

    final entries = <_RssEntry>[];
    String? currentChannel;
    for (var index = 0; index < state.visible.length; index++) {
      final video = state.visible[index];
      if (video.channelId != currentChannel) {
        currentChannel = video.channelId;
        entries.add(
          _RssGroupHeaderEntry(
            channelId: video.channelId,
            title: video.channelTitle,
            count: counts[video.channelId] ?? 0,
          ),
        );
      }
      entries.add(_RssVideoEntry(video, index));
    }
    return entries;
  }
}

class _RssEntry {}

class _RssGroupHeaderEntry extends _RssEntry {
  _RssGroupHeaderEntry({
    required this.channelId,
    required this.title,
    required this.count,
  });

  final String channelId;
  final String title;
  final int count;
}

class _RssVideoEntry extends _RssEntry {
  _RssVideoEntry(this.video, this.index);

  final VideoItem video;
  final int index;
}

class _RssGroupHeader extends StatelessWidget {
  const _RssGroupHeader({required this.entry});

  final _RssGroupHeaderEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isEmpty ? entry.channelId : entry.title;
    final color = videoChannelColor(entry.channelId);
    return Container(
      key: ValueKey('rss-group-${entry.channelId}'),
      height: _rssHeaderHeight,
      padding: const EdgeInsets.fromLTRB(26, 14, 24, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ExpeditusColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.count == 1 ? '1 video' : '${entry.count} video',
            style: const TextStyle(
              color: ExpeditusColors.muted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RssChannelFilter extends StatelessWidget {
  const _RssChannelFilter({required this.state, required this.onSelect});

  final AppState state;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final summaries = summarizeRssChannels(state.rssHistory);
    final total = summaries.fold<int>(0, (sum, item) => sum + item.count);
    final selectedId = state.rssChannel;
    final items = List<RssChannelSummary>.of(summaries);
    if (selectedId != null &&
        !items.any((item) => item.channelId == selectedId)) {
      items.add(
        RssChannelSummary(
          channelId: selectedId,
          title: selectedId,
          count: 0,
          latest: 0,
        ),
      );
    }
    final selected = selectedId == null
        ? null
        : items.firstWhere((item) => item.channelId == selectedId);
    final matching = state.search.trim().isEmpty
        ? total
        : state.visible.length;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ExpeditusColors.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list_rounded,
            size: 16,
            color: ExpeditusColors.muted,
          ),
          const SizedBox(width: 8),
          const Text(
            'Canale',
            style: TextStyle(color: ExpeditusColors.muted, fontSize: 11.5),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 260,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('rss-channel-filter'),
                value: selectedId ?? '',
                isDense: true,
                isExpanded: true,
                dropdownColor: ExpeditusColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(
                  color: ExpeditusColors.text,
                  fontSize: 12.5,
                ),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: ExpeditusColors.muted,
                ),
                selectedItemBuilder: (context) => [
                  Text(
                    'Tutti i canali ($total)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final summary in items)
                    Text(
                      _summaryLabel(summary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
                items: [
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(
                      'Tutti i canali ($total)',
                      key: const Key('rss-channel-option-all'),
                    ),
                  ),
                  for (final summary in items)
                    DropdownMenuItem<String>(
                      value: summary.channelId,
                      child: Text(
                        '${_summaryLabel(summary)} (${summary.count})',
                        key: ValueKey(
                          'rss-channel-option-${summary.channelId}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onSelect(
                  value == null || value.isEmpty ? null : value,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selected == null
                  ? '${summaries.length} canali · $matching video'
                  : '${state.visible.length} video · ${_summaryLabel(selected)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _summaryLabel(RssChannelSummary summary) {
    return summary.title.trim().isEmpty
        ? summary.channelId
        : summary.title;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final filtered = state.search.trim().isNotEmpty;
    final noChannels = state.channels.isEmpty;
    final title = filtered
        ? 'Nessun risultato'
        : noChannels
            ? 'La tua casella è vuota'
            : state.view == 'new'
                ? 'Sei in pari'
                : state.view == 'queue' || state.view == 'watch-later'
                    ? 'Guarda più tardi è vuoto'
                    : state.view == 'saved'
                        ? 'Nessun video salvato'
                        : 'Nessun video';
    final message = filtered
        ? 'Prova con un altro termine. Cerchiamo solo nei canali che segui.'
        : noChannels
            ? 'Importa le tue iscrizioni da Google Takeout, oppure incolla un handle o un URL di canale.'
            : state.view == 'queue' || state.view == 'watch-later'
                ? 'Metti un video in Guarda più tardi con il tasto S o con l’icona dell’orologio nella riga del video.'
                : state.view == 'saved'
                    ? 'Apri il dettaglio di un canale e usa il pulsante di download per guardarlo offline.'
                    : state.view == 'rss'
                        ? 'I video che compaiono nei feed RSS resteranno qui, senza duplicati, anche quando non sono più nell’ultimo feed.'
                        : 'Nessun nuovo video dai canali che segui.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noChannels ? Icons.inbox_outlined : Icons.check_circle_outline,
              size: 42,
              color: ExpeditusColors.muted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (noChannels) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('empty-import-button'),
                onPressed: () async {
                  final result = await showDialog<ImportResult>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ImportDialog(state: state),
                  );
                  if (result != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${result.added} canali importati.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Importa iscrizioni'),
              ),
            ],
            if (!noChannels && !filtered) ...[
              const SizedBox(height: 10),
              Text(
                'R per aggiornare · / per cercare',
                style: TextStyle(
                  color: ExpeditusColors.muted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ExpeditusColors.border)),
        color: ExpeditusColors.surface,
      ),
      child: Row(
        children: [
          Text(
            '${state.channels.length} canali · ${state.newCount} nuovi',
            style: const TextStyle(color: ExpeditusColors.muted, fontSize: 11),
          ),
          if (state.error != null) ...[
            const SizedBox(width: 12),
            const Icon(
              Icons.warning_amber_rounded,
              size: 13,
              color: ExpeditusColors.red,
            ),
            const SizedBox(width: 4),
            Text(
              state.error!,
              style: const TextStyle(color: ExpeditusColors.red, fontSize: 11),
            ),
          ],
          const Spacer(),
          if (state.refreshing) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 7),
            const Text(
              'Aggiornamento…',
              style: TextStyle(color: ExpeditusColors.muted, fontSize: 11),
            ),
          ] else
            Text(
              'Aggiornato ${relativeTime(state.lastRefresh)}',
              style: const TextStyle(color: ExpeditusColors.muted, fontSize: 11),
            ),
          const SizedBox(width: 16),
          Text(
            '↑↓ muovi · Invio guarda · M letto · S guarda più tardi',
            style: TextStyle(
              color: ExpeditusColors.muted.withValues(alpha: 0.55),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 12,
            color: ExpeditusColors.border,
          ),
          const SizedBox(width: 10),
          Text(
            'v$kAppVersion',
            key: const Key('app-version'),
            style: const TextStyle(
              color: ExpeditusColors.muted,
              fontSize: 10.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
