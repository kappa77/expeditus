import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_update.dart';

const defaultUpdateFeedUrl = String.fromEnvironment(
  'UPDATE_FEED_URL',
  defaultValue:
      'https://api.github.com/repos/kappa77/expeditus/releases/latest',
);

const defaultUpdateFeedToken = String.fromEnvironment(
  'UPDATE_FEED_TOKEN',
  defaultValue: '',
);

/// Result of reading the release feed.
class UpdateFeedResult {
  const UpdateFeedResult({
    required this.release,
    required this.checkedAt,
    this.etag,
    this.rawBody,
    this.fromCache = false,
  });

  final AppRelease release;
  final DateTime checkedAt;
  final String? etag;
  final String? rawBody;

  /// True when the network failed (or the feed answered `304`) and the local
  /// copy was used.
  final bool fromCache;
}

/// Reads GitHub's `releases/latest` response.
///
/// The check is read-only and needs no token for the public Expeditus repo.
/// A token can still be supplied at build time for forks or private feeds.
class UpdateFeedClient {
  UpdateFeedClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const _maxBodyBytes = 2 * 1024 * 1024;
  static const _userAgent = 'Expeditus-Updater/1.0';

  Future<UpdateFeedResult> fetch({
    required String feedUrl,
    String? token,
    String? etag,
    String? cachedBody,
    DateTime Function()? clock,
  }) async {
    final uri = _validateUri(feedUrl);
    final now = (clock ?? DateTime.now)();
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': _userAgent,
    };
    if (uri.host == 'api.github.com') {
      headers['X-GitHub-Api-Version'] = '2022-11-28';
    }
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    if (etag != null && etag.trim().isNotEmpty) {
      headers['If-None-Match'] = etag.trim();
    }

    http.Response response;
    try {
      response = await _getFollowingSafeRedirects(uri, headers, token);
    } on TimeoutException {
      return _fallback(
        cachedBody,
        now,
        etag,
        'The update server is not responding.',
      );
    } on UpdateException {
      rethrow;
    } on Object catch (error) {
      return _fallback(
        cachedBody,
        now,
        etag,
        'Could not contact the update server: $error',
      );
    }

    if (response.statusCode == 304) {
      return _fallback(
        cachedBody,
        now,
        etag,
        'The feed did not change but there is no valid local copy.',
      );
    }

    if (response.statusCode == 401) {
      throw const UpdateException(
        'The update feed rejected the credentials (401).',
        kind: UpdateFailureKind.unauthorized,
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      final remaining = response.headers['x-ratelimit-remaining'];
      if (remaining == '0') {
        throw const UpdateException(
          'Too many GitHub requests for the update check. Try again later.',
          kind: UpdateFailureKind.rateLimited,
          statusCode: 403,
        );
      }
      throw const UpdateException(
        'GitHub rejected the update check (403).',
        kind: UpdateFailureKind.unauthorized,
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw const UpdateException(
        'No release found. The repository may not have published any releases yet.',
        kind: UpdateFailureKind.notFound,
        statusCode: 404,
      );
    }
    if (response.statusCode == 429) {
      throw const UpdateException(
        'Too many requests to the update server (429): try again later.',
        kind: UpdateFailureKind.rateLimited,
        statusCode: 429,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateException(
        'The update server responded ${response.statusCode}.',
        kind: response.statusCode >= 500
            ? UpdateFailureKind.server
            : UpdateFailureKind.invalidFeed,
        statusCode: response.statusCode,
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.length > _maxBodyBytes) {
      throw const UpdateException(
        'The update feed response is too large.',
        kind: UpdateFailureKind.invalidFeed,
      );
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    final release = AppRelease.fromJsonString(body);
    if (release == null) {
      throw const UpdateException(
        'The update feed response is not a valid release.',
        kind: UpdateFailureKind.invalidFeed,
      );
    }
    return UpdateFeedResult(
      release: release,
      checkedAt: now,
      etag: response.headers['etag'],
      rawBody: body,
    );
  }

  Future<http.Response> _getFollowingSafeRedirects(
    Uri uri,
    Map<String, String> headers,
    String? token,
  ) async {
    var current = uri;
    var currentHeaders = Map<String, String>.from(headers);
    var redirects = 0;
    while (true) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(currentHeaders);
      final streamed = await _http.send(request).timeout(timeout);
      if (!_isRedirect(streamed.statusCode)) {
        return http.Response.fromStream(streamed);
      }
      if (redirects++ >= 5) {
        await _discard(streamed);
        throw const UpdateException(
          'Too many redirects in the update feed.',
          kind: UpdateFailureKind.invalidFeed,
        );
      }
      final location = streamed.headers['location'];
      await _discard(streamed);
      if (location == null || location.trim().isEmpty) {
        throw const UpdateException(
          'Redirect without a destination in the update feed.',
          kind: UpdateFailureKind.invalidFeed,
        );
      }
      final next = _validateUri(current.resolve(location.trim()).toString());
      if (next.host.toLowerCase() != current.host.toLowerCase()) {
        currentHeaders = Map<String, String>.from(currentHeaders)
          ..remove('Authorization');
      } else if (token != null && token.trim().isNotEmpty) {
        currentHeaders['Authorization'] = 'Bearer ${token.trim()}';
      }
      current = next;
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static Future<void> _discard(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } on Object {
      // Ignore a broken redirect body.
    }
  }

  UpdateFeedResult _fallback(
    String? cachedBody,
    DateTime now,
    String? etag,
    String reason,
  ) {
    if (cachedBody == null || cachedBody.trim().isEmpty) {
      throw UpdateException(reason, kind: UpdateFailureKind.network);
    }
    final release = AppRelease.fromJsonString(cachedBody);
    if (release == null) {
      throw UpdateException(
        'The local update feed cache is invalid. $reason',
        kind: UpdateFailureKind.invalidFeed,
      );
    }
    return UpdateFeedResult(
      release: release,
      checkedAt: now,
      etag: etag,
      rawBody: cachedBody,
      fromCache: true,
    );
  }

  static Uri _validateUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const UpdateException(
        'Invalid update feed URL.',
        kind: UpdateFailureKind.invalidFeed,
      );
    }
    final local =
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (uri.scheme == 'https' || (uri.scheme == 'http' && local)) {
      return uri;
    }
    throw const UpdateException(
      'The update feed must use HTTPS.',
      kind: UpdateFailureKind.invalidFeed,
    );
  }

  void close() {
    _http.close();
  }
}
