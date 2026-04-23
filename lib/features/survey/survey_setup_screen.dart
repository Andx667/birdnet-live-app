// =============================================================================
// Survey Setup Screen — Wizard for configuring a long-running survey
// =============================================================================
//
// A three-step setup wizard:
//
//   1. **Survey Details** — Name, location (GPS/Manual/Skip), transect ID,
//      observer name.
//   2. **Parameters** — Inference rate, GPS interval, recording mode,
//      detection sampling, max duration, auto-stop battery.
//   3. **Ready** — Summary card with warnings and "Start Survey" button.
//
// After pressing Start, navigates to [SurveyLiveScreen].
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/map_picker_screen.dart';
import '../../shared/widgets/wizard_scaffold.dart';
import '../audio/audio_providers.dart';
import '../explore/explore_providers.dart';
import '../settings/settings_screen.dart';
import 'survey_live_screen.dart';
import 'survey_notification.dart';

/// Location choice for survey setup.
enum _LocationChoice { gps, manual, skip }

/// Setup wizard for a survey transect.
class SurveySetupScreen extends ConsumerStatefulWidget {
  const SurveySetupScreen({super.key});

  @override
  ConsumerState<SurveySetupScreen> createState() => _SurveySetupScreenState();
}

class _SurveySetupScreenState extends ConsumerState<SurveySetupScreen>
    with WidgetsBindingObserver {
  int _step = 0;
  static const _totalSteps = 4;

  // ── Step 1: Survey Details ────────────────────────────────────────────
  _LocationChoice _locationChoice = _LocationChoice.gps;
  double? _latitude;
  double? _longitude;
  bool _gpsFetching = false;
  bool _hasBackgroundGps = false;
  bool _awaitingSettingsReturn = false;
  final _nameController = TextEditingController();
  final _transectController = TextEditingController();
  final _observerController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observerController.text = ref.read(surveyLastObserverProvider);
    _transectController.text = ref.read(surveyLastTransectIdProvider);
    _fetchGpsLocation();
    _checkBackgroundPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _transectController.dispose();
    _observerController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettingsReturn) {
      _awaitingSettingsReturn = false;
      _checkBackgroundPermission();
    }
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _gpsFetching = true);
    try {
      final location = await ref.read(currentLocationProvider.future);
      if (location != null && mounted) {
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _gpsFetching = false;
        });
      } else {
        if (mounted) setState(() => _gpsFetching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _gpsFetching = false);
    }
  }

  Future<void> _checkBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (mounted) {
      setState(() {
        _hasBackgroundGps = permission == LocationPermission.always;
      });
    }
  }

  Future<void> _requestBackgroundPermission() async {
    var permission = await Geolocator.checkPermission();

    // First ensure we have at least whileInUse.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _awaitingSettingsReturn = true;
      await Geolocator.openAppSettings();
      return;
    }

    // Android 11+ requires the user to grant "Allow all the time" in app
    // settings — requestPermission() can only escalate to whileInUse.
    if (permission != LocationPermission.always) {
      _awaitingSettingsReturn = true;
      await Geolocator.openAppSettings();
      return;
    }

    if (mounted) {
      setState(() => _hasBackgroundGps = true);
    }
  }

  void _next() {
    if (_step == 0 && _locationChoice == _LocationChoice.manual) {
      _latitude = double.tryParse(_latController.text)?.clamp(-90, 90);
      _longitude = double.tryParse(_lonController.text)?.clamp(-180, 180);
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _start() async {
    // Request notification permission before navigating, so the OS dialog
    // doesn't interrupt the foreground-service start on the live screen.
    await SurveyNotificationService.ensurePermission();

    if (!mounted) return;

    // Persist observer and transect for next time.
    final observer = _observerController.text.trim();
    final transect = _transectController.text.trim();
    if (observer.isNotEmpty) {
      ref.read(surveyLastObserverProvider.notifier).set(observer);
    }
    if (transect.isNotEmpty) {
      ref.read(surveyLastTransectIdProvider.notifier).set(transect);
    }

    final lat = _locationChoice == _LocationChoice.skip ? null : _latitude;
    final lon = _locationChoice == _LocationChoice.skip ? null : _longitude;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SurveyLiveScreen(
          customName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          transectId: transect.isEmpty ? null : transect,
          observerName: observer.isEmpty ? null : observer,
          startLatitude: lat,
          startLongitude: lon,
          backgroundGps: _hasBackgroundGps,
        ),
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppHelpBottomSheet(
        title: l10n.surveySetupHelpTitle,
        sections: [
          AppHelpSection(
            icon: Icons.route_rounded,
            body: l10n.surveySetupHelpSteps,
          ),
          AppHelpSection(
            icon: Icons.location_on_rounded,
            body: l10n.surveySetupHelpLocation,
          ),
          AppHelpSection(
            icon: Icons.play_arrow_rounded,
            body: l10n.surveySetupHelpStart,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLastStep = _step == _totalSteps - 1;

    return WizardScaffold(
      title: l10n.surveySetupTitle,
      step: _step,
      totalSteps: _totalSteps,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          onPressed: _showHelp,
          tooltip: l10n.surveySetupHelpTitle,
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
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
      onBack: _back,
      onNext: isLastStep ? _start : _next,
      backLabel: _step == 0 ? l10n.cancel : l10n.surveyBack,
      nextLabel: isLastStep ? l10n.surveyStart : l10n.surveyNext,
      nextIcon: isLastStep ? Icons.play_arrow_rounded : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          0 => _DetailsStep(
              key: const ValueKey(0),
              nameController: _nameController,
              transectController: _transectController,
              observerController: _observerController,
              locationChoice: _locationChoice,
              latitude: _latitude,
              longitude: _longitude,
              gpsFetching: _gpsFetching,
              hasBackgroundGps: _hasBackgroundGps,
              latController: _latController,
              lonController: _lonController,
              onLocationChoiceChanged: (c) {
                setState(() => _locationChoice = c);
                if (c == _LocationChoice.gps) _fetchGpsLocation();
              },
              onFetchGps: _fetchGpsLocation,
              onRequestBackgroundGps: _requestBackgroundPermission,
              onMapPick: (lat, lon) {
                setState(() {
                  _latitude = lat;
                  _longitude = lon;
                });
              },
            ),
          1 => const _ParametersStep(key: ValueKey(1)),
          2 => const _FieldTipsStep(key: ValueKey(2)),
          _ => _ReadyStep(
              key: const ValueKey(3),
              hasBackgroundGps: _hasBackgroundGps,
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Survey Details
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    super.key,
    required this.nameController,
    required this.transectController,
    required this.observerController,
    required this.locationChoice,
    required this.latitude,
    required this.longitude,
    required this.gpsFetching,
    required this.hasBackgroundGps,
    required this.latController,
    required this.lonController,
    required this.onLocationChoiceChanged,
    required this.onFetchGps,
    required this.onRequestBackgroundGps,
    required this.onMapPick,
  });

  final TextEditingController nameController;
  final TextEditingController transectController;
  final TextEditingController observerController;
  final _LocationChoice locationChoice;
  final double? latitude;
  final double? longitude;
  final bool gpsFetching;
  final bool hasBackgroundGps;
  final TextEditingController latController;
  final TextEditingController lonController;
  final ValueChanged<_LocationChoice> onLocationChoiceChanged;
  final VoidCallback onFetchGps;
  final VoidCallback onRequestBackgroundGps;
  final void Function(double lat, double lon) onMapPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Survey name
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.surveyName,
            hintText: l10n.surveyNameHint,
            prefixIcon: const Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 16),

        // Transect ID
        TextField(
          controller: transectController,
          decoration: InputDecoration(
            labelText: l10n.surveyTransectId,
            hintText: l10n.surveyTransectIdHint,
            prefixIcon: const Icon(Icons.route_rounded),
          ),
        ),
        const SizedBox(height: 16),

        // Observer name
        TextField(
          controller: observerController,
          decoration: InputDecoration(
            labelText: l10n.surveyObserverName,
            hintText: l10n.surveyObserverNameHint,
            prefixIcon: const Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 24),

        // Location section
        Text(l10n.surveyLocation, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<_LocationChoice>(
          segments: [
            ButtonSegment(
              value: _LocationChoice.gps,
              label: Text(l10n.surveyLocationGps),
            ),
            ButtonSegment(
              value: _LocationChoice.manual,
              label: Text(l10n.surveyLocationManual),
            ),
            ButtonSegment(
              value: _LocationChoice.skip,
              label: Text(l10n.surveyLocationSkip),
            ),
          ],
          selected: {locationChoice},
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            onLocationChoiceChanged(s.first);
          },
        ),
        const SizedBox(height: 12),

        // GPS result or manual input
        if (locationChoice == _LocationChoice.gps) ...[
          if (gpsFetching)
            const Center(child: CircularProgressIndicator())
          else if (latitude != null && longitude != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  '${latitude!.toStringAsFixed(4)}, '
                  '${longitude!.toStringAsFixed(4)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_off),
                title: Text(l10n.surveyLocationUnavailable),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.pointCountLocationRefresh,
                  onPressed: onFetchGps,
                ),
              ),
            ),
          if (!hasBackgroundGps) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.tertiaryContainer,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRequestBackgroundGps,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.surveyManualGpsWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.onTertiaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],

        if (locationChoice == _LocationChoice.manual) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: l10n.surveyLatitude,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: l10n.surveyLongitude,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute<LatLng>(
                  builder: (_) => const MapPickerScreen(),
                ),
              );
              if (result != null) {
                onMapPick(result.latitude, result.longitude);
              }
            },
            icon: const Icon(Icons.map),
            label: Text(l10n.surveyPickOnMap),
          ),
        ],

        if (locationChoice == _LocationChoice.skip)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.surveyLocationSkipNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Parameters
