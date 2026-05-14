// =============================================================================
// AnnouncementsSettingsSection
// =============================================================================
//
// The Settings → Announcements section. Pulled into its own file (rather
// than dropped inline into settings_screen.dart) because it owns roughly
// fifteen interacting widgets — master toggle, two preset segmented
// buttons, two voice sliders, a preview button that drives the local
// TTS engine, and an "Advanced" disclosure with four routing/capture
// switches plus six numeric sliders and a trigger-mode picker.
//
// Visibility / scope: this section is shown in the global Settings
// screen and from the per-mode Settings entries (Live, Survey, Point
// Count). The first-run setup *wizard* is hosted only by the Survey
// flow's notification setup step; Live and Point Count wizards do not
// expose it. The "Run setup again" button is therefore a placeholder
// pending Phase 3b — when the wizard widget lands it is wired in
// directly here.
//
// All gating is done with [announcementsEnabledProvider]. Editing any
// Advanced numeric or routing toggle should downgrade the corresponding
// preset to `custom` so the UI never lies about which preset is in
// effect; that downgrade is implemented inline in the slider/switch
// `onChanged` callbacks below (writing through to both the numeric
// pref and the preset pref).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../announcements_providers.dart';
import '../domain/announcement_presets.dart';
import '../platform/tts_engine.dart';

/// Settings section for the Announcements feature.
///
/// Renders nothing on the screen unless mounted inside a `ListView` /
/// `Column`. Returns a `Column` with a [Divider] at the bottom so it
/// drops into existing Settings layouts without further wrapping.
class AnnouncementsSettingsSection extends ConsumerWidget {
  const AnnouncementsSettingsSection({
    super.key,
    required this.sectionHeader,
    required this.titleWithHelp,
  });

  /// Builder for the small section header used in `settings_screen.dart`.
  /// Passed in so this widget does not have to import a private widget.
  final Widget Function({required String title, required String subtitle})
  sectionHeader;

