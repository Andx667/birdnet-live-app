// =============================================================================
// Session Review Screen — Post-session review, playback, and spectrogram
// =============================================================================
//
// Shown after finalizing a live session, or when reopening from the library.
//
// ### UX highlights
//
//   • **Species-collapsed list** — All detections of the same species are
//     merged into one expandable row.  The row shows the species name, best
//     confidence, total count, and first/last timestamps.
//
//   • **Consecutive clustering** — Within a species, adjacent detections
//     whose gap is shorter than the inference window duration are grouped
//     into time-span clusters so that a bird calling for 30 continuous
//     seconds shows as one cluster, not 10 rows.
//
//   • **Playback highlighting** — When audio plays through a detection's
//     timestamp, the corresponding species row pulses with a highlight so
//     the user can visually follow along.
//
//   • **Scrolling spectrogram** — A strip above the player shows ~10 seconds
//     of decoded audio centered on the playback position, scrolling in
//     real-time.  Detection markers are overlaid.
//
//   • **Delete confirmation** — Removing a detection shows a confirmation
//     dialog.  Changes are tracked as "dirty" and require an explicit Save.
//
//   • **Session naming** — The session displays its `displayName`
//     (`BirdNET-Live_Session_YYYY-MM-DD_HH-MM-SS`) which is also used for
//     the ZIP export filename.
//
// ### Layout (top → bottom)
//
//   1. AppBar with session name, save / share / discard actions.
//   2. Summary header — date, duration, species count, detections.
//   3. Spectrogram strip — ~160 dp tall scrolling FFT view.
//   4. Audio player bar — play/pause, seek slider, position / duration.
//   5. Species detection list — expandable rows, scrollable.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/score_colors.dart';
import '../../shared/models/gps_point.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/utils/timestamp_format.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/stat_chip.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';
import '../recording/native_audio_decoder.dart';
import '../spectrogram/color_maps.dart';
import 'session_export.dart';
import 'session_map_screen.dart';
import 'widgets/clip_player_sheet.dart';
import '../settings/settings_screen.dart';
import '../survey/survey_live_screen.dart';
import '../survey/widgets/survey_map_widget.dart';
import '../../core/services/reverse_geocoding_service.dart';

part 'widgets/session_review_widgets.dart';

/// Review screen displayed after a live session ends.
class SessionReviewScreen extends ConsumerStatefulWidget {
  const SessionReviewScreen({super.key, required this.session});

  /// The completed session to review.
  final LiveSession session;

  @override
  ConsumerState<SessionReviewScreen> createState() =>
      _SessionReviewScreenState();
}

class _SessionReviewScreenState extends ConsumerState<SessionReviewScreen> {
  // ── State ───────────────────────────────────────────────────────────

  late List<DetectionRecord> _detections;
  late List<SessionAnnotation> _annotations;
  late List<_SpeciesGroup> _speciesGroups;
  final Set<String> _expandedSpecies = {};
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _clipPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<PlayerState>? _clipPlayerStateSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _audioAvailable = false;

  /// Cluster currently being played via [_clipPlayer] (survey mode
  /// without a full recording). Used to highlight the active row and
  /// route taps on it to a pause action.
  _DetectionCluster? _activeClipCluster;

  /// When set, playback automatically pauses once [_position] reaches
  /// this value. Set by [_seekToCluster] so a single-cluster playback
  /// stops at the end of the detection's continuous-detection window.
  /// Cleared on any other player interaction (manual play/pause, drag,
  /// tap-to-seek, completion).
  Duration? _autoStopPosition;
  bool _isDirty = false;
  bool _trimMode = false;
  double? _trimStartSec;
  double? _trimEndSec;

  /// Pre-trim-mode values of [_trimStartSec]/[_trimEndSec], saved when
  /// entering trim mode so the undo snapshot captures the real pre-trim state
  /// instead of the transient handle positions set by [_onTrimChanged].
  double? _preTrimStartSec;
  double? _preTrimEndSec;

  // ── Clip state (after trim is applied) ─────────────────────────────

  /// Offset in original-recording seconds of the clip start (0 = no clip).
  double _clipOffsetSec = 0.0;

  /// Full recording duration before any clip was applied.
  double _fullDurationSec = 0.0;

  /// Full-recording spectrogram (never cropped).  Kept for undo / trim view.
  ui.Image? _fullSpectrogramImage;

  // ── Undo / Redo ────────────────────────────────────────────────────

  final List<_ReviewSnapshot> _undoStack = [];
  final List<_ReviewSnapshot> _redoStack = [];

  /// Pre-computed spectrogram image covering the current playback range.
  /// When a clip is active this is cropped to the trimmed region.
  ui.Image? _spectrogramImage;

  /// Whether the audio is being decoded and the spectrogram computed.
  bool _decoding = false;

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  /// Cached reverse-geocoded location name for display.
  String? _locationName;

  /// Detection highlighted on the map (set by tapping a species/cluster).
  DetectionRecord? _highlightedDetection;

  /// Current visible map bounds (updated by camera move callback).
  /// When non-null, the species list is filtered to only show detections
  /// within these bounds.
  LatLngBounds? _visibleMapBounds;

  _ReviewSnapshot _takeSnapshot() => _ReviewSnapshot(
    detections: List.of(_detections),
    annotations: List.of(_annotations),
    trimStartSec: _trimStartSec,
    trimEndSec: _trimEndSec,
    clipOffsetSec: _clipOffsetSec,
  );

  void _pushUndo() {
    _undoStack.add(_takeSnapshot());
    _redoStack.clear();
  }

  void _undo() {
    if (!_canUndo) return;
    _redoStack.add(_takeSnapshot());
    final snap = _undoStack.removeLast();
    setState(() {
      _detections = snap.detections;
      _annotations = snap.annotations;
      _trimStartSec = snap.trimStartSec;
      _trimEndSec = snap.trimEndSec;
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = _undoStack.isNotEmpty;
    });
    _syncPlayerClip(snap.clipOffsetSec);
  }

