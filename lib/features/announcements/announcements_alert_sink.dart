// =============================================================================
// AnnouncementsAlertSink
// =============================================================================
//
// Thin bridge that turns the per-mode "fresh detection" stream into
// calls on [AnnouncementsController]. Lives in the announcements
// feature (not in `live/` / `survey/` / `point_count/`) so the mode
// screens stay ignorant of TTS — they just hand a batch of detections
// to `submit()` whenever new inference results land.
//
// Design notes:
//
//   * **Lazy initialization.** The TTS plugin, audio routing service
//     and template bundle are *only* built on the first `submit()`
//     call made while announcements are enabled. Users who never turn
//     the feature on never pay the plugin / asset cost — and we avoid
//     the `MissingPluginException` that follows a hot-reload of a
//     freshly-added native plugin.
//
//   * **Errors are swallowed.** A TTS hiccup must never bubble up into
//     the audio capture loop; on any failure `submit()` returns
//     [AnnounceOutcome.routingFailed] and the mode controller continues
//     normally.
//
//   * **Ref-driven config.** `_readConfig()` reads the live
//     SharedPreferences-backed providers each call, so flipping a
//     setting in the UI takes effect on the next detection batch.
//
// Wiring (Phase 4):
//
//   * [LiveController.onFreshDetections] →
//     `ref.read(announcementsAlertSinkProvider).submit(batch)`
//     (also covers Point Count, which reuses LiveController).
//   * [SurveyController.onFreshDetections] → same.
//   * Each controller calls `resetSession()` at session start.
//
// See `dev/announcements.md` §2 (data flow) and §6 (settings layer).
// =============================================================================

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import 'announcements_controller.dart';
import 'announcements_providers.dart';
import 'domain/announcement_presets.dart';
import 'geo_commonness_provider.dart';
import 'phrasing/phrasing_engine.dart';
import 'phrasing/template_library.dart';
import 'platform/routing_service.dart';
import 'platform/tts_engine.dart';

/// Glue layer the per-mode controllers call when a fresh batch of
/// detections is published.
class AnnouncementsAlertSink {
  AnnouncementsAlertSink(this._ref);

  final Ref _ref;

  AnnouncementsController? _controller;
  TtsEngine? _tts;
  RoutingService? _routing;
  Future<AnnouncementsController>? _initFuture;

  /// Submit a batch of detections for possible announcement. Returns
  /// the controller's outcome for the call (useful for tests and for
  /// surfacing a debug log later). Suppresses errors so a TTS
  /// hiccup never bubbles up into the audio capture loop.
  Future<AnnounceOutcome> submit(List<AnnouncementDetection> batch) async {
    try {
      // Cheap exit before touching any platform code: if the user has
      // not enabled announcements, don't even build the TTS engine.
      if (!_ref.read(announcementsEnabledProvider)) {
        return AnnounceOutcome.disabled;
      }
      final controller = _controller ?? await _ensureController();
      final enriched = _enrichWithCommonness(batch);
      return await controller.announce(enriched, _readConfig());
    } catch (_) {
      return AnnounceOutcome.routingFailed;
    }
  }

  /// Attach geo-model commonness/season metadata to each detection in
  /// the batch when available. Reads the cached
  /// [geoCommonnessProvider] value non-blockingly via
  /// `valueOrNull` — if the geo data isn't ready yet we just hand the
  /// batch through unchanged and the engine will skip the Chatty
  /// addendum (the bucket templates still render normally). Detections
  /// that already carry a non-null `commonness` (e.g. from tests) are
  /// preserved.
  List<AnnouncementDetection> _enrichWithCommonness(
    List<AnnouncementDetection> batch,
  ) {
    final map = _ref.read(geoCommonnessProvider).valueOrNull;
    if (map == null || map.isEmpty) return batch;
    return [
      for (final d in batch)
        if (d.commonness != null)
          d
        else
          () {
            final entry = map[d.speciesId];
            if (entry == null) return d;
            return AnnouncementDetection(
              speciesId: d.speciesId,
              displayName: d.displayName,
              score: d.score,
              at: d.at,
              commonness: entry.commonness,
              isOutOfSeason: entry.isOutOfSeason,
            );
          }(),
    ];
  }

  /// Reset per-session bookkeeping. Wire to mode-controller session
  /// start (Live `startSession()`, Survey `startSurvey()`).
  void resetSession() => _controller?.resetSession();

