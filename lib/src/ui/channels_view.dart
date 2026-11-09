import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import 'import_dialog.dart';

class ChannelsView extends StatelessWidget {
  const ChannelsView({
    super.key,
    required this.state,
    required this.onOpenChannel,
  });

  final AppState state;
  final ValueChanged<String> onOpenChannel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.subscriptions_outlined,
              size: 42,
              color: ExpeditusColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noChannelsTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noChannelsBody,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final result = await showDialog<ImportResult>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ImportDialog(state: state),
                );
                if (result != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.channelsImportedCount(result.added)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.importSubscriptions),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: state.channels.length,
      itemBuilder: (context, index) {
        final channel = state.channels[index];
        return _ChannelRow(
          channel: channel,
          onMute: () => state.toggleMute(channel.id),
          onToggleShow: () => state.toggleShowInLatest(channel.id),
          onDelete: () => _confirmDelete(context, channel),
          onOpen: () => onOpenChannel(channel.id),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Channel channel) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ExpeditusColors.surface,
        title: Text(l10n.deleteChannelTitle),
        content: Text(l10n.deleteChannelBody(channel.displayTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.deleteChannel(channel.id);
    }
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.onMute,
    required this.onToggleShow,
    required this.onDelete,
    required this.onOpen,
  });

  final Channel channel;
  final VoidCallback onMute;
  final VoidCallback onToggleShow;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = channel.lastChecked == null
        ? l10n.relativeNever
        : l10n.updatedRelative(
            relativeTime(
              context,
              DateTime.fromMillisecondsSinceEpoch(channel.lastChecked!),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        key: ValueKey('channel-row-${channel.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ExpeditusColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ExpeditusColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  color: channel.muted
                      ? ExpeditusColors.muted
                      : ExpeditusColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: channel.muted
                            ? ExpeditusColors.muted
                            : ExpeditusColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${channel.id} · $last',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (channel.error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExpeditusColors.red,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: channel.muted ? l10n.unmuteTooltip : l10n.muteTooltip,
                child: Switch(
                  value: !channel.muted,
                  onChanged: (_) => onMute(),
                  activeThumbColor: ExpeditusColors.accent,
                ),
              ),
              IconButton(
                tooltip: l10n.removeTooltip,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
