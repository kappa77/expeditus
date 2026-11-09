import 'package:flutter/material.dart';

import '../models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme.dart';
import '../util/l10n.dart';
import '../util/format.dart';

class VideoRow extends StatefulWidget {
  const VideoRow({
    super.key,
    required this.video,
    required this.selected,
    required this.hideDescription,
    required this.onTap,
    required this.onPlay,
    this.compact = false,
    this.onToggleWatched,
    this.onToggleQueued,
    this.onChannelTap,
    this.onRemove,
    this.showWatchLaterDate = false,
    this.showAddedDate = false,
  });

  final VideoItem video;
  final bool selected;
  final bool hideDescription;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  /// Touch-first layout: the row opens the video and exposes actions through a
  /// 48dp menu (and a long-press sheet) instead of hover-only icons.
  final bool compact;

  final VoidCallback? onToggleWatched;
  final VoidCallback? onToggleQueued;
  final VoidCallback? onChannelTap;
  final VoidCallback? onRemove;

  /// Shows when the video was saved instead of when it was published.
  final bool showWatchLaterDate;

  /// Shows when a local file was added to the library.
  final bool showAddedDate;

  @override
  State<VideoRow> createState() => _VideoRowState();
}

class _VideoRowState extends State<VideoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final video = widget.video;
    final accent = videoChannelColor(video.channelId);
    final dimmed = video.isWatched;
    final showDescription =
        !widget.hideDescription && video.description.trim().isNotEmpty;
    final dateLabel = widget.showWatchLaterDate && video.watchLaterAt != null
        ? l10n.savedRelative(
            relativeTime(
              context,
              DateTime.fromMillisecondsSinceEpoch(video.watchLaterAt!),
            ),
          )
        : widget.showAddedDate
        ? l10n.addedRelative(relativeTime(context, video.published))
        : relativeTime(context, video.published);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: widget.selected && !widget.compact
            ? ExpeditusColors.surfaceAlt
            : _hovered && !widget.compact
            ? ExpeditusColors.surfaceHover
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.selected && !widget.compact
              ? ExpeditusColors.border
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: showDescription ? 58 : 40,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: dimmed ? accent.withValues(alpha: 0.35) : accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: widget.onChannelTap == null
                            ? l10n.localFileLabel
                            : l10n.openChannel,
                        child: InkWell(
                          key: ValueKey('channel-link-${video.channelId}'),
                          onTap: widget.onChannelTap,
                          borderRadius: BorderRadius.circular(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              (video.isLocal
                                      ? l10n.localVideoLabel
                                      : video.channelTitle)
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dimmed
                                    ? ExpeditusColors.muted
                                    : accent.withValues(alpha: 0.95),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (video.isNew) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: ExpeditusColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dimmed
                        ? ExpeditusColors.muted
                        : ExpeditusColors.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (showDescription) ...[
                  const SizedBox(height: 3),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dimmed
                          ? ExpeditusColors.muted.withValues(alpha: 0.65)
                          : ExpeditusColors.muted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (video.isDownloaded && !video.isLocal)
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(
                    Icons.download_done_rounded,
                    size: 14,
                    color: ExpeditusColors.green,
                  ),
                ),
              if (video.watchLater && !video.isLocal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: l10n.navWatchLater,
                    child: const Icon(
                      Icons.watch_later_rounded,
                      size: 14,
                      color: ExpeditusColors.accent,
                    ),
                  ),
                ),
              if (video.durationSeconds != null)
                Text(
                  formatDuration(video.durationSeconds),
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 2),
              if (widget.compact)
                _CompactActionsButton(
                  key: ValueKey('video-actions-${video.id}'),
                  actions: _actions(l10n),
                  tooltip: l10n.videoActions,
                )
              else ...[
                if (_hovered || widget.selected)
                  InkResponse(
                    onTap: widget.onPlay,
                    radius: 20,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 22,
                        color: ExpeditusColors.accent,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 34),
                if (_hovered)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onRemove != null)
                        _MiniAction(
                          tooltip: l10n.removeFromList,
                          icon: Icons.remove_circle_outline_rounded,
                          onTap: widget.onRemove!,
                        )
                      else ...[
                        if (widget.onToggleWatched != null)
                          _MiniAction(
                            tooltip: video.isWatched
                                ? l10n.markUnwatched
                                : l10n.markWatched,
                            icon: video.isWatched
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            onTap: widget.onToggleWatched!,
                          ),
                        if (widget.onToggleQueued != null)
                          _MiniAction(
                            tooltip: video.watchLater
                                ? l10n.removeFromWatchLater
                                : l10n.navWatchLater,
                            icon: video.watchLater
                                ? Icons.watch_later_rounded
                                : Icons.watch_later_outlined,
                            onTap: widget.onToggleQueued!,
                          ),
                      ],
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
    );

    final inkWell = InkWell(
      key: ValueKey('video-row-${video.id}'),
      onTap: widget.compact ? widget.onPlay : widget.onTap,
      onLongPress: widget.compact ? () => _showActionSheet(context) : null,
      hoverColor: widget.compact ? null : ExpeditusColors.surfaceHover,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );

    if (widget.compact) return inkWell;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: inkWell,
    );
  }

  List<(IconData, String, VoidCallback)> _actions(AppLocalizations l10n) {
    final video = widget.video;
    return [
      (Icons.play_arrow_rounded, l10n.playAction, widget.onPlay),
      if (widget.onToggleWatched != null)
        (
          video.isWatched
              ? Icons.check_circle_rounded
              : Icons.check_circle_outline_rounded,
          video.isWatched ? l10n.markUnwatched : l10n.markWatched,
          widget.onToggleWatched!,
        ),
      if (widget.onToggleQueued != null)
        (
          video.watchLater
              ? Icons.watch_later_rounded
              : Icons.watch_later_outlined,
          video.watchLater ? l10n.removeFromWatchLater : l10n.navWatchLater,
          widget.onToggleQueued!,
        ),
      if (widget.onChannelTap != null)
        (Icons.podcasts_rounded, l10n.openChannel, widget.onChannelTap!),
      if (widget.onRemove != null)
        (
          Icons.remove_circle_outline_rounded,
          l10n.removeFromList,
          widget.onRemove!,
        ),
    ];
  }

  void _showActionSheet(BuildContext context) {
    final actions = _actions(context.l10n);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final action in actions)
                ListTile(
                  leading: Icon(action.$1),
                  title: Text(action.$2),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.$3();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactActionsButton extends StatelessWidget {
  const _CompactActionsButton({
    super.key,
    required this.actions,
    required this.tooltip,
  });

  final List<(IconData, String, VoidCallback)> actions;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 210),
      onSelected: (index) => actions[index].$3(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(actions[i].$1, size: 19),
                const SizedBox(width: 12),
                Expanded(child: Text(actions[i].$2)),
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

Color videoChannelColor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.32, 0.66).toColor();
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: ExpeditusColors.muted),
        ),
      ),
    );
  }
}
