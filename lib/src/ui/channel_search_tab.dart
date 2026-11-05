import 'package:flutter/material.dart';

import '../models.dart';
import '../services/channel_search_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ChannelSearchTab extends StatefulWidget {
  const ChannelSearchTab({super.key, required this.state});

  final AppState state;

  @override
  State<ChannelSearchTab> createState() => _ChannelSearchTabState();
}

class _ChannelSearchTabState extends State<ChannelSearchTab> {
  final ChannelSearchService _service = ChannelSearchService();
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<ChannelSearchResult> _results = const [];
  bool _loading = false;
  String? _error;
  String? _message;
  String? _addingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _service.close();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _results = const [];
    });
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) {
          _message = 'Nessun canale trovato per “$query”.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _add(ChannelSearchResult result) async {
    setState(() {
      _addingId = result.id;
      _error = null;
      _message = null;
    });
    final error = await widget.state.addChannel(
      ImportedChannel(id: result.id, title: result.name),
    );
    if (!mounted) return;
    setState(() {
      _addingId = null;
      if (error == null) {
        _message = '${result.name} aggiunto. Il feed si aggiorna.';
      } else {
        _error = 'Canale aggiunto, ma il feed non è stato aggiornato: $error';
      }
    });
  }

  static String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('429') || lower.contains('limit')) {
      return 'YouTube ha limitato la ricerca. Riprova tra poco.';
    }
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = widget.state.channels
        .map((channel) => channel.id)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('channel-search-field'),
                controller: _query,
                focusNode: _focus,
                enabled: !_loading,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Cerca un canale per parola…',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('channel-search-submit'),
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, size: 17),
              label: const Text('Cerca'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'La ricerca interroga YouTube. Poi aggiungi il canale con un click.',
          style: TextStyle(color: ExpeditusColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _loading
                        ? 'Cerco canali…'
                        : _message ?? 'Scrivi una parola e premi Cerca.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 12,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final isSubscribed = subscribed.contains(result.id);
                    final isAdding = _addingId == result.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 38,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: ExpeditusColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (result.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    result.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ExpeditusColors.muted,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSubscribed)
                            const Padding(
                              padding: EdgeInsets.only(top: 7),
                              child: Text(
                                'Già presente',
                                style: TextStyle(
                                  color: ExpeditusColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          else
                            FilledButton(
                              key: Key('channel-add-${result.id}'),
                              onPressed: isAdding ? null : () => _add(result),
                              child: isAdding
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Aggiungi'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(
              color: ExpeditusColors.red,
              fontSize: 11,
            ),
          ),
        ],
        if (_message != null && _results.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _message!,
            style: const TextStyle(
              color: ExpeditusColors.green,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
