import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

/// Metadata read from a local ISO Base Media File Format video (MP4/M4V).
class LocalVideoMetadata {
  const LocalVideoMetadata({this.title, this.durationSeconds});

  /// Title stored in the file's `©nam`/`titl` metadata, when present.
  final String? title;

  /// Duration from the movie header, in whole seconds.
  final int? durationSeconds;
}

/// Reads the small amount of metadata Expeditus needs from local videos.
///
/// MP4 files are ISO Base Media File Format containers. This service walks the
/// box tree and reads only headers plus the metadata payloads, so adding an
/// arbitrarily large file never loads the media data into memory.
class LocalVideoService {
  const LocalVideoService();

  /// Reads title and duration from [path]. Never throws: malformed or
  /// unreadable files simply produce empty metadata so the caller can fall
  /// back to the file name.
  Future<LocalVideoMetadata> readMetadata(String path) async {
    RandomAccessFile? file;
    try {
      file = await File(path).open();
      final length = await file.length();
      if (length <= 0) return const LocalVideoMetadata();
      final info = await _readBoxes(file, start: 0, end: length, depth: 0);
      return LocalVideoMetadata(
        title: info.title,
        durationSeconds: info.durationSeconds,
      );
    } catch (_) {
      return const LocalVideoMetadata();
    } finally {
      await file?.close();
    }
  }

  /// Metadata title when it is non-empty, otherwise the file name without
  /// its extension.
  String titleFor(String path, {String? metadataTitle}) {
    final title = metadataTitle?.trim();
    if (title != null && title.isNotEmpty) return title;

    final name = p.basenameWithoutExtension(path).trim();
    return name.isEmpty ? p.basename(path) : name;
  }

  Future<_Mp4Info> _readBoxes(
    RandomAccessFile file, {
    required int start,
    required int end,
    required int depth,
  }) async {
    final info = _Mp4Info();
    if (depth > 8) return info;

    var offset = start;
    while (offset + 8 <= end) {
      final box = await _readBox(file, offset, end);
      if (box == null || box.end <= offset) break;

      switch (box.type) {
        case 'moov':
        case 'udta':
          info.merge(
            await _readBoxes(
              file,
              start: box.contentStart,
              end: box.contentEnd,
              depth: depth + 1,
            ),
          );
        case 'meta':
          // `meta` is a full box: the four version/flag bytes precede the
          // child boxes.
          info.merge(
            await _readBoxes(
              file,
              start: math.min(box.contentStart + 4, box.contentEnd),
              end: box.contentEnd,
              depth: depth + 1,
            ),
          );
        case 'ilst':
          info.merge(
            await _readBoxes(
              file,
              start: box.contentStart,
              end: box.contentEnd,
              depth: depth + 1,
            ),
          );
        case '\u00A9nam':
          info.title ??= await _readDataText(file, box);
        case 'titl':
          info.title ??= await _readThreeGppTitle(file, box);
        case 'mvhd':
          info.durationSeconds ??= await _readMovieDuration(file, box);
      }

      offset = box.end;
    }
    return info;
  }

  Future<_Mp4Box?> _readBox(
    RandomAccessFile file,
    int offset,
    int parentEnd,
  ) async {
    if (offset + 8 > parentEnd) return null;

    await file.setPosition(offset);
    final header = await file.read(8);
    if (header.length < 8) return null;

    final size32 = _uint32(header, 0);
    final type = String.fromCharCodes(header.sublist(4, 8));
    var headerSize = 8;
    var size = size32;

    if (size32 == 1) {
      final extended = await file.read(8);
      if (extended.length < 8) return null;
      final high = _uint32(extended, 0);
      final low = _uint32(extended, 4);
      if (high > 0x7fffffff) return null;
      size = high * 0x100000000 + low;
      headerSize = 16;
    } else if (size32 == 0) {
      size = parentEnd - offset;
    }

    if (size < headerSize || offset + size > parentEnd) return null;

    return _Mp4Box(
      type: type,
      start: offset,
      contentStart: offset + headerSize,
      end: offset + size,
    );
  }

