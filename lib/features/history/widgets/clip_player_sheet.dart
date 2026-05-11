// =============================================================================
// Clip Player Sheet — Modal player for individual detection audio clips
// =============================================================================
//
// Shown when the user taps a detection marker (e.g. on the survey map) that
// has a kept audio clip. Decodes the clip, renders a spectrogram preview,
// and exposes simple play / pause / seek controls. Closing the sheet stops
// playback and releases the player + decoded image.
//
// The sheet is intentionally lightweight: it owns its own [AudioPlayer] and
// builds a one-shot [ui.Image] of the clip's spectrogram on init. This
// keeps it independent from the larger session-review pipeline so it can be
// invoked from any screen that has a [DetectionRecord] with an audio clip.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/score_colors.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../explore/explore_providers.dart';
import '../../live/live_session.dart';
import '../../recording/audio_decoder.dart';
import '../../recording/native_audio_decoder.dart';
import '../../spectrogram/color_maps.dart';
import '../services/detection_sharing_service.dart';
import 'detection_actions.dart';

/// Show the modal player for a [detection]'s audio clip.
///
/// No-op if the detection has no clip path or the file doesn't exist.
///
/// When [onConfirmChanged] is provided, the sheet renders a tap-to-toggle
/// confirm checkmark next to the species header so reviewers can validate
/// detections while they listen. The callback is invoked after each toggle
/// (the [DetectionRecord.confirmedAt] field is already mutated by the time
/// it fires) so the host can mark the session dirty / trigger a rebuild.
///
/// When [onDelete] is provided, the sheet header's overflow menu adds a
/// `Delete detection` entry. The callback is responsible for removing the
/// detection from the host model and showing any undo affordance; this
/// sheet just dismisses itself before invoking the callback so the user
/// isn't left staring at a clip that no longer belongs to anything.
Future<void> showClipPlayerSheet(
  BuildContext context, {
  required DetectionRecord detection,
  VoidCallback? onConfirmChanged,
  VoidCallback? onDelete,
  LiveSession? session,
}) {
  final path = detection.audioClipPath;
  if (path == null || !File(path).existsSync()) {
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder:
        (_) => _ClipPlayerSheet(
          detection: detection,
          clipPath: path,
          onConfirmChanged: onConfirmChanged,
          onDelete: onDelete,
          session: session,
        ),
  );
}

class _ClipPlayerSheet extends ConsumerStatefulWidget {
  const _ClipPlayerSheet({
    required this.detection,
    required this.clipPath,
    this.onConfirmChanged,
    this.onDelete,
    this.session,
  });

  final DetectionRecord detection;
  final String clipPath;
  final VoidCallback? onConfirmChanged;
  final VoidCallback? onDelete;
  final LiveSession? session;

  @override
  ConsumerState<_ClipPlayerSheet> createState() => _ClipPlayerSheetState();
}

