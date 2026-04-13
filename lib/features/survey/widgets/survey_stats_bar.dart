// =============================================================================
// Survey Stats Bar — Glanceable row of survey statistics
// =============================================================================
//
// Displays distance walked, detection count, and unique species
// count in a compact horizontal row.  Designed for the survey live screen
// top-of-screen overlay.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Compact statistics bar for an active survey.
class SurveyStatsBar extends StatelessWidget {
  const SurveyStatsBar({
    super.key,
    required this.distanceMeters,
    required this.detectionCount,
    required this.speciesCount,
    this.audioLevel = 0,
    this.peakLevel = 0,
  });

  /// Distance walked in meters.
  final double distanceMeters;

  /// Total detection count (after sampling).
  final int detectionCount;

  /// Unique species count.
  final int speciesCount;

  /// Current RMS audio level (0.0 – 1.0).
  final double audioLevel;

  /// Current peak audio level (0.0 – 1.0).
  final double peakLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Audio quality assessment:
    //   green  = good ambient signal (typical birdsong environment)
    //   amber  = marginal (very quiet or moderately loud)
    //   red    = bad (silence / no signal, or clipping / wind noise)
    final Color levelColor;
    if (audioLevel < 0.0005) {
      // Silence or mic not working.
      levelColor = Colors.red;
    } else if (peakLevel > 0.95) {
      // Clipping — wind, handling noise, or mic overload.
      levelColor = Colors.red;
    } else if (audioLevel > 0.15) {
      // Very loud sustained noise (wind, traffic).
      levelColor = Colors.red;
    } else if (audioLevel < 0.001 || audioLevel > 0.08) {
      // Marginal: too quiet or somewhat loud.
      levelColor = Colors.amber;
    } else {
      // Good range for birdsong detection (RMS ~0.001–0.08).
      levelColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AudioLevelChip(level: audioLevel, color: levelColor, style: style),
          _StatChip(
            icon: Icons.straighten,
            value: _formatDistance(distanceMeters),
            style: style,
          ),
          _StatChip(
            icon: Icons.graphic_eq,
            value: '$detectionCount',
            style: style,
          ),
          _StatChip(
            icon: MdiIcons.feather,
            value: '$speciesCount',
            style: style,
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    this.style,
  });

  final IconData icon;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(value, style: style),
      ],
    );
  }
}

/// Audio signal-strength bars (1–3 filled bars) colored by quality.
///
///   3 green bars = good ambient signal (typical birdsong environment)
///   2 amber bars = marginal (very quiet or moderately loud)
///   1 red bar    = bad (silence / no signal, or clipping / wind noise)
class _AudioLevelChip extends StatelessWidget {
  const _AudioLevelChip({
    required this.level,
    required this.color,
    this.style,
  });

  final double level;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int filledBars;
    if (color == Colors.green) {
      filledBars = 3;
    } else if (color == Colors.amber) {
      filledBars = 2;
    } else {
      filledBars = 1;
    }
    final muted = theme.colorScheme.onSurface.withAlpha(40);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(Icons.mic, size: 16, color: color),
        const SizedBox(width: 3),
        for (int i = 0; i < 3; i++)
          Container(
            width: 4,
            height: 6.0 + i * 4, // 6, 10, 14
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: i < filledBars ? color : muted,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
