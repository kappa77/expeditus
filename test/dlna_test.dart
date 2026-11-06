import 'package:expeditus/src/services/dlna/dlna_metadata.dart';
import 'package:expeditus/src/services/dlna/dlna_models.dart';
import 'package:expeditus/src/services/dlna/dlna_transport.dart';
import 'package:expeditus/src/services/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';

const _description = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>TV Salotto</friendlyName>
    <manufacturer>Samsung</manufacturer>
    <modelName>UE55</modelName>
    <UDN>uuid:renderer-1</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/AVTransport1</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/RenderingControl1</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';

String _soapBody(String inner) {
  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>$inner</s:Body>
</s:Envelope>''';
}

DlnaDevice _device() {
  return DlnaDevice(
    friendlyName: 'TV Salotto',
    modelName: 'UE55',
    udn: 'uuid:renderer-1',
    location: Uri.parse('http://192.168.1.50:9197/dmr'),
    avTransportControlUrl: Uri.parse('http://192.168.1.50:9197/avt'),
  );
}

void main() {
  group('SSDP', () {
    test('legge la LOCATION da una risposta 200', () {
      final response = parseSsdpResponse(
        'HTTP/1.1 200 OK\r\n'
        'CACHE-CONTROL: max-age=1800\r\n'
        'LOCATION: http://192.168.1.50:9197/dmr\r\n'
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        'USN: uuid:renderer-1::urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        '\r\n',
      );

      expect(response, isNotNull);
      expect(response!.location.toString(), 'http://192.168.1.50:9197/dmr');
      expect(response.usn, contains('renderer-1'));
    });

    test('ignora risposte non valide o senza LOCATION', () {
      expect(parseSsdpResponse('NOTIFY * HTTP/1.1\r\n\r\n'), isNull);
      expect(
        parseSsdpResponse('HTTP/1.1 200 OK\r\nST: ssdp:all\r\n\r\n'),
        isNull,
      );
      expect(
        parseSsdpResponse(
          'HTTP/1.1 200 OK\r\nLOCATION: ftp://192.168.1.2/device.xml\r\n\r\n',
        ),
        isNull,
      );
    });
  });

  group('descrizione dispositivo', () {
    test('estrae nome, modello e URL di controllo', () {
      final device = parseDeviceDescription(
        _description,
        Uri.parse('http://192.168.1.50:9197/dmr'),
      );

      expect(device, isNotNull);
      expect(device!.displayName, 'TV Salotto');
      expect(device.modelName, 'UE55');
      expect(device.udn, 'uuid:renderer-1');
      expect(
        device.avTransportControlUrl.toString(),
        'http://192.168.1.50:9197/upnp/control/AVTransport1',
      );
      expect(
        device.renderingControlControlUrl.toString(),
        'http://192.168.1.50:9197/upnp/control/RenderingControl1',
      );
    });

    test('onora URLBase per i controlURL relativi', () {
      final xml = _description
          .replaceFirst(
            '<specVersion>',
            '<URLBase>http://192.168.1.50:1234/</URLBase><specVersion>',
          )
          .replaceFirst(
            '<controlURL>/upnp/control/AVTransport1</controlURL>',
            '<controlURL>control/avt</controlURL>',
          );

      final device = parseDeviceDescription(
        xml,
        Uri.parse('http://192.168.1.50:9197/dmr'),
      );

      expect(
        device!.avTransportControlUrl.toString(),
        'http://192.168.1.50:1234/control/avt',
      );
    });

    test('scarta dispositivi senza AVTransport e XML non valido', () {
      final noAv = _description.replaceAll('AVTransport', 'ConnectionManager');
      expect(parseDeviceDescription(noAv, Uri.parse('http://tv/dmr')), isNull);
      expect(
        parseDeviceDescription('<root>', Uri.parse('http://tv/dmr')),
        isNull,
      );
    });
  });

  group('metadata DIDL-Lite', () {
    test('produce XML valido con titolo, poster e protocollo', () {
      final xml = buildDidlLiteMetadata(
        title: 'Titolo & <speciale>',
        resourceUrl: Uri.parse('http://192.168.1.2:5555/media/token.mp4'),
        mimeType: 'video/mp4',
        albumArtUrl: Uri.parse('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
        itemId: 'abc',
      );

      final document = XmlDocument.parse(xml);
      final item = document.findAllElements('item', namespace: '*').single;
      expect(item.getAttribute('id'), 'abc');
      expect(
        document.findAllElements('title', namespace: '*').single.innerText,
        'Titolo & <speciale>',
      );
      expect(
        document.findAllElements('class', namespace: '*').single.innerText,
        'object.item.videoItem',
      );
      expect(
        document
            .findAllElements('res', namespace: '*')
            .single
            .getAttribute('protocolInfo'),
        'http-get:*:video/mp4:$dlnaContentFeatures',
      );
      expect(
        document
            .findAllElements('albumArtURI', namespace: '*')
            .single
            .innerText,
        'https://i.ytimg.com/vi/abc/hqdefault.jpg',
      );
    });

    test('mappa i tipi di stream sui MIME type DLNA', () {
      expect(mimeTypeForStreamKind('hls'), 'application/vnd.apple.mpegurl');
      expect(mimeTypeForStreamKind('muxed'), 'video/mp4');
      expect(mimeTypeForStreamKind('file'), 'video/mp4');
    });
  });

  group('trasporto SOAP', () {
    test('invia SetAVTransportURI con metadati e azione corretta', () async {
      late http.Request captured;
      final transport = DlnaSoapTransport(
        _device(),
        client: MockClient((request) async {
          captured = request;
          return http.Response(_soapBody(''), 200);
        }),
      );

      await transport.setAvTransportUri(
        uri: Uri.parse('http://192.168.1.2:5555/media/a.mp4'),
        metadata: '<DIDL-Lite><item id="a" /></DIDL-Lite>',
      );

      expect(captured.url.toString(), 'http://192.168.1.50:9197/avt');
      expect(captured.headers['SOAPAction'], contains('#SetAVTransportURI'));
      expect(captured.body, contains('http://192.168.1.2:5555/media/a.mp4'));
      expect(captured.body, contains('&lt;DIDL-Lite>'));
      expect(captured.body, contains('<InstanceID>0</InstanceID>'));
    });

    test('legge stato e posizione dalle risposte', () async {
      final transport = DlnaSoapTransport(
        _device(),
        client: MockClient((request) async {
          if (request.body.contains('GetPositionInfo')) {
            return http.Response(
              _soapBody(
                '<u:GetPositionInfoResponse><RelTime>01:02:03</RelTime>'
                '</u:GetPositionInfoResponse>',
              ),
              200,
            );
          }
          return http.Response(
            _soapBody(
              '<u:GetTransportInfoResponse><CurrentTransportState>PLAYING'
              '</CurrentTransportState></u:GetTransportInfoResponse>',
            ),
            200,
          );
        }),
      );

      expect(await transport.getTransportInfo(), DlnaTransportState.playing);
      expect(
        await transport.getPosition(),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('rialza un SOAP fault con il codice UPnP', () async {
      final transport = DlnaSoapTransport(
        _device(),
        client: MockClient((_) async {
          return http.Response(
            _soapBody(
              '<u:Fault><UPnPError><errorCode>701</errorCode>'
              '<errorDescription>Transition not available</errorDescription>'
              '</UPnPError></u:Fault>',
            ),
            500,
          );
        }),
      );

      await expectLater(
        transport.play(),
        throwsA(
          isA<DlnaTransportException>()
              .having((error) => error.code, 'code', 701)
              .having(
                (error) => error.message,
                'message',
                contains('Transition not available'),
              ),
        ),
      );
    });

    test('formatta e interpreta i tempi REL_TIME', () {
      expect(formatUpnpTime(const Duration(seconds: 5)), '00:00:05');
      expect(
        formatUpnpTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(
        parseUpnpTime('01:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(parseUpnpTime('NOT_IMPLEMENTED'), isNull);
    });
  });
}
