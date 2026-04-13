// =============================================================================
// Survey Controller — Orchestrates a long-running background survey
// =============================================================================
//
// Uses composition (not inheritance) with the same components as LiveController:
//
//   - [AudioCaptureService] + [RingBuffer] — audio pipeline
//   - [InferenceIsolate] — ONNX model inference
//   - [RecordingService] — audio file writing
//   - [SurveyGpsTracker] — GPS track recording
//   - [DetectionSampler] — controls which detections to keep
//
// ### State machine
//
//   idle → starting → active → stopping → finalized
//
// No paused state — surveys are always-on or stopped.
//
// ### Key differences from LiveController
//
//   - Incremental persistence every 30 s (crash resilience)
//   - GPS tracking with detection location tagging
//   - Detection sampling (All / Top N / Smart)
//   - No spectrogram (battery saving)
//   - Auto-stop on max duration or low battery
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'survey_notification.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/memory_monitor.dart';
import '../audio/ring_buffer.dart';
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/species_filter.dart';
import '../recording/recording_service.dart';
import 'detection_sampler.dart';
import 'survey_gps_tracker.dart';
import '../live/live_session.dart';
import '../../shared/models/gps_point.dart';

// =============================================================================
// State
// =============================================================================

/// Lifecycle state of the survey pipeline.
enum SurveyState { idle, loading, starting, active, stopping, finalized, error }

// =============================================================================
// Controller
// =============================================================================

/// Orchestrates a long-running survey with GPS tracking, inference, recording,
/// and incremental persistence.
class SurveyController {
  SurveyController({
    required this.ringBuffer,
    required this.recordingService,
  });

  final RingBuffer ringBuffer;
  final RecordingService recordingService;
  final SurveyNotificationService _notificationService =
      SurveyNotificationService();
  final Battery _battery = Battery();

  // ── Internal state ──────────────────────────────────────────────────────

  final InferenceIsolate _isolate = InferenceIsolate();
  ModelConfig? _config;
  LiveSession? _session;
  Timer? _inferenceTimer;
  Timer? _persistTimer;
  SurveyGpsTracker? _gpsTracker;
  DetectionSampler? _sampler;
  SurveyState _state = SurveyState.idle;
  String? _errorMessage;
  DateTime? _maxEndTime;
  int _autoStopBattery = 0;

  /// All session detections (newest first).
  final List<DetectionRecord> _sessionDetections = [];

  /// Current live detections — replaced each inference cycle.
  List<DetectionRecord> _currentLiveDetections = const [];

  bool _inferring = false;
  int _inferenceCycleCount = 0;

  // Species filtering state.
  Map<String, double>? _geoScores;
  Set<String>? _geoModelSpeciesNames;
  SpeciesFilterMode _filterMode = SpeciesFilterMode.off;
  double _geoThreshold = 0.03;
  bool _saveDetectionClips = false;

  /// Species currently shown as active detection cards.
  final Map<String, DetectionRecord> _activeCardSpecies = {};

  static const int _maxInMemoryDetections = 10000;
  static const int _persistIntervalSeconds = 30;

  // ── Getters ─────────────────────────────────────────────────────────────

  SurveyState get state => _state;
  String? get errorMessage => _errorMessage;
  ModelConfig? get config => _config;
  LiveSession? get session => _session;
  SurveyGpsTracker? get gpsTracker => _gpsTracker;
  DetectionSampler? get sampler => _sampler;

  List<DetectionRecord> get sessionDetections =>
      List.unmodifiable(_sessionDetections);

  List<DetectionRecord> get currentLiveDetections =>
      List.unmodifiable(_currentLiveDetections);

  bool get isInferring => _inferring;

  /// Elapsed duration since survey start.
  Duration get elapsed => _session != null
      ? DateTime.now().difference(_session!.startTime)
      : Duration.zero;

  // ── Callbacks ───────────────────────────────────────────────────────────

  /// Called whenever the state changes.
  void Function()? onStateChanged;

  /// Called when auto-stop triggers (max duration or battery).
  void Function(String reason)? onAutoStop;

  // ── Model loading ───────────────────────────────────────────────────────

