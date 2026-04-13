// =============================================================================
// Survey Live Screen — Dashboard shown during an active survey
// =============================================================================
//
// Tabbed UI for an active survey with three tabs: Map, Spectrogram, Summary.
// Map is the default tab and shows 50% of screen height.
//
// Layout (top → bottom):
//   1. Status bar with elapsed time, stop button, settings
//   2. Tab bar: Map | Spectrogram | Summary
//   3. Tab content (50% of screen)
//   4. Stats bar (distance, detections, species, audio level)
//   5. Recent detections list (remaining space)
//
// The survey runs primarily in the background.  When the user opens this
// screen, the map and stats update live.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../shared/providers/settings_providers.dart';
import '../audio/audio_providers.dart';
import '../audio/ring_buffer.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_review_screen.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'detection_sampler.dart';
import 'survey_controller.dart';
import 'survey_providers.dart';
import 'widgets/survey_map_widget.dart';
import 'widgets/survey_stats_bar.dart';

/// Dashboard shown during an active survey.
class SurveyLiveScreen extends ConsumerStatefulWidget {
  const SurveyLiveScreen({
    super.key,
    this.customName,
    this.transectId,
    this.observerName,
    this.startLatitude,
    this.startLongitude,
    this.backgroundGps = true,
    this.resumeSession,
  });

  final String? customName;
  final String? transectId;
  final String? observerName;
  final double? startLatitude;
  final double? startLongitude;
  final bool backgroundGps;

  /// If non-null, resume this unfinished session instead of starting fresh.
  final LiveSession? resumeSession;

  @override
  ConsumerState<SurveyLiveScreen> createState() => _SurveyLiveScreenState();
}