  Future<String?> _readDataText(RandomAccessFile file, _Mp4Box titleBox) async {
    final data = await _findChild(file, titleBox, 'data');
    if (data == null) return null;

    final length = data.contentEnd - data.contentStart;
    if (length <= 8 || length > 64 * 1024) return null;

    await file.setPosition(data.contentStart);
    final bytes = await file.read(length);
    if (bytes.length < 8) return null;

    // The `data` box payload starts with a 4-byte type and a 4-byte locale.
    final dataType = _uint32(bytes, 0) & 0x00FFFFFF;
    final payload = bytes.sublist(8);
    final text = dataType == 2
        ? _decodeUtf16(payload)
        : utf8.decode(payload, allowMalformed: true);
    final title = text.replaceAll('\u0000', '').replaceAll('\uFEFF', '').trim();
    return title.isEmpty ? null : title;
  }

  Future<String?> _readThreeGppTitle(
    RandomAccessFile file,
    _Mp4Box titleBox,
  ) async {
    final length = titleBox.contentEnd - titleBox.contentStart;
    // Full box header (4 bytes) + packed ISO-639-2/T language (2 bytes).
    if (length <= 6 || length > 64 * 1024) return null;

    await file.setPosition(titleBox.contentStart);
    final bytes = await file.read(length);
    if (bytes.length <= 6) return null;

    final text = utf8.decode(bytes.sublist(6), allowMalformed: true);
    final title = text.replaceAll('\u0000', '').trim();
    return title.isEmpty ? null : title;
  }

  Future<int?> _readMovieDuration(
    RandomAccessFile file,
    _Mp4Box movieHeader,
  ) async {
    final length = math.min(
      movieHeader.contentEnd - movieHeader.contentStart,
      32,
    );
    if (length < 20) return null;

    await file.setPosition(movieHeader.contentStart);
    final bytes = await file.read(length);
    if (bytes.length < 20) return null;

    final version = bytes[0];
    final int timescale;
    final int duration;
    if (version == 1) {
      if (bytes.length < 32) return null;
      timescale = _uint32(bytes, 20);
      duration = _uint64(bytes, 24);
    } else {
      timescale = _uint32(bytes, 12);
      duration = _uint32(bytes, 16);
    }

    if (timescale <= 0 || duration <= 0 || duration == 0xFFFFFFFF) return null;
    final seconds = (duration / timescale).round();
    return seconds > 0 ? seconds : null;
  }

  Future<_Mp4Box?> _findChild(
    RandomAccessFile file,
    _Mp4Box parent,
    String type,
  ) async {
    var offset = parent.contentStart;
    while (offset + 8 <= parent.contentEnd) {
      final box = await _readBox(file, offset, parent.contentEnd);
      if (box == null || box.end <= offset) return null;
      if (box.type == type) return box;
      offset = box.end;
    }
    return null;
  }
}

class _Mp4Info {
  String? title;
  int? durationSeconds;

  void merge(_Mp4Info other) {
    title ??= other.title;
    durationSeconds ??= other.durationSeconds;
  }
}

class _Mp4Box {
  const _Mp4Box({
    required this.type,
    required this.start,
    required this.contentStart,
    required this.end,
  });

  final String type;
  final int start;
  final int contentStart;
  final int end;

  int get contentEnd => end;
}

int _uint32(List<int> bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

int _uint64(List<int> bytes, int offset) {
  return _uint32(bytes, offset) * 0x100000000 + _uint32(bytes, offset + 4);
}

String _decodeUtf16(List<int> bytes) {
  var offset = 0;
  var littleEndian = false;
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    offset = 2;
    littleEndian = true;
  } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    offset = 2;
  }

  final units = <int>[];
  for (var i = offset; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}
