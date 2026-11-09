import '../../l10n/generated/app_localizations.dart';
import '../state/cast_controller.dart';

/// Turns a structured cast failure into a localized message.
String castFailureText(AppLocalizations l10n, CastFailure failure) {
  final details = failure.details?.trim();
  final hasDetails = details != null && details.isNotEmpty;
  final deviceName = failure.deviceName?.trim();
  final hasDevice = deviceName != null && deviceName.isNotEmpty;
  return switch (failure.kind) {
    CastFailureKind.connect =>
      hasDevice && hasDetails
          ? l10n.castConnectFailedDetails(deviceName, details)
          : l10n.castConnectFailed,
    CastFailureKind.send =>
      hasDevice && hasDetails
          ? l10n.castSendFailedDetails(deviceName, details)
          : l10n.castSendFailed,
    CastFailureKind.discovery =>
      hasDetails
          ? l10n.castDiscoveryFailedDetails(details)
          : l10n.castSearching,
    CastFailureKind.action =>
      hasDetails ? l10n.castActionFailedDetails(details) : l10n.castSendFailed,
    CastFailureKind.firewallDenied => l10n.castFirewallDenied,
    CastFailureKind.networkProfile => l10n.castNetworkProfileFailed,
    CastFailureKind.unresponsive => l10n.castUnresponsive,
    CastFailureKind.noStream => l10n.castNoStream,
  };
}
