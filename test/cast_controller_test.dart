import 'dart:io';

import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/services/dlna/dlna_models.dart';
import 'package:expeditus/src/services/dlna/dlna_transport.dart';
import 'package:expeditus/src/services/dlna/media_server.dart';
import 'package:expeditus/src/services/dlna/network_profile.dart';
import 'package:expeditus/src/services/dlna/windows_firewall.dart';
import 'package:expeditus/src/services/dlna/ssdp_discovery.dart';
import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:expeditus/src/state/cast_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final _deviceLocation = Uri.parse('http://192.168.1.50:9197/dmr');
final _controlUrl = Uri.parse('http://192.168.1.50:9197/avt');
final _device = DlnaDevice(
  friendlyName: 'TV Salotto',
  modelName: 'UE55',
  udn: 'uuid:renderer-1',
  location: _deviceLocation,
  avTransportControlUrl: _controlUrl,
);

final _video = VideoItem(
  id: 'video-1',
  channelId: 'channel-1',
  channelTitle: 'Canale',
  title: 'Titolo & speciale',
  description: '',
  publishedAt: 0,
);

class _FakeDiscovery implements DlnaDiscovery {
  _FakeDiscovery(this.devices);

  List<DlnaDevice> devices;
  Object? error;
  int calls = 0;
  bool closed = false;

  @override
  Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return devices;
  }

  @override
  void close() {
    closed = true;
  }
}

class _FakeFirewall implements FirewallService {
  FirewallStatus statusValue = FirewallStatus.allowed;
  bool allowResult = true;
  int statusCalls = 0;
  int allowCalls = 0;

  @override
  Future<FirewallStatus> status() async {
    statusCalls++;
    return statusValue;
  }

  @override
  Future<bool> allowExpeditus() async {
    allowCalls++;
    if (allowResult) statusValue = FirewallStatus.allowed;
    return allowResult;
  }
}

class _FakeNetworkProfile implements NetworkProfileService {
  NetworkProfileStatus statusValue = NetworkProfileStatus.private;
  bool makePrivateResult = true;
  int statusCalls = 0;
  int makePrivateCalls = 0;

  @override
  Future<NetworkProfileStatus> status() async {
    statusCalls++;
    return statusValue;
  }

  @override
  Future<bool> makePrivate() async {
    makePrivateCalls++;
    if (makePrivateResult) statusValue = NetworkProfileStatus.private;
    return makePrivateResult;
  }
}

class _FakeTransport implements DlnaTransport {
  final List<String> calls = [];
  DlnaTransportState state = DlnaTransportState.stopped;
  Duration position = Duration.zero;
  Uri? lastUri;
  String? lastMetadata;
  Duration? lastSeek;
  bool failConnect = false;
  bool failSetUri = false;
  bool failPlay = false;
  bool autoPlay = true;
  int transitioningPolls = 0;
  bool closed = false;

  @override
  Future<void> setAvTransportUri({
    required Uri uri,
    required String metadata,
  }) async {
    calls.add('setUri');
    if (failSetUri) throw Exception('URI non accettato');
    lastUri = uri;
    lastMetadata = metadata;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (failPlay) throw Exception('Play rifiutato');
    if (autoPlay) state = DlnaTransportState.playing;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    state = DlnaTransportState.paused;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    state = DlnaTransportState.stopped;
  }

  @override
  Future<void> seek(Duration value) async {
    calls.add('seek');
    lastSeek = value;
  }

  @override
  Future<DlnaTransportState> getTransportInfo() async {
    calls.add('getTransportInfo');
    if (failConnect) throw Exception('dispositivo spento');
    if (transitioningPolls > 0) {
      transitioningPolls--;
      return DlnaTransportState.transitioning;
    }
    return state;
  }

