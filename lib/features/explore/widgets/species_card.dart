// =============================================================================
// Species Card — Compact species tile with thumbnail
// =============================================================================
//
// Displays a species entry with:
//   • Bundled asset thumbnail (3:2 aspect ratio, 480x320 WebP)
//   • Common name + optional scientific name (controlled by setting)
//   • Optional geo-score indicator
//   • Center-aligned 48-week mini bar chart with month labels
//
// Used in both the Explore screen and the live detection list.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../inference/geo_model.dart';
import '../../history/global_species_history.dart';
import '../../../shared/providers/settings_providers.dart';
import '../explore_providers.dart';

/// A compact species card with a 3:2 thumbnail.
class SpeciesCard extends ConsumerWidget {
  const SpeciesCard({
    super.key,
    required this.scientificName,
    required this.commonName,
    this.geoScore,
    this.confidence,
    this.weeklyScores,
    this.onTap,
  });

  /// Scientific name — used to generate the thumbnail URL.
  final String scientificName;

  /// Common name to display.
  final String commonName;

  /// Optional geo-model score (0–100) shown as a subtle indicator.
  final double? geoScore;

  /// Optional audio confidence (0–1) shown when used in detections.
  final double? confidence;

  /// Optional 48-week probability array for drawing a mini chart.
  final List<double>? weeklyScores;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showSciNames = ref.watch(showSciNamesProvider);

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            // Stretch so the thumbnail fills the card's full height and the
            // rounded left corners hug the photo.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Thumbnail (3:2, matching the 360×240 bundled photos) ──
              //
              // Width is 120 so that the AspectRatio's intrinsic height
              // (120 / 1.5 = 80) matches the text column's natural height
              // closely. With Row(stretch) + IntrinsicHeight that gives a
              // 120×80 box whose ratio matches the source image, so
              // BoxFit.cover fills it exactly with no edge cropping.
              SizedBox(
                width: 120,
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SpeciesImage(scientificName: scientificName),
                      if (ref
                          .watch(globalSpeciesHistoryProvider)
                          .contains(scientificName))
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: _DetectedBadge(),
                        ),
                    ],
                  ),
                ),
              ),
              // ── Names and Details ──
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row 1: Common name & Score indicator
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              commonName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (confidence != null || geoScore != null) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: confidence != null
                                  ? AppLocalizations.of(context)!
                                      .a11yConfidencePercent(
                                          (confidence! * 100).round())
                                  : AppLocalizations.of(context)!
                                      .a11yLikelihoodPercent(geoScore!.round()),
                              excludeSemantics: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: probabilityCategoryColor(geoScore ??
                                          (confidence != null
                                              ? confidence! * 100
                                              : 0))
                                      .withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: probabilityCategoryColor(geoScore ??
                                            (confidence != null
                                                ? confidence! * 100
                                                : 0))
                                        .withAlpha(120),
                                  ),
                                ),
                                child: Text(
                                  confidence != null
                                      ? '${(confidence! * 100).toStringAsFixed(0)}%'
                                      : '${geoScore!.toStringAsFixed(0)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: probabilityCategoryColor(geoScore ??
                                        (confidence != null
                                            ? confidence! * 100
                                            : 0)),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Row 2: Scientific name (optional)
                      if (showSciNames)
                        Text(
                          scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                            fontStyle: FontStyle.italic,
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      // Row 3: Bar chart
                      if (weeklyScores != null)
                        _MiniChart(weeklyScores: weeklyScores!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Species thumbnail loaded from bundled assets.
class _SpeciesImage extends ConsumerWidget {
  const _SpeciesImage({required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final path = taxonomyAsync.valueOrNull?.assetImagePath(scientificName) ??
        'assets/images/dummy_species.png';

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/dummy_species.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Center-aligned 48-week bar chart with month labels.
///
/// Bars are normalized to 100 (= the #1 species peak) so that the chart
/// scale is consistent across all species cards.  A minimum bar height
/// ensures small values remain visible.
class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.weeklyScores});

  final List<double> weeklyScores;

  static const double _chartHeight = 24.0;
  static const double _minBarHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    if (weeklyScores.every((p) => p == 0)) return const SizedBox();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Bars (center-aligned) ──
        SizedBox(
          height: _chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(48, (index) {
              final score = weeklyScores[index];
              final normalized = (score / 100.0).clamp(0.0, 1.0);
              final isCurrentWeek = index == currentWeekIndex;

              final barHeight = score > 0
                  ? (normalized * _chartHeight)
                      .clamp(_minBarHeight, _chartHeight)
                  : 0.0;

              final baseColor = theme.colorScheme.primary;
              final activeColor = theme.colorScheme.tertiary;

              return Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isCurrentWeek
                          ? activeColor
                          : baseColor.withAlpha(
                              (50 + (normalized * 150)).toInt().clamp(0, 255)),
                      borderRadius: BorderRadius.circular(1),
                      border: isCurrentWeek
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 0.5,
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // ── Month labels ──
        SizedBox(
          height: 10,
          child: Row(
            children: _monthLabels(l10n).map((label) {
              return Expanded(
                flex: 4,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 7,
                    height: 1.0,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static List<String> _monthLabels(AppLocalizations l10n) => [
        l10n.monthJ,
        l10n.monthF,
        l10n.monthM,
        l10n.monthA,
        l10n.monthMay,
        l10n.monthJun,
        l10n.monthJul,
        l10n.monthAug,
        l10n.monthS,
        l10n.monthO,
        l10n.monthN,
        l10n.monthD,
      ];
}

/// Small overlay badge that flags a species as previously detected by the
/// user. Rendered in the corner of the species thumbnail in the Explore
/// screen and the species info overlay so users can spot at a glance which
/// species they have already added to their personal life list.
class _DetectedBadge extends StatelessWidget {
  const _DetectedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        // Solid background so the icon stays legible over both bright and
        // dark areas of the bird photo. Using the primary color makes it
        // clearly an "earned" marker rather than a UI affordance.
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.check,
        size: 12,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}
