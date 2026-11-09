import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/l10n.dart';
import '../version.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.state});

  final AppState state;

  static const _intervals = <int>[15, 30, 60, 120, 240];

  static const _languageCodes = <String>['system', 'it', 'en', 'de', 'es'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600 || size.height < 480;
    final categories = <String, String>{
      'sponsor': l10n.sponsorCategorySponsor,
      'selfpromo': l10n.sponsorCategorySelfPromo,
      'interaction': l10n.sponsorCategoryInteraction,
      'intro': l10n.sponsorCategoryIntro,
      'outro': l10n.sponsorCategoryOutro,
      'preview': l10n.sponsorCategoryPreview,
      'music_offtopic': l10n.sponsorCategoryMusicOfftopic,
      'filler': l10n.sponsorCategoryFiller,
    };
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
                  Expanded(
                    child: Text(
                      l10n.settingsTitle,
                      style: const TextStyle(
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
              _SectionLabel(l10n.sectionLanguage),
              DropdownButtonFormField<String>(
                key: const Key('settings-language'),
                initialValue: state.localeCode,
                items: [
                  for (final code in _languageCodes)
                    DropdownMenuItem(
                      value: code,
                      child: Text(_languageLabel(l10n, code)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) state.setLocale(value);
                },
              ),
              const SizedBox(height: 4),
              Text(
                l10n.languageSubtitle,
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const Divider(height: 24),
              _SectionLabel(l10n.sectionReading),
              SwitchListTile(
                key: const Key('settings-hide-descriptions'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.hideDescriptions),
                subtitle: Text(l10n.hideDescriptionsSubtitle),
                value: state.hideDescriptions,
                activeThumbColor: ExpeditusColors.accent,
                onChanged: state.setHideDescriptions,
              ),
              const Divider(height: 24),
              _SectionLabel(l10n.sectionUpdate),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                key: const Key('settings-refresh'),
                initialValue: state.refreshMinutes,
                items: [
                  for (final minutes in _intervals)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(l10n.refreshEvery(minutes)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) state.setRefreshMinutes(value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.rssRefreshNote,
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const Divider(height: 24),
              _SectionLabel(l10n.sectionSponsorBlock),
              SwitchListTile(
                key: const Key('settings-sponsorblock'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.skipSponsors),
                subtitle: Text(l10n.skipSponsorsSubtitle),
                value: state.sponsorBlockEnabled,
                activeThumbColor: ExpeditusColors.accent,
                onChanged: state.setSponsorBlockEnabled,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in categories.entries)
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
              _SectionLabel(l10n.sectionHowItWorks),
              const SizedBox(height: 6),
              Text(
                l10n.howItWorksBody,
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.privacyNote(onDeviceLocation(l10n)),
                style: const TextStyle(
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
                  label: Text(l10n.licensesButton),
                ),
              ),
              Text(
                l10n.licensesNote,
                style: const TextStyle(
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
                  child: Text(l10n.done),
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

  static String _languageLabel(AppLocalizations l10n, String code) =>
      switch (code) {
        'system' => l10n.languageSystem,
        'it' => l10n.languageItalian,
        'de' => l10n.languageGerman,
        'es' => l10n.languageSpanish,
        _ => l10n.languageEnglish,
      };
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