class _SurveyLiveScreenState extends ConsumerState<SurveyLiveScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _started = false;
  bool _finalizing = false;
  Timer? _uiUpdateTimer;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    final controller = ref.read(surveyControllerProvider);
    controller.onStateChanged = _onControllerStateChanged;
    controller.onAutoStop = _onAutoStop;

    // Listen for "Stop" button pressed in the foreground notification.
    FlutterForegroundTask.addTaskDataCallback(_onNotificationData);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSurvey();
    });
  }

  /// Handle data from the foreground service TaskHandler (e.g. Stop button).
  void _onNotificationData(Object data) {
    if (data is Map && data['action'] == 'stop') {
      _confirmStop();
    }
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final controller = ref.read(surveyControllerProvider);
    ref.read(surveyStateProvider.notifier).state = controller.state;
    ref.read(surveyDetectionsProvider.notifier).state =
        controller.currentLiveDetections;
    ref.read(surveySessionProvider.notifier).state = controller.session;
  }

  void _onAutoStop(String reason) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.surveyAutoStopped(reason)),
        duration: const Duration(seconds: 3),
      ),
    );
    _finalizeAndReview();
  }

  Future<void> _startSurvey() async {
    if (_started) return;
    final controller = ref.read(surveyControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final deviceId = ref.read(selectedDeviceProvider);

    // Start audio capture.
    await captureNotifier.start(deviceId: deviceId);

    // Read settings.
    final windowDuration = ref.read(windowDurationProvider);
    final inferenceRate = ref.read(surveyInferenceRateProvider);
    final confidenceThreshold = ref.read(confidenceThresholdProvider);
    final filterMode = ref.read(speciesFilterModeProvider);
    final recordingModeStr = ref.read(surveyRecordingModeProvider);
    final recordingMode = recordingModeFromString(recordingModeStr);
    final recordingFormat = ref.read(recordingFormatProvider);
    final geoThreshold = ref.read(geoThresholdProvider);
    final gpsInterval = ref.read(surveyGpsIntervalProvider);
    final maxDuration = ref.read(surveyMaxDurationProvider);
    final samplingStr = ref.read(surveyDetectionSamplingProvider);
    final samplingMode = samplingModeFromString(samplingStr);
    final topN = ref.read(surveyTopNPerSpeciesProvider);
    final clipPreBuffer = ref.read(surveyClipPreBufferProvider);
    final clipPostBuffer = ref.read(surveyClipPostBufferProvider);
    final autoStopBattery = ref.read(surveyAutoStopBatteryProvider);

    final geoScores = await ref.read(geoScoresProvider.future);
    final geoSpeciesNames = await ref.read(geoModelSpeciesNamesProvider.future);

    if (widget.resumeSession != null) {
      await controller.resumeSurvey(
        existingSession: widget.resumeSession!,
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
        recordingFormat: recordingFormat,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoSpeciesNames,
        gpsIntervalSeconds: gpsInterval,
        maxDurationHours: maxDuration,
        samplingMode: samplingMode,
        topNPerSpecies: topN,
        backgroundGps: widget.backgroundGps,
        clipPreBuffer: clipPreBuffer,
        clipPostBuffer: clipPostBuffer,
        autoStopBattery: autoStopBattery,
      );
    } else {
      await controller.startSurvey(
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
        recordingFormat: recordingFormat,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoSpeciesNames,
        gpsIntervalSeconds: gpsInterval,
        maxDurationHours: maxDuration,
        samplingMode: samplingMode,
        topNPerSpecies: topN,
        transectId: widget.transectId,
        observerName: widget.observerName,
        customName: widget.customName,
        startLatitude: widget.startLatitude,
        startLongitude: widget.startLongitude,
        backgroundGps: widget.backgroundGps,
        clipPreBuffer: clipPreBuffer,
        clipPostBuffer: clipPostBuffer,
        autoStopBattery: autoStopBattery,
      );
    }

    _started = true;
    _onControllerStateChanged();

    // Update UI periodically (elapsed time, stats).
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _confirmStop() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.surveyStopTitle),
        content: Text(l10n.surveyStopMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.surveyStopConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _finalizeAndReview();
  }

  Future<void> _finalizeAndReview() async {
    if (_finalizing) return;
    _finalizing = true;
    _uiUpdateTimer?.cancel();

    final controller = ref.read(surveyControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);

    await captureNotifier.stop();
    final session = await controller.stopSurvey();
    _onControllerStateChanged();

    if (session != null && mounted) {
      final repo = ref.read(sessionRepositoryProvider);
      session.sessionNumber = await repo.nextSessionNumber(session.type);
      await repo.save(session);
      ref.invalidate(sessionListProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SessionReviewScreen(session: session),
          ),
        );
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In manual GPS mode, capture a fix when the user returns to the app.
    if (state == AppLifecycleState.resumed && !widget.backgroundGps) {
      ref.read(surveyControllerProvider).captureGpsFix();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onNotificationData);
    _uiUpdateTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surveyState = ref.watch(surveyStateProvider);
    final session = ref.watch(surveySessionProvider);
    final controller = ref.read(surveyControllerProvider);
    final ringBuffer = ref.read(ringBufferProvider);
    final isActive = surveyState == SurveyState.active;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isActive) {
          await _confirmStop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Status bar ────────────────────────────────────
              _SurveyStatusBar(
                elapsed: controller.elapsed,
                isActive: isActive,
                onStop: _confirmStop,
              ),

              // ── Tab bar ───────────────────────────────────────
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    text: l10n.surveyTabMap,
                  ),
                  Tab(
                    icon: const Icon(Icons.graphic_eq, size: 18),
                    text: l10n.surveyTabSpectrogram,
                  ),
                  Tab(
                    icon: Icon(MdiIcons.chartBar, size: 18),
                    text: l10n.surveyTabSummary,
                  ),
                ],
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                indicatorWeight: 2,
                labelStyle: theme.textTheme.labelSmall,
              ),

              // ── Tab content (50% of screen) ───────────────────
              Expanded(
                flex: 1,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Map tab.
                    SurveyMapWidget(
                      gpsTrack: controller.gpsTracker?.track ?? [],
                      detections: session?.detections ?? [],
                    ),

                    // Spectrogram tab.
                    _SurveySpectrogram(
                      ringBuffer: ringBuffer,
                      isActive: isActive,
                    ),

                    // Summary tab.
                    _SurveySummaryTab(session: session),
                  ],
                ),
              ),

              // ── Stats bar ─────────────────────────────────────
              SurveyStatsBar(
                distanceMeters: controller.gpsTracker?.distanceMeters ?? 0,
                detectionCount: session?.detections.length ?? 0,
                speciesCount: session?.uniqueSpeciesCount ?? 0,
                audioLevel: ringBuffer.rmsLevel(),
                peakLevel: ringBuffer.peakLevel(),
              ),

              // ── Recent detections ─────────────────────────────
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: DetectionList(
                      detections: _recentDetections(session),
                      isActive: isActive,
                      onDetectionTap: (detection) {
                        SpeciesInfoOverlay.show(
                          context,
                          ref,
                          scientificName: detection.scientificName,
                          commonName: detection.commonName,
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SurveyStatusBar extends StatelessWidget {
  const _SurveyStatusBar({
    required this.elapsed,
    required this.isActive,
    required this.onStop,
  });

  final Duration elapsed;
  final bool isActive;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          // Stop button (matches point count).
          IconButton(
            icon: const Icon(Icons.stop_rounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: isActive ? onStop : () => Navigator.of(context).pop(),
            tooltip: l10n.surveyStop,
            color: isActive ? theme.colorScheme.error : null,
          ),

          // Elapsed timer (center).
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$hours:$minutes:$seconds',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Settings gear (matches point count).
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(
                    settingsContext: SettingsContext.survey,
                  ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Spectrogram Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SurveySpectrogram extends ConsumerWidget {
  const _SurveySpectrogram({
    required this.ringBuffer,
    required this.isActive,
  });

  final RingBuffer ringBuffer;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fftSize = ref.watch(fftSizeProvider);
    final colorMap = ref.watch(colorMapProvider);
    final dbFloor = ref.watch(dbFloorProvider);
    final dbCeiling = ref.watch(dbCeilingProvider);
    final durationSec = ref.watch(spectrogramDurationProvider);
    final maxFreq = ref.watch(spectrogramMaxFreqProvider);
    final logAmplitude = ref.watch(logAmplitudeProvider);

    final hopSize = fftSize ~/ 2;
    const sampleRate = 32000;
    final maxColumns = (durationSec * sampleRate / hopSize).round();

    return SpectrogramWidget(
      ringBuffer: ringBuffer,
      isActive: isActive,
      fftSize: fftSize,
      colorMapName: colorMap,
      dbFloor: dbFloor,
      dbCeiling: dbCeiling,
      maxColumns: maxColumns,
      showFrequencyAxis: false,
      showTimeAxis: false,
      maxDisplayFrequency: maxFreq,
      logAmplitude: logAmplitude,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Summary Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SurveySummaryTab extends StatelessWidget {
  const _SurveySummaryTab({required this.session});

  final LiveSession? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (session == null) {
      return Center(
        child: Text(
          l10n.surveyStarting,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      );
    }

    final detections = session!.detections;
    final speciesCounts = <String, _SpeciesSummary>{};
    for (final d in detections) {
      final existing = speciesCounts[d.scientificName];
      if (existing == null) {
        speciesCounts[d.scientificName] = _SpeciesSummary(
          scientificName: d.scientificName,
          commonName: d.commonName,
          count: 1,
          bestConfidence: d.confidence,
        );
      } else {
        existing.count++;
        if (d.confidence > existing.bestConfidence) {
          existing.bestConfidence = d.confidence;
        }
      }
    }

    final sorted = speciesCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final elapsed = DateTime.now().difference(session!.startTime);
    final rate = elapsed.inSeconds > 0
        ? (detections.length / (elapsed.inMinutes.clamp(1, 999999)))
            .toStringAsFixed(1)
        : '0';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Quick stats row.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SummaryChip(
              label: l10n.surveyTabSummarySpecies,
              value: '${speciesCounts.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryDetections,
              value: '${detections.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryRate,
              value: '$rate/min',
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Species list.
        for (final sp in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${sp.count}×',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sp.commonName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(sp.bestConfidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sp.bestConfidence >= 0.7
                        ? Colors.green
                        : sp.bestConfidence >= 0.4
                            ? Colors.amber
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpeciesSummary {
  _SpeciesSummary({
    required this.scientificName,
    required this.commonName,
    required this.count,
    required this.bestConfidence,
  });

  final String scientificName;
  final String commonName;
  int count;
  double bestConfidence;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }
}

/// Extract the last 10 detections (newest first) for display.
List<DetectionRecord> _recentDetections(LiveSession? session) {
  final all = session?.detections ?? [];
  if (all.length > 10) {
    return all.sublist(all.length - 10).reversed.toList();
  }
  return all.reversed.toList();
}