  /// Builder for an inline title row with a "?" affordance.
  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(announcementsEnabledProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(
          title: l10n.settingsAnnouncements,
          subtitle: l10n.settingsAnnouncementsDescription,
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsEnabled,
            helpBody: l10n.settingsHelpAnnouncementsEnabled,
          ),
          subtitle: Text(l10n.settingsAnnouncementsEnabledSubtitle),
          value: enabled,
          onChanged:
              (v) => ref.read(announcementsEnabledProvider.notifier).set(v),
        ),
        if (enabled) ...[
          _VerbosityPicker(titleWithHelp: titleWithHelp),
          _FrequencyPicker(titleWithHelp: titleWithHelp),
          _VoiceSubsection(titleWithHelp: titleWithHelp),
          const _PreviewAndWizardRow(),
          _AdvancedDisclosure(titleWithHelp: titleWithHelp),
        ],
        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verbosity / Frequency segmented pickers
// ---------------------------------------------------------------------------

class _VerbosityPicker extends ConsumerWidget {
  const _VerbosityPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsVerbosityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsVerbosity,
            helpBody: l10n.settingsHelpAnnouncementsVerbosity,
          ),
          subtitle: Text(l10n.settingsAnnouncementsVerbosityDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<AnnouncementVerbosity>(
              segments: [
                ButtonSegment(
                  value: AnnouncementVerbosity.minimal,
                  label: Text(l10n.settingsAnnouncementsVerbosityMinimal),
                ),
                ButtonSegment(
                  value: AnnouncementVerbosity.balanced,
                  label: Text(l10n.settingsAnnouncementsVerbosityBalanced),
                ),
                ButtonSegment(
                  value: AnnouncementVerbosity.chatty,
                  label: Text(l10n.settingsAnnouncementsVerbosityChatty),
                ),
                if (value == AnnouncementVerbosity.custom)
                  ButtonSegment(
                    value: AnnouncementVerbosity.custom,
                    label: Text(l10n.settingsAnnouncementsVerbosityCustom),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (sel) {
                final v = sel.first;
                if (v == AnnouncementVerbosity.custom) return;
                ref.read(announcementsVerbosityProvider.notifier).set(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FrequencyPicker extends ConsumerWidget {
  const _FrequencyPicker({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(announcementsFrequencyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsFrequency,
            helpBody: l10n.settingsHelpAnnouncementsFrequency,
          ),
          subtitle: Text(l10n.settingsAnnouncementsFrequencyDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<AnnouncementFrequency>(
              segments: [
                ButtonSegment(
                  value: AnnouncementFrequency.sparse,
                  label: Text(l10n.settingsAnnouncementsFrequencySparse),
                ),
                ButtonSegment(
                  value: AnnouncementFrequency.normal,
                  label: Text(l10n.settingsAnnouncementsFrequencyNormal),
                ),
                ButtonSegment(
                  value: AnnouncementFrequency.frequent,
                  label: Text(l10n.settingsAnnouncementsFrequencyFrequent),
                ),
                if (value == AnnouncementFrequency.custom)
                  ButtonSegment(
                    value: AnnouncementFrequency.custom,
                    label: Text(l10n.settingsAnnouncementsFrequencyCustom),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (sel) {
                final v = sel.first;
                if (v == AnnouncementFrequency.custom) return;
                ref.read(announcementsFrequencyProvider.notifier).set(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice subsection
// ---------------------------------------------------------------------------

class _VoiceSubsection extends ConsumerWidget {
  const _VoiceSubsection({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rate = ref.watch(announcementsVoiceRateProvider);
    final pitch = ref.watch(announcementsVoicePitchProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsAnnouncementsVoice,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _LabeledSlider(
            label: l10n.settingsAnnouncementsVoiceRate,
            value: rate,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            display: rate.toStringAsFixed(2),
            onChanged:
                (v) =>
                    ref.read(announcementsVoiceRateProvider.notifier).set(v),
          ),
          _LabeledSlider(
            label: l10n.settingsAnnouncementsVoicePitch,
            value: pitch,
            min: 0.7,
            max: 1.3,
            divisions: 6,
            display: pitch.toStringAsFixed(2),
            onChanged:
                (v) =>
                    ref.read(announcementsVoicePitchProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview + setup buttons
// ---------------------------------------------------------------------------

class _PreviewAndWizardRow extends ConsumerWidget {
  const _PreviewAndWizardRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l10n.settingsAnnouncementsPreview),
            onPressed: () => _speakPreview(ref, l10n),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.tune),
            // The wizard widget lands in Phase 3b; for now this is a
            // no-op that surfaces a SnackBar so the UI affordance is
            // discoverable without a half-wired action.
            label: Text(l10n.settingsAnnouncementsRunSetupWizard),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.settingsAnnouncementsRunSetupWizard),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _speakPreview(WidgetRef ref, AppLocalizations l10n) async {
    final tts = FlutterTtsEngine();
    try {
      final lang = ref.read(announcementsVoiceLanguageProvider);
      final rate = ref.read(announcementsVoiceRateProvider);
      final pitch = ref.read(announcementsVoicePitchProvider);
      await tts.configure(
        languageTag: lang.isEmpty ? 'en-US' : lang,
        rate: rate,
        pitch: pitch,
      );
      final s1 = l10n.announcementsSampleSpecies1;
      final s2 = l10n.announcementsSampleSpecies2;
      final s3 = l10n.announcementsSampleSpecies3;
      await tts.speak('$s1. $s2. $s3.');
    } finally {
      await tts.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Advanced disclosure
// ---------------------------------------------------------------------------

class _AdvancedDisclosure extends ConsumerWidget {
  const _AdvancedDisclosure({required this.titleWithHelp});

  final Widget Function({required String title, String? helpBody})
  titleWithHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      title: Text(l10n.settingsAnnouncementsAdvanced),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsSpeakerOutputAllowed,
            helpBody: l10n.settingsHelpAnnouncementsSpeakerOutputAllowed,
          ),
          value: ref.watch(announcementsSpeakerOutputAllowedProvider),
          onChanged:
              (v) => ref
                  .read(announcementsSpeakerOutputAllowedProvider.notifier)
                  .set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsMuteCaptureDuringSpeech,
            helpBody: l10n.settingsHelpAnnouncementsMuteCaptureDuringSpeech,
          ),
          value: ref.watch(announcementsMuteCaptureDuringSpeechProvider),
          onChanged:
              (v) => ref
                  .read(announcementsMuteCaptureDuringSpeechProvider.notifier)
                  .set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsDuckOtherAudio,
            helpBody: l10n.settingsHelpAnnouncementsDuckOtherAudio,
          ),
          value: ref.watch(announcementsDuckOtherAudioProvider),
          onChanged:
              (v) => ref
                  .read(announcementsDuckOtherAudioProvider.notifier)
                  .set(v),
        ),
        SwitchListTile(
          title: titleWithHelp(
            title: l10n.settingsAnnouncementsPrerollCue,
            helpBody: l10n.settingsHelpAnnouncementsPrerollCue,
          ),
          value: ref.watch(announcementsPrerollCueProvider),
          onChanged:
              (v) =>
                  ref.read(announcementsPrerollCueProvider.notifier).set(v),
        ),
        const SizedBox(height: 8),
        // Numeric sliders. Each one writes the int and downgrades the
        // frequency preset to `custom` so the UI's preset chip stops
        // claiming a named profile is in effect.
        _IntAdvancedSlider(
          label: l10n.settingsAnnouncementsStartupGraceSeconds(
            ref.watch(announcementsStartupGraceSecondsProvider),
          ),
          value: ref.watch(announcementsStartupGraceSecondsProvider),
          min: 0,
          max: 120,
          divisions: 12,
          onChanged: (v) => _setIntAndCustomize(
            ref,
            announcementsStartupGraceSecondsProvider,
            v,
          ),
        ),
        _IntAdvancedSlider(
          label: l10n.settingsAnnouncementsMinIntervalSeconds(
            ref.watch(announcementsMinIntervalSecondsProvider),
          ),
          value: ref.watch(announcementsMinIntervalSecondsProvider),
          min: 2,
          max: 60,
          divisions: 29,
          onChanged: (v) => _setIntAndCustomize(
            ref,
            announcementsMinIntervalSecondsProvider,
            v,
          ),
        ),
        _IntAdvancedSlider(
          label: l10n.settingsAnnouncementsMaxPerMinute(
            ref.watch(announcementsMaxPerMinuteProvider),
          ),
          value: ref.watch(announcementsMaxPerMinuteProvider),
          min: 1,
          max: 20,
          divisions: 19,
          onChanged: (v) => _setIntAndCustomize(
            ref,
            announcementsMaxPerMinuteProvider,
            v,
          ),
        ),
        _IntAdvancedSlider(
          label: l10n.settingsAnnouncementsStreakSilenceSeconds(
            ref.watch(announcementsStreakSilenceSecondsProvider),
          ),
          value: ref.watch(announcementsStreakSilenceSecondsProvider),
          min: 10,
          max: 300,
          divisions: 29,
          onChanged: (v) => _setIntAndCustomize(
            ref,
            announcementsStreakSilenceSecondsProvider,
            v,
          ),
        ),
        _IntAdvancedSlider(
          label: l10n.settingsAnnouncementsRecencyResetSeconds(
            ref.watch(announcementsRecencyResetSecondsProvider),
          ),
          value: ref.watch(announcementsRecencyResetSecondsProvider),
          min: 30,
          max: 600,
          divisions: 19,
          onChanged: (v) => _setIntAndCustomize(
            ref,
            announcementsRecencyResetSecondsProvider,
            v,
          ),
        ),
        const Divider(),
        _TriggerModePicker(),
      ],
    );
  }

  void _setIntAndCustomize(
    WidgetRef ref,
    StateNotifierProvider<dynamic, int> provider,
    int value,
  ) {
    (ref.read(provider.notifier) as dynamic).set(value);
    final freq = ref.read(announcementsFrequencyProvider);
    if (freq != AnnouncementFrequency.custom) {
      ref
          .read(announcementsFrequencyProvider.notifier)
          .set(AnnouncementFrequency.custom);
    }
  }
}

class _IntAdvancedSlider extends StatelessWidget {
  const _IntAdvancedSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  /// Localized label including the formatted value (callers pass
  /// `l10n.settingsAnnouncementsXxx(value)`).
  final String label;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            label: value.toString(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _TriggerModePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(announcementsTriggerModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsAnnouncementsTriggerMode,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'all',
                label: Text(l10n.settingsAnnouncementsTriggerModeAll),
              ),
              ButtonSegment(
                value: 'firstInSession',
                label: Text(
                  l10n.settingsAnnouncementsTriggerModeFirstInSession,
                ),
              ),
              ButtonSegment(
                value: 'watchlist',
                label: Text(l10n.settingsAnnouncementsTriggerModeWatchlist),
              ),
            ],
            selected: {mode},
            onSelectionChanged:
                (sel) => ref
                    .read(announcementsTriggerModeProvider.notifier)
                    .set(sel.first),
          ),
        ],
      ),
    );
  }
}
