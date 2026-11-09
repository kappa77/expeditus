import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models.dart';
import '../services/stream_resolver.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import '../util/platform.dart';
import '../util/rss_grouping.dart';
import 'channel_page.dart';
import 'channels_view.dart';
import 'import_dialog.dart';
import 'player_page.dart';
import 'settings_dialog.dart';
import 'update_dialog.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
        if (isCompactWidth(context)) return _buildCompact(context, state);
        return _buildDesktop(context, state);
      },
    );
  }

  Widget _buildDesktop(BuildContext context, AppState state) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              state: state,
              width: 224,
              onOpenImport: () => _openImport(),
              onSearchChannel: () => _openImport(initialTab: 2),
              onOpenSettings: _openSettings,
              onOpenUpdates: _openUpdates,
              showUpdates: supportsDesktopUpdates,
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
                    onAddLocalVideos: _addLocalVideos,
                    onMarkAllSeen: state.markAllSeen,
                  ),
                  Expanded(child: _buildView(state, compact: false)),
                  _StatusBar(
                    state: state,
                    onOpenUpdates: _openUpdates,
                    showUpdates: supportsDesktopUpdates,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context, AppState state) {
    final drawer = Drawer(
      width: 300,
      child: SafeArea(
        child: _Sidebar(
          state: state,
          width: 300,
          onClose: _closeDrawer,
          onOpenImport: () {
            _closeDrawer();
            _openImport();
          },
          onSearchChannel: () {
            _closeDrawer();
            _openImport(initialTab: 2);
          },
          onOpenSettings: () {
            _closeDrawer();
            _openSettings();
          },
          onOpenUpdates: () {
            _closeDrawer();
            _openUpdates();
          },
          showUpdates: supportsDesktopUpdates,
          onSelect: (view) {
            _closeDrawer();
            _selectView(view);
          },
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: drawer,
      onDrawerChanged: (open) {
        if (open) _searchFocus.unfocus();
      },
      appBar: _compactAppBar(state),
      bottomNavigationBar: _CompactNavBar(
        state: state,
        onSelect: _selectView,
        onMore: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (state.view != 'channels')
              _CompactSearch(
                state: state,
                controller: _searchController,
                focusNode: _searchFocus,
                onSearch: state.setSearch,
                onClear: () {
                  _searchController.clear();
                  state.setSearch('');
                },
              ),
            if (state.error != null)
              _CompactError(
                message: _errorMessage(context.l10n, state)!,
                onRefresh: state.refresh,
              ),
            Expanded(child: _buildView(state, compact: true)),
          ],
        ),
      ),
    );
  }

  AppBar _compactAppBar(AppState state) {
    final l10n = context.l10n;
    return AppBar(
      leading: IconButton(
        key: const Key('open-drawer'),
        tooltip: l10n.openMenu,
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      titleSpacing: 0,
      toolbarHeight: 64,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleForView(l10n, state.view),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _subtitleForView(l10n, state),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ExpeditusColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        if (state.view != 'local')
          IconButton(
            key: const Key('refresh-button'),
            tooltip: l10n.refreshTooltip,
            onPressed: state.refreshing
                ? null
                : () => state.refresh(force: true),
            icon: state.refreshing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        if (state.view == 'local')
          IconButton(
            key: const Key('add-local-video-button'),
            tooltip: l10n.addVideo,
            onPressed: _addLocalVideos,
            icon: const Icon(Icons.video_library_outlined),
          )
        else
          IconButton(
            key: const Key('import-button'),
            tooltip: l10n.importAction,
            onPressed: () => _openImport(),
            icon: const Icon(Icons.add_rounded),
          ),
        PopupMenuButton<_CompactAction>(
          key: const Key('compact-menu'),
          tooltip: l10n.moreActions,
          onSelected: (action) {
            switch (action) {
              case _CompactAction.markSeen:
                state.markAllSeen();
              case _CompactAction.local:
                _selectView('local');
              case _CompactAction.rss:
                _selectView('rss');
              case _CompactAction.searchChannel:
                _openImport(initialTab: 2);
              case _CompactAction.importCsv:
                _openImport();
              case _CompactAction.settings:
                _openSettings();
              case _CompactAction.updates:
                _openUpdates();
            }
          },
          itemBuilder: (context) => [
            if (state.newCount > 0 &&
                !const {'channels', 'rss', 'local'}.contains(state.view))
              PopupMenuItem(
                key: Key('compact-mark-seen'),
                value: _CompactAction.markSeen,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.done_all_rounded),
                  title: Text(l10n.markAllRead),
                ),
              ),
            if (state.view != 'local')
              PopupMenuItem(
                value: _CompactAction.local,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.video_file_outlined),
                  title: Text(l10n.navLocal),
                ),
              ),
            if (state.view != 'rss')
              PopupMenuItem(
                value: _CompactAction.rss,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(l10n.navRss),
                ),
              ),
            PopupMenuItem(
              value: _CompactAction.searchChannel,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_search_rounded),
                title: Text(l10n.navSearchChannel),
              ),
            ),
            PopupMenuItem(
              value: _CompactAction.importCsv,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(l10n.importAction),
              ),
            ),
            if (supportsDesktopUpdates)
              PopupMenuItem(
                value: _CompactAction.updates,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: Text(l10n.navUpdates),
                ),
              ),
            PopupMenuItem(
              value: _CompactAction.settings,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_rounded),
                title: Text(l10n.navSettings),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildView(AppState state, {required bool compact}) {
    if (state.view == 'channels') {
      return ChannelsView(state: state, onOpenChannel: _openChannelById);
    }
    return _FeedView(
      state: state,
      listFocus: _listFocus,
      scrollController: _scrollController,
      compact: compact,
      onSelect: _ensureListFocus,
      onPlay: _play,
      onKey: _onKey,
      onChannelTap: _openChannelById,
      onAddLocalVideos: _addLocalVideos,
      onRefresh: () => state.refresh(force: true),
    );
  }

  void _closeDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _ensureListFocus() {
    if (!mounted) return;
    if (!_listFocus.hasFocus) _listFocus.requestFocus();
  }

  void _selectView(String view) {
    widget.state.setView(view);
    if (mounted && isCompactWidth(context)) _searchFocus.unfocus();
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
    final l10n = context.l10n;
    final result = await showDialog<ImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(state: widget.state, initialTab: initialTab),
    );
    if (!mounted) return;
    if (result != null) {
      final parts = <String>[];
      if (result.added > 0) {
        parts.add(l10n.channelsImportedCount(result.added));
      }
      if (result.skipped > 0) {
        parts.add(l10n.alreadyPresentCount(result.skipped));
      }
      if (result.errors.isNotEmpty) {
        parts.add(l10n.errorsCount(result.errors.length));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? l10n.noChannelsImported : parts.join(' · '),
          ),
        ),
      );
    }
    _listFocus.requestFocus();
  }

  Future<void> _addLocalVideos() async {
    final l10n = context.l10n;
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.mp4VideoType, extensions: const ['mp4']),
      ],
    );
    if (files.isEmpty || !mounted) return;

    final result = await widget.state.addLocalVideos(
      files.map((file) => file.path),
    );
    if (!mounted) return;

    final parts = <String>[];
    if (result.added > 0) {
      parts.add(l10n.videosAddedCount(result.added));
    }
    if (result.errors.isNotEmpty) {
      parts.add(l10n.errorsCount(result.errors.length));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.isEmpty ? l10n.noVideosAdded : parts.join(' · ')),
      ),
    );
    _listFocus.requestFocus();
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(state: widget.state),
    );
    if (mounted) _listFocus.requestFocus();
  }

  Future<void> _openUpdates() async {
    await showUpdateDialog(context, widget.state);
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
    if (!mounted) return;
    // The player persists the last position and watched flags. Give the
    // unawaited dispose write a moment, then reload so the next open resumes
    // from the saved second instead of the stale feed row.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await widget.state.reload();
    if (mounted) _listFocus.requestFocus();
  }

  Future<void> _openExternal(VideoItem video) async {
    await launchUrl(Uri.parse(video.url), mode: LaunchMode.externalApplication);
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
        builder: (_) => ChannelPage(channel: channel!, state: widget.state),
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

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      state.moveSelection(1);
      _scrollToSelected(state.selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
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
    if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.keyW) {
      final video = state.selectedVideo;
      if (video != null) state.toggleQueued(video);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final video = state.selectedVideo;
      if (video != null && video.isLocal) {
        state.removeLocalVideo(video);
        return KeyEventResult.handled;
      }
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

String _titleForView(AppLocalizations l10n, String view) => switch (view) {
  'new' => l10n.viewNew,
  'queue' => l10n.viewWatchLater,
  'watch-later' => l10n.viewWatchLater,
  'saved' => l10n.viewSaved,
  'local' => l10n.viewLocal,
  'rss' => l10n.viewRss,
  'channels' => l10n.viewChannels,
  _ => l10n.viewLatest,
};

String _subtitleForView(AppLocalizations l10n, AppState state) =>
    switch (state.view) {
      'new' => l10n.subtitleNew(l10n.videosLabel(state.visible.length)),
      'queue' => l10n.subtitleWatchLater(
        l10n.videosLabel(state.watchLaterCount),
      ),
      'watch-later' => l10n.subtitleWatchLater(
        l10n.videosLabel(state.watchLaterCount),
      ),
      'saved' => l10n.subtitleSaved(l10n.videosLabel(state.savedCount)),
      'local' => l10n.subtitleLocal(
        l10n.mp4FilesLabel(state.localCount),
        onDeviceLocation(l10n),
      ),
      'rss' =>
        state.rssChannel == null && state.search.trim().isEmpty
            ? l10n.subtitleRssAll(l10n.videosLabel(state.rssHistoryCount))
            : l10n.subtitleRssFiltered(
                l10n.videosLabel(state.visible.length),
                '${state.rssHistoryCount}',
              ),
      'channels' => l10n.subtitleChannels(
        l10n.subscriptionsLabel(state.channels.length),
      ),
      _ => l10n.subtitleLatest(
        l10n.channelsLabel(state.latestCount),
        l10n.newLabel(state.newCount),
      ),
    };

String? _errorMessage(AppLocalizations l10n, AppState state) {
  if (state.refreshFailures > 0) {
    return l10n.channelsNotUpdated(state.refreshFailures);
  }
  return state.error;
}

enum _CompactAction {
  markSeen,
  local,
  rss,
  searchChannel,
  importCsv,
  settings,
  updates,
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    required this.width,
    required this.onOpenImport,
    required this.onSearchChannel,
    required this.onOpenSettings,
    required this.onOpenUpdates,
    required this.onSelect,
    this.onClose,
    this.showUpdates = true,
  });

  final AppState state;
  final double width;
  final VoidCallback onOpenImport;
  final VoidCallback onSearchChannel;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenUpdates;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClose;
  final bool showUpdates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: width,
      color: ExpeditusColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
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
                const Expanded(
                  child: Text(
                    'EXPEDITUS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    tooltip: l10n.closeMenu,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavItem(
                    key: const Key('nav-latest'),
                    label: l10n.navLatest,
                    icon: Icons.bolt_rounded,
                    count: state.latestCount,
                    selected: state.view == 'latest',
                    onTap: () => onSelect('latest'),
                  ),
                  _NavItem(
                    key: const Key('nav-new'),
                    label: l10n.navNew,
                    icon: Icons.fiber_new_rounded,
                    count: state.newCount,
                    selected: state.view == 'new',
                    onTap: () => onSelect('new'),
                  ),
                  KeyedSubtree(
                    key: const Key('nav-watch-later'),
                    child: _NavItem(
                      key: const Key('nav-queue'),
                      label: l10n.navWatchLater,
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
                    label: l10n.navSaved,
                    icon: Icons.download_done_rounded,
                    count: state.savedCount,
                    selected: state.view == 'saved',
                    onTap: () => onSelect('saved'),
                  ),
                  _NavItem(
                    key: const Key('nav-local'),
                    label: l10n.navLocal,
                    icon: Icons.video_file_outlined,
                    count: state.localCount,
                    selected: state.view == 'local',
                    onTap: () => onSelect('local'),
                  ),
                  _NavItem(
                    key: const Key('nav-rss-history'),
                    label: l10n.navRss,
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
                    label: l10n.navChannels,
                    icon: Icons.subscriptions_outlined,
                    count: state.channels.length,
                    selected: state.view == 'channels',
                    onTap: () => onSelect('channels'),
                  ),
                  // In the compact drawer these two actions live in the
                  // app bar (import) and its overflow menu (channel search).
                  if (onClose == null) ...[
                    _NavItem(
                      key: const Key('nav-import'),
                      label: l10n.navImport,
                      icon: Icons.add_circle_outline_rounded,
                      onTap: onOpenImport,
                    ),
                    _NavItem(
                      key: const Key('nav-channel-search'),
                      label: l10n.navSearchChannel,
                      icon: Icons.person_search_rounded,
                      onTap: onSearchChannel,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showUpdates)
            TextButton.icon(
              key: const Key('nav-updates'),
              onPressed: onOpenUpdates,
              icon: Icon(
                state.hasUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.system_update_alt_outlined,
                size: 18,
                color: state.hasUpdate ? ExpeditusColors.accent : null,
              ),
              label: Text(
                state.hasUpdate && state.latestRelease != null
                    ? l10n.updateNavPrompt(
                        'v${state.latestRelease!.version.canonical}',
                      )
                    : l10n.navUpdates,
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: state.hasUpdate
                    ? ExpeditusColors.accent
                    : ExpeditusColors.muted,
              ),
            ),
          TextButton.icon(
            key: const Key('settings-button'),
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(l10n.navSettings),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: ExpeditusColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              l10n.sidebarTagline,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: selected ? ExpeditusColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? ExpeditusColors.accent
                    : ExpeditusColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? ExpeditusColors.text
                        : ExpeditusColors.textDim,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
    required this.onAddLocalVideos,
    required this.onMarkAllSeen,
  });

  final AppState state;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final VoidCallback onImport;
  final VoidCallback onAddLocalVideos;
  final VoidCallback onMarkAllSeen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _titleForView(l10n, state.view);
    final subtitle = _subtitleForView(l10n, state);

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
              state.view != 'rss' &&
              state.view != 'local') ...[
            TextButton(onPressed: onMarkAllSeen, child: Text(l10n.markAllRead)),
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
              child: _SearchBar(
                state: state,
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onSearch,
                onClear: onClearSearch,
              ),
            ),
          ),
          if (state.view != 'local') ...[
            const SizedBox(width: 8),
            IconButton(
              key: const Key('refresh-button'),
              tooltip: l10n.refreshWithKey,
              onPressed: state.refreshing ? null : onRefresh,
              icon: state.refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
          const SizedBox(width: 2),
          if (state.view == 'local')
            FilledButton.icon(
              key: const Key('add-local-video-button'),
              onPressed: onAddLocalVideos,
              icon: const Icon(Icons.video_library_outlined, size: 18),
              label: Text(l10n.addVideo),
            )
          else
            FilledButton.icon(
              key: const Key('import-button'),
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.importAction),
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
    required this.compact,
    required this.onSelect,
    required this.onPlay,
    required this.onKey,
    required this.onChannelTap,
    required this.onAddLocalVideos,
    required this.onRefresh,
  });

  final AppState state;
  final FocusNode listFocus;
  final ScrollController scrollController;
  final bool compact;
  final VoidCallback onSelect;
  final Future<void> Function(VideoItem) onPlay;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final ValueChanged<String> onChannelTap;
  final VoidCallback onAddLocalVideos;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final showFilter = state.view == 'rss' && state.rssHistory.isNotEmpty;
    final filter = showFilter
        ? _RssChannelFilter(
            state: state,
            compact: compact,
            onSelect: (channelId) {
              state.setRssChannel(channelId);
              WidgetsBinding.instance.addPostFrameCallback((_) => onSelect());
            },
          )
        : null;

    if (state.visible.isEmpty) {
      if (filter == null) {
        return _RefreshableEmpty(
          onRefresh: onRefresh,
          child: _EmptyState(
            state: state,
            compact: compact,
            onAddLocalVideos: onAddLocalVideos,
          ),
        );
      }
      return Column(
        children: [
          filter,
          Expanded(
            child: _RefreshableEmpty(
              onRefresh: onRefresh,
              child: _EmptyState(
                state: state,
                compact: compact,
                onAddLocalVideos: onAddLocalVideos,
              ),
            ),
          ),
        ],
      );
    }

    final list = Focus(
      focusNode: listFocus,
      onKeyEvent: onKey,
      child: Scrollbar(
        controller: scrollController,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: state.view == 'rss' ? _buildRssList() : _buildFlatList(),
        ),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 28),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 28),
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
      compact: compact,
      selected: index == state.selected,
      hideDescription: state.hideDescriptions,
      onTap: () {
        state.select(index);
        onSelect();
      },
      onPlay: () {
        state.select(index);
        onPlay(video);
      },
      onToggleWatched: video.isLocal ? null : () => state.toggleWatched(video),
      onToggleQueued: video.isLocal ? null : () => state.toggleQueued(video),
      onChannelTap: video.isLocal ? null : () => onChannelTap(video.channelId),
      onRemove: video.isLocal ? () => state.removeLocalVideo(video) : null,
      showWatchLaterDate: state.view == 'queue' || state.view == 'watch-later',
      showAddedDate: video.isLocal,
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
    final l10n = context.l10n;
    final title = entry.title.trim().isEmpty ? entry.channelId : entry.title;
    final color = videoChannelColor(entry.channelId);
    return Container(
      key: ValueKey('rss-group-${entry.channelId}'),
      constraints: const BoxConstraints(minHeight: _rssHeaderHeight),
      padding: const EdgeInsets.fromLTRB(26, 14, 24, 8),
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
            l10n.videosLabel(entry.count),
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
  const _RssChannelFilter({
    required this.state,
    required this.compact,
    required this.onSelect,
  });

  final AppState state;
  final bool compact;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
    final matching = state.search.trim().isEmpty ? total : state.visible.length;

    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const Key('rss-channel-filter'),
        value: selectedId ?? '',
        isDense: true,
        isExpanded: true,
        dropdownColor: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        style: const TextStyle(color: ExpeditusColors.text, fontSize: 12.5),
        icon: const Icon(
          Icons.expand_more_rounded,
          size: 18,
          color: ExpeditusColors.muted,
        ),
        selectedItemBuilder: (context) => [
          Text(
            l10n.allChannelsWithCount(total),
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
              l10n.allChannelsWithCount(total),
              key: const Key('rss-channel-option-all'),
            ),
          ),
          for (final summary in items)
            DropdownMenuItem<String>(
              value: summary.channelId,
              child: Text(
                '${_summaryLabel(summary)} (${summary.count})',
                key: ValueKey('rss-channel-option-${summary.channelId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) =>
            onSelect(value == null || value.isEmpty ? null : value),
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ExpeditusColors.border)),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            const Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: ExpeditusColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.channelFilterLabel,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 260, child: dropdown),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected == null
                    ? l10n.rssChannelSummary(
                        l10n.channelsLabel(summaries.length),
                        l10n.videosLabel(matching),
                      )
                    : l10n.rssSelectedSummary(
                        l10n.videosLabel(state.visible.length),
                        _summaryLabel(selected),
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ),
          ] else
            Expanded(child: dropdown),
        ],
      ),
    );
  }

  static String _summaryLabel(RssChannelSummary summary) {
    return summary.title.trim().isEmpty ? summary.channelId : summary.title;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.state,
    required this.compact,
    required this.onAddLocalVideos,
  });

  final AppState state;
  final bool compact;
  final VoidCallback onAddLocalVideos;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = state.search.trim().isNotEmpty;
    final local = state.view == 'local';
    final noChannels = state.channels.isEmpty;
    final title = filtered
        ? l10n.emptyNoResults
        : local
        ? l10n.emptyNoLocalVideos
        : noChannels
        ? l10n.emptyInbox
        : state.view == 'new'
        ? l10n.emptyCaughtUp
        : state.view == 'queue' || state.view == 'watch-later'
        ? l10n.emptyWatchLater
        : state.view == 'saved'
        ? l10n.emptyNoSaved
        : l10n.emptyNoVideos;
    final message = filtered
        ? local
              ? l10n.emptyNoResultsLocalBody
              : l10n.emptyNoResultsBody
        : local
        ? l10n.emptyNoLocalVideosBody(fromDeviceLocation(l10n))
        : noChannels
        ? l10n.emptyInboxBody
        : state.view == 'queue' || state.view == 'watch-later'
        ? (compact
              ? l10n.emptyWatchLaterBodyCompact
              : l10n.emptyWatchLaterBodyDesktop)
        : state.view == 'saved'
        ? l10n.emptyNoSavedBody
        : state.view == 'rss'
        ? l10n.emptyRssBody
        : l10n.emptyNoNewBody;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                local
                    ? Icons.video_file_outlined
                    : noChannels
                    ? Icons.inbox_outlined
                    : Icons.check_circle_outline,
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
              if (local) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('empty-add-local-button'),
                  onPressed: onAddLocalVideos,
                  icon: const Icon(Icons.video_library_outlined, size: 18),
                  label: Text(l10n.addMp4Button),
                ),
              ] else if (noChannels) ...[
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
                            l10n.channelsImportedCount(result.added),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.importSubscriptions),
                ),
              ],
              if (!compact && !local && !noChannels && !filtered) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.keyboardHint,
                  style: TextStyle(
                    color: ExpeditusColors.muted.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.state,
    required this.onOpenUpdates,
    this.showUpdates = true,
  });

  final AppState state;
  final VoidCallback onOpenUpdates;
  final bool showUpdates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ExpeditusColors.border)),
        color: ExpeditusColors.surface,
      ),
      child: Row(
        children: [
          Text(
            l10n.subtitleLatest(
              l10n.channelsLabel(state.channels.length),
              l10n.newLabel(state.newCount),
            ),
            style: const TextStyle(color: ExpeditusColors.muted, fontSize: 11),
          ),
          if (_errorMessage(l10n, state) != null) ...[
            const SizedBox(width: 12),
            const Icon(
              Icons.warning_amber_rounded,
              size: 13,
              color: ExpeditusColors.red,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _errorMessage(l10n, state)!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ExpeditusColors.red,
                  fontSize: 11,
                ),
              ),
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
            Text(
              l10n.statusUpdating,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 11,
              ),
            ),
          ] else
            Text(
              l10n.statusUpdated(relativeTime(context, state.lastRefresh)),
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 11,
              ),
            ),
          if (!isMobilePlatform) ...[
            const SizedBox(width: 16),
            Text(
              l10n.statusShortcuts,
              style: TextStyle(
                color: ExpeditusColors.muted.withValues(alpha: 0.55),
                fontSize: 10.5,
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 12, color: ExpeditusColors.border),
            const SizedBox(width: 10),
          ] else
            const SizedBox(width: 10),
          if (showUpdates)
            Tooltip(
              message: state.hasUpdate
                  ? l10n.updateAvailableTooltip(
                      'v${state.latestRelease!.version.canonical}',
                    )
                  : l10n.navUpdates,
              child: InkWell(
                key: const Key('updates-button'),
                onTap: onOpenUpdates,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.updateChecking)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else if (state.hasUpdate)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: ExpeditusColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (state.updateChecking || state.hasUpdate)
                        const SizedBox(width: 6),
                      Text(
                        'v${state.currentVersion.canonical}',
                        key: const Key('app-version'),
                        style: TextStyle(
                          color: state.hasUpdate
                              ? ExpeditusColors.accent
                              : ExpeditusColors.muted,
                          fontSize: 10.5,
                          fontWeight: state.hasUpdate
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (state.hasUpdate) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.system_update_alt_rounded,
                          size: 12,
                          color: ExpeditusColors.accent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final AppState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          key: const Key('search-field'),
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: state.view == 'local'
                ? l10n.searchLocalHint
                : l10n.searchSubscriptionsHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 48,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('search-clear'),
                    tooltip: l10n.clearSearch,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
          ),
        );
      },
    );
  }
}

