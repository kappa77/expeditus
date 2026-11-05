import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../util/format.dart';

class VideoRow extends StatefulWidget {
  const VideoRow({
    super.key,
    required this.video,
    required this.selected,
    required this.hideDescription,
    required this.onTap,
    required this.onPlay,
    required this.onToggleWatched,
    required this.onToggleQueued,
    this.onChannelTap,
  });

  final VideoItem video;
  final bool selected;
  final bool hideDescription;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;
  final VoidCallback onToggleQueued;
  final VoidCallback? onChannelTap;

  @override
  State<VideoRow> createState() => _VideoRowState();
}

class _VideoRowState extends State<VideoRow> {
  bool _hovered = false;

  static const _rowHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final accent = _channelColor(video.channelId);
    final dimmed = video.isWatched;
    final showDescription =
        !widget.hideDescription && video.description.trim().isNotEmpty;

    return SizedBox(
      height: _rowHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          key: ValueKey('video-row-${video.id}'),
          onTap: widget.onTap,
          hoverColor: ExpeditusColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? ExpeditusColors.surfaceAlt
                  : _hovered
                      ? ExpeditusColors.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.selected
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
                              message: 'Apri canale',
                              child: InkWell(
                                key: ValueKey(
                                  'channel-link-${video.channelId}',
                                ),
                                onTap: widget.onChannelTap,
                                borderRadius: BorderRadius.circular(3),
                                child: Text(
                                  video.channelTitle.toUpperCase(),
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
                            relativeTime(video.published),
                            style: const TextStyle(
                              color: ExpeditusColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.title,
                        maxLines: 1,
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
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (video.queued)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(
                          Icons.bookmark_rounded,
                          size: 14,
                          color: ExpeditusColors.accent,
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
                    if (_hovered || widget.selected)
                      InkResponse(
                        onTap: widget.onPlay,
                        radius: 18,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: ExpeditusColors.accent,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 30),
                    if (_hovered)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniAction(
                            tooltip: 'Segna visto',
                            icon: video.isWatched
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            onTap: widget.onToggleWatched,
                          ),
                          _MiniAction(
                            tooltip: video.queued ? 'Togli dalla coda' : 'In coda',
                            icon: video.queued
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            onTap: widget.onToggleQueued,
                          ),
                        ],
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

  static Color _channelColor(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.32, 0.66).toColor();
  }
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
        radius: 14,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 15, color: ExpeditusColors.muted),
        ),
      ),
    );
  }
}
