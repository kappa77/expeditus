import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/stream_resolver.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../version.dart';
import 'channel_page.dart';
import 'channels_view.dart';
import 'import_dialog.dart';
import 'player_page.dart';
import 'settings_dialog.dart';
import 'video_row.dart';

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

  static const double _rowHeight = 104;

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
    if (key == LogicalKeyboardKey.keyS) {
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
    final target = (index * _rowHeight).clamp(
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
          _NavItem(
            key: const Key('nav-queue'),
            label: 'Coda',
            icon: Icons.bookmark_border_rounded,
            count: state.queueCount,
            selected: state.view == 'queue',
            onTap: () => onSelect('queue'),
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
      'queue' => 'Coda',
      'channels' => 'Canali',
      _ => 'Ultimi',
    };
    final subtitle = switch (state.view) {
      'new' => '${state.visible.length} video da vedere',
      'queue' => '${state.queueCount} video in coda',
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
          if (state.newCount > 0 && state.view != 'channels') ...[
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
    if (state.visible.isEmpty) {
      return _EmptyState(state: state);
    }

    return Focus(
      focusNode: listFocus,
      onKeyEvent: onKey,
      child: Scrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(top: 2, bottom: 24),
          itemCount: state.visible.length,
          itemBuilder: (context, index) {
            final video = state.visible[index];
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
            );
          },
        ),
      ),
    );
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
                : state.view == 'queue'
                    ? 'La coda è vuota'
                    : 'Nessun video';
    final message = filtered
        ? 'Prova con un altro termine. Cerchiamo solo nei canali che segui.'
        : noChannels
            ? 'Importa le tue iscrizioni da Google Takeout, oppure incolla un handle o un URL di canale.'
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
            '↑↓ muovi · Invio guarda · M letto · S coda',
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
