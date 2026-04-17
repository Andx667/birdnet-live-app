// =============================================================================
// Detection Sampler — Controls which survey detections are kept
// =============================================================================
//
// A 6-hour survey at 0.25 Hz can produce thousands of detections.  The
// sampler controls which detections are persisted to keep storage and
// review manageable.  Three modes:
//
//   * **All** — keep everything above threshold.
//   * **Top N per species** — keep only the N highest-scoring detections
//     per species (min-heap eviction).
//   * **Smart** — spatially and temporally distributed sampling.  For each
//     species, detections within 500 m *and* 2 min of an existing kept
//     detection are considered the "same spot" and only the highest-
//     scoring one is retained.  This avoids large clusters at one spot
//     while preserving the best detections along the full transect.
//
// All modes run inference on every window; sampling only affects which
// results are *kept and clipped*.
// =============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../live/live_session.dart';

/// Detection sampling mode.
enum SamplingMode { all, topN, smart }

/// Parses a [SamplingMode] from its persisted string representation.
SamplingMode samplingModeFromString(String value) {
  return switch (value) {
    'topN' => SamplingMode.topN,
    'smart' => SamplingMode.smart,
    _ => SamplingMode.all,
  };
}

/// Controls which detections are kept during a long-running survey.
class DetectionSampler {
  DetectionSampler({
    required this.mode,
    this.topN = 10,
    this.distanceThresholdMeters = 500,
    this.timeThresholdSeconds = 120,
    this.globalCap = 500,
  });

  /// Active sampling mode.
  final SamplingMode mode;

  /// Maximum detections per species (for topN mode).
  final int topN;

  /// Minimum distance (meters) between kept detections of the same species
  /// for smart mode. Detections closer than this AND within
  /// [timeThresholdSeconds] are considered the "same spot".
  final double distanceThresholdMeters;

  /// Minimum time (seconds) between kept detections of the same species
  /// for smart mode. Detections closer than this AND within
  /// [distanceThresholdMeters] are considered the "same spot".
  final int timeThresholdSeconds;

  /// Global cap on total kept detections (smart mode only).
  final int globalCap;

  /// Per-species heaps for topN mode.
  /// Maps species name → sorted list (ascending by confidence).
  final Map<String, List<DetectionRecord>> _speciesHeaps = {};

  /// Per-species kept detections for smart mode.
  final Map<String, List<DetectionRecord>> _smartHeaps = {};

  /// Total kept detection count.
  int get keptCount {
    return switch (mode) {
      SamplingMode.all => _allCount,
      SamplingMode.topN => _speciesHeaps.values.fold(0, (s, l) => s + l.length),
      SamplingMode.smart => _smartHeaps.values.fold(0, (s, l) => s + l.length),
    };
  }

  int _allCount = 0;

  /// Decide whether a detection should be kept.
  ///
  /// Returns the [DetectionRecord] that was evicted (whose clip can be
  /// deleted), or null if nothing was evicted.
  DetectionRecord? shouldKeep(DetectionRecord detection) {
    return switch (mode) {
      SamplingMode.all => _keepAll(detection),
      SamplingMode.topN => _keepTopN(detection),
      SamplingMode.smart => _keepSmart(detection),
    };
  }

  /// Whether the detection was accepted (check after calling shouldKeep).
  bool wasAccepted(DetectionRecord detection) {
    return switch (mode) {
      SamplingMode.all => true,
      SamplingMode.topN =>
        _speciesHeaps[detection.scientificName]?.contains(detection) ?? false,
      SamplingMode.smart =>
        _smartHeaps[detection.scientificName]?.contains(detection) ?? false,
    };
  }

  /// Enforce the global cap (smart mode). Returns evicted records.
  List<DetectionRecord> enforceGlobalCap() {
    if (mode != SamplingMode.smart) return const [];
    final evicted = <DetectionRecord>[];

    while (keptCount > globalCap) {
      // Find the globally weakest detection.
      DetectionRecord? weakest;
      String? weakestKey;

      for (final entry in _smartHeaps.entries) {
        if (entry.value.isEmpty) continue;
        final candidate = entry.value.first; // lowest confidence
        if (weakest == null || candidate.confidence < weakest.confidence) {
          weakest = candidate;
          weakestKey = entry.key;
        }
      }

      if (weakest == null || weakestKey == null) break;
      _smartHeaps[weakestKey]!.remove(weakest);
      if (_smartHeaps[weakestKey]!.isEmpty) _smartHeaps.remove(weakestKey);
      evicted.add(weakest);
    }

    return evicted;
  }

  /// Delete clip files for evicted detections.
  static Future<void> deleteClips(List<DetectionRecord> evicted) async {
    for (final record in evicted) {
      if (record.audioClipPath != null) {
        try {
          final file = File(record.audioClipPath!);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('[DetectionSampler] failed to delete clip: $e');
        }
      }
    }
  }

  /// Get all kept detections (for session finalization).
  List<DetectionRecord> get keptDetections {
    return switch (mode) {
      SamplingMode.all => const [], // caller manages the list
      SamplingMode.topN => [
          for (final heap in _speciesHeaps.values) ...heap,
        ],
      SamplingMode.smart => [
          for (final heap in _smartHeaps.values) ...heap,
        ],
    };
  }

  // ── Private ─────────────────────────────────────────────────────────────

  DetectionRecord? _keepAll(DetectionRecord detection) {
    _allCount++;
    return null; // always keep, never evict
  }

  DetectionRecord? _keepTopN(DetectionRecord detection) {
    final species = detection.scientificName;
    final heap = _speciesHeaps.putIfAbsent(species, () => []);

    if (heap.length < topN) {
      _insertSorted(heap, detection);
      return null;
    }

    // Heap is full — check if new detection is better than the worst.
    if (detection.confidence > heap.first.confidence) {
      final evicted = heap.removeAt(0);
      _insertSorted(heap, detection);
      return evicted;
    }

    // New detection is worse — discard it (return it as "evicted").
    return detection;
  }

  DetectionRecord? _keepSmart(DetectionRecord detection) {
    final species = detection.scientificName;
    final heap = _smartHeaps.putIfAbsent(species, () => []);

    // Find an existing detection at the "same spot" — within both distance
    // and time thresholds.
    DetectionRecord? neighbor;
    for (final existing in heap) {
      if (_isSameSpot(detection, existing)) {
        neighbor = existing;
        break;
      }
    }

    if (neighbor == null) {
      // No nearby detection — accept unconditionally.
      _insertSorted(heap, detection);
      return null;
    }

    // Same spot: keep only the higher-confidence one.
    if (detection.confidence > neighbor.confidence) {
      heap.remove(neighbor);
      _insertSorted(heap, detection);
      return neighbor;
    }

    // Existing is better — discard the new detection.
    return detection;
  }

  /// Whether two detections are at the "same spot" (close in both space
  /// and time).
  bool _isSameSpot(DetectionRecord a, DetectionRecord b) {
    final timeDiff = a.timestamp.difference(b.timestamp).inSeconds.abs();
    if (timeDiff > timeThresholdSeconds) return false;

    final dist = _haversineMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return dist <= distanceThresholdMeters;
  }

  /// Haversine distance in meters. Returns 0 if coordinates are missing,
  /// which makes detections without GPS cluster together (same spot).
  static double _haversineMeters(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return 0;
    const earthRadius = 6371000.0; // meters
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Insert into a list sorted ascending by confidence.
  static void _insertSorted(List<DetectionRecord> list, DetectionRecord item) {
    var i = 0;
    while (i < list.length && list[i].confidence <= item.confidence) {
      i++;
    }
    list.insert(i, item);
  }
}
