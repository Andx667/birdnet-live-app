// =============================================================================
// timestamp_format_test.dart
// =============================================================================
// Verifies that [formatDetectionTime] renders both modes correctly, including
// the day-rollover suffix and the negative-offset clamp.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/shared/utils/timestamp_format.dart';

void main() {
  group('formatDetectionTime — relative', () {
    final start = DateTime.utc(2026, 5, 6, 8, 0, 0);

    test('zero offset renders as 00:00', () {
      expect(
        formatDetectionTime(start, start, TimestampDisplayMode.relative),
        '00:00',
      );
    });

    test('sub-hour offset uses MM:SS', () {
      final ts = start.add(const Duration(minutes: 12, seconds: 34));
      expect(
        formatDetectionTime(ts, start, TimestampDisplayMode.relative),
        '12:34',
      );
    });

    test('multi-hour offset uses H:MM:SS', () {
      final ts = start.add(const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(
        formatDetectionTime(ts, start, TimestampDisplayMode.relative),
        '1:02:03',
      );
    });

    test('negative offset clamps to 00:00', () {
      final ts = start.subtract(const Duration(seconds: 5));
      expect(
        formatDetectionTime(ts, start, TimestampDisplayMode.relative),
        '00:00',
      );
    });

    test('clipOffset shifts the relative zero forward', () {
      final ts = start.add(const Duration(minutes: 5));
      expect(
        formatDetectionTime(
          ts,
          start,
          TimestampDisplayMode.relative,
          clipOffset: const Duration(minutes: 1),
        ),
        '04:00',
      );
    });
  });

  group('formatDetectionTime — absolute', () {
    test('renders local clock time as HH:mm:ss', () {
      // Use a local DateTime so the rendering is deterministic regardless of
      // the test runner's timezone.
      final start = DateTime(2026, 5, 6, 8, 0, 0);
      final ts = DateTime(2026, 5, 6, 8, 42, 17);
      expect(
        formatDetectionTime(ts, start, TimestampDisplayMode.absolute),
        '08:42:17',
      );
    });

    test('appends +1d when detection lands on next calendar day', () {
      final start = DateTime(2026, 5, 6, 23, 50, 0);
      final ts = DateTime(2026, 5, 7, 0, 5, 0);
      expect(
        formatDetectionTime(ts, start, TimestampDisplayMode.absolute),
        '00:05:00 +1d',
      );
    });

    test('clipOffset has no effect on absolute mode', () {
      final start = DateTime(2026, 5, 6, 8, 0, 0);
      final ts = DateTime(2026, 5, 6, 8, 5, 0);
      expect(
        formatDetectionTime(
          ts,
          start,
          TimestampDisplayMode.absolute,
          clipOffset: const Duration(minutes: 1),
        ),
        '08:05:00',
      );
    });
  });

  group('formatDetectionTime — showSeconds: false', () {
    test('relative is unaffected by showSeconds (always renders :SS)', () {
      final start = DateTime.utc(2026, 5, 6, 8, 0, 0);
      final ts = start.add(const Duration(minutes: 12, seconds: 34));
      expect(
        formatDetectionTime(
          ts,
          start,
          TimestampDisplayMode.relative,
          showSeconds: false,
        ),
        '12:34',
      );
    });

    test('absolute renders as HH:mm', () {
      final start = DateTime(2026, 5, 6, 8, 0, 0);
      final ts = DateTime(2026, 5, 6, 8, 42, 17);
      expect(
        formatDetectionTime(
          ts,
          start,
          TimestampDisplayMode.absolute,
          showSeconds: false,
        ),
        '08:42',
      );
    });

    test('absolute keeps day-rollover suffix without seconds', () {
      final start = DateTime(2026, 5, 6, 23, 50, 0);
      final ts = DateTime(2026, 5, 7, 0, 5, 0);
      expect(
        formatDetectionTime(
          ts,
          start,
          TimestampDisplayMode.absolute,
          showSeconds: false,
        ),
        '00:05 +1d',
      );
    });
  });

  group('TimestampDisplayMode.fromString', () {
    test('parses known values', () {
      expect(
        TimestampDisplayMode.fromString('relative'),
        TimestampDisplayMode.relative,
      );
      expect(
        TimestampDisplayMode.fromString('absolute'),
        TimestampDisplayMode.absolute,
      );
    });

    test('falls back to relative for unknown / null', () {
      expect(
        TimestampDisplayMode.fromString(null),
        TimestampDisplayMode.relative,
      );
      expect(
        TimestampDisplayMode.fromString('bogus'),
        TimestampDisplayMode.relative,
      );
    });
  });
}
