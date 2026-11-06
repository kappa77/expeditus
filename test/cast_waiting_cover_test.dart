import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/ui/cast_waiting_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _video = VideoItem(
  id: 'video-1',
  channelId: 'channel-1',
  channelTitle: 'Canale',
  title: 'Titolo',
  description: '',
  publishedAt: 0,
);

void main() {
  Future<void> pumpCover(
    WidgetTester tester, {
    required bool starting,
    required VoidCallback onPlay,
    VoidCallback? onUseLocal,
    bool firewallRequired = false,
    bool firewallBusy = false,
    VoidCallback? onAllowFirewall,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CastWaitingCover(
            video: _video,
            deviceName: 'TV Salotto',
            starting: starting,
            firewallRequired: firewallRequired,
            firewallBusy: firewallBusy,
            onPlay: () async => onPlay(),
            onAllowFirewall: () async => onAllowFirewall?.call(),
            onUseLocal: () async => onUseLocal?.call(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('mostra miniatura e simbolo play quando non è avviato', (
    tester,
  ) async {
    var plays = 0;
    await pumpCover(tester, starting: false, onPlay: () => plays++);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.textContaining('Riproduzione non avviata'), findsOneWidget);
    expect(find.text('TV SALOTTO'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cast-play-button')));
    await tester.pump();
    expect(plays, 1);
  });

  testWidgets('durante l\'avvio mostra comunque il play e un indicatore', (
    tester,
  ) async {
    var plays = 0;
    await pumpCover(tester, starting: true, onPlay: () => plays++);

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Invio del video'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cast-play-button')));
    await tester.pump();
    expect(plays, 0);
  });

  testWidgets('mostra il pulsante firewall quando il PC non è raggiungibile', (
    tester,
  ) async {
    var allowed = 0;
    await pumpCover(
      tester,
      starting: false,
      onPlay: () {},
      firewallRequired: true,
      onAllowFirewall: () => allowed++,
    );

    expect(
      find.textContaining('non riesce a contattare il PC'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cast-allow-firewall')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cast-allow-firewall')));
    await tester.pump();
    expect(allowed, 1);
  });

  testWidgets('permette di tornare alla riproduzione locale', (tester) async {
    var local = 0;
    await pumpCover(
      tester,
      starting: false,
      onPlay: () {},
      onUseLocal: () => local++,
    );

    await tester.tap(find.byKey(const Key('cast-use-local')));
    await tester.pump();

    expect(local, 1);
  });
}