  @override
  Future<Duration> getPosition() async {
    calls.add('getPosition');
    return position;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _FakeServer implements CastMediaServer {
  final Uri address = Uri.parse('http://127.0.0.1:9999');
  final List<Uri> publishedRemote = [];
  final List<String> publishedFiles = [];
  bool started = false;
  bool closed = false;
  bool requested = true;
  int cleared = 0;

  @override
  Uri get baseUri => address;

  @override
  Future<Uri> start() async {
    started = true;
    return address;
  }

  @override
  Future<Uri> publishFile(File file, {required String contentType}) async {
    publishedFiles.add(file.path);
    return address.resolve('/media/file.mp4');
  }

  @override
  Future<Uri> publishRemote(
    Uri source, {
    required String contentType,
    bool playlist = false,
  }) async {
    publishedRemote.add(source);
    return address.resolve('/media/remote.mp4');
  }

  @override
  void clearMedia() {
    cleared++;
  }

  @override
  bool wasRequested(Uri mediaUri) => requested;

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late _FakeDiscovery discovery;
  late _FakeTransport transport;
  late _FakeServer server;
  late _FakeFirewall firewall;
  late _FakeNetworkProfile networkProfile;
  late CastController controller;

  setUp(() {
    discovery = _FakeDiscovery([_device]);
    transport = _FakeTransport();
    server = _FakeServer();
    firewall = _FakeFirewall();
    networkProfile = _FakeNetworkProfile();
    controller = CastController(
      discovery: discovery,
      transportFactory: (_) => transport,
      mediaServer: server,
      resolver: (_) async => ResolvedStream(
        url: Uri.parse('https://cdn.example/video.mp4'),
        quality: '360p',
        kind: 'muxed',
      ),
      firewall: firewall,
      networkProfile: networkProfile,
      discoveryTimeout: Duration.zero,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> connect() async {
    await controller.discover();
    final ok = await controller.connect(_device);
    expect(ok, isTrue);
  }

  Future<void> waitFor(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Condizione non raggiunta entro $timeout.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('la ricerca viene eseguita una volta e il refresh la ripete', () async {
    await controller.discover();
    expect(discovery.calls, 1);
    expect(controller.devices, hasLength(1));
    expect(controller.hasDiscovered, isTrue);

    await controller.discover();
    expect(discovery.calls, 1);

    await controller.discover(force: true);
    expect(discovery.calls, 2);
  });

  test(
    'un errore di ricerca è esposto e non marca la ricerca come fatta',
    () async {
      discovery.error = Exception('multicast bloccato');

      await controller.discover();

      expect(controller.discoveryError, contains('multicast bloccato'));
      expect(controller.hasDiscovered, isFalse);
      expect(controller.discovering, isFalse);
    },
  );

  test('connessione riuscita e fallita', () async {
    await controller.discover();
    expect(await controller.connect(_device), isTrue);
    expect(controller.isConnected, isTrue);
    expect(controller.device?.displayName, 'TV Salotto');

    final failing = _FakeTransport()..failConnect = true;
    final failingController = CastController(
      discovery: discovery,
      transportFactory: (_) => failing,
      mediaServer: server,
      resolver: (_) async => throw Exception('non usato'),
    );
    addTearDown(failingController.dispose);
    expect(await failingController.connect(_device), isFalse);
    expect(failingController.isConnected, isFalse);
    expect(failingController.device, isNull);
    expect(failingController.error, contains('Aggancio a TV Salotto'));
    expect(failing.closed, isTrue);
  });

  test('castVideo invia URI, metadati, seek e play', () async {
    await connect();

    final ok = await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
      startAt: const Duration(seconds: 7),
    );

    expect(ok, isTrue);
    expect(server.started, isTrue);
    expect(server.cleared, 1);
    expect(
      server.publishedRemote.single.toString(),
      'https://cdn.example/video.mp4',
    );
    expect(
      transport.calls,
      containsAllInOrder(['stop', 'setUri', 'seek', 'play']),
    );
    expect(transport.lastSeek, const Duration(seconds: 7));
    expect(
      transport.lastUri.toString(),
      'http://127.0.0.1:9999/media/remote.mp4',
    );
    expect(transport.lastMetadata, contains('DIDL-Lite'));
    expect(transport.lastMetadata, contains('Titolo &amp; speciale'));
    expect(transport.lastMetadata, contains('video/mp4'));
    expect(transport.lastMetadata, contains('media/remote.mp4'));

    await waitFor(() => controller.playback == CastPlaybackState.playing);
    expect(controller.remotePlaying, isTrue);
  });

  test('un download locale viene servito dal media server', () async {
    final temp = await Directory.systemTemp.createTemp('expeditus_cast_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/video.mp4');
    await file.writeAsBytes([1, 2, 3]);
    await connect();

    final ok = await controller.castVideo(video: _video, localPath: file.path);

    expect(ok, isTrue);
    expect(server.publishedFiles.single, file.path);
    expect(transport.lastUri!.path, '/media/file.mp4');
  });

  test('un errore di invio resta sul controller', () async {
    await connect();
    transport.failSetUri = true;

    final ok = await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );

    expect(ok, isFalse);
    expect(controller.playback, CastPlaybackState.error);
    expect(controller.error, contains('Invio a TV Salotto'));
    expect(controller.error, contains('URI non accettato'));
  });

  test(
    'playback non confermato espone lo stato stopped per il tasto play',
    () async {
      transport.autoPlay = false;
      await connect();

      await controller.castVideo(
        video: _video,
        fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 4200));

      expect(controller.playback, CastPlaybackState.stopped);
      expect(controller.remotePlaying, isFalse);

      await controller.play();
      expect(transport.state, DlnaTransportState.stopped);
      expect(controller.playback, CastPlaybackState.starting);
    },
  );

  test(
    'stopPlayback mantiene la connessione per il video successivo',
    () async {
      await connect();
      await controller.castVideo(
        video: _video,
        fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
      );

      await controller.stopPlayback(expectedVideoId: _video.id);

      expect(controller.isConnected, isTrue);
      expect(controller.isCasting, isFalse);
      expect(transport.closed, isFalse);
      expect(transport.state, DlnaTransportState.stopped);

      final ok = await controller.castVideo(
        video: _video,
        fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
      );
      expect(ok, isTrue);
    },
  );

  test('stopPlayback non ferma un altro video', () async {
    await connect();
    await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );

    await controller.stopPlayback(expectedVideoId: 'altro-video');

    expect(controller.isCasting, isTrue);
  });

  test('disconnect ferma e chiude trasporto e server', () async {
    await connect();
    await controller.disconnect();

    expect(controller.isConnected, isFalse);
    expect(controller.device, isNull);
    expect(transport.closed, isTrue);
    expect(server.closed, isTrue);
  });

  test('mirrorLocalPlaying riflette pausa e ripresa', () async {
    await connect();
    await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );
    await waitFor(() => controller.playback == CastPlaybackState.playing);

    await controller.mirrorLocalPlaying(false);
    expect(transport.calls, contains('pause'));
    expect(controller.playback, CastPlaybackState.paused);

    await controller.mirrorLocalPlaying(true);
    expect(transport.calls.last, 'play');
  });

  test('accetta un avvio lento del renderer (es. Samsung)', () async {
    transport.autoPlay = false;
    await connect();

    final ok = await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );
    expect(ok, isTrue);
    expect(controller.playback, CastPlaybackState.starting);
    // The renderer reports TRANSITIONING for a while before playing, like a
    // Samsung TV. The probe must wait instead of marking playback as stopped.
    transport.transitioningPolls = 10;
    transport.state = DlnaTransportState.playing;

    await waitFor(
      () => controller.playback == CastPlaybackState.playing,
      timeout: const Duration(seconds: 15),
    );
    expect(controller.remotePlaying, isTrue);
  });

