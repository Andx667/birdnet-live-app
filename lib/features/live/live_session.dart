// =============================================================================
// Live Session — Data model for a real-time identification session
// =============================================================================
//
// Captures everything that happens during a Live Mode session:
//
//   - **Metadata**: unique id, start / end timestamps.
//   - **Detections**: accumulated species detections with timestamps.
//   - **Recording path**: optional filesystem path to the recorded WAV file.
//   - **Settings snapshot**: inference settings active during the session.
//
// Sessions are serializable to / from JSON for persistence via the session
// repository.
// =============================================================================

import 'package:intl/intl.dart';

import '../../shared/models/gps_point.dart';
import '../inference/models/detection.dart';
import '../inference/models/species.dart';

/// A snapshot of inference settings active when a session was started.
class SessionSettings {
  const SessionSettings({
    required this.windowDuration,
    required this.confidenceThreshold,
    required this.inferenceRate,
    required this.speciesFilterMode,
  });

  /// Window duration in seconds.
  final int windowDuration;

  /// Confidence threshold (0–100 scale).
  final int confidenceThreshold;

  /// Inference rate in Hz.
  final double inferenceRate;

  /// Species filter mode ('off', 'geoExclude', 'geoMerge', 'customList').
  final String speciesFilterMode;

  /// Deserialize from JSON.
  factory SessionSettings.fromJson(Map<String, dynamic> json) {
    return SessionSettings(
      windowDuration: json['windowDuration'] as int? ?? 3,
      confidenceThreshold: json['confidenceThreshold'] as int? ?? 25,
      inferenceRate: (json['inferenceRate'] as num?)?.toDouble() ?? 1.0,
      speciesFilterMode: json['speciesFilterMode'] as String? ?? 'off',
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'windowDuration': windowDuration,
        'confidenceThreshold': confidenceThreshold,
        'inferenceRate': inferenceRate,
        'speciesFilterMode': speciesFilterMode,
      };
}

/// The type of session (maps to one of the four app modes).
enum SessionType {
  /// Real-time microphone-based identification session.
  live,

  /// Offline analysis of an uploaded audio file.
  fileUpload,

  /// Timed point-count survey at a fixed location.
  pointCount,

  /// Background survey session with GPS tracking.
  survey,
}

/// Why a session ended.
///
/// Used primarily for survey sessions that can auto-stop on max duration
/// or low battery, but applicable to any session type. `null` means the
/// session was stopped manually or pre-dates this field.
enum SessionStopReason {
  /// User tapped Stop.
  manual,

  /// Configured maximum duration was reached.
  maxDuration,

  /// Battery dropped below the configured auto-stop threshold.
  lowBattery,
}

/// How a detection was created.
enum DetectionSource {
  /// Automatically detected by the inference model.
  auto,

  /// Manually added by the user in session review at a specific timestamp.
  manual,

  /// Manually added as a session-wide (global) annotation — not tied to a
  /// specific time window.
  manualGlobal,
}

/// A timestamped detection record for session persistence.
///
/// Unlike [Detection] (which holds a full [Species] object), this stores
/// only the essential fields needed for history display and export.
class DetectionRecord {
  DetectionRecord({
    required this.scientificName,
    required this.commonName,
    required this.confidence,
    required this.timestamp,
    this.endTimestamp,
    this.audioClipPath,
    this.source = DetectionSource.auto,
    this.latitude,
    this.longitude,
  });

  /// Scientific name of the detected species.
  ///
  /// Use [unknownSpeciesName] for unknown / unidentifiable detections.
  final String scientificName;

  /// Common (vernacular) name of the detected species.
  final String commonName;

  /// Confidence score (0.0–1.0).
  final double confidence;

  /// Wall-clock time when this detection first appeared.
  final DateTime timestamp;

  /// Wall-clock time when the species' card disappeared from the live
  /// view (i.e. when continuous detection ended). May be `null` for:
  ///   * detections still in progress,
  ///   * legacy sessions saved before this field existed,
  ///   * manual annotations.
  ///
  /// When `null`, consumers should treat the detection as a single
  /// inference window starting at [timestamp].
  final DateTime? endTimestamp;

