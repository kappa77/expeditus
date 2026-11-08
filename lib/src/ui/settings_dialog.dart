import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../version.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.state});

  final AppState state;

  static const _categories = <String, String>{
    'sponsor': 'Sponsor',
    'selfpromo': 'Autopromozione',
    'interaction': 'Like / iscrizione',
    'intro': 'Intro',
    'outro': 'Outro',
    'preview': 'Anteprima',
    'music_offtopic': 'Musica fuori tema',
    'filler': 'Riempitivo',
  };

  static const _intervals = <int>[15, 30, 60, 120, 240];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600 || size.height < 480;
    final content = ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Impostazioni',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Expeditus v$kAppVersion',
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              const _SectionLabel('Lettura'),
              SwitchListTile(
                key: const Key('settings-hide-descriptions'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Nascondi descrizioni'),
                subtitle: const Text(
                  'Mostra solo canale e titolo. Modalità focus.',
                ),
                value: state.hideDescriptions,
                activeThumbColor: ExpeditusColors.accent,
                onChanged: state.setHideDescriptions,
              ),
              const Divider(height: 24),
              const _SectionLabel('Aggiornamento'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                key: const Key('settings-refresh'),
                initialValue: state.refreshMinutes,
                items: [
                  for (final minutes in _intervals)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text('Ogni $minutes minuti'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) state.setRefreshMinutes(value);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Gli RSS di YouTube sono gratuiti e non consumano quota API. '
                'Expeditus controlla i canali in modo scaglionato.',
                style: TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const Divider(height: 24),
              const _SectionLabel('SponsorBlock'),
              SwitchListTile(
                key: const Key('settings-sponsorblock'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Salta gli sponsor'),
                subtitle: const Text(
                  'Segmenti segnalati dalla community. Solo stream diretti.',
                ),
                value: state.sponsorBlockEnabled,
                activeThumbColor: ExpeditusColors.accent,
                onChanged: state.setSponsorBlockEnabled,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in _categories.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: state.sponsorCategories.contains(entry.key),
                      onSelected: state.sponsorBlockEnabled
                          ? (_) => state.toggleSponsorCategory(entry.key)
                          : null,
                      selectedColor: ExpeditusColors.accentSoft,
                      checkmarkColor: ExpeditusColors.accent,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: state.sponsorCategories.contains(entry.key)
                            ? ExpeditusColors.accent
                            : ExpeditusColors.muted,
                      ),
                      side: const BorderSide(color: ExpeditusColors.border),
                      backgroundColor: ExpeditusColors.surfaceAlt,
                    ),
                ],
              ),
              const Divider(height: 24),
              const _SectionLabel('Come funziona'),
              const SizedBox(height: 6),
              const Text(
                'Expeditus non carica il player di YouTube. Risolve lo stream '
                'del video e lo riproduce con libmpv: niente annunci del '
                'player, niente raccomandazioni, niente autoplay. '
                'SponsorBlock copre gli sponsor dentro il video.',
                style: TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La riproduzione dipende da YouTube: se un video non si '
                'apre, usa “Apri su YouTube”. Iscrizioni e stato restano '
                '$onDeviceLabel; l’app contatta YouTube per i feed e GitHub '
                'per controllare le release.',
                style: TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Expeditus',
                    applicationVersion: kAppVersion,
                    applicationLegalese: 'MIT License',
                  ),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Licenze open source'),
                ),
              ),
              const Text(
                'Le licenze dei componenti nativi (libmpv, ANGLE, SQLite) '
                'sono disponibili nella pagina delle licenze.',
                style: TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fatto'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (compact) {
      return Dialog.fullscreen(
        backgroundColor: ExpeditusColors.surface,
        child: SafeArea(child: content),
      );
    }

    return Dialog(
      backgroundColor: ExpeditusColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: content,
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
        letterSpacing: 1.3,
      ),
    );
  }
}