  Future<void> dispose() async {
    final tts = _tts;
    final routing = _routing;
    _controller = null;
    _tts = null;
    _routing = null;
    _initFuture = null;
    if (tts != null) await tts.dispose();
    if (routing != null) await routing.dispose();
  }

  Future<AnnouncementsController> _ensureController() {
    return _initFuture ??= _build();
  }

  Future<AnnouncementsController> _build() async {
    final ringBuffer = _ref.read(ringBufferProvider);
    final tts = FlutterTtsEngine();
    final routing = AudioSessionRoutingService();
    await routing.init();
    await tts.configure(
      languageTag: _resolveLanguageTag(),
      rate: _ref.read(announcementsVoiceRateProvider),
      pitch: _ref.read(announcementsVoicePitchProvider),
    );
    final library = TemplateLibrary();
    final bundle = await library.load(_resolveLanguageTag());
    final engine = PhrasingEngine(bundle: bundle);
    final controller = AnnouncementsController(
      engine: engine,
      tts: tts,
      routing: routing,
      ringBuffer: ringBuffer,
    );
    _tts = tts;
    _routing = routing;
    _controller = controller;
    return controller;
  }

  String _resolveLanguageTag() {
    final pref = _ref.read(announcementsVoiceLanguageProvider);
    if (pref.isNotEmpty) return pref;
    return ui.PlatformDispatcher.instance.locale.toLanguageTag();
  }

  AnnouncementsControllerConfig _readConfig() {
    final enabled = _ref.read(announcementsEnabledProvider);
    final verbosity = _ref.read(announcementsVerbosityProvider);
    final frequency = _ref.read(announcementsFrequencyProvider);
    // For non-`custom` presets, use the preset profile directly. For
    // `custom`, build a profile from the live Advanced numerics so the
    // controller honours user overrides.
    FrequencyProfile profile;
    if (frequency == AnnouncementFrequency.custom) {
      profile = FrequencyProfile(
        startupGraceSeconds: _ref.read(
          announcementsStartupGraceSecondsProvider,
        ),
        minIntervalSeconds: _ref.read(announcementsMinIntervalSecondsProvider),
        // No separate "speaker" pref yet; nudge the headphone value
        // up so speaker mode stays meaningfully stricter (matches the
        // ratio used in the named profiles).
        minIntervalSecondsSpeaker:
            _ref.read(announcementsMinIntervalSecondsProvider) * 3 ~/ 2,
        maxPerMinute: _ref.read(announcementsMaxPerMinuteProvider),
        maxPerMinuteSpeaker:
            (_ref.read(announcementsMaxPerMinuteProvider) * 2 / 3).floor(),
        streakSilenceSeconds: _ref.read(
          announcementsStreakSilenceSecondsProvider,
        ),
        recencyResetSeconds: _ref.read(
          announcementsRecencyResetSecondsProvider,
        ),
        // sessionResetSeconds / coalesceWindowSeconds are not exposed
        // as live providers yet; fall back to the `normal` profile
        // values so the controller has reasonable numbers.
        sessionResetSeconds:
            kFrequencyProfiles[AnnouncementFrequency.normal]!
                .sessionResetSeconds,
        coalesceWindowSeconds:
            kFrequencyProfiles[AnnouncementFrequency.normal]!
                .coalesceWindowSeconds,
      );
    } else {
      profile = kFrequencyProfiles[frequency]!;
    }
    return AnnouncementsControllerConfig(
      enabled: enabled,
      verbosity: verbosity,
      profile: profile,
      speakerOutputAllowed: _ref.read(
        announcementsSpeakerOutputAllowedProvider,
      ),
      muteCaptureDuringSpeech: _ref.read(
        announcementsMuteCaptureDuringSpeechProvider,
      ),
      duckOtherAudio: _ref.read(announcementsDuckOtherAudioProvider),
      prerollCue: _ref.read(announcementsPrerollCueProvider),
    );
  }
}

/// Process-wide singleton sink. Lazy: the TTS engine, audio routing
/// service and template bundle are only built on the first `submit()`
/// while announcements are enabled.
final announcementsAlertSinkProvider = Provider<AnnouncementsAlertSink>((ref) {
  final sink = AnnouncementsAlertSink(ref);
  ref.onDispose(() {
    // Fire-and-forget — the provider container only disposes at app
    // shutdown, where awaiting platform cleanup is best-effort anyway.
    sink.dispose();
  });
  return sink;
});
