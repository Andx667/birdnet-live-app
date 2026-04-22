// =============================================================================
// ScoreColors — theme extension for confidence / geo-score color tokens
// =============================================================================
//
// Provides a unified five-step red→green scale for any "how confident is
// this number" badge across the app: Live confidence, Survey detection
// confidence, and Explore geo-model scores.
//
// Design rationale (see dev/STYLE_GUIDE.md → "Score & Confidence Color
// Tokens"):
//   • Five buckets at even quintiles: very-low (< 0.20),
//     low (0.20 – 0.40), mid (0.40 – 0.60), high (0.60 – 0.80),
//     very-high (≥ 0.80). The extra steps make distinguishing a
//     borderline detection (≈ 0.50) from a strong one (≈ 0.80) much
//     more obvious in long lists.
//   • Color is never the only signal — pair with a label or shape change.
//
// Usage:
// ```dart
// final scoreColors = Theme.of(context).extension<ScoreColors>()!;
// final color = scoreColors.forScore(detection.confidence);
// ```
// =============================================================================

import 'package:flutter/material.dart';

/// Unified color tokens for confidence and geo-score badges.
@immutable
class ScoreColors extends ThemeExtension<ScoreColors> {
  const ScoreColors({
    required this.veryLow,
    required this.low,
    required this.mid,
    required this.high,
    required this.veryHigh,
  });

  /// Color used for very-low scores (< [lowThreshold]).
  final Color veryLow;

  /// Color used for low scores ([lowThreshold] – [midThreshold]).
  final Color low;

  /// Color used for mid scores ([midThreshold] – [highThreshold]).
  final Color mid;

  /// Color used for high scores ([highThreshold] – [veryHighThreshold]).
  final Color high;

  /// Color used for very-high scores (≥ [veryHighThreshold]).
  final Color veryHigh;

  /// Threshold separating [veryLow] from [low].
  static const double lowThreshold = 0.20;

  /// Threshold separating [low] from [mid].
  static const double midThreshold = 0.40;

  /// Threshold separating [mid] from [high].
  static const double highThreshold = 0.60;

  /// Threshold separating [high] from [veryHigh].
  static const double veryHighThreshold = 0.80;

  /// Returns the bucket color for a normalized 0–1 score.
  Color forScore(double score) {
    if (score < lowThreshold) return veryLow;
    if (score < midThreshold) return low;
    if (score < highThreshold) return mid;
    if (score < veryHighThreshold) return high;
    return veryHigh;
  }

  /// Light-theme defaults — Material red → orange → amber → light-green
  /// → green at 700-ish saturation for legibility on white backgrounds.
  static const ScoreColors light = ScoreColors(
    veryLow: Color(0xFFC62828), // red 800
    low: Color(0xFFEF6C00), // orange 800
    mid: Color(0xFFF9A825), // amber 800
    high: Color(0xFF7CB342), // light green 600
    veryHigh: Color(0xFF2E7D32), // green 800
  );

  /// Dark-theme defaults — same hue progression but lighter for
  /// legibility on dark surfaces.
  static const ScoreColors dark = ScoreColors(
    veryLow: Color(0xFFE57373), // red 300
    low: Color(0xFFFFB74D), // orange 300
    mid: Color(0xFFFFD54F), // amber 300
    high: Color(0xFFAED581), // light green 300
    veryHigh: Color(0xFF81C784), // green 300
  );

  @override
  ScoreColors copyWith({
    Color? veryLow,
    Color? low,
    Color? mid,
    Color? high,
    Color? veryHigh,
  }) {
    return ScoreColors(
      veryLow: veryLow ?? this.veryLow,
      low: low ?? this.low,
      mid: mid ?? this.mid,
      high: high ?? this.high,
      veryHigh: veryHigh ?? this.veryHigh,
    );
  }

  @override
  ScoreColors lerp(ThemeExtension<ScoreColors>? other, double t) {
    if (other is! ScoreColors) return this;
    return ScoreColors(
      veryLow: Color.lerp(veryLow, other.veryLow, t) ?? veryLow,
      low: Color.lerp(low, other.low, t) ?? low,
      mid: Color.lerp(mid, other.mid, t) ?? mid,
      high: Color.lerp(high, other.high, t) ?? high,
      veryHigh: Color.lerp(veryHigh, other.veryHigh, t) ?? veryHigh,
    );
  }
}
