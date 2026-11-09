import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import '../util/update_error_text.dart';

Future<void> showUpdateDialog(BuildContext context, AppState state) {
  return showDialog<void>(
    context: context,
    builder: (_) => UpdateDialog(state: state),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.state});

  final AppState state;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = widget.state;
      if (state.updateChecking) return;
      final last = state.updateLastCheck;
      if (last == null ||
          DateTime.now().difference(last) >= const Duration(hours: 6)) {
        unawaited(state.checkForUpdates(manual: true));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Dialog(
      key: const Key('update-dialog'),
      backgroundColor: ExpeditusColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final state = widget.state;
            final release = state.latestRelease;
            final asset = usesWindowsInstaller
                ? release?.assetForWindows()
                : null;
            final skipped = state.updateSkipped;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: ExpeditusColors.accentSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          state.hasUpdate
                              ? Icons.system_update_alt_rounded
                              : Icons.system_update_alt_outlined,
                          size: 19,
                          color: ExpeditusColors.accent,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          l10n.updatesTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('update-close'),
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _VersionLine(
                    label: l10n.installedVersion,
                    version: state.currentVersionLabel,
                  ),
                  if (release != null) ...[
                    const SizedBox(height: 4),
                    _VersionLine(
                      label: state.hasUpdate
                          ? l10n.availableVersion
                          : l10n.latestRelease,
                      version: 'v${release.version.canonical}',
                      accent: state.hasUpdate,
                    ),
                  ],
                  if (state.updateChecking) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 12),
                  if (updateErrorMessage(l10n, state) case final message?) ...[
                    _UpdateError(message: message),
                    const SizedBox(height: 10),
                  ],
                  if (state.hasUpdate && release != null) ...[
                    _ReleaseCard(
                      release: release,
                      assetName: asset?.name,
                      assetSize: asset?.size,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (asset != null)
                          FilledButton.icon(
                            key: const Key('update-download'),
                            onPressed: state.updateChecking
                                ? null
                                : () => _open(asset.url),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(l10n.downloadInstaller),
                          )
                        else
                          FilledButton.icon(
                            key: const Key('update-open-release'),
                            onPressed: state.updateChecking
                                ? null
                                : () => _open(release.pageUrl),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: Text(l10n.openRelease),
                          ),
                        OutlinedButton.icon(
                          key: const Key('update-check-now'),
                          onPressed: state.updateChecking
                              ? null
                              : () => state.checkForUpdates(manual: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l10n.checkNow),
                        ),
                        TextButton(
                          key: const Key('update-skip'),
                          onPressed: state.skipUpdateVersion,
                          child: Text(l10n.skipVersion),
                        ),
                      ],
                    ),
                    if (release.pageUrl.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _open(release.pageUrl),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: Text(l10n.releasePage),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      asset != null ? l10n.installerNote : l10n.releasePageNote,
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                  ] else if (skipped && release != null) ...[
                    _SkippedCard(
                      version: 'v${release.version.canonical}',
                      onRestore: state.clearSkippedUpdateVersion,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('update-check-now'),
                        onPressed: state.updateChecking
                            ? null
                            : () => state.checkForUpdates(manual: true),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.checkNow),
                      ),
                    ),
                  ] else if (release == null) ...[
                    const _NotCheckedCard(),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('update-check-now'),
                        onPressed: state.updateChecking
                            ? null
                            : () => state.checkForUpdates(manual: true),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.checkNow),
                      ),
                    ),
                  ] else ...[
                    _UpToDateCard(fromCache: state.updateFromCache),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('update-check-now'),
                        onPressed: state.updateChecking
                            ? null
                            : () => state.checkForUpdates(manual: true),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.checkNow),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastCheckLabel(state, context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _lastCheckLabel(AppState state, BuildContext context) {
    final l10n = context.l10n;
    final last = state.updateLastCheck;
    if (last == null) return l10n.lastCheckNever;
    final relative = relativeTime(context, last);
    return state.updateFromCache
        ? l10n.lastCheckCached(relative)
        : l10n.lastCheck(relative);
  }

  Future<void> _open(String url) async {
    final value = url.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({
    required this.label,
    required this.version,
    this.accent = false,
  });

  final String label;
  final String version;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? ExpeditusColors.accent : ExpeditusColors.text;
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: ExpeditusColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Text(
          version,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, this.assetName, this.assetSize});

  final AppRelease release;
  final String? assetName;
  final int? assetSize;

  @override
  Widget build(BuildContext context) {
    final notes = release.notes.trim();
    final published = release.publishedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  release.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (published != null)
                Text(
                  shortDate(context, published),
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: SelectableText(
                  notes,
                  key: const Key('update-notes'),
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
          if (assetName != null && assetName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: ExpeditusColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assetName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                if (assetSize != null && assetSize! > 0)
                  Text(
                    _formatBytes(assetSize!),
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}

class _NotCheckedCard extends StatelessWidget {
  const _NotCheckedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ExpeditusColors.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              l10n.notCheckedTitle,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpToDateCard extends StatelessWidget {
  const _UpToDateCard({required this.fromCache});

  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: ExpeditusColors.green,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              fromCache ? l10n.upToDateCached : l10n.upToDate,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedCard extends StatelessWidget {
  const _SkippedCard({required this.version, required this.onRestore});

  final String version;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: ExpeditusColors.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              l10n.skippedVersion(version),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            key: const Key('update-restore-skipped'),
            onPressed: () => onRestore(),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }
}

class _UpdateError extends StatelessWidget {
  const _UpdateError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('update-error'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ExpeditusColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ExpeditusColors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: ExpeditusColors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ExpeditusColors.red,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