  test('seekTo inoltra subito la posizione al dispositivo', () async {
    await connect();
    await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );

    expect(await controller.seekTo(const Duration(seconds: 42)), isTrue);
    expect(transport.lastSeek, const Duration(seconds: 42));
  });

  test(
    'se il media server non viene contattato propone la regola firewall',
    () async {
      server.requested = false;
      firewall.statusValue = FirewallStatus.missing;
      transport.autoPlay = false;
      await connect();

      await controller.castVideo(
        video: _video,
        fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
      );
      await waitFor(() => controller.firewallRequired);

      expect(controller.firewallRequired, isTrue);
      expect(firewall.statusCalls, greaterThan(0));

      expect(await controller.allowFirewall(), isTrue);
      expect(controller.firewallRequired, isFalse);
      expect(firewall.allowCalls, 1);
      expect(controller.error, isNull);
    },
  );

  test('syncTo corregge uno scostamento oltre la soglia', () async {
    await connect();
    await controller.castVideo(
      video: _video,
      fallbackUri: Uri.parse('https://fallback.example/video.mp4'),
    );
    await waitFor(() => controller.playback == CastPlaybackState.playing);
    transport.position = const Duration(seconds: 30);

    await controller.syncTo(const Duration(seconds: 2));

    expect(transport.lastSeek, const Duration(seconds: 2));
  });

  test('una rete pubblica è segnalata quando non ci sono dispositivi', () async {
    discovery.devices = [];
    networkProfile.statusValue = NetworkProfileStatus.public;

    await controller.discover();
    await pumpEventQueue();

    expect(controller.devices, isEmpty);
    expect(controller.networkProfileRequired, isTrue);
    expect(networkProfile.statusCalls, 1);
  });

  test('allowPrivateNetwork corregge la rete e pulisce il flag', () async {
    discovery.devices = [];
    networkProfile.statusValue = NetworkProfileStatus.public;

    await controller.discover();
    await pumpEventQueue();
    expect(controller.networkProfileRequired, isTrue);

    expect(await controller.allowPrivateNetwork(), isTrue);
    expect(controller.networkProfileRequired, isFalse);
    expect(networkProfile.makePrivateCalls, 1);
    expect(controller.error, isNull);
  });

  test('allowPrivateNetwork espone un errore se UAC viene annullato', () async {
    discovery.devices = [];
    networkProfile.statusValue = NetworkProfileStatus.public;
    networkProfile.makePrivateResult = false;

    await controller.discover();
    await pumpEventQueue();

    expect(await controller.allowPrivateNetwork(), isFalse);
    expect(controller.networkProfileRequired, isTrue);
    expect(controller.error, contains('Rete e Internet'));
  });
}
