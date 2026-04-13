// =============================================================================
// Detection Sampler Tests — All / TopN / Smart sampling modes
// =============================================================================

import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

DetectionRecord _det(String sci, double conf,
    {Duration offset = Duration.zero}) {
  return DetectionRecord(
    scientificName: sci,
    commonName: sci,
    confidence: conf,
    timestamp: DateTime.utc(2025, 7, 1, 12).add(offset),
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
    test('distributes across spatial bins', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 4,
        spatialBins: 2,
        globalCap: 100,
      );
      sampler.totalDistanceMeters = 1000;

      // Two detections in first half of transect.
      final d1 = _det('Parus major', 0.9, offset: const Duration(seconds: 0));
      final d2 = _det('Parus major', 0.8, offset: const Duration(seconds: 3));
      sampler.shouldKeep(d1, distanceFromStart: 100);
      sampler.shouldKeep(d2, distanceFromStart: 200);

      // Two detections in second half.
      final d3 = _det('Parus major', 0.7, offset: const Duration(seconds: 6));
      final d4 = _det('Parus major', 0.6, offset: const Duration(seconds: 9));
      sampler.shouldKeep(d3, distanceFromStart: 600);
      sampler.shouldKeep(d4, distanceFromStart: 700);

      expect(sampler.keptCount, 4);
    });

    test('enforceGlobalCap removes weakest across bins', () {
      final sampler = DetectionSampler(
        mode: SamplingMode.smart,
        topN: 10,
        spatialBins: 2,
        globalCap: 2,
      );
      sampler.totalDistanceMeters = 1000;

      final d1 = _det('Parus major', 0.9, offset: const Duration(seconds: 0));
      final d2 = _det('Parus major', 0.3, offset: const Duration(seconds: 3));
      final d3 = _det('Parus major', 0.7, offset: const Duration(seconds: 6));

      sampler.shouldKeep(d1, distanceFromStart: 100);
      sampler.shouldKeep(d2, distanceFromStart: 200);
      sampler.shouldKeep(d3, distanceFromStart: 600);

      final evicted = sampler.enforceGlobalCap();
      expect(evicted.length, 1);
      expect(evicted.first.confidence, 0.3);
      expect(sampler.keptCount, 2);
    });
  });
}
