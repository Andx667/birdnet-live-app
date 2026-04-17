// =============================================================================
// Detection Sampler Tests — All / TopN / Smart sampling modes
// =============================================================================

import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

DetectionRecord _det(String sci, double conf,
    {Duration offset = Duration.zero,
    double? latitude,
    double? longitude}) {
  return DetectionRecord(
    scientificName: sci,
    commonName: sci,
    confidence: conf,
    timestamp: DateTime.utc(2025, 7, 1, 12).add(offset),
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  group('samplingModeFromString', () {
    test('parses known modes', () {
      expect(samplingModeFromString('all'), SamplingMode.all);
      expect(samplingModeFromString('topN'), SamplingMode.topN);
      expect(samplingModeFromString('smart'), SamplingMode.smart);
    });

    test('falls back to all for unknown', () {
      expect(samplingModeFromString('unknown'), SamplingMode.all);
      expect(samplingModeFromString(''), SamplingMode.all);
    });
  });

  group('SamplingMode.all', () {
    test('keeps all detections and never evicts', () {
      final sampler = DetectionSampler(mode: SamplingMode.all);
      final d1 = _det('Parus major', 0.9);
      final d2 = _det('Parus major', 0.5);
      final d3 = _det('Turdus merula', 0.7);

      expect(sampler.shouldKeep(d1), isNull);
      expect(sampler.shouldKeep(d2), isNull);
      expect(sampler.shouldKeep(d3), isNull);
      expect(sampler.keptCount, 3);
    });
  });

  group('SamplingMode.topN', () {
    test('keeps up to N per species', () {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 2);
      final d1 = _det('Parus major', 0.9, offset: const Duration(seconds: 0));
      final d2 = _det('Parus major', 0.8, offset: const Duration(seconds: 3));
      final d3 = _det('Parus major', 0.7, offset: const Duration(seconds: 6));

      expect(sampler.shouldKeep(d1), isNull); // accepted
      expect(sampler.shouldKeep(d2), isNull); // accepted
      // d3 is worse than both d1 and d2, so it's evicted (returned as-is).
      final evicted = sampler.shouldKeep(d3);
      expect(evicted, d3);
      expect(sampler.keptCount, 2);
    });

    test('evicts weakest when a better one arrives', () {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 2);
      final d1 = _det('Parus major', 0.5, offset: const Duration(seconds: 0));
      final d2 = _det('Parus major', 0.6, offset: const Duration(seconds: 3));
      final d3 = _det('Parus major', 0.9, offset: const Duration(seconds: 6));

      sampler.shouldKeep(d1);
      sampler.shouldKeep(d2);
      final evicted = sampler.shouldKeep(d3);
      expect(evicted, d1); // d1 was weakest
      expect(sampler.keptCount, 2);
      expect(sampler.wasAccepted(d3), isTrue);
    });

    test('tracks species independently', () {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 1);
      final d1 = _det('Parus major', 0.9);
      final d2 = _det('Turdus merula', 0.8);

      sampler.shouldKeep(d1);
      sampler.shouldKeep(d2);
      expect(sampler.keptCount, 2);
    });

    test('keptDetections returns all kept', () {
      final sampler = DetectionSampler(mode: SamplingMode.topN, topN: 2);
      final d1 = _det('Parus major', 0.9, offset: const Duration(seconds: 0));
      final d2 = _det('Parus major', 0.7, offset: const Duration(seconds: 3));

      sampler.shouldKeep(d1);
      sampler.shouldKeep(d2);

      final kept = sampler.keptDetections;
      expect(kept.length, 2);
      expect(kept, contains(d1));
      expect(kept, contains(d2));
    });
  });

  group('SamplingMode.smart', () {
    test('keeps detections far apart in space', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      // Two detections ~10 km apart — both kept.
      final d1 = _det('Parus major', 0.9,
          offset: const Duration(seconds: 0),
          latitude: 52.0, longitude: 13.0);
      final d2 = _det('Parus major', 0.8,
          offset: const Duration(seconds: 30),
          latitude: 52.1, longitude: 13.0); // ~11 km north

      expect(sampler.shouldKeep(d1), isNull);
      expect(sampler.shouldKeep(d2), isNull);
      expect(sampler.keptCount, 2);
    });

    test('evicts weaker detection at same spot', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      // Two detections at nearly the same location within 2 min.
      final d1 = _det('Parus major', 0.5,
          offset: const Duration(seconds: 0),
          latitude: 52.0, longitude: 13.0);
      final d2 = _det('Parus major', 0.9,
          offset: const Duration(seconds: 30),
          latitude: 52.0001, longitude: 13.0001); // ~14 m away

      sampler.shouldKeep(d1);
      final evicted = sampler.shouldKeep(d2);
      expect(evicted, d1); // weaker one evicted
      expect(sampler.keptCount, 1);
      expect(sampler.wasAccepted(d2), isTrue);
    });

    test('keeps both if time apart exceeds threshold', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      // Same location, but 5 min apart.
      final d1 = _det('Parus major', 0.9,
          offset: Duration.zero,
          latitude: 52.0, longitude: 13.0);
      final d2 = _det('Parus major', 0.8,
          offset: const Duration(minutes: 5),
          latitude: 52.0, longitude: 13.0);

      expect(sampler.shouldKeep(d1), isNull);
      expect(sampler.shouldKeep(d2), isNull);
      expect(sampler.keptCount, 2);
    });

    test('discards new detection if weaker at same spot', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        distanceThresholdMeters: 500,
        timeThresholdSeconds: 120,
      );

      final d1 = _det('Parus major', 0.9,
          offset: Duration.zero,
          latitude: 52.0, longitude: 13.0);
      final d2 = _det('Parus major', 0.3,
          offset: const Duration(seconds: 30),
          latitude: 52.0, longitude: 13.0);

      sampler.shouldKeep(d1);
      final evicted = sampler.shouldKeep(d2);
      expect(evicted, d2); // new detection is weaker, discarded
      expect(sampler.keptCount, 1);
      expect(sampler.wasAccepted(d1), isTrue);
    });

    test('enforceGlobalCap removes weakest across species', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        globalCap: 2,
      );

      // Three detections of different species, far apart.
      final d1 = _det('Parus major', 0.9,
          offset: Duration.zero,
          latitude: 52.0, longitude: 13.0);
      final d2 = _det('Turdus merula', 0.3,
          offset: const Duration(seconds: 30),
          latitude: 53.0, longitude: 14.0);
      final d3 = _det('Fringilla coelebs', 0.7,
          offset: const Duration(seconds: 60),
          latitude: 54.0, longitude: 15.0);

      sampler.shouldKeep(d1);
      sampler.shouldKeep(d2);
      sampler.shouldKeep(d3);

      final evicted = sampler.enforceGlobalCap();
      expect(evicted.length, 1);
      expect(evicted.first.confidence, 0.3);
      expect(sampler.keptCount, 2);
    });
  });
}
