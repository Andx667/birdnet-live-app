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
// Why not `Provider.listen()` straight from the controller? Two
// reasons:
//   1. The mode controllers (Live/Survey/Point Count) do not currently
//      expose detection batches as Riverpod providers; they hold
//      mutable lists on their `ChangeNotifier` instances. Wiring the
//      sink as a callable means each mode only needs to add a single
//      `ref.read(announcementsAlertSinkProvider).submit(...)` line at
//      the point it already publishes detections — no architecture
//      changes required.
//   2. Keeping the sink interface tiny keeps tests trivial: the
//      controller's behaviour is already covered by
//      `announcements_controller_test.dart`; the sink only adds the
//      Riverpod glue to read live preset values.
//
// See `dev/announcements.md` §2 (data flow) and §6 (settings layer).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'announcements_controller.dart';
import 'announcements_providers.dart';
import 'domain/announcement_presets.dart';

/// Glue layer the per-mode controllers call when a fresh batch of
/// detections is published.
class AnnouncementsAlertSink {
  final Ref _ref;
  final AnnouncementsController _controller;

  AnnouncementsAlertSink(this._ref, this._controller);

  /// Submit a batch of detections for possible announcement. Returns
  /// the controller's outcome for the call (useful for tests and for
  /// surfacing a debug log later). Suppresses errors so a TTS
  /// hiccup never bubbles up into the audio capture loop.
  Future<AnnounceOutcome> submit(List<AnnouncementDetection> batch) async {
    try {
      final cfg = _readConfig();
      return await _controller.announce(batch, cfg);
    } catch (_) {
      return AnnounceOutcome.routingFailed;
    }
  }

  /// Reset per-session bookkeeping. Wire to mode-controller session
  /// start (e.g. Live `start()`, Survey `beginTransect()`).
  void resetSession() => _controller.resetSession();

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
        startupGraceSeconds:
            _ref.read(announcementsStartupGraceSecondsProvider),
        minIntervalSeconds:
            _ref.read(announcementsMinIntervalSecondsProvider),
        // No separate "speaker" pref yet; double the headphone value
        // so speaker mode stays meaningfully stricter (matches the
        // ratio used in the named profiles).
        minIntervalSecondsSpeaker:
            _ref.read(announcementsMinIntervalSecondsProvider) * 3 ~/ 2,
        maxPerMinute: _ref.read(announcementsMaxPerMinuteProvider),
        maxPerMinuteSpeaker:
            (_ref.read(announcementsMaxPerMinuteProvider) * 2 / 3).floor(),
        streakSilenceSeconds:
            _ref.read(announcementsStreakSilenceSecondsProvider),
        recencyResetSeconds:
            _ref.read(announcementsRecencyResetSecondsProvider),
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
    );
  }
}
