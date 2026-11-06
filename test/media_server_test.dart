import 'dart:io';

import 'package:expeditus/src/services/dlna/media_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Reply {
  _Reply(this.status, this.body, this.headers);

  final int status;
  final List<int> body;
  final HttpHeaders headers;
}

Future<_Reply> _get(Uri uri, {String method = 'GET', String? range}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    final body = <int>[];
    await for (final chunk in response) {
      body.addAll(chunk);
    }
    return _Reply(response.statusCode, body, response.headers);
  } finally {
    client.close(force: true);
  }
}

void main() {
  late MediaServer server;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('expeditus_media_');
    server = MediaServer(
      addressProvider: () async => InternetAddress.loopbackIPv4,
    );
    await server.start();
  });

  tearDown(() async {
    await server.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('serve un file locale con HEAD e Range', () async {
    final bytes = List<int>.generate(100, (index) => index);
    final file = File(p.join(temp.path, 'video.mp4'));
    await file.writeAsBytes(bytes);

    final uri = await server.publishFile(file, contentType: 'video/mp4');
    expect(uri.path, endsWith('.mp4'));

    final head = await _get(uri, method: 'HEAD');
    expect(head.status, 200);
    expect(head.headers.value(HttpHeaders.contentLengthHeader), '100');
    expect(head.headers.contentType?.mimeType, 'video/mp4');
    expect(head.body, isEmpty);

    final partial = await _get(uri, range: 'bytes=10-19');
    expect(partial.status, 206);
    expect(
      partial.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 10-19/100',
    );
    expect(partial.body, bytes.sublist(10, 20));

    final invalid = await _get(uri, range: 'bytes=100-200');
    expect(invalid.status, 416);
    expect(
      invalid.headers.value(HttpHeaders.contentRangeHeader),
      'bytes */100',
    );
  });

  test('risponde 404 per token sconosciuti e consente il riavvio', () async {
    final missing = await _get(server.baseUri.resolve('/media/nope.mp4'));
    expect(missing.status, 404);

    await server.close();
    expect(server.isRunning, isFalse);
    await server.start();
    expect(server.isRunning, isTrue);

    final file = File(p.join(temp.path, 'again.mp4'));
    await file.writeAsBytes([1, 2, 3]);
    final uri = await server.publishFile(file, contentType: 'video/mp4');
    expect((await _get(uri)).body, [1, 2, 3]);
  });

  test('inoltra lo stream remoto e il Range', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    final payload = List<int>.generate(50, (index) => index + 1);
    upstream.listen((request) async {
      final header = request.headers.value(HttpHeaders.rangeHeader);
      if (header == 'bytes=5-14') {
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 5-14/50',
        );
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'video/mp4',
        );
        request.response.contentLength = 10;
        request.response.add(payload.sublist(5, 15));
      } else {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'video/mp4',
        );
        request.response.contentLength = payload.length;
        request.response.add(payload);
      }
      await request.response.close();
    });

    final source = Uri.parse('http://127.0.0.1:${upstream.port}/video.mp4');
    final uri = await server.publishRemote(source, contentType: 'video/mp4');

    final head = await _get(uri, method: 'HEAD');
    expect(head.status, 200);
    expect(head.headers.value(HttpHeaders.contentLengthHeader), '50');
    expect(head.body, isEmpty);

    final partial = await _get(uri, range: 'bytes=5-14');
    expect(partial.status, 206);
    expect(
      partial.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 5-14/50',
    );
    expect(partial.body, payload.sublist(5, 15));
  });

  test('riscrive le playlist HLS e proxa varianti e segmenti', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/master.m3u8':
          response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/vnd.apple.mpegurl',
          );
          response.write(
            '#EXTM3U\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
            'child.m3u8\n',
          );
        case '/child.m3u8':
          response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/vnd.apple.mpegurl',
          );
          response.write(
            '#EXTM3U\n'
            '#EXT-X-TARGETDURATION:1\n'
            '#EXTINF:1.0,\n'
            'seg.ts\n'
            '#EXT-X-ENDLIST\n',
          );
        case '/seg.ts':
          response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
          response.add([9, 8, 7]);
          break;
        default:
          response.statusCode = 404;
      }
      await response.close();
    });

    final master = Uri.parse('http://127.0.0.1:${upstream.port}/master.m3u8');
    final local = await server.publishRemote(
      master,
      contentType: 'application/vnd.apple.mpegurl',
      playlist: true,
    );

    final masterReply = await _get(local);
    expect(masterReply.status, 200);
    final masterText = String.fromCharCodes(masterReply.body);
    expect(masterText, contains('${server.baseUri}/media/'));
    expect(masterText, isNot(contains('127.0.0.1:${upstream.port}')));

    final playlistUrl = Uri.parse(
      masterText
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty && !line.startsWith('#')),
    );
    final childReply = await _get(playlistUrl);
    final childText = String.fromCharCodes(childReply.body);
    expect(childText, contains('#EXTM3U'));
    expect(childText, isNot(contains('seg.ts')));

    final segmentUrl = Uri.parse(
      childText
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty && !line.startsWith('#')),
    );
    final segmentReply = await _get(segmentUrl);
    expect(segmentReply.status, 200);
    expect(segmentReply.body, [9, 8, 7]);
  });
}
