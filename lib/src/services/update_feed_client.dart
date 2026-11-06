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
        'Il server aggiornamenti non risponde.',
      );
    } on UpdateException {
      rethrow;
    } on Object catch (error) {
      return _fallback(
        cachedBody,
        now,
        etag,
        'Impossibile contattare il server aggiornamenti: $error',
      );
    }

    if (response.statusCode == 304) {
      return _fallback(
        cachedBody,
        now,
        etag,
        'Il feed non è cambiato ma non c’è una copia locale valida.',
      );
    }

    if (response.statusCode == 401) {
      throw const UpdateException(
        'Il feed aggiornamenti ha rifiutato le credenziali (401).',
        kind: UpdateFailureKind.unauthorized,
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      final remaining = response.headers['x-ratelimit-remaining'];
      if (remaining == '0') {
        throw const UpdateException(
          'Troppe richieste a GitHub per il controllo aggiornamenti. '
          'Riprova più tardi.',
          kind: UpdateFailureKind.rateLimited,
          statusCode: 403,
        );
      }
      throw const UpdateException(
        'GitHub ha rifiutato il controllo aggiornamenti (403).',
        kind: UpdateFailureKind.unauthorized,
        statusCode: 403,
      );
    }
    if (response.statusCode == 404) {
      throw const UpdateException(
        'Nessuna release trovata. Il repository potrebbe non avere ancora '
        'release pubblicate.',
        kind: UpdateFailureKind.notFound,
        statusCode: 404,
      );
    }
    if (response.statusCode == 429) {
      throw const UpdateException(
        'Troppe richieste al server aggiornamenti (429): riprova più tardi.',
        kind: UpdateFailureKind.rateLimited,
        statusCode: 429,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateException(
        'Il server aggiornamenti ha risposto ${response.statusCode}.',
        kind: response.statusCode >= 500
            ? UpdateFailureKind.server
            : UpdateFailureKind.invalidFeed,
        statusCode: response.statusCode,
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.length > _maxBodyBytes) {
      throw const UpdateException(
        'La risposta del feed aggiornamenti è troppo grande.',
        kind: UpdateFailureKind.invalidFeed,
      );
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    final release = AppRelease.fromJsonString(body);
    if (release == null) {
      throw const UpdateException(
        'La risposta del feed aggiornamenti non è una release valida.',
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
          'Troppi redirect nel feed aggiornamenti.',
          kind: UpdateFailureKind.invalidFeed,
        );
      }
      final location = streamed.headers['location'];
      await _discard(streamed);
      if (location == null || location.trim().isEmpty) {
        throw const UpdateException(
          'Redirect senza destinazione nel feed aggiornamenti.',
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
        'La copia locale del feed aggiornamenti non è valida. $reason',
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
        'URL del feed aggiornamenti non valido.',
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
      'Il feed aggiornamenti deve usare HTTPS.',
      kind: UpdateFailureKind.invalidFeed,
    );
  }

  void close() {
    _http.close();
  }
}
