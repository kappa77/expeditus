import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dlna_models.dart';

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
  SsdpDlnaDiscovery({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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

  @override
  Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final responses = <String, SsdpResponse>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final datagram = socket?.receive();
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

      final destination = InternetAddress(_multicastAddress);
      var sent = 0;
      for (final target in _searchTargets) {
        final request = StringBuffer()
          ..write('M-SEARCH * HTTP/1.1\r\n')
          ..write('HOST: $_multicastAddress:$_multicastPort\r\n')
          ..write('MAN: "ssdp:discover"\r\n')
          ..write('MX: 3\r\n')
          ..write('ST: $target\r\n')
          ..write('USER-AGENT: Expeditus/1.0 UPnP/1.1\r\n')
          ..write('\r\n');
        try {
          final written = socket.send(
            utf8.encode(request.toString()),
            destination,
            _multicastPort,
          );
          if (written > 0) sent++;
        } on Object {
          // Some adapters reject multicast. Try the next search target.
        }
      }
      if (sent == 0) {
        throw Exception('Invio della ricerca multicast non riuscito.');
      }

      await Future<void>.delayed(timeout);
    } finally {
      await subscription?.cancel();
      socket?.close();
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
