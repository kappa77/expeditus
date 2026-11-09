import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'platform.dart';

/// Convenience accessor for the generated localizations.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String onDeviceLocation(AppLocalizations l10n) =>
    isMobilePlatform ? l10n.onPhone : l10n.onComputer;

String fromDeviceLocation(AppLocalizations l10n) =>
    isMobilePlatform ? l10n.fromPhone : l10n.fromComputer;
