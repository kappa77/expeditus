import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../util/l10n.dart';

/// Poster shown over the muted local video while the renderer has not
/// confirmed playback yet. It keeps the thumbnail and a play symbol visible so
/// the user can start (or retry) the remote playback.
class CastWaitingCover extends StatelessWidget {
  const CastWaitingCover({
    super.key,
    required this.video,
    required this.deviceName,
    required this.starting,
    required this.firewallRequired,
    required this.firewallBusy,
    required this.onPlay,
    required this.onAllowFirewall,
    required this.onUseLocal,
  });

  final VideoItem video;
  final String deviceName;
  final bool starting;
  final bool firewallRequired;
  final bool firewallBusy;
  final Future<void> Function() onPlay;
  final Future<void> Function() onAllowFirewall;
  final Future<void> Function() onUseLocal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.86),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: ExpeditusColors.surfaceAlt,
                            child: Center(
                              child: Icon(
                                Icons.movie_outlined,
                                size: 48,
                                color: ExpeditusColors.muted.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const ColoredBox(color: Color(0x66000000)),
                        Center(
                          child: SizedBox(
                            width: 82,
                            height: 82,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (starting)
                                  const SizedBox(
                                    width: 82,
                                    height: 82,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: ExpeditusColors.accent,
                                    ),
                                  ),
                                IconButton.filled(
                                  key: const Key('cast-play-button'),
                                  tooltip: l10n.castStartOnDevice,
                                  onPressed: starting
                                      ? null
                                      : () => unawaited(onPlay()),
                                  style: IconButton.styleFrom(
                                    backgroundColor: ExpeditusColors.accent,
                                    foregroundColor: ExpeditusColors.background,
                                    disabledBackgroundColor:
                                        ExpeditusColors.accent,
                                    disabledForegroundColor:
                                        ExpeditusColors.background,
                                    minimumSize: const Size(62, 62),
                                  ),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cast_connected_rounded,
                      size: 15,
                      color: ExpeditusColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        deviceName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExpeditusColors.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  starting
                      ? l10n.castSendingToDevice
                      : l10n.castPlaybackNotStarted,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExpeditusColors.textDim,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.castAudioMuted,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 10.5,
                  ),
                ),
                if (!starting) ...[
                  const SizedBox(height: 4),
                  Text(
                    firewallRequired
                        ? l10n.castFirewallHint
                        : l10n.castNetworkHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: firewallRequired
                          ? ExpeditusColors.red
                          : ExpeditusColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
                if (firewallRequired && !starting) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('cast-allow-firewall'),
                    onPressed: firewallBusy
                        ? null
                        : () => unawaited(onAllowFirewall()),
                    icon: firewallBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_outlined, size: 17),
                    label: Text(
                      firewallBusy
                          ? l10n.castWaitingWindows
                          : l10n.castAllowNetwork,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const Key('cast-use-local'),
                  onPressed: () => unawaited(onUseLocal()),
                  icon: const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(l10n.castPlayHereOnly),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
