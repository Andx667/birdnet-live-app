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
//   * **Smart** — spatially-distributed Top-K along the transect using
//     per-species, per-bin budgets.
//
// All modes run inference on every window; sampling only affects which
// results are *kept and clipped*.
// =============================================================================

import 'dart:io';

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
    this.spatialBins = 20,
    this.globalCap = 500,
  });

  /// Active sampling mode.
  final SamplingMode mode;

  /// Maximum detections per species (for topN and smart modes).
  final int topN;

  /// Number of spatial bins for smart mode.
  final int spatialBins;

  /// Global cap on total kept detections (smart mode only).
  final int globalCap;

  /// Per-species heaps for topN mode.
  /// Maps species name → sorted list (ascending by confidence).
  final Map<String, List<DetectionRecord>> _speciesHeaps = {};

  /// Per-species, per-bin heaps for smart mode.
  /// Maps "$species:$bin" → sorted list.
  final Map<String, List<DetectionRecord>> _binHeaps = {};

  /// Total distance of the survey track (updated externally).
  double totalDistanceMeters = 0;

  /// Total kept detection count.
  int get keptCount {
    return switch (mode) {
      SamplingMode.all => _allCount,
      SamplingMode.topN => _speciesHeaps.values.fold(0, (s, l) => s + l.length),
      SamplingMode.smart => _binHeaps.values.fold(0, (s, l) => s + l.length),
    };
  }

  int _allCount = 0;

  /// Decide whether a detection should be kept.
  ///
  /// [distanceFromStart] is the detection's position along the transect
  /// (meters from start), used only in smart mode.
  ///
  /// Returns the [DetectionRecord] that was evicted (whose clip can be
  /// deleted), or null if nothing was evicted.
  DetectionRecord? shouldKeep(
    DetectionRecord detection, {
    double distanceFromStart = 0,
  }) {
    return switch (mode) {
      SamplingMode.all => _keepAll(detection),
      SamplingMode.topN => _keepTopN(detection),
      SamplingMode.smart => _keepSmart(detection, distanceFromStart),
    };
  }

  /// Whether the detection was accepted (check after calling shouldKeep).
  bool wasAccepted(DetectionRecord detection) {
    return switch (mode) {
      SamplingMode.all => true,
      SamplingMode.topN =>
        _speciesHeaps[detection.scientificName]?.contains(detection) ?? false,
      SamplingMode.smart => _binHeaps.values.any((h) => h.contains(detection)),
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

      for (final entry in _binHeaps.entries) {
        if (entry.value.isEmpty) continue;
        final candidate = entry.value.first; // lowest confidence
        if (weakest == null || candidate.confidence < weakest.confidence) {
          weakest = candidate;
          weakestKey = entry.key;
        }
      }

      if (weakest == null || weakestKey == null) break;
      _binHeaps[weakestKey]!.remove(weakest);
      if (_binHeaps[weakestKey]!.isEmpty) _binHeaps.remove(weakestKey);
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
          for (final heap in _binHeaps.values) ...heap,
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

  DetectionRecord? _keepSmart(
    DetectionRecord detection,
    double distanceFromStart,
  ) {
    final species = detection.scientificName;
    final bin = _assignBin(distanceFromStart);
    final key = '$species:$bin';
    final budgetPerBin = (topN / spatialBins).ceil().clamp(1, topN);
    final heap = _binHeaps.putIfAbsent(key, () => []);

    if (heap.length < budgetPerBin) {
      _insertSorted(heap, detection);
      return null;
    }

    if (detection.confidence > heap.first.confidence) {
      final evicted = heap.removeAt(0);
      _insertSorted(heap, detection);
      return evicted;
    }

    return detection;
  }

  int _assignBin(double distanceFromStart) {
    if (totalDistanceMeters <= 0) return 0;
    final bin = (distanceFromStart / totalDistanceMeters * spatialBins)
        .floor()
        .clamp(0, spatialBins - 1);
    return bin;
  }

  /// Insert into a list sorted ascending by confidence.
  static void _insertSorted(List<DetectionRecord> list, DetectionRecord item) {
    var i = 0;
    while (i < list.length && list[i].confidence <= item.confidence) {
      i++;
    }
    list.insert(i, item);
  }
}
