import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/l10n.dart';
import 'channel_search_tab.dart';
import 'video_link_tab.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.state, this.initialTab = 0});

  final AppState state;
  final int initialTab;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _paste = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      initialIndex: widget.initialTab.clamp(0, 3).toInt(),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _pickCsv() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.takeoutCsvType,
          extensions: const ['csv'],
        ),
      ],
    );
    if (file == null) return;
    final content = await file.readAsString();
    if (!mounted) return;
    await _run(() => widget.state.importCsv(content));
  }

  Future<void> _pasteImport() async {
    final lines = _paste.text.split('\n');
    await _run(() => widget.state.importInputs(lines));
  }

  Future<void> _run(Future<ImportResult> Function() action) async {
    final result = await action();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 600 || media.height < 480;
    final maxHeight = media.height - (compact ? 0 : 48);
    final content = _buildContent(context, compact: compact);

    if (compact) {
      return Dialog.fullscreen(
        key: const Key('import-dialog'),
        backgroundColor: ExpeditusColors.surface,
        child: SafeArea(child: content),
      );
    }

    return Dialog(
      key: const Key('import-dialog'),
      backgroundColor: ExpeditusColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: SizedBox(
          height: maxHeight > 620 ? 620 : maxHeight,
          child: content,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final busy = widget.state.importing;
        return PopScope(
          canPop: !busy,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 22,
              compact ? 14 : 20,
              compact ? 18 : 22,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.importSubscriptionsTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.importIntro,
                  style: const TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tabs,
                  labelColor: ExpeditusColors.accent,
                  unselectedLabelColor: ExpeditusColors.muted,
                  indicatorColor: ExpeditusColors.accent,
                  tabs: [
                    Tab(text: l10n.tabTakeout),
                    Tab(text: l10n.tabPaste),
                    Tab(text: l10n.tabSearch),
                    Tab(text: l10n.tabLink),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _CsvTab(busy: busy, onPick: _pickCsv),
                      _PasteTab(
                        busy: busy,
                        controller: _paste,
                        onSubmit: _pasteImport,
                      ),
                      ChannelSearchTab(state: widget.state),
                      VideoLinkTab(state: widget.state),
                    ],
                  ),
                ),
                if (busy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 8),
                  Text(
                    _importStatusLabel(widget.state, l10n),
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: ExpeditusColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        l10n.noLoginNote,
                        style: const TextStyle(
                          color: ExpeditusColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _importStatusLabel(AppState state, AppLocalizations l10n) {
    return switch (state.importPhase) {
      ImportPhase.resolving when state.importTotal > 0 =>
        l10n.importStatusResolvingProgress(
          state.importCurrent,
          state.importTotal,
        ),
      ImportPhase.resolving => l10n.importStatusResolvingChannels,
      ImportPhase.importing => l10n.importStatusImporting,
      ImportPhase.idle => l10n.importingEllipsis,
    };
  }
}

class _CsvTab extends StatelessWidget {
  const _CsvTab({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.description_outlined,
          size: 36,
          color: ExpeditusColors.muted,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.csvSelectTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.csvSelectBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ExpeditusColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('import-csv'),
          onPressed: busy ? null : onPick,
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(l10n.chooseCsvFile),
        ),
      ],
    );
  }
}

class _PasteTab extends StatelessWidget {
  const _PasteTab({
    required this.busy,
    required this.controller,
    required this.onSubmit,
  });

  final bool busy;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pasteInstructions,
          style: const TextStyle(color: ExpeditusColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            key: const Key('import-paste-field'),
            controller: controller,
            enabled: !busy,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
            decoration: const InputDecoration(
              hintText:
                  '@mkbhd\n@veritasium\n'
                  'https://www.youtube.com/@3blue1brown\n'
                  'UCBJycsmduvYEL83R_U4JriQ',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('import-submit'),
            onPressed: busy ? null : onSubmit,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(l10n.importButton),
          ),
        ),
      ],
    );
  }
}
