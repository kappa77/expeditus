import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// Fast, playback-independent loudness measurement.
///
/// The analysis is done by a second, hidden libmpv instance that decodes only
/// the first seconds of the audio into a temporary WAV file. With `untimed`
/// enabled this costs a fraction of a second for a local file and downloads
/// only the requested window for an audio-only stream. No video frame is
/// decoded and no audio device is opened (`ao=pcm` writes to the file
/// instead), so playback is never interrupted.
class LoudnessAnalyzer {
  LoudnessAnalyzer({
    this.window = const Duration(seconds: 10),
    this.timeout = const Duration(seconds: 20),
  });

  /// How much audio to measure. Ten seconds are enough to estimate speech and
  /// music levels while keeping the analysis cheap.
  final Duration window;

  /// Hard limit for a slow network or a decoder that never reaches EOF.
  final Duration timeout;

  Player? _player;
  Completer<void>? _cancelSignal;
  int _generation = 0;
  bool _disposed = false;

  Future<AudioLoudness?> analyze(Playable source) async {
    if (_disposed) return null;
    final generation = ++_generation;
    await _disposePlayer();

    final cancelSignal = Completer<void>();
    _cancelSignal = cancelSignal;
    Directory? directory;
    Player? player;
    try {
      directory = await _createTempDirectory();
      final wavPath = p.join(directory.path, 'audio.wav');
      player = Player(
        configuration: const PlayerConfiguration(
          // The audio window is small; a large cache would only add latency.
          bufferSize: 8 * 1024 * 1024,
        ),
      );
      _player = player;

      final platform = player.platform;
      if (platform is! NativePlayer) return null;
      for (final entry in <String, String>{
        // Write decoded audio to a file instead of opening an audio device.
        'ao': 'pcm',
        'ao-pcm-file': wavPath,
        'ao-pcm-waveheader': 'yes',
        'ao-pcm-append': 'no',
        // Decode as fast as the source allows instead of real time.
        'untimed': 'yes',
        'end': (window.inMilliseconds / 1000).toStringAsFixed(3),
        // Audio only: mpv will not decode video frames.
        'vid': 'no',
        'audio': 'yes',
        'audio-display': 'no',
        // Measure the original level, without user volume or filters.
        'volume': '100',
        'volume-max': '200',
        'af': '',
        'cache': 'yes',
        'cache-on-disk': 'no',
      }.entries) {
        try {
          await platform.setProperty(entry.key, entry.value);
        } on Object {
          // An older libmpv may not know every option. If the WAV output does
          // not work, the analysis below returns null and playback is normal.
        }
      }

      // If libmpv refused to switch the output (some Android builds set
      // OpenSL ES at construction), do not open the media: an untimed hidden
      // player would otherwise play the window as a short burst.
      try {
        final output = await platform.getProperty('ao');
        if (!output.toLowerCase().contains('pcm')) return null;
      } on Object {
        return null;
      }

      final done = Completer<void>();
      final subscriptions = <StreamSubscription<Object?>>[
        player.stream.completed.listen((completed) {
          if (completed && !done.isCompleted) done.complete();
        }),
        player.stream.error.listen((error) {
          if (!done.isCompleted) done.completeError(StateError(error));
        }),
      ];
      try {
        await player.open(source, play: true);
        await Future.any([done.future, cancelSignal.future]).timeout(timeout);
      } finally {
        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
      }

      if (generation != _generation || _disposed) return null;
      // Close the audio output before reading the file so the WAV header and
      // the last samples are flushed.
      if (identical(_player, player)) {
        await player.dispose();
        _player = null;
      }
      final file = File(wavPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length < 64) return null;
      return AudioLoudnessCodec.parseWav(bytes);
    } on Object {
      return null;
    } finally {
      if (identical(_cancelSignal, cancelSignal)) _cancelSignal = null;
      // If a newer analysis or cancel() replaced the player, it already
      // disposed this one. Only clean up the instance this call still owns.
      if (identical(_player, player)) {
        await _disposePlayer();
      }
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } on Object {
          // Best effort: the OS will clean its temporary directory.
        }
      }
    }
  }

  Future<Directory> _createTempDirectory() async {
    try {
      final root = await getTemporaryDirectory();
      return await Directory(
        p.join(
          root.path,
          'expeditus_loudness_${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
    } on Object {
      return Directory.systemTemp.createTemp('expeditus_loudness_');
    }
  }

  Future<void> _disposePlayer() async {
    final signal = _cancelSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } on Object {
      // The player may already be closing after an open failure.
    }
  }

  /// Stops a running analysis. The pending future completes with null.
  Future<void> cancel() async {
    _generation++;
    await _disposePlayer();
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancel();
  }
}

/// WAV parsing and gain policy shared by the analyzer and its tests.
class AudioLoudnessCodec {
  /// Gated RMS target. Speech and documentary audio sit around -16/-18 dBFS
  /// RMS; -15 dBFS makes quiet local files clearly louder without turning
  /// normal YouTube audio into a wall of sound.
  static const double targetRmsDb = -15;

  /// Leave one decibel of headroom for the sample peak returned by libmpv.
  static const double ceilingDb = -1;