  /// Load the ONNX model from assets.
  Future<void> loadModel() async {
    if (_state == SurveyState.loading || _state == SurveyState.active) return;

    _state = SurveyState.loading;
    _errorMessage = null;
    _notifyListeners();

    try {
      final configJson = await rootBundle.loadString(
        AppConstants.modelConfigAssetPath,
      );
      final fullConfig = json.decode(configJson) as Map<String, dynamic>;
      _config = ModelConfig.fromJson(
        fullConfig['audioModel'] as Map<String, dynamic>,
      );

      final modelFilePath = await _ensureModelOnDisk(
        _config!.onnx.modelFile,
        _config!.version,
      );

      final labelsAssetPath =
          '${AppConstants.modelAssetsDir}/${_config!.labels.file}';
      final labelsCsv = await rootBundle.loadString(labelsAssetPath);

      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
      );

      _state = SurveyState.idle;
      debugPrint('[SurveyController] model loaded');
    } catch (e, st) {
      debugPrint('[SurveyController] loadModel error: $e\n$st');
      _state = SurveyState.error;
      _errorMessage = e.toString();
    }
    _notifyListeners();
  }

  Future<String> _ensureModelOnDisk(String fileName, String version) async {
    final appDir = await getApplicationDocumentsDirectory();
    final versionedName = '${fileName}_v$version';
    final modelFile = File('${appDir.path}/$versionedName');

    if (!modelFile.existsSync()) {
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return modelFile.path;
  }

  // ── Session lifecycle ───────────────────────────────────────────────────

  /// Start a new survey session.
  Future<void> startSurvey({
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    required int gpsIntervalSeconds,
    required int maxDurationHours,
    required SamplingMode samplingMode,
    int topNPerSpecies = 10,
    String? transectId,
    String? observerName,
    String? customName,
    double? startLatitude,
    double? startLongitude,
    bool backgroundGps = true,
    int clipPreBuffer = 3,
    int clipPostBuffer = 3,
    int autoStopBattery = 0,
  }) async {
    if (_state == SurveyState.active) return;
    _state = SurveyState.starting;
    _notifyListeners();

    try {
      // Load model if not already loaded.
      if (!_isolate.isRunning) {
        await loadModel();
        if (_state == SurveyState.error) return;
      }

      final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');

      _session = LiveSession(
        id: sessionId,
        startTime: DateTime.now(),
        type: SessionType.survey,
        settings: SessionSettings(
          windowDuration: windowDuration,
          confidenceThreshold: confidenceThreshold,
          inferenceRate: inferenceRate,
          speciesFilterMode: speciesFilterMode,
        ),
        transectId: transectId,
        observerName: observerName,
        customName: customName,
      );

      if (startLatitude != null && startLongitude != null) {
        _session!.latitude = startLatitude;
        _session!.longitude = startLongitude;
      }

      _sessionDetections.clear();
      _currentLiveDetections = const [];
      _activeCardSpecies.clear();
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();

      if (kDebugMode) {
        MemoryMonitor.startPeriodic(intervalSeconds: 30);
        MemoryMonitor.logOnce(tag: 'survey-start');
      }

      // Store geo-filter state.
      _geoScores = geoScores;
      _geoThreshold = geoThreshold;
      _geoModelSpeciesNames = geoModelSpeciesNames;
      _filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      // Detection sampling.
      _sampler = DetectionSampler(
        mode: samplingMode,
        topN: topNPerSpecies,
      );

      // Recording.
      _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: sessionId,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking.
      _gpsTracker = SurveyGpsTracker(
        intervalSeconds: gpsIntervalSeconds,
      );
      _gpsTracker!.onPoint = _onGpsPoint;
      if (backgroundGps) {
        await _gpsTracker!.startTracking();
      } else {
        // Manual GPS mode: capture initial fix.
        await _gpsTracker!.captureOnce();
      }

      // Max duration auto-stop.
      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      // Start inference timer.
      final intervalMs = (1000.0 / inferenceRate).round();
      _inferenceTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _runInference(
          windowDuration: windowDuration,
          confidenceThreshold: confidenceThreshold,
        ),
      );

      // Start incremental persistence timer.
      _persistTimer = Timer.periodic(
        const Duration(seconds: _persistIntervalSeconds),
        (_) {
          _persistSession();
          _updateNotification();
          _checkBatteryAutoStop();
        },
      );

      // Start foreground service notification.
      await _notificationService.start(
        title: 'Survey Recording',
        text: _buildNotificationText(),
      );

      _state = SurveyState.active;
      _notifyListeners();

      debugPrint('[SurveyController] survey started '
          '(rate=${inferenceRate}Hz, gps=${gpsIntervalSeconds}s, '
          'sampling=${samplingMode.name})');
    } catch (e, st) {
      debugPrint('[SurveyController] startSurvey error: $e\n$st');
      _state = SurveyState.error;
      _errorMessage = e.toString();
      _notifyListeners();
    }
  }

  /// Resume an unfinished survey from an existing [LiveSession].
  ///
  /// Restores detections and GPS track from the saved session, then starts
  /// a fresh inference + GPS pipeline that appends to the existing data.
  Future<void> resumeSurvey({
    required LiveSession existingSession,
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    required int gpsIntervalSeconds,
    required int maxDurationHours,
    required SamplingMode samplingMode,
    int topNPerSpecies = 10,
    bool backgroundGps = true,
    int clipPreBuffer = 3,
    int clipPostBuffer = 3,
    int autoStopBattery = 0,
  }) async {
    if (_state == SurveyState.active) return;
    _state = SurveyState.starting;
    _notifyListeners();

    try {
      if (!_isolate.isRunning) {
        await loadModel();
        if (_state == SurveyState.error) return;
      }

      // Restore the existing session.
      _session = existingSession;

      // Restore in-memory detection list (newest first).
      _sessionDetections.clear();
      _sessionDetections.addAll(existingSession.detections.reversed);
      _currentLiveDetections = const [];
      _activeCardSpecies.clear();
      _isolate.resetPooling();
      _inferenceCycleCount = 0;
      ringBuffer.clear();

      if (kDebugMode) {
        MemoryMonitor.startPeriodic(intervalSeconds: 30);
        MemoryMonitor.logOnce(tag: 'survey-resume');
      }

      _geoScores = geoScores;
      _geoThreshold = geoThreshold;
      _geoModelSpeciesNames = geoModelSpeciesNames;
      _filterMode = switch (speciesFilterMode) {
        'geoExclude' => SpeciesFilterMode.geoExclude,
        'geoMerge' => SpeciesFilterMode.geoMerge,
        'customList' => SpeciesFilterMode.customList,
        _ => SpeciesFilterMode.off,
      };

      _sampler = DetectionSampler(
        mode: samplingMode,
        topN: topNPerSpecies,
      );

      // Recording: start a new recording segment.
      _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;
      if (recordingMode != RecordingMode.off) {
        final dir = await recordingService.startRecording(
          sessionId: existingSession.id,
          mode: recordingMode,
          format: recordingFormat,
        );
        _session!.recordingPath = dir;
      }

      // GPS tracking: seed with existing track data.
      _gpsTracker = SurveyGpsTracker(
        intervalSeconds: gpsIntervalSeconds,
      );
      _gpsTracker!.onPoint = _onGpsPoint;
      _gpsTracker!.seedTrack(existingSession.gpsTrack);
      if (backgroundGps) {
        await _gpsTracker!.startTracking();
      } else {
        await _gpsTracker!.captureOnce();
      }

      _maxEndTime = DateTime.now().add(Duration(hours: maxDurationHours));
      _autoStopBattery = autoStopBattery;

      final intervalMs = (1000.0 / inferenceRate).round();
      _inferenceTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _runInference(
          windowDuration: windowDuration,
          confidenceThreshold: confidenceThreshold,
        ),
      );

      _persistTimer = Timer.periodic(
        const Duration(seconds: _persistIntervalSeconds),
        (_) {
          _persistSession();
          _updateNotification();
          _checkBatteryAutoStop();
        },
      );

      await _notificationService.start(
        title: 'Survey Recording',
        text: _buildNotificationText(),
      );

      _state = SurveyState.active;
      _notifyListeners();

      debugPrint('[SurveyController] survey resumed '
          '(${existingSession.detections.length} existing detections, '
          '${existingSession.gpsTrack.length} GPS points)');
    } catch (e, st) {
      debugPrint('[SurveyController] resumeSurvey error: $e\n$st');
      _state = SurveyState.error;
      _errorMessage = e.toString();
      _notifyListeners();
    }
  }

  /// Stop and finalize the survey.
  Future<LiveSession?> stopSurvey() async {
    if (_session == null) return null;
    _state = SurveyState.stopping;
    _notifyListeners();

    // Stop timers.
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
    _persistTimer?.cancel();
    _persistTimer = null;

    // Stop foreground service notification.
    await _notificationService.stop();

    // Stop GPS.
    await _gpsTracker?.stopTracking();

    // Simplify GPS track.
    _gpsTracker?.simplifyTrack();
    if (_gpsTracker != null) {
      _session!.gpsTrack
        ..clear()
        ..addAll(_gpsTracker!.track);
      _session!.distanceMeters = _gpsTracker!.distanceMeters;
    }

    // Stop recording.
    final recordingPath = await recordingService.stopRecording();
    if (recordingPath != null) {
      _session!.recordingPath = recordingPath;
    }

    // Enforce global cap on detections (smart mode).
    if (_sampler != null) {
      final evicted = _sampler!.enforceGlobalCap();
      await DetectionSampler.deleteClips(evicted);
    }

    if (kDebugMode) {
      MemoryMonitor.logOnce(tag: 'survey-end');
      MemoryMonitor.printSummary();
      MemoryMonitor.stop();
    }

    _session!.end();
    final completedSession = _session!;

    // Final persist.
    await _persistSession();

    // Delete recovery file.
    await _deleteRecoveryFile();

    // Reset state.
    _session = null;
    _sessionDetections.clear();
    _currentLiveDetections = const [];
    _activeCardSpecies.clear();
    _gpsTracker = null;
    _sampler = null;

    _state = SurveyState.finalized;
    _notifyListeners();

    debugPrint('[SurveyController] survey finalized');
    return completedSession;
  }

  /// Capture a manual GPS fix (for manual GPS mode).
  Future<void> captureGpsFix() async {
    await _gpsTracker?.captureOnce();
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    _inferenceTimer?.cancel();
    _persistTimer?.cancel();
    await _gpsTracker?.stopTracking();
    await _isolate.stop();
    recordingService.dispose();
  }

  // ── GPS callbacks ───────────────────────────────────────────────────────

  void _onGpsPoint(GpsPoint point) {
    if (_session == null) return;
    _session!.gpsTrack.add(point);
    if (_gpsTracker != null) {
      _session!.distanceMeters = _gpsTracker!.distanceMeters;
      _sampler?.totalDistanceMeters = _gpsTracker!.distanceMeters;
    }
    _notifyListeners();
  }

  // ── Inference ───────────────────────────────────────────────────────────

  Future<void> _runInference({
    required int windowDuration,
    required int confidenceThreshold,
  }) async {
    // Check auto-stop conditions.
    if (_maxEndTime != null && DateTime.now().isAfter(_maxEndTime!)) {
      _triggerAutoStop('Maximum survey duration reached');
      return;
    }

    if (_inferring || !_isolate.isRunning) return;
    _inferring = true;
    _inferenceCycleCount++;

    try {
      final sampleRate = _config?.audio.sampleRate ?? AppConstants.sampleRate;
      final windowSamples = windowDuration * sampleRate;
      final audioSamples = ringBuffer.readLast(windowSamples);

      if (kDebugMode && _inferenceCycleCount % 30 == 0) {
        MemoryMonitor.logOnce(tag: 'survey-cycle-$_inferenceCycleCount');
      }

      final detections = await _isolate.infer(
        audioSamples,
        windowSeconds: windowDuration,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      // Apply species filter.
      final speciesFiltered = SpeciesFilter.apply(
        detections: detections,
        mode: _filterMode,
        geoScores: _geoScores,
        geoThreshold: _geoThreshold,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      final geoNames = _geoModelSpeciesNames;
      final filteredDetections = geoNames == null
          ? speciesFiltered
          : speciesFiltered
              .where((d) => geoNames.contains(d.species.scientificName))
              .toList();

      // Update live detection list.
      _currentLiveDetections = [
        for (final d in filteredDetections) DetectionRecord.fromDetection(d),
      ];

      // Detection counting (card-visibility based, same as LiveController).
      if (_session != null) {
        final currentNames = <String>{
          for (final d in filteredDetections) d.species.scientificName,
        };

        final appeared =
            currentNames.difference(_activeCardSpecies.keys.toSet());
        final disappeared =
            _activeCardSpecies.keys.toSet().difference(currentNames);
        for (final name in disappeared) {
          _activeCardSpecies.remove(name);
        }

        // Get current GPS position for detection tagging.
        final gpsPoint = _gpsTracker?.lastPoint;

        String? clipPath;
        if (_saveDetectionClips && appeared.isNotEmpty) {
          final clipName = 'clip_${DateTime.now().millisecondsSinceEpoch}';
          clipPath = await recordingService.saveDetectionClip(
            clipName: clipName,
          );
        }

        for (final detection in filteredDetections) {
          final name = detection.species.scientificName;

          if (appeared.contains(name)) {
            final record = DetectionRecord(
              scientificName: detection.species.scientificName,
              commonName: detection.species.commonName,
              confidence: detection.confidence,
              timestamp: detection.timestamp ?? DateTime.now(),
              audioClipPath: clipPath,
              latitude: gpsPoint?.latitude,
              longitude: gpsPoint?.longitude,
            );

            // Check detection sampling.
            final evicted = _sampler?.shouldKeep(
              record,
              distanceFromStart: _gpsTracker?.distanceMeters ?? 0,
            );

            final accepted = _sampler == null ||
                _sampler!.mode == SamplingMode.all ||
                _sampler!.wasAccepted(record);

            if (accepted) {
              _session!.addDetection(record);
              _sessionDetections.insert(0, record);
              _activeCardSpecies[name] = record;
            }

            // Delete evicted clip if any.
            if (evicted != null && evicted != record) {
              DetectionSampler.deleteClips([evicted]);
            }
          } else if (_activeCardSpecies.containsKey(name)) {
            // Update confidence if higher — also move to end so it
            // appears at the top of the recent detections list.
            final existing = _activeCardSpecies[name]!;
            if (detection.confidence > existing.confidence) {
              final updated = DetectionRecord(
                scientificName: existing.scientificName,
                commonName: existing.commonName,
                confidence: detection.confidence,
                timestamp: existing.timestamp,
                audioClipPath: existing.audioClipPath ?? clipPath,
                latitude: existing.latitude ?? gpsPoint?.latitude,
                longitude: existing.longitude ?? gpsPoint?.longitude,
              );
              _sessionDetections.remove(existing);
              _sessionDetections.add(updated);
              final lsIdx = _session!.detections.indexOf(existing);
              if (lsIdx != -1) _session!.detections[lsIdx] = updated;
              _activeCardSpecies[name] = updated;
            }
          }
        }

        if (_sessionDetections.length > _maxInMemoryDetections) {
          _sessionDetections.removeRange(
            _maxInMemoryDetections,
            _sessionDetections.length,
          );
        }
      }

      _notifyListeners();
    } catch (e, st) {
      debugPrint('[SurveyController] inference error: $e\n$st');
    } finally {
      _inferring = false;
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> _persistSession() async {
    if (_session == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sessionsDir = Directory('${appDir.path}/sessions');
      if (!sessionsDir.existsSync()) {
        await sessionsDir.create(recursive: true);
      }

      final sessionFile = File('${sessionsDir.path}/${_session!.id}.json');
      final recoveryFile =
          File('${sessionsDir.path}/${_session!.id}.recovery.json');

      // Write-ahead: rename current → recovery, write new, delete recovery.
      if (await sessionFile.exists()) {
        await sessionFile.rename(recoveryFile.path);
      }

      final jsonStr = json.encode(_session!.toJson());
      await File('${sessionsDir.path}/${_session!.id}.json')
          .writeAsString(jsonStr, flush: true);

      if (await recoveryFile.exists()) {
        await recoveryFile.delete();
      }

      debugPrint('[SurveyController] session persisted '
          '(${_session!.detections.length} detections, '
          '${_session!.gpsTrack.length} GPS points)');
    } catch (e) {
      debugPrint('[SurveyController] persist error: $e');
    }
  }

  Future<void> _deleteRecoveryFile() async {
    if (_session == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recoveryFile =
          File('${appDir.path}/sessions/${_session!.id}.recovery.json');
      if (await recoveryFile.exists()) {
        await recoveryFile.delete();
      }
    } catch (_) {}
  }

  // ── Notification + battery ─────────────────────────────────────────────

  /// Build the notification body text with current stats.
  String _buildNotificationText() {
    final e = elapsed;
    final hh = e.inHours.toString().padLeft(2, '0');
    final mm = (e.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (e.inSeconds % 60).toString().padLeft(2, '0');
    final det = _session?.detections.length ?? 0;
    final spp = _session?.uniqueSpeciesCount ?? 0;
    final dist = _gpsTracker?.distanceMeters ?? 0;
    final km = (dist / 1000).toStringAsFixed(1);
    return '\u23F1 $hh:$mm:$ss   \uD83D\uDC26 $det det · $spp spp   '
        '\uD83D\uDCCD $km km';
  }

  /// Push updated stats to the foreground notification.
  Future<void> _updateNotification() async {
    await _notificationService.update(
      title: 'Survey Recording',
      text: _buildNotificationText(),
    );
  }

  /// Check battery level and trigger auto-stop if below threshold.
  Future<void> _checkBatteryAutoStop() async {
    if (_autoStopBattery <= 0) return;
    try {
      final level = await _battery.batteryLevel;
      if (level <= _autoStopBattery) {
        _triggerAutoStop('Battery below $_autoStopBattery%');
      }
    } catch (e) {
      debugPrint('[SurveyController] battery check error: $e');
    }
  }

  // ── Auto-stop ───────────────────────────────────────────────────────────

  void _triggerAutoStop(String reason) {
    debugPrint('[SurveyController] auto-stop: $reason');
    onAutoStop?.call(reason);
    stopSurvey();
  }

  void _notifyListeners() {
    onStateChanged?.call();
  }
}
