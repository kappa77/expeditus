import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import '../models.dart';
import '../services/channel_search_service.dart';
import '../state/app_state.dart';
import '../util/platform.dart';
import '../theme.dart';
import '../util/l10n.dart';

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
      if (mounted && !isMobilePlatform) _focus.requestFocus();
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
          _message = context.l10n.noChannelFound(query);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e, context.l10n);
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
        _message = context.l10n.channelAddedFeedUpdating(result.name);
      } else {
        _error = context.l10n.channelAddedFeedFailed(error);
      }
    });
  }

  static String _friendlyError(Object error, AppLocalizations l10n) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('429') || lower.contains('limit')) {
      return l10n.searchRateLimited;
    }
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchChannelPlaceholder,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 48,
                  ),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _query.clear();
                            setState(() {
                              _results = const [];
                              _message = null;
                              _error = null;
                            });
                            _focus.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
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
              label: Text(l10n.searchAction),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          isMobilePlatform
              ? l10n.searchExplanationPhone
              : l10n.searchExplanationDesktop,
          style: TextStyle(color: ExpeditusColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _loading
                        ? l10n.searchingChannels
                        : _message ?? l10n.searchPrompt,
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
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                l10n.alreadySubscribed,
                                style: const TextStyle(
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
                                  : Text(l10n.addChannel),
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
            style: const TextStyle(color: ExpeditusColors.red, fontSize: 11),
          ),
        ],
        if (_message != null && _results.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _message!,
            style: const TextStyle(color: ExpeditusColors.green, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
