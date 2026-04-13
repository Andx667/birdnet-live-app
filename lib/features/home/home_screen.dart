import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../history/session_library_screen.dart';
import '../live/live_screen.dart';
import '../file_analysis/file_analysis_screen.dart';
import '../point_count/point_count_setup_screen.dart';
import '../settings/settings_screen.dart';
import '../survey/survey_setup_screen.dart';
import 'help_screen.dart';

// =============================================================================
// Home Screen — Main Menu
// =============================================================================
//
// Clean, full-screen landing with:
//   • App logo + title
//   • 4 mode cards in a 2×2 grid
//   • Settings & About in the footer
//
// Only "Live" mode is active; the other three show a "Coming Soon" badge.
// Tapping Live pushes a full-screen [LiveScreen] for maximum real estate.
// =============================================================================

/// Main menu screen — entry point after onboarding.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Logo + Title ─────────────────────────────────
              _LogoHeader(l10n: l10n, theme: theme),

              const Spacer(),

              // ── Mode Grid ────────────────────────────────────
              _ModeGrid(l10n: l10n, theme: theme),

              const Spacer(),

              // ── Footer ───────────────────────────────────────
              _Footer(l10n: l10n, theme: theme),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Header
// ─────────────────────────────────────────────────────────────────────────────

class _LogoHeader extends ConsumerWidget {
  const _LogoHeader({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    return Column(
      children: [
        // Circular logo with subtle glow.
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(60),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/app-icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.appTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.homeSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
        const SizedBox(height: 4),
        packageInfo.when(
          data: (info) => Text(
            'v${info.version}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Grid — 2×2 cards
// ─────────────────────────────────────────────────────────────────────────────

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.0,
        children: [
          _ModeCard(
            icon: Icons.mic_rounded,
            label: l10n.liveMode,
            description: l10n.liveModeDescription,
            color: theme.colorScheme.primary,
            onTap: () => _openLive(context),
          ),
          _ModeCard(
            icon: Icons.location_on_rounded,
            label: l10n.pointCountMode,
            description: l10n.pointCountModeDescription,
            color: theme.colorScheme.secondary,
            onTap: () => _openPointCount(context),
          ),
          _ModeCard(
            icon: Icons.route_rounded,
            label: l10n.surveyMode,
            description: l10n.surveyModeDescription,
            color: theme.colorScheme.tertiary,
            onTap: () => _openSurvey(context),
          ),
          _ModeCard(
            icon: Icons.audio_file_rounded,
            label: l10n.fileAnalysisMode,
            description: l10n.fileAnalysisModeDescription,
            color: theme.colorScheme.secondary,
            onTap: () => _openFileAnalysis(context),
          ),
        ],
      ),
    );
  }

  void _openLive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LiveScreen(),
      ),
    );
  }

  void _openPointCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PointCountSetupScreen(),
      ),
    );
  }

  void _openSurvey(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SurveySetupScreen(),
      ),
    );
  }

  void _openFileAnalysis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FileAnalysisScreen(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual mode card
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon in a tinted circle.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 50 : 30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(100),
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — 5 items in two rows (3 + 2)
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.onSurface.withAlpha(153);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row 1: Settings, Explore, Sessions ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterButton(
              icon: Icons.tune_rounded,
              label: l10n.settings,
              color: color,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _FooterButton(
              icon: Icons.search_rounded,
              label: l10n.exploreMode,
              color: color,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _FooterButton(
              icon: Icons.library_music_outlined,
              label: l10n.sessionLibraryTitle,
              color: color,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const SessionLibraryScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ── Row 2: Help, About ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterButton(
              icon: Icons.help_outline_rounded,
              label: l10n.helpTitle,
              color: color,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _FooterButton(
              icon: Icons.info_outline,
              label: l10n.about,
              color: color,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
