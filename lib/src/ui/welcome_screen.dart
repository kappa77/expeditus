import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/l10n.dart';
import 'channel_search_tab.dart';
import 'import_dialog.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  Future<void> _openImport(BuildContext context, {int tab = 0}) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(state: state, initialTab: tab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700 || size.height < 480;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 20 : 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: ExpeditusColors.accent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.inbox_rounded,
                          color: ExpeditusColors.background,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'EXPEDITUS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 22 : 28),
                  Text(
                    l10n.welcomeTitle,
                    style: TextStyle(
                      fontSize: compact ? 28 : 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeBody,
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.welcomePhilosophy,
                    style: const TextStyle(
                      color: ExpeditusColors.muted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Keep the alternatives visible above the fold on a phone:
                  // the search area itself needs a bounded height and would
                  // otherwise push these actions off screen.
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openImport(context),
                        icon: const Icon(Icons.file_upload_outlined, size: 17),
                        label: Text(l10n.welcomeImportTakeout),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openImport(context, tab: 3),
                        icon: const Icon(Icons.link_rounded, size: 17),
                        label: Text(l10n.welcomeAddVideoLink),
                      ),
                      TextButton(
                        onPressed: state.completeOnboarding,
                        child: Text(l10n.welcomeSkip),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    compact
                        ? l10n.welcomeSearchHeadingCompact
                        : l10n.welcomeSearchHeading,
                    style: const TextStyle(
                      color: ExpeditusColors.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: compact ? 300 : 340,
                    child: ChannelSearchTab(state: state),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