class _CompactSearch extends StatelessWidget {
  const _CompactSearch({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onClear,
  });

  final AppState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _SearchBar(
        state: state,
        controller: controller,
        focusNode: focusNode,
        onChanged: onSearch,
        onClear: onClear,
      ),
    );
  }
}

class _CompactError extends StatelessWidget {
  const _CompactError({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function({bool force}) onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: ExpeditusColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ExpeditusColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: ExpeditusColors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ExpeditusColors.red,
                  fontSize: 11.5,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.retry,
              onPressed: () => onRefresh(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNavBar extends StatelessWidget {
  const _CompactNavBar({
    required this.state,
    required this.onSelect,
    required this.onMore,
  });

  final AppState state;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  static int _indexFor(String view) => switch (view) {
    'latest' => 0,
    'new' => 1,
    'queue' || 'watch-later' => 2,
    'channels' => 3,
    _ => 4,
  };

  static Widget _counted(IconData icon, int count) {
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NavigationBar(
      selectedIndex: _indexFor(state.view),
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            onSelect('latest');
          case 1:
            onSelect('new');
          case 2:
            onSelect('queue');
          case 3:
            onSelect('channels');
          default:
            onMore();
        }
      },
      destinations: [
        NavigationDestination(
          key: const Key('mobile-nav-latest'),
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt_rounded),
          label: l10n.navLatest,
        ),
        NavigationDestination(
          key: const Key('mobile-nav-new'),
          icon: _counted(Icons.fiber_new_outlined, state.newCount),
          selectedIcon: _counted(Icons.fiber_new_rounded, state.newCount),
          label: l10n.navNew,
        ),
        NavigationDestination(
          key: const Key('mobile-nav-queue'),
          icon: _counted(Icons.watch_later_outlined, state.watchLaterCount),
          selectedIcon: _counted(
            Icons.watch_later_rounded,
            state.watchLaterCount,
          ),
          label: l10n.mobileQueueShort,
        ),
        NavigationDestination(
          key: const Key('mobile-nav-channels'),
          icon: const Icon(Icons.subscriptions_outlined),
          selectedIcon: const Icon(Icons.subscriptions_rounded),
          label: l10n.navChannels,
        ),
        NavigationDestination(
          key: const Key('mobile-nav-more'),
          icon: Icon(Icons.more_horiz_rounded),
          label: l10n.navMore,
        ),
      ],
    );
  }
}

class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}