  /// Never apply more than this much gain. A quiet intro must not turn into a
  /// huge boost for loud speech later in the video.
  static const double maxGainDb = 6;

  /// Gain that raises [sample] to the target, limited by the measured peak.
  ///
  /// The peak limit is what makes a static gain safe without a limiter: a
  /// video whose peaks already touch full scale is left alone instead of
  /// clipping. Only positive gains are returned because the goal is to raise
  /// quiet playback, not to re-master loud material.
  static double gainFor(
    AudioLoudness sample, {
    double target = targetRmsDb,
    double ceiling = ceilingDb,
    double maxGain = maxGainDb,
  }) {
    if (!sample.rmsDb.isFinite || !sample.peakDb.isFinite) return 0;
    final byLoudness = target - sample.rmsDb;
    final byPeak = ceiling - sample.peakDb;
    final gain = math.min(byLoudness, byPeak);
    if (gain <= 0.25) return 0;
    return math.min(gain, maxGain);
  }

  /// mpv's `volume` property uses a cubic amplitude scale: 100 is unity and
  /// `60 * log10(volume / 100)` is the resulting gain in dB. Keeping the
  /// conversion here avoids a second, linear-only formula in the player.
  static double volumePercentForGain(double gainDb) {
    if (!gainDb.isFinite || gainDb <= 0) return 100;
    return 100 * math.pow(10, gainDb / 60).toDouble();
  }

  /// Measures gated RMS and absolute peak from a RIFF/WAVE file produced by
  /// `ao=pcm`. Float32 (what mpv writes) and 16-bit PCM are supported.
  static AudioLoudness? parseWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (id == 'fmt ' && start + 16 <= bytes.length) {
        channels = data.getUint16(start + 2, Endian.little);
        sampleRate = data.getUint32(start + 4, Endian.little);
        bitsPerSample = data.getUint16(start + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = start;
        dataSize = math.min(size, bytes.length - start);
      }
      offset = start + size + (size & 1);
    }

    final count = dataSize;
    if (count == null ||
        dataOffset == null ||
        channels == null ||
        channels <= 0 ||
        sampleRate == null ||
        sampleRate <= 0 ||
        bitsPerSample == null ||
        count < 64) {
      return null;
    }

    final dataStart = dataOffset;
    final channelCount = channels;
    final rate = sampleRate;
    final bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample != 2 && bytesPerSample != 4) return null;
    final sampleCount = count ~/ bytesPerSample;
    if (sampleCount < channelCount) return null;
    final frameCount = sampleCount ~/ channelCount;
    if (frameCount < 1) return null;

    final blockFrames = math.max(1, (rate * 0.4).round());
    final energies = <double>[];
    final samplesPerBlock = <int>[];
    var blockEnergy = 0.0;
    var blockSamples = 0;
    var peak = 0.0;

    double sampleAt(int index) {
      final position = dataStart + index * bytesPerSample;
      if (bytesPerSample == 4) {
        return data.getFloat32(position, Endian.little);
      }
      return data.getInt16(position, Endian.little) / 32768.0;
    }

    for (var frame = 0; frame < frameCount; frame++) {
      for (var channel = 0; channel < channelCount; channel++) {
        final value = sampleAt(frame * channels + channel);
        final absolute = value.abs();
        if (absolute > peak) peak = absolute;
        blockEnergy += value * value;
        blockSamples++;
      }
      if ((frame + 1) % blockFrames == 0) {
        energies.add(blockEnergy);
        samplesPerBlock.add(blockSamples);
        blockEnergy = 0;
        blockSamples = 0;
      }
    }
    if (blockSamples > 0) {
      energies.add(blockEnergy);
      samplesPerBlock.add(blockSamples);
    }
    if (energies.isEmpty) return null;

    // EBU-style gating: ignore silence and quiet tails so a long intro or
    // pause does not make speech look much quieter than it is.
    final blockDb = <double>[];
    for (var i = 0; i < energies.length; i++) {
      blockDb.add(10 * _log10(energies[i] / samplesPerBlock[i] + 1e-20));
    }
    final aboveAbsolute = <double>[
      for (final db in blockDb)
        if (db > -70) db,
    ];
    var gate = -70.0;
    if (aboveAbsolute.isNotEmpty) {
      final meanEnergy =
          aboveAbsolute
              .map((db) => math.pow(10, db / 10).toDouble())
              .reduce((a, b) => a + b) /
          aboveAbsolute.length;
      gate = math.max(gate, 10 * _log10(meanEnergy) - 10);
    }

    var keptEnergy = 0.0;
    var keptSamples = 0;
    for (var i = 0; i < energies.length; i++) {
      if (blockDb[i] <= gate) continue;
      keptEnergy += energies[i];
      keptSamples += samplesPerBlock[i];
    }
    // A completely silent window carries no usable level. Returning null is
    // safer than treating it as very quiet speech and applying maximum gain
    // to whatever plays later in the video.
    if (keptSamples == 0) return null;

    final rms = math.sqrt(keptEnergy / keptSamples);
    return AudioLoudness(
      rmsDb: 20 * _log10(rms + 1e-12),
      peakDb: 20 * _log10(peak + 1e-12),
    );
  }

  static double _log10(double value) => math.log(value) / math.ln10;
}
