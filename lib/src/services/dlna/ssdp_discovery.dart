import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dlna_models.dart';
import 'multicast_lock.dart';

/// Finds MediaRenderers on the local network.
abstract class DlnaDiscovery {
  Future<List<DlnaDevice>> discover({Duration timeout});

  void close();
}

/// SSDP discovery followed by a UPnP device-description fetch.
///
/// The app searches with `M-SEARCH` on the standard multicast address and then
/// reads each `LOCATION` document to keep only devices with an AVTransport
/// service.
class SsdpDlnaDiscovery implements DlnaDiscovery {
  SsdpDlnaDiscovery({http.Client? client, MulticastLock? multicastLock})
    : _client = client ?? http.Client(),
      _multicastLock = multicastLock ?? _defaultMulticastLock();

  final http.Client _client;
  final MulticastLock _multicastLock;

  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 1900;
  static const _searchTargets = [
    'urn:schemas-upnp-org:device:MediaRenderer:1',
    'urn:schemas-upnp-org:service:AVTransport:1',
    // A few TVs only answer the generic search.
    'ssdp:all',
  ];
  static const int _maxDescriptionBytes = 512 * 1024;
  static const int _maxDevices = 24;

  static MulticastLock _defaultMulticastLock() {
    return Platform.isAndroid ? AndroidMulticastLock() : NoopMulticastLock();
  }

  @override
  Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final responses = <String, SsdpResponse>{};
    final sockets = <RawDatagramSocket>[];
    final subscriptions = <StreamSubscription<RawSocketEvent>>[];

    await _multicastLock.acquire();
    try {
      // Send from every IPv4 interface. A single wildcard socket can pick
      // the wrong adapter on multi-homed machines (Wi-Fi, Hyper-V, VMware),
      // so the M-SEARCH would never reach the TV's subnet.
      for (final address in await _discoveryAddresses()) {
        try {
          final socket = await RawDatagramSocket.bind(address, 0);
          socket.broadcastEnabled = true;
          sockets.add(socket);
          subscriptions.add(_listen(socket, responses));
        } on Object {
          // A virtual or disconnected adapter may not accept the bind.
        }
      }
      if (sockets.isEmpty) {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        socket.broadcastEnabled = true;
        sockets.add(socket);
        subscriptions.add(_listen(socket, responses));
      }

      final destination = InternetAddress(_multicastAddress);
      var sent = 0;
      for (final socket in sockets) {
        for (final target in _searchTargets) {
          try {
            final written = socket.send(
              utf8.encode(_searchRequest(target)),
              destination,
              _multicastPort,
            );
            if (written > 0) sent++;
          } on Object {
            // Some adapters reject multicast. Try the next search target.
          }
        }
      }
      if (sent == 0) {
        throw Exception('Invio della ricerca multicast non riuscito.');
      }

      await Future<void>.delayed(timeout);
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      for (final socket in sockets) {
        socket.close();
      }
      await _multicastLock.release();
    }

    if (responses.isEmpty) return const [];

    final devices = <String, DlnaDevice>{};
    await Future.wait(
      responses.values.take(_maxDevices).map((response) async {
        try {
          final description = await _fetchDescription(response.location);
          if (description == null) return;
          final device = parseDeviceDescription(description, response.location);
          if (device == null) return;
          devices.putIfAbsent(device.udn, () => device);
        } on Object {
          // A single unreachable renderer must not hide the other results.
        }
      }),
    );

    final result = devices.values.toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return result;
  }

  StreamSubscription<RawSocketEvent> _listen(
    RawDatagramSocket socket,
    Map<String, SsdpResponse> responses,
  ) {
    return socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        final parsed = parseSsdpResponse(
          utf8.decode(datagram.data, allowMalformed: true),
        );
        if (parsed == null) return;
        responses[parsed.location.toString()] = parsed;
      },
      onError: (_) {
        // Keep waiting for other interfaces' responses.
      },
    );
  }

  /// Non-loopback IPv4 addresses to search from. Link-local (169.254/16)
  /// adapters are excluded by default and usually carry no DLNA devices.
  Future<List<InternetAddress>> _discoveryAddresses() async {
    final seen = <String>{};
    final result = <InternetAddress>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type != InternetAddressType.IPv4) continue;
          if (address.isLoopback) continue;
          if (seen.add(address.address)) result.add(address);
        }
      }
    } on Object {
      // Fall back to the wildcard socket in discover().
    }
    return result;
  }

  static String _searchRequest(String target) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_multicastAddress:$_multicastPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 3\r\n'
        'ST: $target\r\n'
        'USER-AGENT: Expeditus/1.0 UPnP/1.1\r\n'
        '\r\n';
  }

  Future<String?> _fetchDescription(Uri location) async {
    final response = await _client
        .get(location, headers: const {'User-Agent': 'Expeditus/1.0 UPnP/1.1'})
        .timeout(const Duration(seconds: 4));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    if (response.bodyBytes.length > _maxDescriptionBytes) return null;
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  @override
  void close() => _client.close();
}
