import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:expeditus/src/data/database.dart';
import 'package:expeditus/src/models.dart';
import 'package:expeditus/src/services/loudness_analyzer.dart';
import 'package:expeditus/src/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List _wav(
  List<double> samples, {
  int channels = 1,
  int sampleRate = 48000,
  int bitsPerSample = 32,
}) {
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataSize = samples.length * bytesPerSample;
  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, bitsPerSample == 16 ? 1 : 3, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  data.setUint16(32, channels * bytesPerSample, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final offset = 44 + i * bytesPerSample;
    if (bitsPerSample == 16) {
      data.setInt16(
        offset,
        (samples[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    } else {
      data.setFloat32(offset, samples[i], Endian.little);
    }
  }
  return bytes;
}

List<double> _tone(double amplitude, double seconds, {int sampleRate = 48000}) {
  final count = (seconds * sampleRate).round();
  return [
    for (var i = 0; i < count; i++)
      amplitude * math.sin(2 * math.pi * 440 * i / sampleRate),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WAV analysis', () {
    test('measures the peak and RMS of a floating point tone', () {
      final sample = AudioLoudnessCodec.parseWav(_wav(_tone(0.25, 1)));
      expect(sample, isNotNull);
      expect(sample!.peakDb, closeTo(-12.04, 0.2));
      expect(sample.rmsDb, closeTo(-15.05, 0.3));
    });

    test('supports 16-bit PCM', () {
      final sample = AudioLoudnessCodec.parseWav(
        _wav(_tone(0.5, 1), bitsPerSample: 16),
      );
      expect(sample, isNotNull);
      expect(sample!.peakDb, closeTo(-6.02, 0.2));
      expect(sample.rmsDb, closeTo(-9.03, 0.3));
    });

    test('gates silence out of the measurement', () {
      final bytes = _wav([
        ...List<double>.filled(48000 * 5, 0),
        ..._tone(0.25, 5),
      ]);
      final sample = AudioLoudnessCodec.parseWav(bytes);
      expect(sample, isNotNull);
      // The ungated level would be about -18 dBFS. Gating must recover the
      // level of the audible half instead of treating the intro as quiet
      // speech.
      expect(sample!.rmsDb, greaterThan(-16));
    });

    test('returns null for a silent window', () {
      expect(
        AudioLoudnessCodec.parseWav(_wav(List<double>.filled(48000, 0))),
        isNull,
      );
    });

    test('rejects malformed or truncated files', () {
      expect(AudioLoudnessCodec.parseWav(Uint8List(0)), isNull);
      expect(AudioLoudnessCodec.parseWav(Uint8List(44)), isNull);
      expect(
        AudioLoudnessCodec.parseWav(_wav(_tone(0.25, 1)).sublist(0, 30)),
        isNull,
      );
    });
  });

  group('gain policy', () {
    test('uses the quieter of loudness and peak headroom', () {
      expect(
        AudioLoudnessCodec.gainFor(const AudioLoudness(rmsDb: -20, peakDb: -6)),
        closeTo(5, 0.001),
      );
      expect(
        AudioLoudnessCodec.gainFor(const AudioLoudness(rmsDb: -20, peakDb: -2)),
        closeTo(1, 0.001),
      );
    });

    test('never attenuates already loud media', () {
      expect(
        AudioLoudnessCodec.gainFor(
          const AudioLoudness(rmsDb: -10, peakDb: -0.2),
        ),
        0,
      );
    });

    test('caps runaway gain on almost silent media', () {
      expect(AudioLoudnessCodec.maxGainDb, 6);
      expect(
        AudioLoudnessCodec.gainFor(
          const AudioLoudness(rmsDb: -40, peakDb: -30),
        ),
        AudioLoudnessCodec.maxGainDb,
      );
    });

    test('converts dB to the cubic mpv volume scale', () {
      expect(AudioLoudnessCodec.volumePercentForGain(0), 100);
      expect(AudioLoudnessCodec.volumePercentForGain(6), closeTo(125.89, 0.01));
      expect(AudioLoudnessCodec.volumePercentForGain(-5), 100);
    });
  });

  test('stores measured loudness and keeps the setting', () async {
    final temp = await Directory.systemTemp.createTemp('expeditus_loudness_');
    final db = AppDatabase(pathOverride: p.join(temp.path, 'test.sqlite'));
    await db.open();
    addTearDown(() async {
      await db.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    expect(await db.getAudioLoudness('local:a'), isNull);
    await db.saveAudioLoudness(
      'local:a',
      const AudioLoudness(rmsDb: -17.5, peakDb: -3.2),
    );
    final saved = await db.getAudioLoudness('local:a');
    expect(saved, isNotNull);
    expect(saved!.rmsDb, -17.5);
    expect(saved.peakDb, -3.2);

    final state = AppState(db);
    expect(state.normalizeVolume, isTrue);
    await state.setNormalizeVolume(false);
    expect(state.normalizeVolume, isFalse);
    expect(await db.getSettings(), containsPair('normalizeVolume', '0'));
    state.dispose();
  });
}
