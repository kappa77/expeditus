import '../models/app_update.dart';
import '../util/app_version.dart';
import 'update_feed_client.dart';

/// Testable boundary for the release check.
abstract interface class UpdateChecker {
  Future<UpdateCheckResult> check({
    String? etag,
    String? cachedBody,
    bool bypassCache = false,
  });

  void close();
}

/// Coordinates the feed check and compares the release with the running app.
class UpdateService implements UpdateChecker {
  UpdateService({
    required this.currentVersion,
    UpdateFeedClient? feedClient,
    this.feedUrl = defaultUpdateFeedUrl,
    this.feedToken = defaultUpdateFeedToken,
    DateTime Function()? clock,
  }) : _feed = feedClient ?? UpdateFeedClient(),
       _clock = clock ?? DateTime.now;

  final AppVersion currentVersion;
  final String feedUrl;
  final String feedToken;
  final UpdateFeedClient _feed;
  final DateTime Function() _clock;

  @override
  Future<UpdateCheckResult> check({
    String? etag,
    String? cachedBody,
    bool bypassCache = false,
  }) async {
    final now = _clock();
    try {
      final result = await _feed.fetch(
        feedUrl: feedUrl,
        token: feedToken,
        etag: bypassCache ? null : etag,
        cachedBody: cachedBody,
        clock: _clock,
      );
      final release = result.release;
      return UpdateCheckResult(
        release: release,
        isNewer: release.isNewerThan(currentVersion),
        asset: release.assetForWindows(),
        checkedAt: result.checkedAt,
        fromCache: result.fromCache,
        etag: result.etag,
        rawBody: result.rawBody,
      );
    } on UpdateException catch (error) {
      return UpdateCheckResult(
        checkedAt: now,
        error: error.message,
        failureKind: error.kind,
        statusCode: error.statusCode,
      );
    } on Object catch (error) {
      return UpdateCheckResult(checkedAt: now, error: '$error');
    }
  }

  @override
  void close() => _feed.close();
}
