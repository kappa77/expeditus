import 'package:xml/xml.dart';

/// DLNA flags advertised in `protocolInfo` and in response headers:
/// byte-range seek supported, no conversion, streaming flags.
const dlnaContentFeatures =
    'DLNA.ORG_OP=01;DLNA.ORG_CI=0;'
    'DLNA.ORG_FLAGS=01700000000000000000000000000000';

/// Builds the DIDL-Lite document attached to `SetAVTransportURI`.
///
/// A renderer uses this metadata to show the title and the poster while it
/// opens the stream. [albumArtUrl] is optional because it may point to an
/// image that the renderer cannot reach.
String buildDidlLiteMetadata({
  required String title,
  required Uri resourceUrl,
  required String mimeType,
  Uri? albumArtUrl,
  String itemId = 'expeditus-video',
}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="utf-8"');
  builder.element(
    'DIDL-Lite',
    attributes: {
      'xmlns': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
      'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
      'xmlns:upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
      'xmlns:dlna': 'urn:schemas-dlna-org:metadata-1-0/',
    },
    nest: () {
      builder.element(
        'item',
        attributes: {'id': itemId, 'parentID': '0', 'restricted': '1'},
        nest: () {
          builder.element('dc:title', nest: title);
          builder.element('upnp:class', nest: 'object.item.videoItem');
          if (albumArtUrl != null) {
            builder.element(
              'upnp:albumArtURI',
              attributes: {'dlna:profileID': 'JPEG_TN'},
              nest: albumArtUrl.toString(),
            );
          }
          builder.element(
            'res',
            attributes: {
              'protocolInfo': 'http-get:*:$mimeType:$dlnaContentFeatures',
            },
            nest: resourceUrl.toString(),
          );
        },
      );
    },
  );
  return builder.buildDocument().toXmlString();
}
