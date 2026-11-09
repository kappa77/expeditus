import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/app_update.dart';
import '../state/app_state.dart';

/// Localizes the last update-check failure and keeps raw technical details as
/// a last-resort fallback.
String? updateErrorMessage(AppLocalizations l10n, AppState state) {
  final raw = state.updateError?.trim();
  final hasRaw = raw != null && raw.isNotEmpty;
  final kind = state.updateErrorKind;
  if (kind != null) {
    return switch (kind) {
      UpdateFailureKind.network => l10n.updateErrorNetwork,
      UpdateFailureKind.rateLimited => l10n.updateErrorRateLimited,
      UpdateFailureKind.unauthorized => l10n.updateErrorUnauthorized,
      UpdateFailureKind.notFound => l10n.updateErrorNotFound,
      UpdateFailureKind.invalidFeed => l10n.updateErrorInvalidFeed,
      UpdateFailureKind.server =>
        state.updateErrorStatus == null
            ? l10n.updateCheckFailed
            : l10n.updateErrorServer('${state.updateErrorStatus}'),
    };
  }
  return switch (state.updateErrorOperation) {
    UpdateErrorOperation.saveState =>
      hasRaw ? l10n.updateStateSaveFailed(raw) : l10n.updateCheckFailed,
    UpdateErrorOperation.saveSkipped =>
      hasRaw ? l10n.updateSkipSaveFailed(raw) : l10n.updateCheckFailed,
    UpdateErrorOperation.restoreSkipped =>
      hasRaw ? l10n.updateRestoreFailed(raw) : l10n.updateCheckFailed,
    UpdateErrorOperation.check =>
      hasRaw ? l10n.updateCheckFailedDetails(raw) : null,
  };
}

/// Exposed for tests that exercise the mapping without a widget tree.
@visibleForTesting
String updateKindMessage(AppLocalizations l10n, UpdateFailureKind kind) {
  return switch (kind) {
    UpdateFailureKind.network => l10n.updateErrorNetwork,
    UpdateFailureKind.rateLimited => l10n.updateErrorRateLimited,
    UpdateFailureKind.unauthorized => l10n.updateErrorUnauthorized,
    UpdateFailureKind.notFound => l10n.updateErrorNotFound,
    UpdateFailureKind.invalidFeed => l10n.updateErrorInvalidFeed,
    UpdateFailureKind.server => l10n.updateCheckFailed,
  };
}