// ─────────────────────────────────────────────────────────────────────────────

class _ParametersStep extends ConsumerWidget {
  const _ParametersStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final inferenceRate = ref.watch(surveyInferenceRateProvider);
    final confidenceThreshold = ref.watch(confidenceThresholdProvider);
    final gpsInterval = ref.watch(surveyGpsIntervalProvider);
    final maxDuration = ref.watch(surveyMaxDurationProvider);
    final recordingMode = ref.watch(surveyRecordingModeProvider);
    final clipContext = ref.watch(surveyClipContextProvider);
    final sampling = ref.watch(surveyDetectionSamplingProvider);
    final topN = ref.watch(surveyTopNPerSpeciesProvider);
    final devicesAsync = ref.watch(inputDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(l10n.surveyParametersTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 16),

        // Microphone input
        devicesAsync.when(
          loading: () => ListTile(
            leading: const Icon(Icons.mic_rounded),
            title: Text(l10n.surveyMicrophone),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => ListTile(
            leading: const Icon(Icons.mic_rounded),
            title: Text(l10n.surveyMicrophone),
            trailing: const Text('—'),
          ),
          data: (devices) {
            final label = selectedDevice == null
                ? l10n.surveyMicSystemDefault
                : devices
                        .where((d) => d.id == selectedDevice)
                        .map((d) => d.label.isEmpty ? d.id : d.label)
                        .firstOrNull ??
                    selectedDevice;
            return ListTile(
              leading: const Icon(Icons.mic_rounded),
              title: Text(l10n.surveyMicrophone),
              trailing: Text(label, style: theme.textTheme.bodySmall),
              onTap: () => _showDevicePicker(
                  context, ref, l10n, devices, selectedDevice),
            );
          },
        ),

        const Divider(height: 32),

        // Inference rate
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: Text(l10n.surveyInferenceRate),
          subtitle: Text('${inferenceRate.toStringAsFixed(2)} Hz'),
        ),
        Slider(
          value: inferenceRate,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: '${inferenceRate.toStringAsFixed(2)} Hz',
          onChanged: (v) =>
              ref.read(surveyInferenceRateProvider.notifier).set(v),
        ),

        // Confidence threshold
        ListTile(
          leading: const Icon(Icons.verified_rounded),
          title: Text(l10n.settingsConfidenceThreshold),
          subtitle: Text('$confidenceThreshold %'),
        ),
        Slider(
          value: confidenceThreshold.toDouble(),
          min: 5,
          max: 90,
          divisions: 17,
          label: '$confidenceThreshold %',
          onChanged: (v) =>
              ref.read(confidenceThresholdProvider.notifier).set(v.round()),
        ),

        // GPS interval
        ListTile(
          leading: const Icon(Icons.my_location),
          title: Text(l10n.surveyGpsInterval),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5s')),
              ButtonSegment(value: 10, label: Text('10s')),
              ButtonSegment(value: 30, label: Text('30s')),
              ButtonSegment(value: 60, label: Text('60s')),
            ],
            selected: {gpsInterval},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyGpsIntervalProvider.notifier).set(s.first);
            },
          ),
        ),

        // Max duration
        ListTile(
          leading: const Icon(Icons.timer_rounded),
          title: Text(l10n.surveyMaxDuration),
          subtitle: Text('$maxDuration ${l10n.surveyHours}'),
        ),
        Slider(
          value: maxDuration.toDouble(),
          min: 1,
          max: 24,
          divisions: 23,
          label: '$maxDuration h',
          onChanged: (v) =>
              ref.read(surveyMaxDurationProvider.notifier).set(v.round()),
        ),

        const Divider(height: 32),

        // Recording mode
        ListTile(
          leading: const Icon(Icons.fiber_manual_record_rounded),
          title: Text(l10n.surveyRecordingMode),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'full', label: Text(l10n.surveyRecordingFull)),
              ButtonSegment(
                  value: 'detections',
                  label: Text(l10n.surveyRecordingDetections)),
              ButtonSegment(value: 'off', label: Text(l10n.surveyRecordingOff)),
            ],
            selected: {recordingMode},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyRecordingModeProvider.notifier).set(s.first);
            },
          ),
        ),

        // Clip context (visible only when recording mode = detections)
        if (recordingMode == 'detections') ...[
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.surveyClipContext),
            subtitle: Text(l10n.surveyClipContextDescription),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: clipContext.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: '±${clipContext}s',
              onChanged: (v) =>
                  ref.read(surveyClipContextProvider.notifier).set(v.round()),
            ),
          ),
        ],

        // Detection sampling
        ListTile(
          leading: const Icon(Icons.filter_alt_rounded),
          title: Text(l10n.surveyDetectionSampling),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'all', label: Text(l10n.surveySamplingAll)),
              ButtonSegment(
                  value: 'topN', label: Text(l10n.surveySamplingTopN)),
              ButtonSegment(
                  value: 'smart', label: Text(l10n.surveySamplingSmart)),
            ],
            selected: {sampling},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              ref.read(surveyDetectionSamplingProvider.notifier).set(s.first);
            },
          ),
        ),

        // Top N (visible only when sampling = topN or smart)
        if (sampling != 'all') ...[
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: Text(l10n.surveyTopNPerSpecies),
            subtitle: Text('$topN'),
          ),
          Slider(
            value: topN.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$topN',
            onChanged: (v) =>
                ref.read(surveyTopNPerSpeciesProvider.notifier).set(v.round()),
          ),
        ],
      ],
    );
  }

  void _showDevicePicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<InputDeviceInfo> devices,
    String? selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.surveyMicSelect,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            RadioListTile<String?>(
              title: Text(l10n.surveyMicSystemDefault),
              value: null,
              groupValue: selected,
              onChanged: (v) {
                ref.read(selectedDeviceProvider.notifier).state = v;
                Navigator.of(ctx).pop();
              },
            ),
            ...devices.map(
              (d) => RadioListTile<String?>(
                title: Text(d.label.isEmpty ? d.id : d.label),
                value: d.id,
                groupValue: selected,
                onChanged: (v) {
                  ref.read(selectedDeviceProvider.notifier).state = v;
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Field Tips
// ─────────────────────────────────────────────────────────────────────────────

class _FieldTipsStep extends StatelessWidget {
  const _FieldTipsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final tips = [
      (Icons.directions_walk_rounded, l10n.surveyTipWalkSteady),
      (Icons.air_rounded, l10n.surveyTipWind),
      (Icons.mic_external_on_rounded, l10n.surveyTipMic),
      (Icons.volume_off_rounded, l10n.surveyTipSilence),
      (Icons.wb_twilight_rounded, l10n.surveyTipTime),
      (Icons.repeat_rounded, l10n.surveyTipRepeat),
      (Icons.battery_saver_rounded, l10n.surveyTipBattery),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.surveyFieldTips,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...tips.map((tip) {
          final (icon, text) = tip;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Ready
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep({super.key, required this.hasBackgroundGps});
  final bool hasBackgroundGps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final inferenceRate = ref.watch(surveyInferenceRateProvider);
    final gpsInterval = ref.watch(surveyGpsIntervalProvider);
    final maxDuration = ref.watch(surveyMaxDurationProvider);
    final sampling = ref.watch(surveyDetectionSamplingProvider);
    final recordingMode = ref.watch(surveyRecordingModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Icon(Icons.route_rounded,
              size: 64, color: theme.colorScheme.tertiary),
          const SizedBox(height: 16),
          Text(l10n.surveyReadyTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(Icons.speed_rounded, l10n.surveyInferenceRate,
                      '${inferenceRate.toStringAsFixed(2)} Hz'),
                  _SummaryRow(Icons.my_location, l10n.surveyGpsInterval,
                      '${gpsInterval}s'),
                  _SummaryRow(Icons.timer_rounded, l10n.surveyMaxDuration,
                      '$maxDuration ${l10n.surveyHours}'),
                  _SummaryRow(Icons.filter_alt_rounded,
                      l10n.surveyDetectionSampling, sampling),
                  _SummaryRow(Icons.fiber_manual_record_rounded,
                      l10n.surveyRecordingMode, recordingMode),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Warnings
          if (!hasBackgroundGps)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: theme.colorScheme.onTertiaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.surveyManualGpsReadyWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