  /// Path to the saved audio clip for this detection (if available).
  ///
  /// Mutable: the survey detection sampler may clear this (and delete the
  /// underlying file) when an audio clip is dropped to enforce per-species
  /// or spatial caps. The detection record itself is always retained.
  String? audioClipPath;

  /// How this detection was created.
  final DetectionSource source;

  /// GPS latitude at the time of detection (null if unavailable).
  final double? latitude;

  /// GPS longitude at the time of detection (null if unavailable).
  final double? longitude;

  /// Scientific name placeholder for unknown / unidentifiable species.
  static const String unknownSpeciesName = 'Unknown species';

  /// Common name placeholder for unknown / unidentifiable species.
  static const String unknownCommonName = 'Unknown / Other';

  /// Whether this represents an unknown species.
  bool get isUnknown => scientificName == unknownSpeciesName;

  /// Create from a live [Detection].
  factory DetectionRecord.fromDetection(
    Detection detection, {
    String? audioClipPath,
  }) {
    return DetectionRecord(
      scientificName: detection.species.scientificName,
      commonName: detection.species.commonName,
      confidence: detection.confidence,
      timestamp: detection.timestamp ?? DateTime.now(),
      audioClipPath: audioClipPath,
    );
  }

  /// Deserialize from JSON.
  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    return DetectionRecord(
      scientificName: json['scientificName'] as String,
      commonName: json['commonName'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      endTimestamp: json['endTimestamp'] != null
          ? DateTime.parse(json['endTimestamp'] as String)
          : null,
      audioClipPath: json['audioClipPath'] as String?,
      source: switch (json['source'] as String?) {
        'manual' => DetectionSource.manual,
        'manualGlobal' => DetectionSource.manualGlobal,
        _ => DetectionSource.auto,
      },
      latitude: (json['detLat'] as num?)?.toDouble(),
      longitude: (json['detLon'] as num?)?.toDouble(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'scientificName': scientificName,
        'commonName': commonName,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        if (endTimestamp != null)
          'endTimestamp': endTimestamp!.toIso8601String(),
        if (audioClipPath != null) 'audioClipPath': audioClipPath,
        if (source != DetectionSource.auto) 'source': source.name,
        if (latitude != null) 'detLat': latitude,
        if (longitude != null) 'detLon': longitude,
      };

  /// Confidence expressed as a percentage string, e.g. "87.3 %".
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)} %';

  @override
  String toString() => 'DetectionRecord($commonName, $confidencePercent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionRecord &&
          runtimeType == other.runtimeType &&
          scientificName == other.scientificName &&
          confidence == other.confidence &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(scientificName, confidence, timestamp);
}

/// A user-created text annotation associated with a session.
///
/// Annotations can describe environmental conditions, location context,
/// or any observation the user wants to record alongside the audio.
class SessionAnnotation {
  const SessionAnnotation({
    required this.text,
    required this.createdAt,
    this.offsetInRecording,
  });

  /// Free-form annotation text.
  final String text;

  /// When the annotation was created.
  final DateTime createdAt;

  /// Optional offset (seconds from session start) this annotation refers to.
  /// When null, the annotation is considered session-global.
  final double? offsetInRecording;

