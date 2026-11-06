import 'package:xml/xml.dart';

/// Response to an SSDP `M-SEARCH` request.
class SsdpResponse {
  const SsdpResponse({
    required this.location,
    this.usn,
    this.searchTarget,
    this.server,
  });

  final Uri location;
  final String? usn;
  final String? searchTarget;
  final String? server;
}

/// A UPnP/DLNA MediaRenderer reachable on the local network.
class DlnaDevice {
  const DlnaDevice({
    required this.friendlyName,
    required this.modelName,
    required this.udn,
    required this.location,
    required this.avTransportControlUrl,
    this.renderingControlControlUrl,
  });

  final String friendlyName;
  final String modelName;
  final String udn;
  final Uri location;
  final Uri avTransportControlUrl;
  final Uri? renderingControlControlUrl;

  /// A non-empty label for the UI.
  String get displayName {
    final name = friendlyName.trim();
    if (name.isNotEmpty) return name;
    final model = modelName.trim();
    if (model.isNotEmpty) return model;
    return udn.trim().isNotEmpty ? udn.trim() : 'Dispositivo DLNA';
  }

  String get descriptor => modelName.trim().isEmpty ? udn : modelName.trim();
}

/// Parses one SSDP search response. Returns null for unrelated or malformed
/// datagrams.
SsdpResponse? parseSsdpResponse(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return null;
  final status = lines.first.trim().toUpperCase();
  if (!status.startsWith('HTTP/1.1 200') &&
      !status.startsWith('HTTP/1.0 200')) {
    return null;
  }

  final headers = <String, String>{};
  for (final line in lines.skip(1)) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final name = line.substring(0, separator).trim().toLowerCase();
    final value = line.substring(separator + 1).trim();
    if (name.isNotEmpty && value.isNotEmpty) headers[name] = value;
  }

  final rawLocation = headers['location'];
  if (rawLocation == null) return null;
  final location = Uri.tryParse(rawLocation);
  if (location == null ||
      !location.hasScheme ||
      (location.scheme != 'http' && location.scheme != 'https')) {
    return null;
  }

  return SsdpResponse(
    location: location,
    usn: headers['usn'],
    searchTarget: headers['st'],
    server: headers['server'],
  );
}

/// Parses a UPnP device description document and extracts the AVTransport
/// control endpoint used to push media.
///
/// Returns null when the document is not valid XML or does not expose the
/// AVTransport service (for example an audio-only or non-renderer device).
DlnaDevice? parseDeviceDescription(String xml, Uri location) {
  XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } catch (_) {
    return null;
  }

  final root = _first(document.findAllElements('device', namespace: '*'));
  if (root == null) return null;

  final urlBaseText = _text(document, 'URLBase');
  final urlBase = urlBaseText == null ? null : Uri.tryParse(urlBaseText);
  final base = urlBase != null && urlBase.hasScheme ? urlBase : location;

  Uri? avTransport;
  Uri? renderingControl;
  for (final service in document.findAllElements('service', namespace: '*')) {
    final type = (_text(service, 'serviceType') ?? '').toLowerCase();
    final control = _text(service, 'controlURL');
    if (control == null) continue;
    final resolved = base.resolve(control);
    if (type.contains('avtransport')) {
      avTransport ??= resolved;
    } else if (type.contains('renderingcontrol')) {
      renderingControl ??= resolved;
    }
  }
  if (avTransport == null) return null;

  final friendlyName = _text(root, 'friendlyName') ?? '';
  final modelName = _text(root, 'modelName') ?? '';
  final udn =
      _text(root, 'UDN') ?? _text(document, 'UDN') ?? location.toString();

  return DlnaDevice(
    friendlyName: friendlyName,
    modelName: modelName,
    udn: udn,
    location: location,
    avTransportControlUrl: avTransport,
    renderingControlControlUrl: renderingControl,
  );
}

String? _text(XmlNode node, String name) {
  final element = _first(node.findAllElements(name, namespace: '*'));
  if (element == null) return null;
  final value = element.innerText.trim();
  return value.isEmpty ? null : value;
}

T? _first<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
