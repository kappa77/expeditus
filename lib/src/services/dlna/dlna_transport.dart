import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'dlna_models.dart';

enum DlnaTransportState {
  playing,
  paused,
  stopped,
  transitioning,
  noMedia,
  unknown;

  static DlnaTransportState parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PLAYING':
        return playing;
      case 'PAUSED_PLAYBACK':
      case 'PAUSED_RECORDING':
        return paused;
      case 'STOPPED':
        return stopped;
      case 'TRANSITIONING':
        return transitioning;
      case 'NO_MEDIA_PRESENT':
        return noMedia;
      default:
        return unknown;
    }
  }
}

class DlnaTransportException implements Exception {
  const DlnaTransportException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

/// The AVTransport actions used by the app.
abstract class DlnaTransport {
  Future<void> setAvTransportUri({required Uri uri, required String metadata});

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<DlnaTransportState> getTransportInfo();

  Future<Duration> getPosition();

  Future<void> close();
}

/// UPnP AVTransport client over SOAP.
class DlnaSoapTransport implements DlnaTransport {
  DlnaSoapTransport(this.device, {http.Client? client})
    : _client = client ?? http.Client();

  final DlnaDevice device;
  final http.Client _client;

  static const _serviceType = 'urn:schemas-upnp-org:service:AVTransport:1';
  static const _instance = '0';
  static const _timeout = Duration(seconds: 10);

  @override
  Future<void> setAvTransportUri({
    required Uri uri,
    required String metadata,
  }) async {
    await _call('SetAVTransportURI', {
      'InstanceID': _instance,
      'CurrentURI': uri.toString(),
      'CurrentURIMetaData': metadata,
    });
  }

  @override
  Future<void> play() async {
    await _call('Play', {'InstanceID': _instance, 'Speed': '1'});
  }

  @override
  Future<void> pause() async {
    await _call('Pause', {'InstanceID': _instance});
  }

  @override
  Future<void> stop() async {
    await _call('Stop', {'InstanceID': _instance});
  }

  @override
  Future<void> seek(Duration position) async {
    await _call('Seek', {
      'InstanceID': _instance,
      'Unit': 'REL_TIME',
      'Target': formatUpnpTime(position),
    });
  }

  @override
  Future<DlnaTransportState> getTransportInfo() async {
    final result = await _call('GetTransportInfo', {'InstanceID': _instance});
    return DlnaTransportState.parse(result['CurrentTransportState']);
  }

  @override
  Future<Duration> getPosition() async {
    final result = await _call('GetPositionInfo', {'InstanceID': _instance});
    return parseUpnpTime(result['RelTime']) ?? Duration.zero;
  }

  Future<Map<String, String>> _call(
    String action,
    Map<String, String> arguments,
  ) async {
    final envelope = _buildEnvelope(_serviceType, action, arguments);
    http.Response response;
    try {
      response = await _client
          .post(
            device.avTransportControlUrl,
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"$_serviceType#$action"',
              'User-Agent': 'Expeditus/1.0 UPnP/1.1',
            },
            body: utf8.encode(envelope),
          )
          .timeout(_timeout);
    } on Object catch (error) {
      throw DlnaTransportException(
        'The device did not respond ($action): ${_short(error)}',
      );
    }

    if (response.statusCode >= 300) {
      throw _faultFrom(response, action);
    }
    if (response.bodyBytes.isEmpty) return const {};

    XmlDocument document;
    try {
      document = XmlDocument.parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } on Object {
      return const {};
    }

    final values = <String, String>{};
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.children.any((child) => child is XmlElement)) continue;
      values.putIfAbsent(element.name.local, () => element.innerText.trim());
    }
    return values;
  }

  DlnaTransportException _faultFrom(http.Response response, String action) {
    int? code;
    String? description;
    try {
      final document = XmlDocument.parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      final codeText = _elementText(document, 'errorCode');
      code = int.tryParse(codeText ?? '');
      description = _elementText(document, 'errorDescription');
    } on Object {
      // The body is not a SOAP fault; fall back to the HTTP status.
    }

    final detail = description != null && description.trim().isNotEmpty
        ? ': ${description.trim()}'
        : '';
    return DlnaTransportException(
      'Action $action rejected by the device'
      '${code == null ? '' : ' (code $code)'}$detail',
      code: code,
    );
  }

  static String? _elementText(XmlDocument document, String name) {
    for (final element in document.findAllElements(name, namespace: '*')) {
      return element.innerText;
    }
    return null;
  }

  static String _short(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  @override
  Future<void> close() async => _client.close();
}

String _buildEnvelope(
  String serviceType,
  String action,
  Map<String, String> arguments,
) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="utf-8"');
  builder.element(
    's:Envelope',
    attributes: {
      'xmlns:s': 'http://schemas.xmlsoap.org/soap/envelope/',
      's:encodingStyle': 'http://schemas.xmlsoap.org/soap/encoding/',
    },
    nest: () {
      builder.element(
        's:Body',
        nest: () {
          builder.element(
            'u:$action',
            attributes: {'xmlns:u': serviceType},
            nest: () {
              arguments.forEach((name, value) {
                builder.element(name, nest: value);
              });
            },
          );
        },
      );
    },
  );
  return builder.buildDocument().toXmlString();
}

/// `REL_TIME` uses `HH:MM:SS`, with hours allowed to exceed 24.
String formatUpnpTime(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

Duration? parseUpnpTime(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split(':');
  if (parts.length != 3) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = int.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}