  factory SessionAnnotation.fromJson(Map<String, dynamic> json) {
    return SessionAnnotation(
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      offsetInRecording: (json['offsetInRecording'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        if (offsetInRecording != null) 'offsetInRecording': offsetInRecording,
      };
}

/// A complete live identification session.
class LiveSession {
  LiveSession({
    required this.id,
    required this.startTime,
    this.type = SessionType.live,
    this.sessionNumber,
    this.customName,
    this.endTime,
    List<DetectionRecord>? detections,
    this.recordingPath,
    required this.settings,
    List<SessionAnnotation>? annotations,
    this.trimStartSec,
    this.trimEndSec,
    this.latitude,
    this.longitude,
    this.locationName,
    List<GpsPoint>? gpsTrack,
    this.distanceMeters,
    this.transectId,
    this.observerName,
    this.stopReason,
    this.stopReasonValue,
    int? recordedDurationSeconds,
  })  : detections = detections ?? [],
        annotations = annotations ?? [],
        gpsTrack = gpsTrack ?? [],
        _recordedDurationSeconds = recordedDurationSeconds;

  /// Unique session identifier (ISO 8601 timestamp-based).
  final String id;

  /// The type of session (live, file upload, point count, survey).
  SessionType type;

  /// Sequential session number within this [type] (starting at 1).
  ///
  /// Assigned when the session is first saved.  Legacy sessions that
  /// pre-date this field will have `null`.
  int? sessionNumber;

  /// User-defined session name (e.g. "Morning walk").
  ///
  /// When set, overrides the auto-generated numbered title for display
  /// and export filenames.
  String? customName;

  /// When the session started.
  final DateTime startTime;

  /// When the session ended (`null` while active).
  DateTime? endTime;

  /// All detections recorded during this session.
  final List<DetectionRecord> detections;

  /// Path to the full recording file (if recording was enabled).
  String? recordingPath;

  /// Inference settings that were active during this session.
  final SessionSettings settings;

  /// User annotations (environmental notes, observations, etc.).
  final List<SessionAnnotation> annotations;

  /// Trim start offset in seconds from the original recording start.
  ///
  /// When non-null, audio and detections before this offset are excluded
  /// from exports and the review timeline.
  double? trimStartSec;

  /// Trim end offset in seconds from the original recording start.
  ///
  /// When non-null, audio and detections after this offset are excluded.
  double? trimEndSec;

  /// Recording location latitude (null if location unavailable).
  double? latitude;

  /// Recording location longitude (null if location unavailable).
  double? longitude;

  /// Reverse-geocoded location name (e.g. "Berlin, Germany").
  ///
  /// Populated on first review when internet is available.
  String? locationName;

  /// GPS track recorded during a survey (empty for other session types).
  final List<GpsPoint> gpsTrack;

  /// Total distance walked in meters (computed from gpsTrack).
  double? distanceMeters;

  /// Transect / route identifier for repeat surveys.
  String? transectId;

  /// Name of the observer (remembered across sessions).
  String? observerName;

  /// Why the session ended. `null` for legacy sessions or sessions still
  /// active. Surveys set this when they auto-stop.
  SessionStopReason? stopReason;

  /// Numeric value associated with [stopReason] (e.g. battery % for
  /// [SessionStopReason.lowBattery], or duration hours for
  /// [SessionStopReason.maxDuration]). `null` when not applicable.
  num? stopReasonValue;

  /// Persisted total of seconds during which the session was actively
  /// recording, **excluding** any pause/resume gaps. `null` for legacy
  /// sessions saved before this field existed; in that case [duration] is
  /// used as an approximation. Accumulated by the controller via
  /// [accumulateRecordedSeconds] each time a recording segment ends.
  int? _recordedDurationSeconds;

  /// Total recorded seconds, or `null` if not yet tracked.
  int? get recordedDurationSeconds => _recordedDurationSeconds;

  /// Add [seconds] to the accumulated recorded duration. Called by the
  /// controller whenever a recording segment ends (manual stop, pause,
  /// auto-stop, or right before a resume opens a new segment).
  void accumulateRecordedSeconds(int seconds) {
    if (seconds <= 0) return;
    _recordedDurationSeconds = (_recordedDurationSeconds ?? 0) + seconds;
  }

  /// Whether this session is still active (no end time).
  bool get isActive => endTime == null;

  /// Human-readable session name for display in the UI.
  ///
  /// Format: `Session_2026-03-30_14-30-00_#123`
  /// Falls back to timestamp only for legacy sessions without a number.
  String get displayName {
    if (customName != null && customName!.isNotEmpty) {
      return customName!;
    }
    final dt = DateFormat('yyyy-MM-dd_HH-mm-ss').format(startTime);
    final suffix = sessionNumber != null ? '_#$sessionNumber' : '';
    return 'Session_$dt$suffix';
  }

  /// Duration of the session.
  ///
  /// Prefers the accumulated [recordedDurationSeconds] when available so
  /// that resumed sessions report their *actual recorded* time rather than
  /// wall-clock time spanning resume gaps. Falls back to wall-clock for
  /// legacy sessions and for active sessions before the first segment is
  /// accumulated.
  Duration get duration {
    final recorded = _recordedDurationSeconds;
    if (recorded != null) return Duration(seconds: recorded);
    return (endTime ?? DateTime.now()).difference(startTime);
  }

  /// Number of unique species detected.
  int get uniqueSpeciesCount =>
      detections.map((d) => d.scientificName).toSet().length;

  // Maximum number of detection records kept in memory per session.
  // At ~1 Hz inference this allows >2.7 hours of continuous recording.
  static const int _maxDetections = 10000;

  /// Add a detection to the session.
  void addDetection(DetectionRecord record) {
    if (detections.length < _maxDetections) {
      detections.add(record);
    }
  }

  /// Add multiple detections from a single inference cycle.
  void addDetections(List<DetectionRecord> records) {
    final remaining = _maxDetections - detections.length;
    if (remaining > 0) {
      detections.addAll(records.take(remaining));
    }
  }

  /// End the session.
  void end() {
    endTime ??= DateTime.now();
  }

  /// Deserialize from JSON.
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id'] as String,
      type: SessionType.values.firstWhere(
        (t) => t.name == (json['type'] as String?),
        orElse: () => SessionType.live,
      ),
      sessionNumber: json['sessionNumber'] as int?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      detections: (json['detections'] as List<dynamic>?)
              ?.map((d) => DetectionRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      recordingPath: json['recordingPath'] as String?,
      settings: SessionSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? {},
      ),
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map(
                  (a) => SessionAnnotation.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      trimStartSec: (json['trimStartSec'] as num?)?.toDouble(),
      trimEndSec: (json['trimEndSec'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['locationName'] as String?,
      customName: json['customName'] as String?,
      gpsTrack: (json['gpsTrack'] as List<dynamic>?)
              ?.map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      transectId: json['transectId'] as String?,
      observerName: json['observerName'] as String?,
      stopReason: json['stopReason'] != null
          ? SessionStopReason.values.firstWhere(
              (r) => r.name == (json['stopReason'] as String),
              orElse: () => SessionStopReason.manual,
            )
          : null,
      stopReasonValue: json['stopReasonValue'] as num?,
      recordedDurationSeconds:
          (json['recordedDurationSeconds'] as num?)?.toInt(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (type != SessionType.live) 'type': type.name,
        if (sessionNumber != null) 'sessionNumber': sessionNumber,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'detections': detections.map((d) => d.toJson()).toList(),
        if (recordingPath != null) 'recordingPath': recordingPath,
        'settings': settings.toJson(),
        if (annotations.isNotEmpty)
          'annotations': annotations.map((a) => a.toJson()).toList(),
        if (trimStartSec != null) 'trimStartSec': trimStartSec,
        if (trimEndSec != null) 'trimEndSec': trimEndSec,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationName != null) 'locationName': locationName,
        if (customName != null) 'customName': customName,
        if (gpsTrack.isNotEmpty)
          'gpsTrack': gpsTrack.map((p) => p.toJson()).toList(),
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (transectId != null) 'transectId': transectId,
        if (observerName != null) 'observerName': observerName,
        if (stopReason != null) 'stopReason': stopReason!.name,
        if (stopReasonValue != null) 'stopReasonValue': stopReasonValue,
        if (_recordedDurationSeconds != null)
          'recordedDurationSeconds': _recordedDurationSeconds,
      };

  @override
  String toString() => 'LiveSession($id, ${detections.length} detections, '
      '$uniqueSpeciesCount species)';
}
