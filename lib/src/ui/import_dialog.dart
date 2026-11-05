import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
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
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Google Takeout CSV', extensions: ['csv']),
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
    final maxHeight = MediaQuery.sizeOf(context).height - 48;
    return Dialog(
      key: const Key('import-dialog'),
      backgroundColor: ExpeditusColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final busy = widget.state.importing;
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Importa iscrizioni',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Non serve accedere a Google. Takeout è il modo più pulito: '
                    'Scarica i dati → YouTube → subscriptions.csv.',
                    style: TextStyle(
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
                    tabs: const [
                      Tab(text: 'File Takeout'),
                      Tab(text: 'Incolla canali'),
                      Tab(text: 'Cerca canale'),
                      Tab(text: 'Link video'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SizedBox(
                      height: 360,
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
                  ),
                  if (busy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 8),
                    Text(
                      widget.state.importStatus ?? 'Importazione…',
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
                      const Expanded(
                        child: Text(
                          'Nessun login. La ricerca canali interroga YouTube.',
                          style: TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Chiudi'),
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
}

class _CsvTab extends StatelessWidget {
  const _CsvTab({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.description_outlined,
          size: 36,
          color: ExpeditusColors.muted,
        ),
        const SizedBox(height: 12),
        const Text(
          'Seleziona subscriptions.csv',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Il file che Google prepara in Takeout contiene\nID, URL e nome di ogni canale.',
          textAlign: TextAlign.center,
          style: TextStyle(
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
          label: const Text('Scegli file CSV'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Un canale per riga: handle, URL o ID.',
          style: TextStyle(
            color: ExpeditusColors.muted,
            fontSize: 12,
          ),
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
              hintText: '@mkbhd\n@veritasium\n'
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
            label: const Text('Importa'),
          ),
        ),
      ],
    );
  }
}
