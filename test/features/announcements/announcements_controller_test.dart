// Tests for AnnouncementsController throttling logic. Uses fake
// TtsEngine / RoutingService so no platform plugins are loaded.

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/announcements/announcements_controller.dart';
import 'package:birdnet_live/features/announcements/domain/announcement_presets.dart';
import 'package:birdnet_live/features/announcements/phrasing/phrasing_engine.dart';
import 'package:birdnet_live/features/announcements/phrasing/template_library.dart';
import 'package:birdnet_live/features/announcements/platform/routing_service.dart';
import 'package:birdnet_live/features/announcements/platform/tts_engine.dart';

class _FakeTts implements TtsEngine {
  final List<String> spoken = <String>[];
  bool throwOnSpeak = false;
  @override
  Future<void> configure({
    required String languageTag,
    required double rate,
    required double pitch,
  }) async {}
  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw StateError('boom');
    spoken.add(text);
  }
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeRouting implements RoutingService {
  RoutingState next = RoutingState.ok;
  bool speaker = false;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> init() async {}
  @override
  bool get isSpeakerOutput => speaker;
  @override
  Future<RoutingState> prepareForSpeech() async => next;
}

PhrasingEngine _engine() {
  // Use a tiny in-memory bundle so tests don't depend on rootBundle.
  final bundle = TemplateBundle.fromJson({
    'locale': 'en',
    'version': 1,
    'buckets': {
      'A': {
        'balanced': ['{name}.'],
        'chatty': ['{name} singing.'],
      },
      'B': {'balanced': ['{name} again.']},
      'C': {'balanced': ['{name} still calling.']},
      'D': {'balanced': ['Sounds like {name}.']},
      'E': {'balanced': ['{name} maybe back.']},
      'F': {'balanced': ['Maybe {name}.']},
      'G': {'balanced': ['Could be {name}.']},
      'H_three': {'balanced': ['{name1}, {name2}, {name3}.']},
      'H_many': {
        'balanced': ['{name1}, {name2}, {name3}, and more.']
      },
    },
  });
  return PhrasingEngine(bundle: bundle);
}

AnnouncementsControllerConfig _cfg(
  FrequencyProfile profile, {
  bool enabled = true,
  AnnouncementVerbosity verbosity = AnnouncementVerbosity.balanced,
}) =>
    AnnouncementsControllerConfig(
      enabled: enabled,
      verbosity: verbosity,
      profile: profile,
    );

void main() {
  group('AnnouncementsController', () {
    late DateTime now;
    late RingBuffer ring;
    late _FakeTts tts;
    late _FakeRouting routing;
    late AnnouncementsController ctrl;

    setUp(() {
      now = DateTime(2026, 1, 1, 12, 0, 0);
      ring = RingBuffer(capacity: 1024);
      ring.clock = () => now;
      tts = _FakeTts();
      routing = _FakeRouting();
      ctrl = AnnouncementsController(
        engine: _engine(),
        tts: tts,
        routing: routing,
        ringBuffer: ring,
        now: () => now,
      );
    });

    AnnouncementDetection det(String id, double score) =>
        AnnouncementDetection(
          speciesId: id,
          displayName: id,
          score: score,
          at: now,
        );

    test('disabled config never speaks', () async {
      final out = await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!,
            enabled: false),
      );
      expect(out, AnnounceOutcome.disabled);
      expect(tts.spoken, isEmpty);
    });

    test('startup grace blocks early utterances', () async {
      now = now.add(const Duration(seconds: 5));
      final out = await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.startupGrace);
      expect(tts.spoken, isEmpty);
    });

    test('speaks once startup grace has passed', () async {
      now = now.add(const Duration(seconds: 31));
      final out = await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.spoken);
      expect(tts.spoken, ['Robin.']);
    });

    test('min interval gate blocks back-to-back speech', () async {
      now = now.add(const Duration(seconds: 31));
      await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      now = now.add(const Duration(seconds: 3));
      final out = await ctrl.announce(
        [det('Wren', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.minIntervalNotMet);
      expect(tts.spoken.length, 1);
    });

    test('speaker mode applies stricter min-interval', () async {
      routing.speaker = true;
      now = now.add(const Duration(seconds: 31));
      await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      // headphone min is 8 s, speaker min is 12 s — 10 s should fail.
      now = now.add(const Duration(seconds: 10));
      final out = await ctrl.announce(
        [det('Wren', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.minIntervalNotMet);
    });

    test('streak silence mutes the same species briefly', () async {
      now = now.add(const Duration(seconds: 31));
      await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      now = now.add(const Duration(seconds: 30)); // > min, < streak (45)
      final out = await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.streakSilence);
    });

    test('routing failure suppresses speech', () async {
      routing.next = RoutingState.hfpDowngrade;
      now = now.add(const Duration(seconds: 31));
      final out = await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.routingFailed);
      expect(tts.spoken, isEmpty);
    });

    test('mute window sized for spoken text and unmuted on completion',
        () async {
      now = now.add(const Duration(seconds: 31));
      await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      // After speak() resolves, controller calls unmute().
      expect(ring.isMuted, false);
    });

    test('coalesces multiple species into a batch utterance', () async {
      now = now.add(const Duration(seconds: 31));
      final out = await ctrl.announce(
        [
          det('Robin', 0.9),
          det('Wren', 0.85),
          det('Crow', 0.82),
        ],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      expect(out, AnnounceOutcome.spoken);
      expect(tts.spoken, ['Robin, Wren, Crow.']);
    });

    test('resetSession clears throttling state', () async {
      now = now.add(const Duration(seconds: 31));
      await ctrl.announce(
        [det('Robin', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      ctrl.resetSession();
      // Without reset, this would hit min-interval. After reset, the
      // session-clock gate is not — but the *controller's* startup
      // grace tracks the original session start, so we still need to
      // be past it (we are).
      now = now.add(const Duration(seconds: 1));
      final out = await ctrl.announce(
        [det('Wren', 0.9)],
        _cfg(kFrequencyProfiles[AnnouncementFrequency.normal]!),
      );
      // resetSession clears _lastAnnouncedAt so the min-interval gate
      // no longer applies.
      expect(out, AnnounceOutcome.spoken);
    });
  });
}
