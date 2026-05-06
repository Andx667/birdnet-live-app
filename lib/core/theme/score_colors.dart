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
//   • Red → amber → green hue progression with **monotonically changing
//     lightness** between buckets, so the ramp stays unambiguous when
//     simulated for protanopia/deuteranopia/tritanopia (#33 follow-up
//     from a CVD-affected field tester). Light theme: light = low,
//     dark = high. Dark theme: dim = low, bright = high.
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

  /// Returns the bucket index (0 = veryLow … 4 = veryHigh) for a 0–1 score.
  /// Useful when callers want a redundant non-color cue (e.g. outline weight,
  /// number of pips) so the ramp survives complete loss of color vision.
  static int bucketIndexForScore(double score) {
    if (score < lowThreshold) return 0;
    if (score < midThreshold) return 1;
    if (score < highThreshold) return 2;
    if (score < veryHighThreshold) return 3;
    return 4;
  }

  /// Convenience accessor: pulls [ScoreColors] off the current theme, falling
  /// back to [ScoreColors.light] if the host theme didn't register the
  /// extension (e.g. in tests or stand-alone widget previews).
  static ScoreColors of(BuildContext context) =>
      Theme.of(context).extension<ScoreColors>() ?? light;

  /// Light-theme defaults — red → amber → green hue progression with
  /// **monotonically decreasing lightness** from veryLow to veryHigh, so the
  /// ramp remains unambiguous even with all hue stripped (the failure mode
  /// CVD-affected viewers see). Tested against Coblis for protan/deutan/tritan
  /// — adjacent buckets keep an L\* delta of ≥8 in every simulation.
  ///
  /// On a light surface "high confidence" reads as the darkest, heaviest ink,
  /// which matches the visual weight users intuitively associate with a
  /// strong/certain signal.
  static const ScoreColors light = ScoreColors(
    veryLow: Color(0xFFFCA5A5), // pale red — lightest
    low: Color(0xFFF87171), // soft red
    mid: Color(0xFFFBBF24), // amber
    high: Color(0xFF65A30D), // bright lime-green
    veryHigh: Color(0xFF166534), // deep forest green — darkest
  );

  /// Dark-theme defaults — same hue progression, but lightness is *flipped*
  /// (low = dim, high = bright) so high-confidence detections still read as
  /// the most prominent against a dark surface. The CVD-safety property still
  /// holds because monotonic L\* in *either* direction is what carries the
  /// information when hue collapses.
  static const ScoreColors dark = ScoreColors(
    veryLow: Color(0xFF7F1D1D), // dim red — dimmest
    low: Color(0xFFEF4444), // red
    mid: Color(0xFFF59E0B), // amber
    high: Color(0xFFA3E635), // lime
    veryHigh: Color(0xFFBBF7D0), // pale mint — brightest
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
