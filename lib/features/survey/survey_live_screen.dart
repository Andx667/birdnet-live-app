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
import 'package:latlong2/latlong.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/theme/score_colors.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
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
import 'alert_throttler.dart';
import 'species_alert_notifier.dart';
import 'survey_alert_coordinator.dart';
import 'survey_alert_engine.dart';
import 'survey_controller.dart';
import 'survey_providers.dart';
import '../history/global_species_history.dart';
import '../inference/custom_species_list.dart';
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
  late final SurveyController _surveyController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    _surveyController = ref.read(surveyControllerProvider);
    _surveyController.onStateChanged = _onControllerStateChanged;
    _surveyController.onAutoStop = _onAutoStop;

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

  /// Construct and attach the [SurveyAlertCoordinator] honoring all
  /// `surveyAlert*` user prefs. Skips entirely when alerts are off.
  Future<void> _maybeBuildAlertCoordinator({
    required SurveyController controller,
  }) async {
    final modeIdx = ref.read(surveyAlertModeProvider);
    final mode = AlertMode.fromPrefValue(modeIdx);
    if (mode == AlertMode.off) {
      await controller.setAlertCoordinator(null);
      return;
    }
    final l10n = AppLocalizations.of(context)!;

    final notifier = ref.read(speciesAlertNotifierProvider);
    final sound = ref.read(surveyAlertSoundProvider);
    final vibrate = ref.read(surveyAlertVibrateProvider);
    final strings = SpeciesAlertStrings(
      channelName: l10n.surveyAlertChannelName,
      channelDescription: l10n.surveyAlertChannelDescription,
      firstInSessionBody: l10n.surveyAlertBodyFirstInSession,
      firstEverBody: l10n.surveyAlertBodyFirstEver,
      // l10n.surveyAlertBodyRare requires a String pct placeholder; the
      // notifier substitutes `{pct}` at delivery time so we pass the raw
      // template through.
      rareBody: l10n.surveyAlertBodyRare('{pct}'),
      watchlistBody: l10n.surveyAlertBodyWatchlist,
      summaryTitle: l10n.surveyAlertSummaryTitle(0).replaceAll('0', '{count}'),
      summaryBody:
          l10n.surveyAlertSummaryBody(0, '{names}').replaceAll('0', '{count}'),
    );
    await notifier.init(strings: strings, sound: sound, vibrate: vibrate);

    final history = ref.read(globalSpeciesHistoryProvider);
    history.load();
    final geoScores = await ref.read(geoScoresProvider.future);

    Set<String>? watchlist;
    final wlName = ref.read(surveyAlertWatchlistNameProvider);
    if (mode == AlertMode.watchlist && wlName.isNotEmpty) {
      try {
        watchlist = await CustomSpeciesList.load(wlName);
      } catch (_) {
        watchlist = const <String>{};
      }
    }

    final coord = SurveyAlertCoordinator(
      mode: mode,
      notifier: notifier,
      notifierStrings: strings,
      globalHistory: history,
      geoScores: geoScores,
      watchlist: watchlist,
      minConfidence: ref.read(surveyAlertMinConfidenceProvider),
      rareThreshold: ref.read(surveyAlertRareThresholdProvider),
      startupGraceSeconds: ref.read(surveyAlertStartupGraceSecondsProvider),
      minIntervalSeconds: ref.read(surveyAlertMinIntervalSecondsProvider),
      maxPerMinute: ref.read(surveyAlertMaxPerMinuteProvider),
      coalesce: ref.read(surveyAlertCoalesceProvider),
      inAppToast: ref.read(surveyAlertInAppToastProvider),
      onDelivered: _onAlertDelivered,
      nameLocalizer: _buildNameLocalizer(),
    );
    await controller.setAlertCoordinator(coord);
  }

  /// Build a closure that maps a scientific name to the user's preferred
  /// localized common name (honoring the species locale and the
  /// "show scientific names" toggle). Reads the taxonomy lazily on each
  /// call so names start translating as soon as the taxonomy service
  /// finishes loading (which can happen *after* survey start).
  String Function(String, String) _buildNameLocalizer() {
    return (sciName, fallback) {
      final showSci = ref.read(showSciNamesProvider);
      if (showSci) return sciName;
      final taxonomy = ref.read(taxonomyServiceProvider).valueOrNull;
      final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
      return taxonomy?.lookup(sciName)?.commonNameForLocale(speciesLocale) ??
          fallback;
    };
  }

  void _onAlertDelivered(AlertCandidate? one, SummaryAlert? summary) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final String text;
    if (one != null) {
      text = one.commonName;
    } else if (summary != null) {
      text = summary.alerts.map((a) => a.commonName).join(', ');
    } else {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startSurvey() async {
    if (_started) return;
    final controller = ref.read(surveyControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final deviceId = ref.read(selectedDeviceProvider);
    // Capture localizations now — the rest of this method awaits multiple
    // futures and we want to wire foreground-notification strings without
    // crossing BuildContext async gaps.
    final l10n = AppLocalizations.of(context)!;

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
    final autoStopBattery = ref.read(surveyAutoStopBatteryProvider);
    final clipContext = ref.read(surveyClipContextProvider);

    final geoScores = await ref.read(geoScoresProvider.future);
    final geoSpeciesNames = await ref.read(geoModelSpeciesNamesProvider.future);

    // Build the species-alert pipeline before starting the controller so
    // the very first detection can fire a notification. If the user
    // chose `off` we skip everything — no plugin init, no history load.
    await _maybeBuildAlertCoordinator(controller: controller);

    // Wire localization helpers used by the foreground notification's
    // recent-detections list (species names + relative timestamps).
    controller.setNameLocalizer(_buildNameLocalizer());
    controller.setNotificationStrings(
      title: l10n.surveyNotificationTitle,
      justNow: l10n.surveyJustNow,
      secondsAgo: (s) => l10n.surveySecondsAgo(s),
      minutesAgo: (m) => l10n.surveyMinutesAgo(m),
      hoursAgo: (h) => l10n.surveyHoursAgo(h),
      stats: (elapsed, det, spp, km) =>
          l10n.surveyNotificationStats(elapsed, det, spp, km),
    );

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
        clipContextSeconds: clipContext,
        transectId: widget.transectId,
        observerName: widget.observerName,
        customName: widget.customName,
        startLatitude: widget.startLatitude,
        startLongitude: widget.startLongitude,
        backgroundGps: widget.backgroundGps,
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
    final confirmed = await confirmDestructive(
      context,
      title: l10n.surveyStopTitle,
      body: l10n.surveyStopMessage,
      confirmLabel: l10n.surveyStopConfirm,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;
    await _finalizeAndReview();
  }

  Future<void> _finalizeAndReview() async {
    if (_finalizing) return;
    _finalizing = true;
    _uiUpdateTimer?.cancel();

    try {
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
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('[SurveyLiveScreen] finalize error: $e\n$st');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.statusError}: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _finalizing = false;
      if (mounted) {
        _uiUpdateTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
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
    if (_surveyController.onStateChanged == _onControllerStateChanged) {
      _surveyController.onStateChanged = null;
    }
    if (_surveyController.onAutoStop == _onAutoStop) {
      _surveyController.onAutoStop = null;
    }
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
          child: _buildBody(
            context,
            theme: theme,
            l10n: l10n,
            isActive: isActive,
            session: session,
            controller: controller,
            ringBuffer: ringBuffer,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required bool isActive,
    required dynamic session,
    required dynamic controller,
    required dynamic ringBuffer,
  }) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = _SurveyStatusBar(
      elapsed: controller.elapsed,
      isActive: isActive,
      alertMode: AlertMode.fromPrefValue(ref.watch(surveyAlertModeProvider)),
      onStop: _confirmStop,
    );
    final tabBar = TabBar(
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
    );
    final tabContent = TabBarView(
      controller: _tabController,
      children: [
        SurveyMapWidget(
          gpsTrack: controller.gpsTracker?.track ?? [],
          detections: session?.detections ?? [],
          initialCenter:
              widget.startLatitude != null && widget.startLongitude != null
                  ? LatLng(widget.startLatitude!, widget.startLongitude!)
                  : null,
        ),
        _SurveySpectrogram(ringBuffer: ringBuffer, isActive: isActive),
        _SurveySummaryTab(session: session),
      ],
    );
    final statsBar = SurveyStatsBar(
      distanceMeters: controller.gpsTracker?.distanceMeters ?? 0,
      detectionCount: session?.detections.length ?? 0,
      speciesCount: session?.uniqueSpeciesCount ?? 0,
      audioLevel: ringBuffer.rmsLevel(),
      peakLevel: ringBuffer.peakLevel(),
    );
    final detectionList = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
    );

    if (isLandscape) {
      return Column(
        children: [
          statusBar,
          Expanded(
            child: Row(
              children: [
                // Left: tabs (map/spectrogram/summary) + stats
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      tabBar,
                      Expanded(child: tabContent),
                      statsBar,
                    ],
                  ),
                ),
                // Right: detection list
                Expanded(flex: 1, child: detectionList),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Portrait: original vertical stack.
    return Column(
      children: [
        statusBar,
        tabBar,
        Expanded(flex: 2, child: tabContent),
        statsBar,
        Expanded(flex: 3, child: detectionList),
        const SizedBox(height: 16),
      ],
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
    required this.alertMode,
    required this.onStop,
  });

  final Duration elapsed;
  final bool isActive;
  final AlertMode alertMode;
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

          // Help button.
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _showSurveyHelp(context),
            tooltip: l10n.surveyLiveHelpTitle,
          ),

          // Alert mode indicator.
          if (alertMode != AlertMode.off)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: l10n.surveyAlertsTitle,
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
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
    final quality = ref.watch(spectrogramQualityProvider);

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
      filterQuality: spectrogramFilterQualityFromString(quality),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Summary Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SurveySummaryTab extends ConsumerWidget {
  const _SurveySummaryTab({required this.session});

  final LiveSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).valueOrNull;
    final showSciNames = ref.watch(showSciNamesProvider);

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
      ..sort((a, b) {
        final cmp = b.count.compareTo(a.count);
        if (cmp != 0) return cmp;
        return b.bestConfidence.compareTo(a.bestConfidence);
      });

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
        for (final (i, sp) in sorted.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taxonomy
                                ?.lookup(sp.scientificName)
                                ?.commonNameForLocale(speciesLocale) ??
                            sp.commonName,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSciNames)
                        Text(
                          sp.scientificName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  '${(sp.bestConfidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: (theme.extension<ScoreColors>() ?? ScoreColors.light)
                        .forScore(sp.bestConfidence),
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

void _showSurveyHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SurveyLiveHelpSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Help Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SurveyLiveHelpSheet extends StatelessWidget {
  const _SurveyLiveHelpSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppHelpBottomSheet(
      title: l10n.surveyLiveHelpTitle,
      sections: [
        AppHelpSection(
          icon: Icons.info_outline,
          body: l10n.surveyLiveHelpOverview,
        ),
        AppHelpSection(
          icon: Icons.help_outline_rounded,
          body: l10n.surveyLiveHelpTopBar,
        ),
        AppHelpSection(
          icon: Icons.map_outlined,
          body: l10n.surveyLiveHelpTabs,
        ),
        AppHelpSection(
          icon: Icons.mic,
          body: l10n.surveyLiveHelpSignal,
        ),
        AppHelpSection(
          icon: MdiIcons.feather,
          body: l10n.surveyLiveHelpDetections,
        ),
      ],
    );
  }
}