  void _redo() {
    if (!_canRedo) return;
    _undoStack.add(_takeSnapshot());
    final snap = _redoStack.removeLast();
    setState(() {
      _detections = snap.detections;
      _annotations = snap.annotations;
      _trimStartSec = snap.trimStartSec;
      _trimEndSec = snap.trimEndSec;
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
    _syncPlayerClip(snap.clipOffsetSec);
  }

  /// Re-synchronize the player clip and spectrogram after restoring a
  /// snapshot (undo/redo).  [snapshotClipOffset] is the clip offset that
  /// was active when the snapshot was taken.
  Future<void> _syncPlayerClip(double snapshotClipOffset) async {
    if (snapshotClipOffset == _clipOffsetSec) return; // No clip change.

    if (snapshotClipOffset > 0) {
      // Re-apply clip matching the snapshot's trim range.
      final start = _trimStartSec ?? 0.0;
      final end = _trimEndSec ?? _fullDurationSec;
      final startDur = Duration(microseconds: (start * 1e6).round());
      final endDur = Duration(microseconds: (end * 1e6).round());
      final clippedDur = await _player.setClip(start: startDur, end: endDur);
      await _player.seek(Duration.zero);
      await _cropSpectrogramForClip(start, end);
      if (mounted) {
        setState(() {
          _clipOffsetSec = snapshotClipOffset;
          _duration = clippedDur ?? (endDur - startDur);
          _position = Duration.zero;
        });
      }
    } else {
      // Remove clip — restore full recording.
      await _player.setClip();
      await _player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          _clipOffsetSec = 0.0;
          _duration = Duration(microseconds: (_fullDurationSec * 1e6).round());
          _position = Duration.zero;
          if (_spectrogramImage != null &&
              !identical(_spectrogramImage, _fullSpectrogramImage)) {
            _spectrogramImage!.dispose();
          }
          _spectrogramImage = _fullSpectrogramImage;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _detections = List.of(widget.session.detections);
    _annotations = List.of(widget.session.annotations);
    _trimStartSec = widget.session.trimStartSec;
    _trimEndSec = widget.session.trimEndSec;
    _speciesGroups = _buildSpeciesGroups(
      _detections,
      widget.session.settings.windowDuration,
    );
    _initAudio();
    _resolveLocation();
  }

  Future<void> _initAudio() async {
    final path = widget.session.recordingPath;
    if (path == null || !File(path).existsSync()) return;

    try {
      final dur = await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _duration = dur ?? Duration.zero;
        _fullDurationSec = _duration.inMicroseconds / 1e6;
        _audioAvailable = true;
      });

      _positionSubscription = _player.positionStream.listen((pos) {
        if (!mounted) return;
        final stopAt = _autoStopPosition;
        if (stopAt != null && pos >= stopAt) {
          _autoStopPosition = null;
          _player.pause();
          // Snap to the exact stop position so the playhead doesn't
          // visually overshoot the end of the cluster.
          _player.seek(stopAt);
        }
        setState(() => _position = pos);
      });
      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _player.pause();
            _player.seek(Duration.zero);
          }
        }
      });

      // Decode audio for spectrogram, then restore saved trim if present.
      await _decodeAudioForSpectrogram(path);
      await _restoreSavedTrim();
    } catch (_) {
      // Audio not available — review still works without playback.
    }
  }

  /// Re-apply a previously saved trim after audio and spectrogram are loaded.
  ///
  /// When a session with trim values is reopened, [_initAudio] loads the full
  /// recording.  This method clips the player and crops the spectrogram to
  /// match the persisted trim range so the user sees the trimmed state.
  Future<void> _restoreSavedTrim() async {
    if (_trimStartSec == null && _trimEndSec == null) return;

    final start = _trimStartSec ?? 0.0;
    final end = _trimEndSec ?? _fullDurationSec;

    final startDur = Duration(microseconds: (start * 1e6).round());
    final endDur = Duration(microseconds: (end * 1e6).round());
    final clippedDur = await _player.setClip(start: startDur, end: endDur);
    await _player.seek(Duration.zero);

    await _cropSpectrogramForClip(start, end);

    if (mounted) {
      setState(() {
        _clipOffsetSec = start;
        _duration = clippedDur ?? (endDur - startDur);
        _position = Duration.zero;
      });
    }
  }

  /// Attempt to reverse-geocode the session location.
  ///
  /// If the session already has a [locationName] (e.g. from a previous save),
  /// that value is reused.  Otherwise a network request via the Nominatim API
  /// is made and the result is persisted so future opens skip the request.
  Future<void> _resolveLocation() async {
    final lat = widget.session.latitude;
    final lon = widget.session.longitude;
    if (lat == null || lon == null) return;

    // Use cached name if already resolved.
    if (widget.session.locationName != null) {
      setState(() => _locationName = widget.session.locationName);
      return;
    }

    final name = await reverseGeocode(latitude: lat, longitude: lon);
    if (name != null && mounted) {
      setState(() => _locationName = name);
      // Persist so we don't re-fetch next time.
      widget.session.locationName = name;
      final repo = ref.read(sessionRepositoryProvider);
      await repo.save(widget.session);
    }
  }

  Future<void> _decodeAudioForSpectrogram(String path) async {
    setState(() => _decoding = true);
    try {
      // Use pure-Dart decoder for WAV/FLAC, native for compressed formats.
      DecodedAudio audio;
      if (await AudioDecoder.canDecodeDart(path)) {
        audio = await AudioDecoder.decodeFile(path);
      } else {
        audio = await NativeAudioDecoder.decodeFile(path);
      }
      if (!mounted) return;
      // Resample to model sample rate so spectrogram matches inference.
      audio = audio.resampleTo(AppConstants.sampleRate);
      await _buildSpectrogramImage(audio);
    } catch (_) {
      // Spectrogram unavailable — non-fatal.
    } finally {
      if (mounted) setState(() => _decoding = false);
    }
  }

  /// Pre-compute the entire session spectrogram as a [ui.Image].
  ///
  /// Uses a fixed FFT size and hop.  Each pixel column = one FFT frame.
  /// The painter scrolls through the image using pixels-per-second.
  Future<void> _buildSpectrogramImage(DecodedAudio audio) async {
    // Larger FFT (2048) gives ~12 Hz/bin resolution which renders
    // formants and harmonic structure much more clearly than the
    // previous 1024-point FFT (~23 Hz/bin). The hop is increased to
    // 1024 so the per-second column count stays similar — keeping the
    // total spectrogram-image memory comparable for long sessions while
    // doubling the vertical (frequency) resolution.
    const fftSize = 2048;
    const hop = 1024;
    const maxFreqHz = 16000;
    const dbFloor = -80.0;
    const dbCeiling = 0.0;

    if (audio.totalSamples < fftSize) return;

    final numCols = (audio.totalSamples - fftSize) ~/ hop + 1;
    if (numCols <= 0) return;

    final nyquist = audio.sampleRate / 2;
    final binCount = fftSize ~/ 2 + 1;
    final displayBins = (maxFreqHz / nyquist * binCount).round().clamp(
      1,
      binCount,
    );

    final lut = SpectrogramColorMap.lut('viridis');
    final pixels = Uint8List(numCols * displayBins * 4);

    // Periodic Hann window (matches FftProcessor).
    final hann = Float64List(fftSize);
    final hannFactor = 2.0 * math.pi / fftSize;
    for (var i = 0; i < fftSize; i++) {
      hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
    }
    final fft = FFT(fftSize);

    for (var c = 0; c < numCols; c++) {
      if (c > 0 && c % 200 == 0) {
        await Future.delayed(Duration.zero);
        if (!mounted) return;
      }

      final colSample = c * hop;
      final chunk = audio.readFloat32(colSample, fftSize);
      final input = Float64List(fftSize);
      for (var i = 0; i < fftSize; i++) {
        input[i] = chunk[i] * hann[i];
      }
      final spectrum = fft.realFft(input);

      for (var bin = 0; bin < displayBins; bin++) {
        final re = spectrum[bin].x;
        final im = spectrum[bin].y;
        final power = re * re + im * im;
        final db = 10 * math.log(power + 1e-10) / math.ln10;
        final norm = ((db - dbFloor) / (dbCeiling - dbFloor)).clamp(0.0, 1.0);

        final y = displayBins - 1 - bin;
        final pxOffset = (y * numCols + c) * 4;
        final lutIdx = (norm * 255).round().clamp(0, 255);
        final color = lut[lutIdx];
        pixels[pxOffset] = (color >> 16) & 0xFF;
        pixels[pxOffset + 1] = (color >> 8) & 0xFF;
        pixels[pxOffset + 2] = color & 0xFF;
        pixels[pxOffset + 3] = (color >> 24) & 0xFF;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      numCols,
      displayBins,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;

    if (mounted) {
      setState(() {
        _fullSpectrogramImage?.dispose();
        _fullSpectrogramImage = image;
        _spectrogramImage = image;
      });
    } else {
      image.dispose();
    }
  }

  /// Crop the full spectrogram to the current clip range and update
  /// [_spectrogramImage].  Must be called whenever the clip changes.
  Future<void> _cropSpectrogramForClip(double startSec, double endSec) async {
    final src = _fullSpectrogramImage;
    if (src == null || _fullDurationSec <= 0) return;

    final startFrac = (startSec / _fullDurationSec).clamp(0.0, 1.0);
    final endFrac = (endSec / _fullDurationSec).clamp(0.0, 1.0);
    final srcStartX = (startFrac * src.width).round();
    final srcEndX = (endFrac * src.width).round();
    final cropWidth = srcEndX - srcStartX;
    if (cropWidth <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      Rect.fromLTRB(
        srcStartX.toDouble(),
        0,
        srcEndX.toDouble(),
        src.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, cropWidth.toDouble(), src.height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(cropWidth, src.height);
    picture.dispose();

    if (mounted) {
      setState(() {
        if (_spectrogramImage != null &&
            !identical(_spectrogramImage, _fullSpectrogramImage)) {
          _spectrogramImage!.dispose();
        }
        _spectrogramImage = cropped;
      });
    } else {
      cropped.dispose();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _clipPlayerStateSubscription?.cancel();
    if (!identical(_spectrogramImage, _fullSpectrogramImage)) {
      _spectrogramImage?.dispose();
    }
    _fullSpectrogramImage?.dispose();
    _player.dispose();
    _clipPlayer.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionReviewTitle),
            content: Text(l10n.sessionUnsavedChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('discard'),
                child: Text(l10n.sessionDiscard),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('save'),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (result == 'save') {
      await _save();
      return true;
    }
    if (result == 'discard') return true;
    return false; // Dialog dismissed.
  }

  Future<void> _showRenameDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text:
          widget.session.customName ??
          _sessionReviewTitle(l10n, widget.session),
    );
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionRenameTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.sessionRenameHint),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (result == null) return;
    final trimmed = result.trim();
    setState(() {
      widget.session.customName = trimmed.isEmpty ? null : trimmed;
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    widget.session.detections
      ..clear()
      ..addAll(_detections);
    widget.session.annotations
      ..clear()
      ..addAll(_annotations);
    widget.session.trimStartSec = _trimStartSec;
    widget.session.trimEndSec = _trimEndSec;
    final repo = ref.read(sessionRepositoryProvider);
    await repo.save(widget.session);
    ref.invalidate(sessionListProvider);
    setState(() {
      _isDirty = false;
      _undoStack.clear();
      _redoStack.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sessionSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionDiscardTitle),
            content: Text(l10n.sessionDiscardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.sessionDiscard),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(sessionRepositoryProvider);
    await repo.delete(widget.session.id);
    ref.invalidate(sessionListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  /// Resume an unfinished survey session (after user confirmation).
  Future<void> _continueSurvey() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.surveyResumeTitle),
            content: Text(l10n.surveyResumeMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.surveyResumeConfirm),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => SurveyLiveScreen(
              customName: widget.session.customName,
              transectId: widget.session.transectId,
              observerName: widget.session.observerName,
              startLatitude: widget.session.latitude,
              startLongitude: widget.session.longitude,
              resumeSession: widget.session,
            ),
      ),
    );
  }

  Future<void> _share() async {
    // Save pending changes before sharing so the export is up to date.
    if (_isDirty) await _save();

    final exportFormat = ref.read(exportFormatProvider);
    final includeAudio = ref.read(includeAudioProvider);
    final taxonomy = ref.read(taxonomyServiceProvider).valueOrNull;
    final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
    // Legacy sessions persisted before SessionSettings.clipContextSeconds
    // existed default to 0, which would falsely place every detection at
    // the very start of every clip in Raven/CSV exports. When the session
    // has clip files but no recorded context value, fall back to the
    // device's current survey clip-context preference.
    final sessionClipContext = widget.session.settings.clipContextSeconds;
    final hasClips = widget.session.detections.any(
      (d) => d.audioClipPath != null && d.audioClipPath!.isNotEmpty,
    );
    final clipContextOverride =
        (hasClips && sessionClipContext == 0)
            ? ref.read(surveyClipContextProvider)
            : null;

    final exportPath = await buildSessionExport(
      widget.session,
      format: exportFormat,
      includeAudio: includeAudio,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      clipContextSecondsOverride: clipContextOverride,
      metadata: await _buildExportMetadata(speciesLocale: speciesLocale),
      useAbsoluteSurveyTime:
          ref.read(timestampDisplayModeProvider) == 'absolute',
    );

    if (exportPath == null) return;
    await Share.shareXFiles([XFile(exportPath)]);
  }

  /// Assembles the provenance metadata block embedded in JSON exports and
  /// dropped as `<prefix>.metadata.json` inside ZIP bundles.
  ///
  /// Captures the app version + build, both ONNX model blocks from
  /// `model_config.json`, and a snapshot of every SharedPreferences key/value
  /// at export time. Failures (e.g. missing platform plugin in tests, model
  /// asset moved) are non-fatal — we return a best-effort map and let the
  /// export continue.
  Future<Map<String, dynamic>> _buildExportMetadata({
    required String speciesLocale,
  }) async {
    String? appVersion;
    String? appBuildNumber;
    String? appPackageName;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      appBuildNumber = info.buildNumber;
      appPackageName = info.packageName;
    } catch (_) {
      /* non-fatal */
    }

    Map<String, dynamic>? audioModel;
    Map<String, dynamic>? geoModel;
    try {
      final raw = await rootBundle.loadString(
        AppConstants.modelConfigAssetPath,
      );
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final am = decoded['audioModel'];
      if (am is Map) audioModel = Map<String, dynamic>.from(am);
      final gm = decoded['geoModel'];
      if (gm is Map) geoModel = Map<String, dynamic>.from(gm);
    } catch (_) {
      /* non-fatal */
    }

    Map<String, dynamic>? prefsMap;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList()..sort();
      prefsMap = {for (final k in keys) k: prefs.get(k)};
    } catch (_) {
      /* non-fatal */
    }

    return buildExportMetadata(
      appVersion: appVersion,
      appBuildNumber: appBuildNumber,
      appPackageName: appPackageName,
      audioModel: audioModel,
      geoModel: geoModel,
      prefs: prefsMap,
      speciesLocale: speciesLocale,
      session: widget.session,
    );
  }

  void _done() {
    Navigator.of(context).pop();
  }

  // ── Add Species ───────────────────────────────────────────────────

  Future<void> _addSpecies() async {
    final positionSec = _position.inMicroseconds / 1000000.0;
    final result = await Navigator.of(context).push<_AddSpeciesResult>(
      MaterialPageRoute(
        builder:
            (_) => _AddSpeciesOverlay(
              sessionStart: widget.session.startTime,
              positionSec: positionSec,
              existingDetections: _detections,
            ),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    _pushUndo();
    setState(() {
      switch (result.mode) {
        case _InsertMode.global:
          // Insert global detection — applies to the whole session.
          _detections.add(
            DetectionRecord(
              scientificName: result.scientificName,
              commonName: result.commonName,
              confidence: 1.0,
              timestamp: widget.session.startTime,
              source: DetectionSource.manualGlobal,
            ),
          );
          break;

        case _InsertMode.atTimestamp:
          // Insert at the current playhead position.
          final ts = widget.session.startTime.add(_position);
          _detections.add(
            DetectionRecord(
              scientificName: result.scientificName,
              commonName: result.commonName,
              confidence: 1.0,
              timestamp: ts,
              source: DetectionSource.manual,
            ),
          );
          break;

        case _InsertMode.replace:
          if (result.replaceRecord != null) {
            final idx = _detections.indexOf(result.replaceRecord!);
            if (idx != -1) {
              _detections[idx] = DetectionRecord(
                scientificName: result.scientificName,
                commonName: result.commonName,
                confidence: result.replaceRecord!.confidence,
                timestamp: result.replaceRecord!.timestamp,
                audioClipPath: result.replaceRecord!.audioClipPath,
                source: DetectionSource.manual,
              );
            }
          }
          break;
      }

      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
  }

  // ── Annotations ───────────────────────────────────────────────────

  void _addAnnotation(SessionAnnotation annotation) {
    _pushUndo();
    setState(() {
      _annotations.add(annotation);
      _isDirty = true;
    });
  }

  void _deleteAnnotation(int index) {
    _pushUndo();
    setState(() {
      _annotations.removeAt(index);
      _isDirty = true;
    });
  }

  // ── Trim ──────────────────────────────────────────────────────────

  void _toggleTrimMode() {
    if (!_trimMode) {
      // Entering trim mode — remember the applied trim state so _applyTrim
      // can build an accurate undo snapshot.
      _preTrimStartSec = _trimStartSec;
      _preTrimEndSec = _trimEndSec;
    }
    setState(() => _trimMode = !_trimMode);
  }

  void _onTrimChanged(double startSec, double endSec) {
    _trimStartSec = startSec;
    _trimEndSec = endSec;
  }

  Future<void> _applyTrim() async {
    if (_trimStartSec == null && _trimEndSec == null) return;
    final start = _trimStartSec ?? 0.0;
    final end = _trimEndSec ?? _fullDurationSec;

    // Build undo snapshot with the state *before* trim mode was entered.
    // _trimStartSec/_trimEndSec now hold transient handle positions from
    // _onTrimChanged; the pre-trim values were saved by _toggleTrimMode.
    _undoStack.add(
      _ReviewSnapshot(
        detections: List.of(_detections),
        annotations: List.of(_annotations),
        trimStartSec: _preTrimStartSec,
        trimEndSec: _preTrimEndSec,
        clipOffsetSec: _clipOffsetSec,
      ),
    );
    _redoStack.clear();

    // Walk the detection list and either drop, keep, or clamp each
    // record. A detection survives the trim as long as any part of its
    // [timestamp, endTimestamp] interval overlaps [start, end] — that
    // way a long-running call that began before the trim window or
    // continued past it remains visible, with its visible extent
    // clamped to the new clip boundaries.
    final sessionStart = widget.session.startTime;
    final windowSec = widget.session.settings.windowDuration;
    final trimStartWall = sessionStart.add(
      Duration(microseconds: (start * 1e6).round()),
    );
    final trimEndWall = sessionStart.add(
      Duration(microseconds: (end * 1e6).round()),
    );
    final clamped = <DetectionRecord>[];
    for (final d in _detections) {
      final detStart = d.timestamp;
      // Treat a missing endTimestamp (legacy records, manual annotations)
      // as a single inference window starting at the detection time.
      final detEnd =
          d.endTimestamp ?? detStart.add(Duration(seconds: windowSec));
      // No overlap → drop.
      if (detEnd.isBefore(trimStartWall) || detStart.isAfter(trimEndWall)) {
        continue;
      }
      // Fully inside → keep as-is to preserve the original endTimestamp
      // (including its null-ness for legacy / manual records).
      if (!detStart.isBefore(trimStartWall) && !detEnd.isAfter(trimEndWall)) {
        clamped.add(d);
        continue;
      }
      // Partial overlap → rebuild with clamped timestamps so the
      // detection's visible extent matches the new clip.
      final newStart =
          detStart.isBefore(trimStartWall) ? trimStartWall : detStart;
      final newEnd = detEnd.isAfter(trimEndWall) ? trimEndWall : detEnd;
      clamped.add(
        DetectionRecord(
          scientificName: d.scientificName,
          commonName: d.commonName,
          confidence: d.confidence,
          timestamp: newStart,
          endTimestamp: newEnd,
          audioClipPath: d.audioClipPath,
          source: d.source,
          latitude: d.latitude,
          longitude: d.longitude,
        ),
      );
    }
    setState(() {
      _detections
        ..clear()
        ..addAll(clamped);
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
      _trimMode = false;
    });

    // Clip the player to the trimmed range.
    final startDur = Duration(microseconds: (start * 1e6).round());
    final endDur = Duration(microseconds: (end * 1e6).round());
    final clippedDur = await _player.setClip(start: startDur, end: endDur);
    await _player.seek(Duration.zero);

    // Crop the spectrogram to the trimmed portion.
    await _cropSpectrogramForClip(start, end);

    if (mounted) {
      setState(() {
        _clipOffsetSec = start;
        _duration = clippedDur ?? (endDur - startDur);
        _position = Duration.zero;
      });
    }
  }

  Future<void> _resetTrim() async {
    _pushUndo();

    // Remove the player clip and restore the full recording.
    await _player.setClip();
    await _player.seek(Duration.zero);

    setState(() {
      _trimStartSec = null;
      _trimEndSec = null;
      _clipOffsetSec = 0.0;
      _duration = Duration(microseconds: (_fullDurationSec * 1e6).round());
      _position = Duration.zero;
      // Restore the full-recording spectrogram.
      if (_spectrogramImage != null &&
          !identical(_spectrogramImage, _fullSpectrogramImage)) {
        _spectrogramImage!.dispose();
      }
      _spectrogramImage = _fullSpectrogramImage;
      _isDirty = true;
      _trimMode = false;
    });
  }

  // ── Help ──────────────────────────────────────────────────────────

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _SessionHelpSheet(
            showContinueSurvey: widget.session.type == SessionType.survey,
          ),
    );
  }

  /// Open fullscreen survey track map with all detections.
  void _openFullscreenSurveyMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _FullscreenSurveyMapScreen(
              gpsTrack: widget.session.gpsTrack,
              detections: _detections,
              initialHighlight: _highlightedDetection,
              onConfirmChanged: () {
                // Detections were mutated in place from the in-sheet
                // checkmark; mark dirty so save/discard prompts trigger
                // and rebuild so species rows + badges refresh.
                if (mounted) setState(() => _isDirty = true);
              },
            ),
      ),
    );
  }

  /// Highlight a detection on the map and scroll to show it.
  void _showDetectionOnMap(DetectionRecord detection) {
    if (detection.latitude == null || detection.longitude == null) return;
    setState(() {
      _highlightedDetection = detection;
    });
  }

  /// Filter species groups to only include detections visible on the map.
  List<_SpeciesGroup> get _filteredSpeciesGroups {
    var groups = _speciesGroups;
    if (widget.session.type == SessionType.survey &&
        _visibleMapBounds != null) {
      final bounds = _visibleMapBounds!;
      final visible =
          _detections.where((d) {
            if (d.latitude == null || d.longitude == null) return true;
            return bounds.contains(LatLng(d.latitude!, d.longitude!));
          }).toList();
      groups = _buildSpeciesGroups(
        visible,
        widget.session.settings.windowDuration,
      );
    }
    return groups;
  }

  /// Toggle the confirmed flag on every record in [cluster]. The new
  /// state is determined by the cluster as a whole: if any record is
  /// already confirmed, the action clears confirmation across the
  /// cluster; otherwise it stamps every record with the same confirmation
  /// timestamp so they group cleanly in exports.
  void _toggleClusterConfirmation(_DetectionCluster cluster) {
    final anyConfirmed = cluster.records.any((r) => r.isConfirmed);
    final stamp = anyConfirmed ? null : DateTime.now().toUtc();
    setState(() {
      for (final r in cluster.records) {
        r.confirmedAt = stamp;
      }
      _isDirty = true;
    });
  }

  Future<void> _confirmDeleteDetection(
    _SpeciesGroup group,
    _DetectionCluster cluster,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionDeleteDetectionTitle),
            content: Text(l10n.sessionDeleteDetectionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.sessionRemove),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    _pushUndo();
    setState(() {
      for (final r in cluster.records) {
        _detections.remove(r);
      }
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
  }

  void _seekToCluster(_DetectionCluster cluster) {
    // Full recording available — seek the main player.
    if (_audioAvailable && _duration != Duration.zero) {
      final clipOffset = Duration(microseconds: (_clipOffsetSec * 1e6).round());
      final offset = cluster.firstTimestamp.difference(
        widget.session.startTime,
      );
      var seekPos = offset - clipOffset;
      // Clamp into the playable range [0, duration] so detections that
      // landed slightly before the recorder fully spun up (negative
      // offset) or after the trim end still play back from a sensible
      // position instead of silently failing.
      if (seekPos.isNegative) seekPos = Duration.zero;
      if (seekPos > _duration) seekPos = _duration;

      // Compute the cluster's end position in clip coordinates so we
      // can auto-pause once playback walks past the detection. Use the
      // recorded continuous-detection end when available; otherwise
      // fall back to a single inference window.
      final windowSec = widget.session.settings.windowDuration;
      final lastRecord = cluster.records.last;
      final endTs =
          lastRecord.endTimestamp ??
          lastRecord.timestamp.add(Duration(seconds: windowSec));
      var stopPos = endTs.difference(widget.session.startTime) - clipOffset;
      if (stopPos > _duration) stopPos = _duration;
      // Guard against degenerate ranges (end before start).
      _autoStopPosition = stopPos > seekPos ? stopPos : null;

      _player.seek(seekPos);
      if (!_isPlaying) _player.play();
      return;
    }
    // No full recording — try to play the first detection clip.
    _playDetectionClip(cluster);
  }

  /// Play the first available detection clip from the given cluster.
  Future<void> _playDetectionClip(_DetectionCluster cluster) async {
    final clip =
        cluster.records
            .where(
              (r) =>
                  r.audioClipPath != null &&
                  File(r.audioClipPath!).existsSync(),
            )
            .firstOrNull;
    if (clip == null) return;
    await _clipPlayer.stop();
    await _clipPlayer.setFilePath(clip.audioClipPath!);
    setState(() => _activeClipCluster = cluster);
    _clipPlayerStateSubscription ??= _clipPlayer.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      if (!state.playing ||
          state.processingState == ProcessingState.completed) {
        if (_activeClipCluster != null) {
          setState(() => _activeClipCluster = null);
        }
      }
    });
    _clipPlayer.play();
  }

  void _seekToPosition(Duration position) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    if (position.isNegative) position = Duration.zero;
    if (position > _duration) position = _duration;
    // Manual seek cancels any pending auto-stop — the user is taking
    // over the timeline.
    _autoStopPosition = null;
    _player.seek(position);
    if (!_isPlaying) _player.play();
  }

  void _pausePlayer() {
    _autoStopPosition = null;
    if (_isPlaying) _player.pause();
    if (_clipPlayer.playing) _clipPlayer.pause();
    if (_activeClipCluster != null) {
      setState(() => _activeClipCluster = null);
    }
  }

  // ── Add Content Menu ──────────────────────────────────────────────

  Future<void> _showAddMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final value = await showModalBottomSheet<String>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(l10n.sessionAddSpecies),
                  onTap: () => Navigator.of(ctx).pop('species'),
                ),
                ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: Text(l10n.sessionAddAnnotationOption),
                  onTap: () => Navigator.of(ctx).pop('annotation'),
                ),
              ],
            ),
          ),
    );
    if (!mounted || value == null) return;
    if (value == 'species') {
      _addSpecies();
    } else if (value == 'annotation') {
      _showAnnotationInput();
    }
  }

  void _showAnnotationInput() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var atTimestamp = false;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  title: Text(l10n.sessionAddAnnotationOption),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: l10n.sessionAddAnnotation,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          maxLines: 5,
                          minLines: 2,
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              avatar: const Icon(Icons.public, size: 18),
                              label: Text(l10n.sessionAnnotationGlobal),
                              selected: !atTimestamp,
                              onSelected:
                                  (_) =>
                                      setDialogState(() => atTimestamp = false),
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.schedule, size: 18),
                              label: Text(l10n.sessionInsertAtTimestamp),
                              selected: atTimestamp,
                              onSelected:
                                  (_) =>
                                      setDialogState(() => atTimestamp = true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        final positionSec =
                            _position.inMicroseconds / 1000000.0;
                        _addAnnotation(
                          SessionAnnotation(
                            text: text,
                            createdAt: DateTime.now(),
                            offsetInRecording: atTimestamp ? positionSec : null,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.sessionAddAnnotationOption),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _replaceDetection(_DetectionCluster cluster) async {
    final positionSec = _position.inMicroseconds / 1000000.0;
    final target = cluster.records.first;
    final result = await Navigator.of(context).push<_AddSpeciesResult>(
      MaterialPageRoute(
        builder:
            (_) => _AddSpeciesOverlay(
              sessionStart: widget.session.startTime,
              positionSec: positionSec,
              existingDetections: _detections,
              initialMode: _InsertMode.replace,
              initialReplaceTarget: target,
            ),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    _pushUndo();
    setState(() {
      if (result.replaceRecord != null) {
        final idx = _detections.indexOf(result.replaceRecord!);
        if (idx != -1) {
          _detections[idx] = DetectionRecord(
            scientificName: result.scientificName,
            commonName: result.commonName,
            confidence: result.replaceRecord!.confidence,
            timestamp: result.replaceRecord!.timestamp,
            audioClipPath: result.replaceRecord!.audioClipPath,
            source: DetectionSource.manual,
          );
        }
      }
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final canPop = await _onWillPop();
          if (canPop) nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _showRenameDialog,
            child: Tooltip(
              message: l10n.sessionRenameTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _sessionReviewTitle(l10n, widget.session),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(153),
                  ),
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.tooltipClose,
            onPressed: () async {
              if (_isDirty) {
                final canPop = await _onWillPop();
                if (canPop && mounted) _done();
              } else {
                _done();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: l10n.sessionHelpTitle,
              onPressed: _showHelp,
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: l10n.settings,
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
            ),
          ],
        ),
        body: _buildReviewBody(context, theme, l10n),
      ),
    );
  }

  // ── Review Body — orientation-aware layout ────────────────────────

  Widget _buildReviewBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final toolbar = _buildToolbar(theme, l10n);
    final speciesList = _buildSpeciesList(theme, l10n);

    if (isLandscape) {
      // Landscape: toolbar on top, then left = scrollable media, right = species.
      return Column(
        children: [
          toolbar,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: scrollable media column.
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      children: _buildMediaWidgets(context, theme, l10n),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: species list. Slightly wider than the media column
                // because each detection row carries a play affordance plus
                // four trailing action buttons; cramming those into a 50/50
                // split makes the row text overflow on phone-sized landscape.
                Expanded(flex: 3, child: speciesList),
              ],
            ),
          ),
        ],
      );
    }

    // Portrait: original vertical stack.
    return Column(
      children: [
        toolbar,
        ..._buildMediaWidgets(context, theme, l10n),
        const Divider(height: 1),
        Expanded(child: speciesList),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: l10n.sessionAddContent,
            onPressed: _showAddMenu,
          ),
          IconButton(
            icon: Icon(
              Icons.undo,
              color:
                  _canUndo ? null : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionUndo,
            onPressed: _canUndo ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo,
              color:
                  _canRedo ? null : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionRedo,
            onPressed: _canRedo ? _redo : null,
          ),
          if (_audioAvailable)
            IconButton(
              icon: Icon(
                _trimMode ? Icons.content_cut : Icons.content_cut_outlined,
              ),
              tooltip: l10n.sessionTrimRecording,
              onPressed: _toggleTrimMode,
              color: _trimMode ? theme.colorScheme.primary : null,
            ),
          IconButton(
            icon: Icon(
              Icons.save,
              color:
                  _isDirty
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionSave,
            onPressed: _isDirty ? _save : null,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.sessionShare,
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.sessionDiscard,
            onPressed: _discard,
          ),
          if (widget.session.type == SessionType.survey)
            IconButton(
              icon: Icon(
                Icons.play_arrow_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: l10n.surveyContinue,
              onPressed: _continueSurvey,
            ),
        ],
      ),
    );
  }

  /// Builds the media widgets: summary header, map, spectrogram, trim bar,
  /// and annotations. Used by both portrait and landscape layouts.
  List<Widget> _buildMediaWidgets(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return [
      _SummaryHeader(
        session: widget.session,
        detectionCount: _detections.length,
        locationName: _locationName,
        onShowMap:
            widget.session.latitude != null
                ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => SessionMapScreen(
                          latitude: widget.session.latitude!,
                          longitude: widget.session.longitude!,
                          locationName: _locationName,
                        ),
                  ),
                )
                : null,
      ),
      if (widget.session.type == SessionType.survey &&
          (widget.session.gpsTrack.isNotEmpty ||
              (widget.session.latitude != null &&
                  widget.session.longitude != null)))
        Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.18,
              child: ClipRRect(
                child: SurveyMapWidget(
                  gpsTrack: widget.session.gpsTrack,
                  detections: _detections,
                  autoFollow: false,
                  fitAllPoints: widget.session.gpsTrack.length >= 2,
                  highlightedDetection: _highlightedDetection,
                  initialCenter:
                      widget.session.latitude != null &&
                              widget.session.longitude != null
                          ? LatLng(
                            widget.session.latitude!,
                            widget.session.longitude!,
                          )
                          : null,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.8),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openFullscreenSurveyMap(context),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.fullscreen,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      if (_audioAvailable) ...[
        if (_trimMode && (_fullSpectrogramImage ?? _spectrogramImage) != null)
          _TrimSpectrogramView(
            spectrogramImage: (_fullSpectrogramImage ?? _spectrogramImage)!,
            durationSec:
                _fullDurationSec > 0
                    ? _fullDurationSec
                    : _duration.inMicroseconds / 1000000.0,
            initialStartSec: _trimStartSec ?? 0.0,
            initialEndSec:
                _trimEndSec ??
                (_fullDurationSec > 0
                    ? _fullDurationSec
                    : _duration.inMicroseconds / 1000000.0),
            onChanged: _onTrimChanged,
          )
        else
          Stack(
            children: [
              _SpectrogramStrip(
                spectrogramImage: _spectrogramImage,
                decoding: _decoding,
                position: _position,
                duration: _duration,
                onSeek: _seekToPosition,
                onPause: _pausePlayer,
                isPlaying: _isPlaying,
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: _PlayPauseButton(
                  isPlaying: _isPlaying,
                  onToggle: () {
                    // Manual play/pause cancels any pending auto-stop.
                    _autoStopPosition = null;
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                ),
              ),
            ],
          ),
      ],
      if (_trimMode)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _resetTrim,
                child: Text(l10n.sessionTrimReset),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyTrim,
                child: Text(l10n.sessionTrimApply),
              ),
            ],
          ),
        ),
      if (_annotations.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _annotations.length; i++)
                Chip(
                  label: Text(
                    _annotations[i].text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: Icon(
                    _annotations[i].offsetInRecording != null
                        ? Icons.schedule
                        : Icons.public,
                    size: 16,
                  ),
                  deleteIcon: const Icon(Icons.delete_outline, size: 16),
                  onDeleted: () => _deleteAnnotation(i),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
    ];
  }

  Widget _buildSpeciesList(ThemeData theme, AppLocalizations l10n) {
    if (_filteredSpeciesGroups.isEmpty) {
      return Center(
        child: Text(
          l10n.sessionNoDetections,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredSpeciesGroups.length,
      itemBuilder: (context, index) {
        final group = _filteredSpeciesGroups[index];
        final isExpanded = _expandedSpecies.contains(group.scientificName);
        final isActive =
            _isSpeciesActive(group) ||
            (_activeClipCluster != null &&
                group.clusters.contains(_activeClipCluster));
        return _SpeciesTile(
          group: group,
          sessionStart: widget.session.startTime,
          isExpanded: isExpanded,
          isActive: isActive,
          activePositionSec: _isPlaying ? _position.inMicroseconds / 1e6 : null,
          activeCluster: _activeClipCluster,
          clipOffsetSec: _clipOffsetSec,
          windowSec: widget.session.settings.windowDuration,
          isSurvey: widget.session.type == SessionType.survey,
          audioAvailable: _audioAvailable,
          onToggleExpand:
              () => setState(() {
                if (isExpanded) {
                  _expandedSpecies.remove(group.scientificName);
                } else {
                  _expandedSpecies.add(group.scientificName);
                }
              }),
          onSpeciesInfo:
              () => SpeciesInfoOverlay.show(
                context,
                ref,
                scientificName: group.scientificName,
                commonName: group.commonName,
              ),
          onSeekCluster: _seekToCluster,
          onPause: _pausePlayer,
          onDeleteCluster: (cluster) => _confirmDeleteDetection(group, cluster),
          onReplaceCluster: _replaceDetection,
          onToggleConfirmCluster: _toggleClusterConfirmation,
          onShowOnMap: _showDetectionOnMap,
        );
      },
    );
  }

  /// Whether any detection in [group] spans the current playback position.
  bool _isSpeciesActive(_SpeciesGroup group) {
    // Only highlight while audio is actually playing — a paused player
    // (whether by the user or by the cluster auto-stop) should leave the
    // species list in its idle styling.
    if (!_isPlaying) return false;
    final windowSec = widget.session.settings.windowDuration;
    final clipOffset = Duration(microseconds: (_clipOffsetSec * 1e6).round());
    for (final r in group.allRecords) {
      final offset = r.timestamp.difference(widget.session.startTime);
      // Map the absolute offset into clip-relative coordinates.
      final rel = offset - clipOffset;
      // Honour the recorded continuous-detection duration when present;
      // otherwise fall back to a single inference window starting at the
      // detection timestamp.
      final detEnd =
          r.endTimestamp != null
              ? r.endTimestamp!.difference(widget.session.startTime) -
                  clipOffset
              : rel + Duration(seconds: windowSec);
      if (_position >= rel && _position <= detEnd) return true;
    }
    return false;
  }

  // ── Grouping Logic ──────────────────────────────────────────────────

  /// Build species-grouped, cluster-merged detection summaries.
  ///
  /// 1. Group all detections by scientific name.
  /// 2. Sort each group by timestamp.
  /// 3. Within each species, merge consecutive detections whose gap is
  ///    shorter than [maxGapSec] or 3s into clusters.
  /// 4. Sort species by their earliest detection.
  static List<_SpeciesGroup> _buildSpeciesGroups(
    List<DetectionRecord> records,
    int maxGapSec,
  ) {
    if (records.isEmpty) return const [];

    // Force grouping gap to be at least 3 seconds.
    final effectiveMaxGapSec = math.max(3, maxGapSec);

    final bySpecies = <String, List<DetectionRecord>>{};
    for (final r in records) {
      bySpecies.putIfAbsent(r.scientificName, () => []).add(r);
    }

    final groups = <_SpeciesGroup>[];
    for (final entry in bySpecies.entries) {
      final sorted = List.of(entry.value)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Merge consecutive detections.
      final clusters = <_DetectionCluster>[];
      var current = <DetectionRecord>[sorted.first];

      for (var i = 1; i < sorted.length; i++) {
        final gap =
            sorted[i].timestamp.difference(sorted[i - 1].timestamp).inSeconds;
        if (gap <= effectiveMaxGapSec) {
          current.add(sorted[i]);
        } else {
          clusters.add(_DetectionCluster(current));
          current = [sorted[i]];
        }
      }
      clusters.add(_DetectionCluster(current));

      groups.add(
        _SpeciesGroup(
          scientificName: entry.key,
          commonName: sorted.first.commonName,
          clusters: clusters,
        ),
      );
    }

    groups.sort((a, b) => a.firstTimestamp.compareTo(b.firstTimestamp));
    return groups;
  }
}

/// Returns a localized display label for the given [SessionType].
String _sessionTypeLabel(AppLocalizations l10n, SessionType type) {
  switch (type) {
    case SessionType.live:
      return l10n.sessionTypeLive;
    case SessionType.fileUpload:
      return l10n.sessionTypeFileUpload;
    case SessionType.pointCount:
      return l10n.sessionTypePointCount;
    case SessionType.survey:
      return l10n.sessionTypeSurvey;
  }
}

/// Returns a numbered review-screen title such as "Live Session #3 Review".
///
/// Falls back to just the un-numbered type label when [session.sessionNumber]
/// is `null` (legacy sessions).
String _sessionReviewTitle(AppLocalizations l10n, LiveSession session) {
  if (session.customName != null && session.customName!.isNotEmpty) {
    return session.customName!;
  }
  final n = session.sessionNumber;
  if (n == null) return _sessionTypeLabel(l10n, session.type);
  switch (session.type) {
    case SessionType.live:
      return l10n.sessionTitleLiveNum(n);
    case SessionType.fileUpload:
      return l10n.sessionTitleFileUploadNum(n);
    case SessionType.pointCount:
      return l10n.sessionTitlePointCountNum(n);
    case SessionType.survey:
      return l10n.sessionTitleSurveyNum(n);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen Survey Track Map
// ─────────────────────────────────────────────────────────────────────────────

/// Filter modes available on the fullscreen survey track map. The
/// confidence threshold is a separate slider that can stack with any of
/// these modes (e.g. "with audio" + ≥75% confidence).
enum _MapFilterMode { all, withAudio, manual }

/// Default confidence floor for the slider. 0.5 keeps every detection a
/// typical survey would keep, so the slider visibly reduces markers as
/// the user drags it up.
const double _defaultConfidenceFloor = 0.1;

/// Fullscreen map showing the complete survey track with species markers.
/// Tapping a species marker plays the detection's audio clip. The app bar
/// hosts a filter button that opens a bottom sheet for restricting which
/// detections are shown (audio only, manual additions, minimum
/// confidence, single species).
class _FullscreenSurveyMapScreen extends ConsumerStatefulWidget {
  const _FullscreenSurveyMapScreen({
    required this.gpsTrack,
    required this.detections,
    this.initialHighlight,
    this.onConfirmChanged,
  });

  final List<GpsPoint> gpsTrack;
  final List<DetectionRecord> detections;

  /// Invoked after the in-sheet confirm checkmark mutates a detection's
  /// [DetectionRecord.confirmedAt]. The host uses this hook to mark the
  /// session dirty and refresh derived UI (species rows, marker badges).
  final VoidCallback? onConfirmChanged;

  /// Detection that the inline review map was currently focused on. When
  /// non-null the fullscreen map opens centered and zoomed in on this
  /// detection instead of fitting the whole track — keeps the user's
  /// place when expanding from the small map.
  final DetectionRecord? initialHighlight;

  @override
  ConsumerState<_FullscreenSurveyMapScreen> createState() =>
      _FullscreenSurveyMapScreenState();
}

class _FullscreenSurveyMapScreenState
    extends ConsumerState<_FullscreenSurveyMapScreen> {
  DetectionRecord? _highlight;
  _MapFilterMode _mode = _MapFilterMode.all;
  double _minConfidence = _defaultConfidenceFloor;
  String? _speciesFilter; // scientific name, or null for "all species"

  @override
  void initState() {
    super.initState();
    // Carry the inline map's focus into the fullscreen view so users land
    // on the same detection they were inspecting instead of being yanked
    // back out to a whole-track fit.
    _highlight = widget.initialHighlight;
  }

  bool get _isFilterActive =>
      _mode != _MapFilterMode.all ||
      _speciesFilter != null ||
      _minConfidence > _defaultConfidenceFloor;

  /// Localized one-line summary for the persistent filter chip — pinpoints
  /// what's currently hidden so users don't have to open the sheet to find
  /// out why some markers vanished. Order of precedence: species > mode >
  /// confidence > inactive.
  String _filterChipSummary(AppLocalizations l10n) {
    if (!_isFilterActive) return l10n.surveyMapFilterChipAll;
    if (_speciesFilter != null) {
      // Find any record with that scientific name to recover a display name.
      final match = widget.detections.firstWhere(
        (d) => d.scientificName == _speciesFilter,
        orElse: () => widget.detections.first,
      );
      return _localizedName(match.scientificName, match.commonName);
    }
    switch (_mode) {
      case _MapFilterMode.withAudio:
        return l10n.surveyMapFilterWithAudio;
      case _MapFilterMode.manual:
        return l10n.surveyMapFilterManual;
      case _MapFilterMode.all:
        // Only the confidence floor differs — show the threshold.
        return '≥ ${(_minConfidence * 100).round()}%';
    }
  }

  /// Localized common name for [sciName]. Falls back to the record's stored
  /// common name when the taxonomy hasn't loaded yet.
  String _localizedName(String sciName, String fallback) {
    final taxonomy = ref.watch(taxonomyServiceProvider).valueOrNull;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    return taxonomy?.lookup(sciName)?.commonNameForLocale(speciesLocale) ??
        fallback;
  }

  List<DetectionRecord> get _filtered {
    return widget.detections.where((d) {
      switch (_mode) {
        case _MapFilterMode.all:
          break;
        case _MapFilterMode.withAudio:
          final p = d.audioClipPath;
          if (p == null || !File(p).existsSync()) return false;
          break;
        case _MapFilterMode.manual:
          if (d.source != DetectionSource.manual &&
              d.source != DetectionSource.manualGlobal) {
            return false;
          }
          break;
      }
      if (d.confidence < _minConfidence) return false;
      if (_speciesFilter != null && d.scientificName != _speciesFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onMarkerTap(DetectionRecord detection) async {
    // Only play markers whose own clip is still on disk. The map widget
    // already prefers the audio-bearing record when grouping, so a tap on
    // a "play badge" marker reaches us here with [audioClipPath] set; a
    // tap on a no-audio marker is a silent no-op.
    final path = detection.audioClipPath;
    if (path == null || !File(path).existsSync()) return;

    setState(() => _highlight = detection);
    await showClipPlayerSheet(
      context,
      detection: detection,
      onConfirmChanged: () {
        // Rebuild this screen so the marker's confirmed badge updates
        // immediately, then forward to the host so the session is marked
        // dirty and the inline review screen refreshes on pop.
        if (mounted) setState(() {});
        widget.onConfirmChanged?.call();
      },
    );
    if (mounted) setState(() => _highlight = null);
  }

  Future<void> _openFilterSheet() async {
    final l10n = AppLocalizations.of(context)!;

    // Build a localized, deduplicated species list once. Each entry
    // captures the scientific name (the filter key), the localized
    // display name, and a max-confidence value used to grey out species
    // that the current confidence floor would already exclude.
    final byScientific = <String, _SpeciesPickerEntry>{};
    for (final d in widget.detections) {
      final existing = byScientific[d.scientificName];
      final localized = _localizedName(d.scientificName, d.commonName);
      if (existing == null) {
        byScientific[d.scientificName] = _SpeciesPickerEntry(
          scientificName: d.scientificName,
          displayName: localized,
          maxConfidence: d.confidence,
        );
      } else if (d.confidence > existing.maxConfidence) {
        byScientific[d.scientificName] = existing.copyWith(
          maxConfidence: d.confidence,
        );
      }
    }
    final speciesEntries =
        byScientific.values.toList()..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

    final result = await showModalBottomSheet<_MapFilterChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _MapFilterSheet(
          initialMode: _mode,
          initialMinConfidence: _minConfidence,
          initialSpecies: _speciesFilter,
          speciesEntries: speciesEntries,
          l10n: l10n,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _mode = result.mode;
        _minConfidence = result.minConfidence;
        _speciesFilter = result.species;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.surveyTrackMap),
            if (_isFilterActive)
              Text(
                l10n.surveyMapMatchCount(filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SurveyMapWidget(
            gpsTrack: widget.gpsTrack,
            detections: filtered,
            autoFollow: false,
            fitAllPoints: true,
            highlightedDetection: _highlight,
            onMarkerTap: _onMarkerTap,
          ),
          // Persistent filter chip — promotes the AppBar action to a
          // first-class on-map affordance so the filter is discoverable
          // (#33: users were missing the AppBar icon entirely). The chip
          // shows the active filter summary so users can see at a glance
          // what's hiding markers.
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: _MapFilterChip(
                isActive: _isFilterActive,
                summary: _filterChipSummary(l10n),
                onTap: _openFilterSheet,
              ),
            ),
          ),
          if (filtered.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.surveyMapFilterEmpty)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Captured state for one species in the filter sheet's picker.
class _SpeciesPickerEntry {
  const _SpeciesPickerEntry({
    required this.scientificName,
    required this.displayName,
    required this.maxConfidence,
  });

  final String scientificName;
  final String displayName;
  final double maxConfidence;

  _SpeciesPickerEntry copyWith({double? maxConfidence}) => _SpeciesPickerEntry(
    scientificName: scientificName,
    displayName: displayName,
    maxConfidence: maxConfidence ?? this.maxConfidence,
  );
}

/// Stateful filter sheet — extracted as its own widget so the search
/// field, mode chips, confidence slider, and species list each rebuild
/// in isolation when the user interacts with them.
class _MapFilterSheet extends StatefulWidget {
  const _MapFilterSheet({
    required this.initialMode,
    required this.initialMinConfidence,
    required this.initialSpecies,
    required this.speciesEntries,
    required this.l10n,
  });

  final _MapFilterMode initialMode;
  final double initialMinConfidence;
  final String? initialSpecies;
  final List<_SpeciesPickerEntry> speciesEntries;
  final AppLocalizations l10n;

  @override
  State<_MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<_MapFilterSheet> {
  late _MapFilterMode _mode = widget.initialMode;
  late double _minConfidence = widget.initialMinConfidence;
  late String? _species = widget.initialSpecies;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = widget.l10n;

    final lowerQuery = _query.trim().toLowerCase();
    final filteredSpecies =
        lowerQuery.isEmpty
            ? widget.speciesEntries
            : widget.speciesEntries
                .where(
                  (e) =>
                      e.displayName.toLowerCase().contains(lowerQuery) ||
                      e.scientificName.toLowerCase().contains(lowerQuery),
                )
                .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.surveyMapFilterTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    // Mode chips.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterAll),
                          selected: _mode == _MapFilterMode.all,
                          onSelected:
                              (_) => setState(() => _mode = _MapFilterMode.all),
                        ),
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterWithAudio),
                          selected: _mode == _MapFilterMode.withAudio,
                          onSelected:
                              (_) => setState(
                                () => _mode = _MapFilterMode.withAudio,
                              ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterManual),
                          selected: _mode == _MapFilterMode.manual,
                          onSelected:
                              (_) =>
                                  setState(() => _mode = _MapFilterMode.manual),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Confidence slider.
                    Row(
                      children: [
                        Text(
                          l10n.surveyMapFilterMinConfidence,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(_minConfidence * 100).round()}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _minConfidence,
                      min: 0.1,
                      max: 0.99,
                      divisions: 89,
                      label: '${(_minConfidence * 100).round()}%',
                      onChanged: (v) => setState(() => _minConfidence = v),
                    ),
                    const SizedBox(height: 8),
                    // Species picker header + search.
                    Text(
                      l10n.surveyMapFilterSpecies,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: l10n.surveyMapFilterSpeciesSearchHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    // "All species" pill — always visible at the top of
                    // the picker so clearing the species filter is one tap.
                    _SpeciesPickerTile(
                      label: l10n.surveyMapFilterAllSpecies,
                      selected: _species == null,
                      onTap: () => setState(() => _species = null),
                    ),
                    for (final e in filteredSpecies)
                      _SpeciesPickerTile(
                        label: e.displayName,
                        scientificName: e.scientificName,
                        selected: _species == e.scientificName,
                        onTap:
                            () => setState(() => _species = e.scientificName),
                      ),
                  ],
                ),
              ),
              // Bottom action bar.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed:
                            () => Navigator.of(context).pop(
                              const _MapFilterChoice(
                                mode: _MapFilterMode.all,
                                minConfidence: _defaultConfidenceFloor,
                                species: null,
                              ),
                            ),
                        child: Text(l10n.clearFilters),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed:
                            () => Navigator.of(context).pop(
                              _MapFilterChoice(
                                mode: _mode,
                                minConfidence: _minConfidence,
                                species: _species,
                              ),
                            ),
                        child: Text(l10n.apply),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lightweight tappable row used by the species picker. Avoids the
/// heavy radio-list look (which felt cluttered with hundreds of
/// detections) and gives a clear selected-state pill.
class _SpeciesPickerTile extends ConsumerWidget {
  const _SpeciesPickerTile({
    required this.label,
    this.scientificName,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? scientificName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showSciNames = ref.watch(showSciNamesProvider);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (showSciNames &&
                      scientificName != null &&
                      scientificName != label)
                    Text(
                      scientificName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFilterChoice {
  const _MapFilterChoice({
    required this.mode,
    required this.minConfidence,
    required this.species,
  });
  final _MapFilterMode mode;
  final double minConfidence;
  final String? species;
}

// -----------------------------------------------------------------------------
// _MapFilterChip � persistent on-map filter affordance.
//
// Promotes the filter from a hidden AppBar action to a chip overlay anchored
// top-right of the fullscreen survey map. Solves the discoverability problem
// reported in #33: users were missing the AppBar icon entirely. The chip
// also serves as a status read-out � its label always shows what the active
// filter is (All species, = 50%, Owl species, etc.) so users don't
// have to open the sheet to find out why some markers vanished.
// -----------------------------------------------------------------------------

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.isActive,
    required this.summary,
    required this.onTap,
  });

  final bool isActive;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surface.withAlpha(230);
    final fg =
        isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Material(
      color: bg,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.filter_list : Icons.filter_list_outlined,
                  size: 18,
                  color: fg,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    summary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
