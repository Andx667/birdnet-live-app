// =============================================================================
// Survey Providers — Riverpod wiring for Survey Mode
// =============================================================================
//
// Connects [SurveyController], [SurveyGpsTracker], and UI state to the
// widget tree via Riverpod providers.
//
// ### Provider dependency graph
//
// ```
// ringBufferProvider (from audio)
//   └─ surveyRecordingServiceProvider
//       └─ surveyControllerProvider
//           └─ surveyStateProvider
//           └─ surveyDetectionsProvider
//           └─ surveySessionProvider
// ```
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../audio/audio_providers.dart';
import '../recording/recording_service.dart';
import '../live/live_session.dart';
import 'survey_controller.dart';

// ---------------------------------------------------------------------------
// Recording (separate instance from live mode)
// ---------------------------------------------------------------------------

/// Recording service for survey mode, with survey-specific buffer settings.
final surveyRecordingServiceProvider = Provider<RecordingService>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final clipContext = ref.watch(surveyClipContextProvider);
  final service = RecordingService(
    ringBuffer: ringBuffer,
    sampleRate: AppConstants.sampleRate,
    clipContextSeconds: clipContext,
  );
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Survey Controller
// ---------------------------------------------------------------------------

/// The [SurveyController] orchestrating the full survey pipeline.
final surveyControllerProvider = Provider<SurveyController>((ref) {
  final ringBuffer = ref.watch(ringBufferProvider);
  final recordingService = ref.watch(surveyRecordingServiceProvider);

  final controller = SurveyController(
    ringBuffer: ringBuffer,
    recordingService: recordingService,
  );

  ref.onDispose(() => controller.dispose());
  return controller;
});

// ---------------------------------------------------------------------------
// Reactive state providers
// ---------------------------------------------------------------------------

/// Current [SurveyState].
final surveyStateProvider =
    StateProvider<SurveyState>((ref) => SurveyState.idle);

/// Current live detections from the active survey.
final surveyDetectionsProvider =
    StateProvider<List<DetectionRecord>>((ref) => const []);

/// The active survey [LiveSession].
final surveySessionProvider = StateProvider<LiveSession?>((ref) => null);
