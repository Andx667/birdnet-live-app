import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import 'ring_buffer.dart';

// =============================================================================
// Audio Capture Service
// =============================================================================
//
// Wraps the `record` package to stream raw PCM audio from the device
// microphone into the shared [RingBuffer].
//
// ### Data flow
//
// ```
// Microphone (Oboe / AVAudioEngine)
//   → Uint8List (PCM16 little-endian, 32 kHz mono)
//   → _pcm16ToFloat32 (normalized −1.0 … 1.0)
//   → RingBuffer.write
//   → downstream consumers (spectrogram, inference, recording)
// ```
//
// ### Level metering
//
// A periodic [Timer] (~15 Hz) reads the ring buffer's RMS and pushes it
// onto [levelStream] for the UI level meter.  This avoids per-sample
// stream events which would be expensive at 32 kHz.
//
// ### Error handling
//
// Errors during `start()` or from the audio stream are captured in
// [lastError] and the state moves to [CaptureState.error].  The UI can
// read both via the corresponding Riverpod providers.
// =============================================================================

/// State of the audio capture pipeline.
enum CaptureState {
  /// Not started or fully stopped.
  stopped,

  /// Capture is active and streaming audio data.
  capturing,

  /// An error occurred (see [AudioCaptureService.lastError]).
  error,
}

