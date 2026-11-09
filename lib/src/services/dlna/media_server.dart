import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'dlna_metadata.dart';

/// A local HTTP endpoint that makes a media stream reachable by a DLNA
/// renderer.
///
/// Remote streams are proxied instead of being sent directly because YouTube
/// URLs may be tied to the requesting IP. Downloaded files are served from
/// disk. HLS playlists are rewritten so variant playlists and segments keep
/// pointing at this server.
abstract class CastMediaServer {
  Future<Uri> start();

  Future<Uri> publishFile(File file, {required String contentType});

  Future<Uri> publishRemote(
    Uri source, {
    required String contentType,
    bool playlist = false,
  });

  void clearMedia();

  /// Whether a renderer has already requested [mediaUri] (or one of its HLS
  /// child URLs). Used to detect firewalls that block the local proxy.
  bool wasRequested(Uri mediaUri);

  Uri get baseUri;

  Future<void> close();
}

class CastMediaException implements Exception {
  const CastMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MediaServer implements CastMediaServer {
  MediaServer({
    Future<InternetAddress?> Function()? addressProvider,
    this.onLog,
  }) : _addressProvider = addressProvider ?? defaultLanAddress;

  final Future<InternetAddress?> Function() _addressProvider;

  /// Optional diagnostic sink for live troubleshooting.
  final void Function(String message)? onLog;
  final Map<String, _MediaEntry> _entries = {};
  final Set<String> _requested = {};
  final Random _random = Random.secure();

  HttpServer? _server;
  HttpClient? _httpClient;
  Uri? _baseUri;
  Uri? _loopbackBaseUri;
  Future<Uri>? _starting;

  static const int _maxPlaylistBytes = 8 * 1024 * 1024;

  @override
  Uri get baseUri {
    final uri = _baseUri;
    if (uri == null) {
      throw const CastMediaException('Media server not started.');
    }
    return uri;
  }

  /// Base URL on loopback, used by tests and diagnostics.
  Uri? get loopbackBaseUri => _loopbackBaseUri;

  bool get isRunning => _server != null;

  @override
  Future<Uri> start() {
    final existing = _baseUri;
    if (existing != null) return Future.value(existing);
    final pending = _starting;
    if (pending != null) return pending;
    final future = _start();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<Uri> _start() async {
    final address = await _addressProvider();
    if (address == null) {
      throw const CastMediaException(
        'No local network address found. Connect the PC to the same network as the device.',
      );
    }

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..autoUncompress = false;

    _baseUri = Uri(scheme: 'http', host: address.address, port: server.port);
    _loopbackBaseUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
    );
    _log('listening on $_baseUri');

    server.listen((request) {
      unawaited(_handle(request));
    }, onError: (_) {});

    return _baseUri!;
  }

  @override
  Future<Uri> publishFile(File file, {required String contentType}) async {
    await start();
    final length = await file.length();
    final token = _newToken();
    _entries[token] = _MediaEntry(
      file: file,
      length: length,
      contentType: contentType,
    );
    return _mediaUri(token, _extensionFor(contentType, playlist: false));
  }

  @override
  Future<Uri> publishRemote(
    Uri source, {
    required String contentType,
    bool playlist = false,
  }) async {
    await start();
    return _registerRemote(
      source,
      contentType: contentType,
      playlist: playlist,
    );
  }

  @override
  void clearMedia() {
    _entries.clear();
    _requested.clear();
  }

  @override
  bool wasRequested(Uri mediaUri) {
    final segments = mediaUri.pathSegments;
    if (segments.isEmpty) return false;
    return _requested.contains(_tokenFromSegment(segments.last));
  }

  Uri _registerRemote(
    Uri source, {
    required String contentType,
    required bool playlist,
  }) {
    final token = _newToken();
    _entries[token] = _MediaEntry(
      remote: source,
      contentType: contentType,
      playlist: playlist,
    );
    return _mediaUri(token, _extensionFor(contentType, playlist: playlist));
  }

  Uri _mediaUri(String token, String extension) {
    return baseUri.replace(
      path: '/media/$token$extension',
      query: null,
      fragment: null,
    );
  }

  String _newToken() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _log(
      '${request.method} ${request.uri} '
      'range=${request.headers.value(HttpHeaders.rangeHeader) ?? '-'}',
    );
    try {
      if (request.uri.path == '/health') {
        response.write('ok');
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }

      final segments = request.uri.pathSegments;
      if (segments.length < 2 || segments[0] != 'media') {
        response.statusCode = HttpStatus.notFound;
        return;
      }

      final token = _tokenFromSegment(segments[1]);
      final entry = _entries[token];
      if (entry == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      _requested.add(token);

      final file = entry.file;
      if (file != null) {
        await _serveFile(request, entry, file);
      } else {
        await _serveRemote(request, entry);
      }
    } on Object catch (error) {
      _log('error ${request.uri}: $error');
      try {
        response.statusCode = HttpStatus.badGateway;
        response.headers.contentType = ContentType.text;
        response.write('Stream unavailable.');
      } on Object {
        // The response may already be committed; nothing else to do.
      }
    } finally {
      try {
        await response.close();
      } on Object {
        // The client may have closed the connection first.
      }
      _log('${request.method} ${request.uri.path} -> ${response.statusCode}');
    }
  }

  Future<void> _serveFile(
    HttpRequest request,
    _MediaEntry entry,
    File file,
  ) async {
    final response = request.response;
    final length = entry.length ?? 0;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final range = rangeHeader == null ? null : _parseRange(rangeHeader, length);
    if (rangeHeader != null && range == null) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      return;
    }

    response.headers.set(HttpHeaders.contentTypeHeader, entry.contentType);
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    _addDlnaHeaders(response);
    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.contentLength = range.length;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-${range.end}/$length',
      );
    } else {
      response.contentLength = length;
    }

    if (request.method == 'HEAD' || length == 0) return;
    final start = range?.start ?? 0;
    final end = range == null ? length : range.end + 1;
    await response.addStream(file.openRead(start, end));
  }

  Future<void> _serveRemote(HttpRequest request, _MediaEntry entry) async {
    final source = entry.remote;
    final client = _httpClient;
    if (source == null || client == null) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      return;
    }

    // A HEAD on googlevideo can be rejected; a GET that we cancel right after
    // the headers is more reliable. The whole body is served only for GET.
    final upstreamMethod = request.method == 'HEAD' ? 'GET' : request.method;
    final upstreamRequest = await client.openUrl(upstreamMethod, source);
    upstreamRequest.headers.set(HttpHeaders.userAgentHeader, 'Expeditus/1.0');
    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null && !entry.playlist) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range);
    }

    final upstream = await upstreamRequest.close().timeout(
      const Duration(seconds: 15),
    );
    final upstreamType =
        upstream.headers.value(HttpHeaders.contentTypeHeader) ?? '';
    final isPlaylist = entry.playlist || _isPlaylist(upstreamType);
    _log(
      'upstream ${upstream.statusCode} $upstreamType '
      'len=${upstream.headers.value(HttpHeaders.contentLengthHeader) ?? '-'} '
      'playlist=$isPlaylist',
    );

    if (isPlaylist) {
      if (request.method == 'HEAD') {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/vnd.apple.mpegurl',
        );
        await upstream.drain<void>();
        return;
      }
      final bytes = await _readLimited(upstream, _maxPlaylistBytes);
      final text = utf8.decode(bytes, allowMalformed: true);
      final rewritten = utf8.encode(_rewritePlaylist(source, text));
      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/vnd.apple.mpegurl',
      );
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      _addDlnaHeaders(request.response);
      request.response.contentLength = rewritten.length;
      request.response.add(rewritten);
      return;
    }

    final response = request.response;
    response.statusCode = upstream.statusCode;
    for (final name in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.lastModifiedHeader,
      HttpHeaders.etagHeader,
    ]) {
      final value = upstream.headers.value(name);
      if (value == null) continue;
      if (name == HttpHeaders.contentTypeHeader && value.trim().isEmpty) {
        continue;
      }
      response.headers.set(name, value);
    }
    if (response.headers.value(HttpHeaders.contentTypeHeader) == null) {
      response.headers.set(HttpHeaders.contentTypeHeader, entry.contentType);
    }
    if (response.headers.value(HttpHeaders.acceptRangesHeader) == null) {
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    }
    _addDlnaHeaders(response);

    if (request.method == 'HEAD') {
      // Cancel instead of downloading the body just to answer a HEAD.
      await upstream.listen(null).cancel();
      return;
    }
    await response.addStream(upstream);
  }

  String _rewritePlaylist(Uri base, String text) {
    final lines = const LineSplitter().convert(text);
    final output = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        output.add(rawLine);
        continue;
      }
      if (line.startsWith('#')) {
        output.add(
          line.replaceAllMapped(RegExp(r'URI="([^"]*)"'), (match) {
            final raw = match.group(1) ?? '';
            final resolved = base.resolve(raw);
            if (!_isHttp(resolved)) return 'URI="$raw"';
            final playlist = _looksLikePlaylist(resolved);
            final local = _registerRemote(
              resolved,
              contentType: _contentTypeFor(resolved, playlist: playlist),
              playlist: playlist,
            );
            return 'URI="$local"';
          }),
        );
        continue;
      }
      final resolved = base.resolve(line);
      if (!_isHttp(resolved)) {
        output.add(line);
        continue;
      }
      final playlist = _looksLikePlaylist(resolved);
      final local = _registerRemote(
        resolved,
        contentType: _contentTypeFor(resolved, playlist: playlist),
        playlist: playlist,
      );
      output.add(local.toString());
    }
    return '${output.join('\n')}\n';
  }

  void _log(String message) {
    final callback = onLog;
    if (callback != null) callback(message);
  }

  static void _addDlnaHeaders(HttpResponse response) {
    response.headers.set('contentFeatures.dlna.org', dlnaContentFeatures);
    response.headers.set('transferMode.dlna.org', 'Streaming');
  }

  static bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  static bool _looksLikePlaylist(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8') || path.endsWith('.m3u')) return true;
    return uri.query.toLowerCase().contains('m3u8');
  }

  static bool _isPlaylist(String contentType) {
    final type = contentType.toLowerCase();
    return type.contains('mpegurl') || type.contains('m3u8');
  }

  static String _contentTypeFor(Uri uri, {required bool playlist}) {
    if (playlist) return 'application/vnd.apple.mpegurl';
    final path = uri.path.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.m4s') ||
        path.endsWith('.m4v')) {
      return 'video/mp4';
    }
    if (path.endsWith('.m4a')) return 'audio/mp4';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    return 'video/mp2t';
  }

  static String _extensionFor(String contentType, {required bool playlist}) {
    if (playlist) return '.m3u8';
    final type = contentType.toLowerCase();
    if (type.startsWith('audio/mp4') || type.contains('m4a')) return '.m4a';
    if (type.startsWith('audio/')) return '.mp3';
    if (type.contains('mpegurl')) return '.m3u8';
    return '.mp4';
  }

  static String _tokenFromSegment(String segment) {
    final dot = segment.indexOf('.');
    return dot < 0 ? segment : segment.substring(0, dot);
  }

  static _ByteRange? _parseRange(String header, int length) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null || length <= 0) return null;
    final rawStart = match.group(1) ?? '';
    final rawEnd = match.group(2) ?? '';
    if (rawStart.isEmpty && rawEnd.isEmpty) return null;

    if (rawStart.isEmpty) {
      final suffix = int.tryParse(rawEnd);
      if (suffix == null || suffix <= 0) return null;
      final start = max(0, length - suffix);
      return _ByteRange(start, length - 1);
    }

    final start = int.tryParse(rawStart);
    if (start == null || start < 0 || start >= length) return null;
    final requestedEnd = rawEnd.isEmpty ? length - 1 : int.tryParse(rawEnd);
    if (requestedEnd == null || requestedEnd < start) return null;
    return _ByteRange(start, min(requestedEnd, length - 1));
  }

  static Future<List<int>> _readLimited(
    HttpClientResponse response,
    int limit,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > limit) {
        throw const CastMediaException('Playlist too large.');
      }
    }
    return builder.takeBytes();
  }

  @override
  Future<void> close() async {
    final server = _server;
    _server = null;
    _starting = null;
    _baseUri = null;
    _loopbackBaseUri = null;
    _entries.clear();
    _requested.clear();
    _httpClient?.close(force: true);
    _httpClient = null;
    await server?.close(force: true);
  }

  /// Chooses a local IPv4 address, preferring private ranges over link-local
  /// and virtual adapter addresses.
  static Future<InternetAddress?> defaultLanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final candidates = <(InternetAddress, int)>[
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (!address.isLoopback)
            (address, _addressScore(address) + _interfaceScore(interface.name)),
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    return candidates.first.$1;
  }

  static int _interfaceScore(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('vethernet') ||
        lower.contains('hyper-v') ||
        lower.contains('vmware') ||
        lower.contains('virtualbox') ||
        lower.contains('tailscale') ||
        lower.contains('vpn') ||
        lower.contains('docker') ||
        lower.contains('wsl') ||
        // Android cellular, VPN and virtual interfaces.
        lower.contains('rmnet') ||
        lower.contains('ccmni') ||
        lower.contains('tun') ||
        lower.contains('ppp') ||
        lower.contains('dummy') ||
        lower.contains('sit')) {
      return -10;
    }
    if (lower.contains('wi-fi') || lower.contains('wifi')) return 3;
    // Android names the primary Wi-Fi interface "wlan0".
    if (lower.contains('wlan')) return 3;
    if (lower.contains('ethernet')) return 2;
    return 0;
  }

  static int _addressScore(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length != 4) return 0;
    final first = bytes[0];
    final second = bytes[1];
    if (first == 192 && second == 168) return 4;
    if (first == 10) return 3;
    if (first == 172 && second >= 16 && second <= 31) return 2;
    if (first == 169 && second == 254) return 0;
    return 1;
  }
}

class _MediaEntry {
  _MediaEntry({
    this.file,
    this.remote,
    this.length,
    required this.contentType,
    this.playlist = false,
  });

  final File? file;
  final Uri? remote;
  final int? length;
  final String contentType;
  final bool playlist;
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;
}