class _ClipPlayerSheetState extends ConsumerState<_ClipPlayerSheet> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  ui.Image? _spectrogramImage;
  bool _decoding = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _decodeSpectrogram();
  }

  Future<void> _initPlayer() async {
    try {
      final dur = await _player.setFilePath(widget.clipPath);
      if (!mounted) return;
      setState(() => _duration = dur ?? Duration.zero);
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _isPlaying = s.playing);
        if (s.processingState == ProcessingState.completed) {
          _player.pause();
          _player.seek(Duration.zero);
        }
      });
      await _player.play();
    } catch (_) {
      // Playback unavailable — sheet still shows spectrogram + metadata.
    }
  }

  Future<void> _decodeSpectrogram() async {
    try {
      DecodedAudio audio;
      if (await AudioDecoder.canDecodeDart(widget.clipPath)) {
        audio = await AudioDecoder.decodeFile(widget.clipPath);
      } else {
        audio = await NativeAudioDecoder.decodeFile(widget.clipPath);
      }
      if (!mounted) return;
      audio = audio.resampleTo(AppConstants.sampleRate);
      final image = await _buildSpectrogramImage(audio);
      if (!mounted) {
        image?.dispose();
        return;
      }
      setState(() {
        _spectrogramImage = image;
        _decoding = false;
      });
    } catch (_) {
      if (mounted) setState(() => _decoding = false);
    }
  }

  Future<ui.Image?> _buildSpectrogramImage(DecodedAudio audio) async {
    const fftSize = 1024;
    const hop = 256;
    const maxFreqHz = 16000;
    const dbFloor = -80.0;
    const dbCeiling = 0.0;

    if (audio.totalSamples < fftSize) return null;
    final numCols = (audio.totalSamples - fftSize) ~/ hop + 1;
    if (numCols <= 0) return null;

    final nyquist = audio.sampleRate / 2;
    final binCount = fftSize ~/ 2 + 1;
    final displayBins = (maxFreqHz / nyquist * binCount).round().clamp(
      1,
      binCount,
    );

    final lut = SpectrogramColorMap.lut('viridis');
    final pixels = Uint8List(numCols * displayBins * 4);

    final hann = Float64List(fftSize);
    final hannFactor = 2.0 * math.pi / fftSize;
    for (var i = 0; i < fftSize; i++) {
      hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
    }
    final fft = FFT(fftSize);

    for (var c = 0; c < numCols; c++) {
      if (c > 0 && c % 200 == 0) {
        await Future.delayed(Duration.zero);
        if (!mounted) return null;
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
    return completer.future;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _spectrogramImage?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Flip the confirmation flag on the underlying record. We mutate the
  /// shared [DetectionRecord] in place (the host owns the list) and notify
  /// the host via [widget.onConfirmChanged] so it can mark its session
  /// dirty and rebuild any dependent UI (map markers, species rows).
  void _toggleConfirm() {
    final det = widget.detection;
    setState(() {
      det.confirmedAt = det.isConfirmed ? null : DateTime.now().toUtc();
    });
    widget.onConfirmChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final det = widget.detection;
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final showSciNames = ref.watch(showSciNamesProvider);
    final imagePath =
        taxonomyAsync.valueOrNull?.assetImagePath(det.scientificName) ??
        'assets/images/dummy_species.png';
    // Resolve the localized common name from the taxonomy when available;
    // fall back to whatever was stored on the record (English at detection
    // time) so legacy or unknown species still render something.
    final displayName =
        taxonomyAsync.valueOrNull
            ?.lookup(det.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        det.commonName;
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(det.timestamp);
    // Use the unified [ScoreColors] CVD-safe ramp so the avatar border on
    // this sheet matches the same detection's marker on the survey map and
    // its pill color in the Explore list.
    final scoreColor = ScoreColors.of(context).forScore(det.confidence);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: image + species info.
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: scoreColor.withAlpha(60),
                            child: Icon(Icons.music_note, color: scoreColor),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSciNames)
                        Text(
                          det.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              det.confidencePercent,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timeStr,
                              style: theme.textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Confirm checkmark in the upper-right corner of the header.
                // Only rendered when the host wired up [onConfirmChanged] so
                // contexts that can't persist the change (e.g. a future
                // read-only viewer) won't show a button that does nothing.
                if (widget.onConfirmChanged != null)
                  _ConfirmToggle(
                    confirmed: det.isConfirmed,
                    onToggle: _toggleConfirm,
                  ),
                // Per-detection overflow (share, delete) — same widget as
                // the session review row so users see one menu shape
                // regardless of where they opened the detection.
                DetectionActionsOverflow(
                  actions: DetectionActions(
                    onShare:
                        () => shareDetection(
                          widget.detection,
                          session: widget.session,
                        ),
                    onDelete:
                        widget.onDelete == null
                            ? null
                            : () {
                              Navigator.of(context).pop();
                              widget.onDelete!();
                            },
                  ),
                  iconColor: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Spectrogram preview.
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  _decoding
                      ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : _spectrogramImage == null
                      ? Center(
                        child: Icon(
                          Icons.graphic_eq,
                          color: Colors.white.withAlpha(80),
                          size: 32,
                        ),
                      )
                      : LayoutBuilder(
                        builder:
                            (_, c) => CustomPaint(
                              size: Size(c.maxWidth, c.maxHeight),
                              painter: _ClipSpectrogramPainter(
                                image: _spectrogramImage!,
                                progress:
                                    _duration.inMicroseconds == 0
                                        ? 0
                                        : _position.inMicroseconds /
                                            _duration.inMicroseconds,
                                accent: theme.colorScheme.primary,
                              ),
                            ),
                      ),
            ),
            const SizedBox(height: 8),

            // Transport row: play/pause inline with the scrubber so the
            // bottom of the sheet stays uncluttered (only the close button
            // remains there). Times flank the slider as compact labels.
            Row(
              children: [
                IconButton.filled(
                  iconSize: 28,
                  onPressed:
                      () => _isPlaying ? _player.pause() : _player.play(),
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_fmt(_position), style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value:
                        _duration.inMilliseconds == 0
                            ? 0
                            : _position.inMilliseconds
                                .clamp(0, _duration.inMilliseconds)
                                .toDouble(),
                    max:
                        _duration.inMilliseconds == 0
                            ? 1.0
                            : _duration.inMilliseconds.toDouble(),
                    onChanged:
                        _duration.inMilliseconds == 0
                            ? null
                            : (v) =>
                                _player.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Text(_fmt(_duration), style: theme.textTheme.labelSmall),
              ],
            ),

            // Bottom row: close-only.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  label: Text(AppLocalizations.of(context)!.tooltipClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipSpectrogramPainter extends CustomPainter {
  _ClipSpectrogramPainter({
    required this.image,
    required this.progress,
    required this.accent,
  });

  final ui.Image image;
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst, Paint());
    final x = (progress.clamp(0.0, 1.0)) * size.width;
    final paint =
        Paint()
          ..color = accent
          ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ClipSpectrogramPainter old) =>
      old.image != image || old.progress != progress || old.accent != accent;
}

/// Small tap-to-toggle confirm checkmark shown in the player sheet header.
/// Uses the same green check-circle iconography as the per-row confirm
/// button in session review and the corner badge on confirmed map markers,
/// so the visual language stays consistent across the three surfaces.
class _ConfirmToggle extends StatelessWidget {
  const _ConfirmToggle({required this.confirmed, required this.onToggle});

  final bool confirmed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message:
          confirmed
              ? l10n.detectionUnconfirmTooltip
              : l10n.detectionConfirmTooltip,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            confirmed ? Icons.check_circle : Icons.check_circle_outline,
            size: 28,
            color:
                confirmed
                    ? Colors.green.shade600
                    : theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      ),
    );
  }
}
