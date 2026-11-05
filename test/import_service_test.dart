import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/services/import_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TakeoutParser', () {
    test('legge il CSV di Google Takeout', () {
      const csv = '''Channel Id,Channel URL,Channel Title
UCaaaaaaaaaaaaaaaaaaaaaa,https://www.youtube.com/channel/UCaaaaaaaaaaaaaaaaaaaaaa,Canale A
UCbbbbbbbbbbbbbbbbbbbbbb,https://www.youtube.com/channel/UCbbbbbbbbbbbbbbbbbbbbbb,"Canale, B"
''';

      final channels = TakeoutParser.parse(csv);
      expect(channels, hasLength(2));
      expect(channels.first.id, 'UCaaaaaaaaaaaaaaaaaaaaaa');
      expect(channels.first.title, 'Canale A');
      expect(channels.last.title, 'Canale, B');
    });

    test('funziona anche senza intestazione e con il BOM', () {
      const csv = '\uFEFFUCaaaaaaaaaaaaaaaaaaaaaa,https://youtube.com/channel/UCaaaaaaaaaaaaaaaaaaaaaa,Canale A\n';
      final channels = TakeoutParser.parse(csv);
      expect(channels, hasLength(1));
      expect(channels.single.title, 'Canale A');
    });

    test('elimina i duplicati', () {
      const csv = '''Channel Id,Channel URL,Channel Title
UCaaaaaaaaaaaaaaaaaaaaaa,https://www.youtube.com/channel/UCaaaaaaaaaaaaaaaaaaaaaa,Canale A
UCaaaaaaaaaaaaaaaaaaaaaa,https://www.youtube.com/channel/UCaaaaaaaaaaaaaaaaaaaaaa,Canale A
''';
      expect(TakeoutParser.parse(csv), hasLength(1));
    });
  });

  group('YouTubeResolver', () {
    test('accetta un ID diretto senza rete', () async {
      final resolver = YouTubeResolver(
        client: MockClient((_) async => http.Response('', 500)),
      );
      final channel = await resolver.resolve('UCaaaaaaaaaaaaaaaaaaaaaa');
      expect(channel.id, 'UCaaaaaaaaaaaaaaaaaaaaaa');
      resolver.close();
    });

    test('risolve un handle dalla pagina del canale', () async {
      final resolver = YouTubeResolver(
        client: MockClient((request) async {
          expect(request.url.path, '/@testchannel');
          return http.Response(
            '<html><script>{"externalId":"UCbbbbbbbbbbbbbbbbbbbbbb",'
            '"channelMetadataRenderer":{"title":"Canale B"}}</script></html>',
            200,
          );
        }),
      );
      final channel = await resolver.resolve('@testchannel');
      expect(channel.id, 'UCbbbbbbbbbbbbbbbbbbbbbb');
      expect(channel.title, 'Canale B');
      resolver.close();
    });

    test('rifiuta un URL di un video', () async {
      final resolver = YouTubeResolver(
        client: MockClient((_) async => http.Response('', 200)),
      );
      await expectLater(
        resolver.resolve('https://www.youtube.com/watch?v=abc'),
        throwsA(isA<FormatException>()),
      );
      resolver.close();
    });
  });
}
