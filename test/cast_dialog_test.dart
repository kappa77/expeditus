import 'dart:async';
import 'dart:io';

import 'package:expeditus/src/services/dlna/dlna_models.dart';
import 'package:expeditus/src/services/dlna/dlna_transport.dart';
import 'package:expeditus/src/services/dlna/media_server.dart';
import 'package:expeditus/src/services/dlna/network_profile.dart';
import 'package:expeditus/src/services/dlna/ssdp_discovery.dart';
import 'package:expeditus/src/state/cast_controller.dart';
import 'package:expeditus/src/ui/cast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _device = DlnaDevice(
  friendlyName: 'TV Salotto',
  modelName: 'UE55',
  udn: 'uuid:renderer-1',
  location: Uri.parse('http://192.168.1.50:9197/dmr'),
  avTransportControlUrl: Uri.parse('http://192.168.1.50:9197/avt'),
);

class _Discovery implements DlnaDiscovery {
  List<DlnaDevice> devices = [];
  Completer<List<DlnaDevice>>? pending;
  int calls = 0;

  @override
  Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) {
    calls++;
    final completer = pending;
    if (completer != null) return completer.future;
    return Future.value(devices);
  }

  @override
  void close() {}
}

class _Transport implements DlnaTransport {
  bool failConnect = false;
  Completer<void>? connectGate;
  DlnaTransportState state = DlnaTransportState.stopped;
  bool closed = false;

  @override
  Future<void> setAvTransportUri({
    required Uri uri,
    required String metadata,
  }) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<DlnaTransportState> getTransportInfo() async {
    final gate = connectGate;
    if (gate != null) await gate.future;
    if (failConnect) throw Exception('renderer spento');
    return state;
  }

  @override
  Future<Duration> getPosition() async => Duration.zero;

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _Server implements CastMediaServer {
  @override
  Uri get baseUri => Uri.parse('http://127.0.0.1:9999');

  @override
  Future<Uri> start() async => baseUri;

  @override
  Future<Uri> publishFile(File file, {required String contentType}) async =>
      baseUri;

  @override
  Future<Uri> publishRemote(
    Uri source, {
    required String contentType,
    bool playlist = false,
  }) async => baseUri;

  @override
  void clearMedia() {}

  @override
  bool wasRequested(Uri mediaUri) => true;

  @override
  Future<void> close() async {}
}

class _NetworkProfile implements NetworkProfileService {
  NetworkProfileStatus statusValue = NetworkProfileStatus.private;
  bool makePrivateResult = true;

  @override
  Future<NetworkProfileStatus> status() async => statusValue;

  @override
  Future<bool> makePrivate() async {
    if (makePrivateResult) statusValue = NetworkProfileStatus.private;
    return makePrivateResult;
  }
}

void main() {
  late _Discovery discovery;
  late _Transport transport;
  late _NetworkProfile networkProfile;
  late CastController controller;

  setUp(() {
    discovery = _Discovery();
    transport = _Transport();
    networkProfile = _NetworkProfile();
    controller = CastController(
      discovery: discovery,
      transportFactory: (_) => transport,
      mediaServer: _Server(),
      resolver: (_) async => throw Exception('non usato'),
      networkProfile: networkProfile,
      discoveryTimeout: Duration.zero,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCastDialog(context, controller),
              child: const Text('Apri cast'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri cast'));
    await tester.pump();
  }

  testWidgets('cerca i dispositivi al primo avvio e mostra il refresh', (
    tester,
  ) async {
    discovery.devices = [_device];

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(discovery.calls, 1);
    expect(find.byKey(const Key('cast-dialog')), findsOneWidget);
    expect(find.text('TV Salotto'), findsOneWidget);
    expect(find.byKey(const Key('cast-refresh')), findsOneWidget);
  });

  testWidgets('mostra l\'attesa durante la ricerca', (tester) async {
    discovery.pending = Completer<List<DlnaDevice>>();

    await openDialog(tester);
    await tester.pump();

    expect(find.text('Ricerca dispositivi in corso…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    discovery.pending!.complete([_device]);
    discovery.pending = null;
    await tester.pumpAndSettle();

    expect(find.text('TV Salotto'), findsOneWidget);
  });

  testWidgets('mostra la mimica di aggancio e chiude dopo il successo', (
    tester,
  ) async {
    discovery.devices = [_device];
    transport.connectGate = Completer<void>();

    await openDialog(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cast-device-uuid:renderer-1')));
    await tester.pump();

    expect(find.byKey(const Key('cast-connecting')), findsOneWidget);
    expect(find.textContaining('Aggancio a TV Salotto'), findsOneWidget);

    transport.connectGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cast-dialog')), findsNothing);
    expect(controller.isConnected, isTrue);
  });

  testWidgets('un errore di aggancio resta visibile con Riprova', (
    tester,
  ) async {
    discovery.devices = [_device];
    transport.failConnect = true;

    await openDialog(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cast-device-uuid:renderer-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cast-dialog')), findsOneWidget);
    expect(find.textContaining('Aggancio a TV Salotto'), findsOneWidget);
    expect(find.byKey(const Key('cast-connect-retry')), findsOneWidget);
    expect(controller.isConnected, isFalse);
  });

  testWidgets('mostra la sessione connessa e permette di disconnettere', (
    tester,
  ) async {
    discovery.devices = [_device];
    expect(await controller.connect(_device), isTrue);

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.text('TV Salotto'), findsOneWidget);
    expect(find.byKey(const Key('cast-disconnect')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cast-disconnect')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cast-dialog')), findsNothing);
    expect(controller.isConnected, isFalse);
    expect(transport.closed, isTrue);
  });

  testWidgets('mostra il pulsante firewall nella sessione connessa', (
    tester,
  ) async {
    discovery.devices = [_device];
    expect(await controller.connect(_device), isTrue);
    controller.firewallRequired = true;
    controller.notifyListeners();

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cast-allow-firewall')), findsOneWidget);
    expect(
      find.textContaining('non riesce a contattare il PC'),
      findsOneWidget,
    );
  });

  testWidgets('dopo la prima ricerca il refresh ritrova i dispositivi', (
    tester,
  ) async {
    discovery.devices = [];

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nessun dispositivo DLNA trovato'),
      findsOneWidget,
    );

    discovery.devices = [_device];
    await tester.tap(find.byKey(const Key('cast-retry-discovery')));
    await tester.pumpAndSettle();

    expect(discovery.calls, 2);
    expect(find.text('TV Salotto'), findsOneWidget);
  });

  testWidgets('mostra il pulsante rete privata quando la rete è pubblica', (
    tester,
  ) async {
    discovery.devices = [];
    networkProfile.statusValue = NetworkProfileStatus.public;

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cast-allow-private-network')), findsOneWidget);
    expect(find.textContaining('impostata come'), findsOneWidget);
    expect(find.text('Rendi la rete privata'), findsOneWidget);
  });

  testWidgets('mostra i suggerimenti quando non trova dispositivi', (
    tester,
  ) async {
    discovery.devices = [];

    await openDialog(tester);
    await tester.pumpAndSettle();

    expect(find.text('Suggerimenti per la ricerca'), findsOneWidget);
    expect(find.textContaining('renderer DLNA'), findsOneWidget);
  });
}
