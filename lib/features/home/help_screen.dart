// =============================================================================
// Help Screen — Comprehensive app help clustered by mode
// =============================================================================
//
// A dedicated help screen accessible from the home screen footer. Explains
// each app mode and general tips for best results, organized into expandable
// sections.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/content_width_constraint.dart';

/// Comprehensive help screen with mode-by-mode explanations.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ContentWidthConstraint(
          child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Introduction ────────────────────────────────────
          Text(
            l10n.helpIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(200),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.helpControlsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ControlCard(
            icon: Icons.tune_rounded,
            title: l10n.settings,
            body: l10n.helpControlSettings,
          ),
          _ControlCard(
            icon: Icons.search_rounded,
            title: l10n.exploreMode,
            body: l10n.helpControlExplore,
          ),
          _ControlCard(
            icon: Icons.library_music_outlined,
            title: l10n.sessionLibraryTitle,
            body: l10n.helpControlSessions,
          ),
          _ControlCard(
            icon: Icons.help_outline_rounded,
            title: l10n.helpTitle,
            body: l10n.helpControlHelp,
          ),
          _ControlCard(
            icon: Icons.info_outline,
            title: l10n.about,
            body: l10n.helpControlAbout,
          ),
          const SizedBox(height: 20),

          // ── Mode sections ───────────────────────────────────
          _HelpSection(
            icon: Icons.mic_rounded,
            color: theme.colorScheme.primary,
            title: l10n.helpLiveTitle,
            body: l10n.helpLiveBody,
          ),
          _HelpSection(
            icon: Icons.location_on_rounded,
            color: theme.colorScheme.secondary,
            title: l10n.helpPointCountTitle,
            body: l10n.helpPointCountBody,
          ),
          _HelpSection(
            icon: Icons.route_rounded,
            color: theme.colorScheme.tertiary,
            title: l10n.helpSurveyTitle,
            body: l10n.helpSurveyBody,
          ),
          _HelpSection(
            icon: Icons.audio_file_rounded,
            color: theme.colorScheme.secondary,
            title: l10n.helpFileAnalysisTitle,
            body: l10n.helpFileAnalysisBody,
          ),
          _HelpSection(
            icon: Icons.search_rounded,
            color: theme.colorScheme.primary,
            title: l10n.helpExploreTitle,
            body: l10n.helpExploreBody,
          ),
          _HelpSection(
            icon: Icons.library_music_outlined,
            color: theme.colorScheme.tertiary,
            title: l10n.helpSessionsTitle,
            body: l10n.helpSessionsBody,
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // ── Tips ────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.helpTipsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TipRow(text: l10n.helpTipQuiet),
          _TipRow(text: l10n.helpTipMic),
          _TipRow(text: l10n.helpTipBasics),
          _TipRow(text: l10n.helpTipThreshold),
          _TipRow(text: l10n.helpTipGeoFilter),
          _TipRow(text: l10n.helpTipGuide),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.aboutUserGuide,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.helpTipGuide,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _launchUserGuide(),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.aboutUserGuide),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help Section — Expandable card for a single mode
// ─────────────────────────────────────────────────────────────────────────────

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(200),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                      height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Tip Row — Bullet-style tip
// ─────────────────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.primary.withAlpha(180),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchUserGuide() async {
  final uri = Uri.parse('${AppConstants.docsUrl}/user/');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
