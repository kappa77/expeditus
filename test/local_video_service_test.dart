import 'dart:convert';
import 'dart:io';

import 'package:expeditus/src/services/local_video_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _titleAtom = [0xA9, 0x6E, 0x61, 0x6D]; // ©nam

List<int> _u32(int value) {
  return [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

List<int> _u64(int value) {
  return [..._u32(value ~/ 0x100000000), ..._u32(value & 0xFFFFFFFF)];
}

List<int> _box(List<int> type, List<int> payload, {bool extended = false}) {
  final header = extended ? 16 : 8;
  return [
    if (extended) ..._u32(1) else ..._u32(header + payload.length),
    ...type,
    if (extended) ..._u64(header + payload.length),
    ...payload,
  ];
}

List<int> _textBox(String type, String text, {int dataType = 1}) {
  final payload = dataType == 2
      ? [
          0xFE, 0xFF, // UTF-16BE BOM
          for (final unit in text.codeUnits) ...[unit >> 8, unit & 0xFF],
        ]
      : utf8.encode(text);
  return _box(utf8.encode(type), [
    ..._u32(dataType),
    ..._u32(0), // locale
    ...payload,
  ]);
}

List<int> _movieHeader({int timescale = 1000, int duration = 125000}) {
  return _box(
    [0x6D, 0x76, 0x68, 0x64],
    [
      // mvhd
      ..._u32(0), // version + flags
      ..._u32(0), // creation
      ..._u32(0), // modification
      ..._u32(timescale),
      ..._u32(duration),
    ],
  );
}

List<int> _mp4WithTitle(
  String title, {
  bool extendedTitleBox = false,
  int dataType = 1,
  int timescale = 1000,
  int duration = 125000,
}) {
  final titleBox = _box(_titleAtom, [
    ..._textBox('data', title),
  ], extended: extendedTitleBox);
  return _box(
    [0x6D, 0x6F, 0x6F, 0x76],
    [
      // moov
      ..._movieHeader(timescale: timescale, duration: duration),
      ..._box(
        [0x75, 0x64, 0x74, 0x61],
        [
          // udta
          ..._box(
            [0x6D, 0x65, 0x74, 0x61],
            [
              // meta
              ..._u32(0), // version + flags
              ..._box([0x69, 0x6C, 0x73, 0x74], [...titleBox]), // ilst
            ],
          ),
        ],
      ),
    ],
  );
}

Future<File> _writeTemp(String name, List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('expeditus_mp4_');
  addTearDown(() => directory.delete(recursive: true));
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(bytes);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = LocalVideoService();

  test('legge il titolo dai metadati ©nam', () async {
    final file = await _writeTemp(
      'nome-del-file.mp4',
      _mp4WithTitle('Titolo dai metadati'),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, 'Titolo dai metadati');
    expect(
      service.titleFor(file.path, metadataTitle: metadata.title),
      'Titolo dai metadati',
    );
  });

  test('legge la durata da mvhd', () async {
    final file = await _writeTemp(
      'durata.mp4',
      _mp4WithTitle('Con durata', timescale: 1000, duration: 125000),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.durationSeconds, 125);
  });

  test('legge i titoli UTF-16', () async {
    final file = await _writeTemp(
      'utf16.mp4',
      _mp4WithTitle('Titolo UTF-16', dataType: 2),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, 'Titolo UTF-16');
  });

  test('supporta le box con dimensione a 64 bit', () async {
    final file = await _writeTemp(
      'extended.mp4',
      _mp4WithTitle('Titolo esteso', extendedTitleBox: true),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, 'Titolo esteso');
  });

  test('usa il nome del file quando i metadati mancano', () async {
    final file = await _writeTemp(
      'Video_del_weekend.mp4',
      _box([0x6D, 0x6F, 0x6F, 0x76], []),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, isNull);
    expect(service.titleFor(file.path), 'Video_del_weekend');
  });

  test('ignora un titolo vuoto e usa il nome del file', () async {
    final file = await _writeTemp('fallback.mp4', _mp4WithTitle('   '));

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, isNull);
    expect(
      service.titleFor(file.path, metadataTitle: metadata.title),
      'fallback',
    );
  });

  test('un file non valido non fa fallire l’aggiunta', () async {
    final file = await _writeTemp('rotto.mp4', [1, 2, 3, 4, 5]);

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, isNull);
    expect(metadata.durationSeconds, isNull);
    expect(service.titleFor(file.path), 'rotto');
  });

  test('un file inesistente restituisce metadati vuoti', () async {
    final metadata = await service.readMetadata(
      p.join(Directory.systemTemp.path, 'non-esiste-12345.mp4'),
    );

    expect(metadata.title, isNull);
    expect(metadata.durationSeconds, isNull);
  });

  test('legge il titolo 3GPP titl', () async {
    final file = await _writeTemp(
      'tre-gpp.mp4',
      _box(
        [0x6D, 0x6F, 0x6F, 0x76],
        [
          ..._box(
            [0x75, 0x64, 0x74, 0x61],
            [
              ..._box(
                [0x74, 0x69, 0x74, 0x6C],
                [
                  ..._u32(0),
                  0x15, 0xC7, // packed language
                  ...utf8.encode('Titolo 3GPP'),
                  0,
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final metadata = await service.readMetadata(file.path);

    expect(metadata.title, 'Titolo 3GPP');
  });

  test('preferisce il nome del file senza estensione', () {
    expect(service.titleFor('/cartella/Il.mio.video.mp4'), 'Il.mio.video');
  });
}
