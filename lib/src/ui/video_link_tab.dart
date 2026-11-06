import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

class VideoLinkTab extends StatefulWidget {
  const VideoLinkTab({super.key, required this.state});

  final AppState state;

  @override
  State<VideoLinkTab> createState() => _VideoLinkTabState();
}

class _VideoLinkTabState extends State<VideoLinkTab> {
  final TextEditingController _link = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final input = _link.text.trim();
    if (input.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final linked = await widget.state.importVideoLink(input);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Aggiunto “${linked.video.title}” e iscritto a ${linked.channel.title}. '
            'Il video è in Guarda più tardi.';
        _link.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Incolla il link di un video YouTube. Expeditus trova il canale, '
          'si iscrive automaticamente e salva il video in Guarda più tardi.',
          style: TextStyle(
            color: ExpeditusColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('video-link-field'),
          controller: _link,
          enabled: !_busy,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _add(),
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=…',
            prefixIcon: Icon(Icons.link_rounded, size: 18),
            prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('video-link-submit'),
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link_rounded, size: 18),
            label: const Text('Aggiungi e iscriviti'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              color: ExpeditusColors.red,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(
            _message!,
            style: const TextStyle(
              color: ExpeditusColors.green,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