/// Audio capture service wrapping the `record` package.
///
/// Captures mono audio at [AppConstants.sampleRate] Hz and pushes
/// float32 samples into a [RingBuffer].  Exposes a [levelStream] for
/// UI level metering and an [onWindowReady] callback for downstream
/// consumers (inference, spectrogram).
class AudioCaptureService {
  AudioCaptureService({RingBuffer? ringBuffer})
    : _ringBuffer = ringBuffer ?? RingBuffer() {
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkWatchdog();
    });
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  AudioRecorder? _recorder;

  /// Lazily create the recorder to avoid platform channel calls at
  /// construction time (breaks unit tests).
  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  final RingBuffer _ringBuffer;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  CaptureState _state = CaptureState.stopped;
  CaptureState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  /// The ring buffer receiving all captured samples.
  RingBuffer get ringBuffer => _ringBuffer;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Emits RMS audio level (0.0 – 1.0) at ~15 Hz for the level meter.
  Stream<double> get levelStream => _levelController.stream;
  final _levelController = StreamController<double>.broadcast();

  /// Emits events whenever a new chunk of audio data has been written
  /// to the ring buffer.
  Stream<int> get onDataAvailable => _dataController.stream;
  final _dataController = StreamController<int>.broadcast();

  StreamSubscription<Uint8List>? _streamSub;
  Timer? _levelTimer;
  Timer? _watchdogTimer;

  bool _shouldBeCapturing = false;
  String? _currentDeviceId;
  DateTime _lastDataTime = DateTime.now();

  bool _isRestarting = false;

  // ── Live-tunable DSP ────────────────────────────────────────
  //
  // Both apply to the float32 stream just before it lands in the
  // ring buffer, so inference, recording, and the live spectrogram
  // all see the same processed signal.

  /// User-set gain multiplier applied to incoming samples. `1.0` is a
  /// pass-through; values >1 boost quiet recordings at the cost of
  /// clipping loud peaks (we saturate to [-1, 1] in float).
  double _gain = 1.0;

  /// High-pass cutoff in Hz. `0` (or any value <=0) disables the
  /// filter. Typical values: 100–300 Hz to remove wind / handling
  /// rumble while preserving most bird vocalizations.
  double _hpfCutoffHz = 0.0;

  // Biquad coefficients (Robert Bristow-Johnson cookbook, HPF).
  double _b0 = 1.0, _b1 = 0.0, _b2 = 0.0, _a1 = 0.0, _a2 = 0.0;

  // Direct-Form II Transposed state, persists across audio chunks so
  // the filter doesn't "click" at chunk boundaries.
  double _z1 = 0.0, _z2 = 0.0;

  bool get _hpfEnabled => _hpfCutoffHz > 0.0;

  /// Update the linear gain (`1.0` = unity). Takes effect on the next
  /// captured chunk.
  void setGain(double value) {
    _gain = value;
  }

  /// Update the high-pass cutoff in Hz. Pass `0` to bypass. Takes
  /// effect on the next captured chunk; filter state is reset so the
  /// new response settles cleanly.
  void setHighPassCutoff(double cutoffHz) {
    final next = cutoffHz <= 0 ? 0.0 : cutoffHz;
    if (next == _hpfCutoffHz) return;
    _hpfCutoffHz = next;
    if (next > 0) {
      _designHighPass(next, AppConstants.sampleRate);
    }
    _z1 = 0.0;
    _z2 = 0.0;
  }

  /// RBJ audio-EQ-cookbook 2nd-order Butterworth HPF (Q = 1/sqrt(2)).
  void _designHighPass(double cutoffHz, int sampleRate) {
    const q = 0.70710678118; // 1 / sqrt(2)
    final w0 = 2 * math.pi * cutoffHz / sampleRate;
    final cosW0 = math.cos(w0);
    final alpha = math.sin(w0) / (2 * q);

    final b0 = (1 + cosW0) / 2;
    final b1 = -(1 + cosW0);
    final b2 = (1 + cosW0) / 2;
    final a0 = 1 + alpha;
    final a1 = -2 * cosW0;
    final a2 = 1 - alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  // ── Microphone-contention detection ────────────────────────────────────
  //
  // Some Android apps (audiobook / music players, voice recorders) hold
  // exclusive control of the microphone. When the watchdog detects a
  // stall it tries to reclaim the mic, which interrupts the other app
  // (e.g. an audiobook stops every 2 s). To avoid that, after a few
  // consecutive failed restarts we stop fighting for the mic and
  // surface a "contested" signal so the foreground notification can
  // explain to the user why audio appears frozen.
  static const int _contestedThreshold = 3;
  static const Duration _contestedBackoff = Duration(seconds: 30);
  int _consecutiveStalls = 0;
  DateTime? _backoffUntil;
  bool _micContested = false;
  final _micContestedController = StreamController<bool>.broadcast();

  /// Whether the microphone is currently considered contested
  /// (another app appears to hold it). Updated by the internal
  /// watchdog after repeated restart attempts fail to deliver audio.
  bool get isMicContested => _micContested;

  /// Emits `true` when the microphone becomes contested and `false`
  /// when normal capture resumes.
  Stream<bool> get micContestedStream => _micContestedController.stream;

  void _setMicContested(bool value) {
    if (_micContested == value) return;
    _micContested = value;
    if (!_micContestedController.isClosed) {
      _micContestedController.add(value);
    }
  }

  void _checkWatchdog() {
    if (!_shouldBeCapturing || _isRestarting) return;

    // Honor the back-off window: stop hammering the mic while another
    // app is using it. The stall check still updates `_lastDataTime`
    // so once data starts flowing again we'll exit back-off naturally.
    final now = DateTime.now();
    if (_backoffUntil != null && now.isBefore(_backoffUntil!)) return;

    final isStalled =
        _state == CaptureState.capturing &&
        now.difference(_lastDataTime) > const Duration(seconds: 2);
    final isFailed =
        _state == CaptureState.error || _state == CaptureState.stopped;

    if (isFailed || isStalled) {
      _consecutiveStalls++;
      debugPrint(
        'Watchdog: Audio stream stall/failure detected '
        '(stalled: $isStalled, failed: $isFailed, '
        'consecutive: $_consecutiveStalls). Restarting...',
      );
      if (_consecutiveStalls >= _contestedThreshold) {
        // Repeated failures — assume another app owns the mic. Back
        // off so we don't keep interrupting it.
        _backoffUntil = now.add(_contestedBackoff);
        _setMicContested(true);
        debugPrint(
          'Watchdog: microphone contested — backing off for '
          '${_contestedBackoff.inSeconds}s',
        );
        return;
      }
      _restart();
    } else {
      // Audio is flowing normally — clear contested state.
      if (_consecutiveStalls != 0 || _micContested) {
        _consecutiveStalls = 0;
        _backoffUntil = null;
        _setMicContested(false);
      }
    }
  }

  Future<void> _restart() async {
    if (_isRestarting) return;
    _isRestarting = true;
    try {
      await stop();
      _shouldBeCapturing = true; // stop sets this to false
      await start(deviceId: _currentDeviceId);
    } catch (_) {
    } finally {
      _isRestarting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Device enumeration
  // ---------------------------------------------------------------------------

  /// List available audio input devices.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _rec.listInputDevices();
    } catch (e) {
      debugPrint('Failed to list input devices: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Capture lifecycle
  // ---------------------------------------------------------------------------

  /// Start capturing audio.
  ///
  /// [deviceId] — optional specific input device.
  Future<void> start({String? deviceId}) async {
    _shouldBeCapturing = true;
    _currentDeviceId = deviceId;
    _lastDataTime = DateTime.now();

    if (_state == CaptureState.capturing) return;

    try {
      final hasPermission = await _rec.hasPermission();
      if (!hasPermission) {
        _state = CaptureState.error;
        _lastError = 'Microphone permission not granted';
        return;
      }

      // Configure for raw PCM streaming at 32 kHz mono 16-bit.
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        device: deviceId != null ? InputDevice(id: deviceId, label: '') : null,
      );

      final stream = await _rec.startStream(config);

      _streamSub = stream.listen(
        _onAudioData,
        onError: _onStreamError,
        onDone: _onStreamDone,
      );

      // Periodic level metering (~15 Hz).
      _levelTimer = Timer.periodic(
        const Duration(milliseconds: 67),
        (_) => _emitLevel(),
      );

      _state = CaptureState.capturing;
      _lastError = null;
      debugPrint('Audio capture started @ ${AppConstants.sampleRate} Hz');
    } catch (e, st) {
      _state = CaptureState.error;
      _lastError = e.toString();
      debugPrint('Audio capture start failed: $e\n$st');
    }
  }

  /// Stop capturing audio.
  Future<void> stop() async {
    _shouldBeCapturing = false;

    _levelTimer?.cancel();
    _levelTimer = null;

    await _streamSub?.cancel();
    _streamSub = null;

    try {
      if (_recorder != null) await _rec.stop();
    } catch (_) {
      // Recorder may already be stopped.
    }

    _state = CaptureState.stopped;
    debugPrint('Audio capture stopped');
  }

  /// Release all resources.  Call when the service is no longer needed.
  Future<void> dispose() async {
    _watchdogTimer?.cancel();
    await stop();
    await _levelController.close();
    await _dataController.close();
    await _micContestedController.close();
    _recorder?.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  int _audioChunkCount = 0;

  /// Process incoming PCM16 audio data.
  void _onAudioData(Uint8List bytes) {
    _lastDataTime = DateTime.now();
    // Audio is flowing — clear any pending mic-contention back-off so
    // the foreground notification reflects the recovered state.
    if (_consecutiveStalls != 0 || _micContested) {
      _consecutiveStalls = 0;
      _backoffUntil = null;
      _setMicContested(false);
    }

    // Convert signed 16-bit PCM (little-endian) → float32 [-1.0, 1.0].
    final samples = _pcm16ToFloat32(bytes);
    _applyDsp(samples);
    _ringBuffer.write(samples);
    _dataController.add(samples.length);

    _audioChunkCount++;
    if (_audioChunkCount % 50 == 1) {
      debugPrint(
        '[AudioCapture] chunk #$_audioChunkCount: '
        '${samples.length} samples, '
        'totalWritten=${_ringBuffer.totalWritten}',
      );
    }
  }

  void _onStreamError(Object error) {
    debugPrint('Audio stream error: $error');
    _state = CaptureState.error;
    _lastError = error.toString();
  }

  void _onStreamDone() {
    debugPrint('Audio stream ended');
    if (_state == CaptureState.capturing) {
      _state = CaptureState.stopped;
    }
  }

  void _emitLevel() {
    if (_state != CaptureState.capturing) return;
    final rms = _ringBuffer.rmsLevel(windowSize: 2048);
    _levelController.add(rms);
  }

  /// Convert signed 16-bit little-endian PCM bytes to Float32List [-1, 1].
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final result = Float32List(sampleCount);
    final byteData = ByteData.sublistView(bytes);

    for (var i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      result[i] = sample / 32768.0;
    }

    return result;
  }

  /// Apply the user-tunable DSP chain (gain → high-pass) in place.
  ///
  /// Both stages bypass cheaply when the user hasn't moved the slider
  /// off the default. Gain is clipped to [-1, 1] so downstream
  /// quantization to PCM16 doesn't wrap. The biquad uses Direct-Form
  /// II Transposed with state persisted on the service instance so
  /// chunk boundaries don't introduce clicks.
  void _applyDsp(Float32List samples) {
    final gain = _gain;
    final useGain = gain != 1.0;
    final useHpf = _hpfEnabled;
    if (!useGain && !useHpf) return;

    final b0 = _b0, b1 = _b1, b2 = _b2, a1 = _a1, a2 = _a2;
    var z1 = _z1, z2 = _z2;

    for (var i = 0; i < samples.length; i++) {
      var x = samples[i].toDouble();
      if (useGain) {
        x *= gain;
        if (x > 1.0) {
          x = 1.0;
        } else if (x < -1.0) {
          x = -1.0;
        }
      }
      if (useHpf) {
        final y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        x = y;
      }
      samples[i] = x;
    }

    if (useHpf) {
      _z1 = z1;
      _z2 = z2;
    }
  }
}
