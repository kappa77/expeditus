import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/l10n.dart';

Future<String?> showBookmarkNoteDialog(
  BuildContext context, {
  String initialNote = '',
}) {
  final controller = TextEditingController(text: initialNote);
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: ExpeditusColors.surface,
        title: Text(l10n.bookmarkDialogTitle),
        content: TextField(
          key: const Key('bookmark-note-field'),
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: l10n.noteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('bookmark-note-save'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}

class VideoOutlineDialog extends StatefulWidget {
  const VideoOutlineDialog({
    super.key,
    required this.video,
    required this.chapters,
    required this.position,
    required this.state,
  });

  final VideoItem video;
  final List<VideoChapter> chapters;
  final Duration position;
  final AppState state;

  @override
  State<VideoOutlineDialog> createState() => _VideoOutlineDialogState();
}

class _VideoOutlineDialogState extends State<VideoOutlineDialog> {
  List<VideoBookmark> _bookmarks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await widget.state.bookmarksForVideo(widget.video.id);
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _loading = false;
    });
  }

  Future<void> _addBookmark() async {
    final note = await showBookmarkNoteDialog(context);
    if (note == null || note.isEmpty) return;
    await widget.state.addBookmark(
      widget.video.id,
      widget.position.inSeconds,
      note,
    );
    await _loadBookmarks();
  }

  Future<void> _deleteBookmark(VideoBookmark bookmark) async {
    await widget.state.deleteBookmark(bookmark.id);
    await _loadBookmarks();
  }

  void _seekTo(int seconds) {
    Navigator.of(context).pop(Duration(seconds: seconds));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return Dialog(
      key: const Key('outline-dialog'),
      backgroundColor: ExpeditusColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chaptersAndBookmarks,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('outline-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_add_outlined,
                          size: 16,
                          color: ExpeditusColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.bookmarkAt(
                              formatDuration(widget.position.inSeconds),
                            ),
                            style: const TextStyle(
                              color: ExpeditusColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('outline-add-bookmark'),
                          onPressed: _addBookmark,
                          child: Text(l10n.addNote),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.chapters.isNotEmpty) ...[
                      _SectionLabel(l10n.chapters),
                      const SizedBox(height: 4),
                      for (var i = 0; i < widget.chapters.length; i++)
                        ListTile(
                          key: Key('outline-chapter-$i'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            formatDuration(widget.chapters[i].startSeconds),
                            style: const TextStyle(
                              color: ExpeditusColors.accent,
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          title: Text(
                            widget.chapters[i].title,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _seekTo(widget.chapters[i].startSeconds),
                        ),
                      const SizedBox(height: 10),
                    ],
                    _SectionLabel(l10n.bookmarks),
                    const SizedBox(height: 4),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_bookmarks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          l10n.noBookmarks,
                          style: const TextStyle(
                            color: ExpeditusColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      for (final bookmark in _bookmarks)
                        ListTile(
                          key: Key('outline-bookmark-${bookmark.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            formatDuration(bookmark.positionSeconds),
                            style: const TextStyle(
                              color: ExpeditusColors.accent,
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          title: Text(
                            bookmark.note,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _seekTo(bookmark.positionSeconds),
                          trailing: IconButton(
                            tooltip: l10n.deleteBookmark,
                            onPressed: () => _deleteBookmark(bookmark),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: ExpeditusColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
