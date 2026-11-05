import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
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
                const SizedBox(height: 28),
                const Text(
                  'Benvenuto.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cerca un canale per nome per iniziare. Puoi anche incollare '
                  'il link di un canale o di un video, oppure importare le '
                  'iscrizioni da Google Takeout.',
                  style: TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Expeditus mostrerà solo l’ultimo video di ogni canale: '
                  'niente raccomandazioni, niente autoplay, niente rumore.',
                  style: TextStyle(
                    color: ExpeditusColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 360,
                  child: ChannelSearchTab(state: state),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openImport(context),
                      icon: const Icon(
                        Icons.file_upload_outlined,
                        size: 17,
                      ),
                      label: const Text('Importa da Google Takeout'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openImport(context, tab: 3),
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: const Text('Aggiungi un video da link'),
                    ),
                    TextButton(
                      onPressed: state.completeOnboarding,
                      child: const Text('Salta per ora'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
