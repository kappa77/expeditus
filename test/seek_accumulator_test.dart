import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/util/seek_accumulator.dart';

void main() {
  test('compounds rapid seeks into one', () {
    final calls = <Duration>[];
    final accumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 50),
      onSeek: calls.add,
    );
    const base = Duration(seconds: 100);

    accumulator.add(const Duration(seconds: 10), base: base);
    accumulator.add(const Duration(seconds: 10), base: base);
    accumulator.add(const Duration(seconds: 10), base: base);

    expect(accumulator.pending, const Duration(seconds: 130));
    expect(calls, isEmpty);

    accumulator.flush();

    expect(calls, [const Duration(seconds: 130)]);
    expect(accumulator.pending, isNull);
  });

  test('handles backward seeks and clamps to zero', () {
    final calls = <Duration>[];
    final accumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 50),
      onSeek: calls.add,
    );

    accumulator.add(
      const Duration(seconds: -30),
      base: const Duration(seconds: 10),
    );
    expect(accumulator.pending, Duration.zero);

    accumulator.flush();
    expect(calls, [Duration.zero]);
  });

  test('clamps to the video duration', () {
    final calls = <Duration>[];
    final accumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 50),
      onSeek: calls.add,
    );

    accumulator.add(
      const Duration(seconds: 30),
      base: const Duration(seconds: 90),
      max: const Duration(minutes: 2),
    );
    expect(accumulator.pending, const Duration(minutes: 2));
  });

  test('waits for the debounce before emitting', () async {
    final calls = <Duration>[];
    final accumulator = SeekAccumulator(
      debounce: const Duration(milliseconds: 10),
      onSeek: calls.add,
    );

    accumulator.add(
      const Duration(seconds: 10),
      base: Duration.zero,
    );
    expect(calls, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(calls, [const Duration(seconds: 10)]);
  });
}
