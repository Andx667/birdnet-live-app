// =============================================================================
// AnnouncementsRoutingService
// =============================================================================
//
// Wraps `package:audio_session` to configure the platform audio
// session for "speech alongside microphone capture" without breaking
// inference quality on Bluetooth devices.
//
// The hard problem (see `dev/announcements.md` §2 and §11):
//   - We must keep capturing 32 kHz mic audio for inference.
//   - We must speak short utterances out the *same* audio session.
//   - On Android + iOS, asking the OS to route audio "to a Bluetooth
//     device" can silently downgrade the BT link from A2DP (high-
//     fidelity sink-only) to HFP (telephony-grade duplex), which
//     crushes the mic to 8 kHz mono and ruins inference.
//
// The strategy here is conservative:
//   - Pick `AVAudioSessionCategory.playAndRecord` with options that
//     allow A2DP for output but explicitly *do not* request
//     `.allowBluetooth` (which on iOS implies HFP).
//   - On Android use `AndroidAudioUsage.assistanceAccessibility` so
//     the system treats our utterance like a screen-reader prompt
//     (ducks media, doesn't steal the mic).
//   - Detect HFP downgrade by sampling `AudioSession.devicesEvent`
//     before/after speech start; if the active input device drops to
//     a BT SCO mic, mark the session as "routing failed" so the
//     controller can suppress further announcements until the user
//     unplugs/replugs.
//
// This file deliberately keeps the *interface* small. The platform
// glue lives behind a `RoutingService` abstraction so the controller
// and tests don't have to import `audio_session`.
// =============================================================================

import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// Outcome of a routing-configuration attempt.
enum RoutingState {
  /// No issues — speech can proceed.
  ok,

  /// The active input device flipped to a BT-SCO microphone (HFP),
  /// which would degrade inference. Caller should suppress
  /// announcements until the user resolves the route.
  hfpDowngrade,

  /// Routing could not be configured at all (e.g. plugin error).
  /// Treated like `hfpDowngrade` by the controller.
  failed,
}

/// Pure interface so tests can swap a fake.
abstract class RoutingService {
  /// One-time initialization (idempotent). Call once when the
  /// Announcements feature is enabled.
  Future<void> init();

  /// Configure the audio session for an upcoming utterance and
  /// return the resulting [RoutingState].
  ///
  /// Should be called immediately before `TtsEngine.speak`.
  Future<RoutingState> prepareForSpeech();

  /// Whether the most recently observed output device is the
  /// device's loudspeaker (as opposed to headphones / A2DP). The
  /// throttling layer uses this to apply the stricter speaker
  /// profile.
  bool get isSpeakerOutput;

  /// Free any platform resources. Safe to call multiple times.
  Future<void> dispose();
}

/// Production implementation backed by `audio_session`.
class AudioSessionRoutingService implements RoutingService {
  AudioSession? _session;
  bool _isSpeakerOutput = true;
  StreamSubscription<Set<AudioDevice>>? _devicesSub;

  @override
  bool get isSpeakerOutput => _isSpeakerOutput;

  @override
  Future<void> init() async {
    if (_session != null) return;
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      // iOS: playAndRecord lets us mix capture and speech in one
      // session. Crucially we DO NOT pass `.allowBluetooth`, which on
      // iOS forces HFP. `.allowBluetoothA2DP` keeps Bluetooth output
      // at high fidelity without touching the mic route.
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetoothA2dp |
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      // Android: usage = assistanceAccessibility makes the system
      // treat our utterance like a screen-reader prompt (mixed with
      // / ducks media, doesn't steal the mic).
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.assistanceAccessibility,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
    _session = session;
    _devicesSub = session.devicesStream.listen((event) {
      _isSpeakerOutput = _detectSpeakerOutput(event);
    });
    // Seed the initial value.
    final initial = await session.getDevices();
    _isSpeakerOutput = _detectSpeakerOutput(initial);
  }

  @override
  Future<RoutingState> prepareForSpeech() async {
    final session = _session;
    if (session == null) return RoutingState.failed;
    try {
      final activated = await session.setActive(true);
      if (!activated) return RoutingState.failed;
      // Sample the input device set; if any is a BT-SCO mic, the OS
      // has forced HFP and inference will be junk.
      final devices = await session.getDevices(includeInputs: true);
      for (final d in devices) {
        if (d.isInput && _isBluetoothSco(d)) {
          return RoutingState.hfpDowngrade;
        }
      }
      return RoutingState.ok;
    } catch (_) {
      return RoutingState.failed;
    }
  }

  @override
  Future<void> dispose() async {
    await _devicesSub?.cancel();
    _devicesSub = null;
    final s = _session;
    if (s != null) {
      try {
        await s.setActive(false);
      } catch (_) {}
    }
    _session = null;
  }

  // --- Helpers ---

  bool _detectSpeakerOutput(Set<AudioDevice> devices) {
    // If any non-speaker output device is present (wired headphones,
    // A2DP sink, USB), treat it as "not speaker". Otherwise speaker.
    for (final d in devices) {
      if (!d.isOutput) continue;
      if (_isHeadphoneOrSinkLike(d)) return false;
    }
    return true;
  }

  bool _isHeadphoneOrSinkLike(AudioDevice d) {
    final name = d.name.toLowerCase();
    final type = d.type.toString().toLowerCase();
    if (type.contains('bluetootha2dp') ||
        type.contains('wiredheadphones') ||
        type.contains('wiredheadset') ||
        type.contains('usbheadset') ||
        type.contains('usbdevice')) {
      return true;
    }
    if (name.contains('headphone') ||
        name.contains('headset') ||
        name.contains('airpods')) {
      return true;
    }
    return false;
  }

  bool _isBluetoothSco(AudioDevice d) {
    final type = d.type.toString().toLowerCase();
    return type.contains('bluetoothsco');
  }
}
