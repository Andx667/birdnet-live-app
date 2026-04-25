// =============================================================================
// Species Info Overlay — Detailed species information bottom sheet
// =============================================================================
//
// A modal bottom sheet showing detailed species information:
//   • Medium image (480x320 WebP, 3:2)
//   • Common name + scientific name
//   • Wikipedia excerpt (if available from API)
//   • External links (eBird, iNaturalist)
//   • Image credit
//
// ### Usage
//
// ```dart
// SpeciesInfoOverlay.show(context, ref, scientificName: 'Parus major');
// ```
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/taxonomy_species.dart';
import '../../../shared/providers/settings_providers.dart';
import '../explore_providers.dart';
import '../../inference/geo_model.dart';

/// Shows a modal bottom sheet with detailed species information.
class SpeciesInfoOverlay {
  SpeciesInfoOverlay._();

  /// Show the species info overlay for the given [scientificName].
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required String scientificName,
    required String commonName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SpeciesInfoSheet(
        scientificName: scientificName,
        commonName: commonName,
      ),
    );
  }
}

class _SpeciesInfoSheet extends ConsumerStatefulWidget {
  const _SpeciesInfoSheet({
    required this.scientificName,
    required this.commonName,
  });

  final String scientificName;
  final String commonName;

  @override
  ConsumerState<_SpeciesInfoSheet> createState() => _SpeciesInfoSheetState();
}

class _SpeciesInfoSheetState extends ConsumerState<_SpeciesInfoSheet> {
  TaxonomySpecies? _detail;
  String? _description;
  bool _loading = true;
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      _loadBundledData();
    }
  }

  Future<void> _loadBundledData() async {
    try {
      final locale = ref.read(effectiveSpeciesLocaleProvider);
      final taxonomyService = await ref.read(taxonomyServiceProvider.future);
      final descService = ref.read(speciesDescriptionServiceProvider);

      final detail = taxonomyService.lookup(widget.scientificName);
      final description = await descService.getDescription(
        widget.scientificName,
        locale,
      );

      if (mounted) {
        setState(() {
          _detail = detail;
          _description = description;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SpeciesInfoOverlay] loadBundledData error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Pick the best Wikipedia URL for the active locale.
  ///
  /// Prefers the user's interface/species locale, falls back to English,
  /// returns null if neither exists. Only locales bundled in taxonomy.csv
  /// are considered (interface locales).
  String? _pickWikipediaUrl(TaxonomySpecies detail) {
    final urls = detail.wikipediaUrls;
    if (urls == null || urls.isEmpty) return null;
    final locale = ref.read(effectiveSpeciesLocaleProvider);
    return urls[locale] ?? urls['en'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Image ────────────────────────────────────────
              // Bundled species photos are 320×240 (4:3); using a 4:3
              // aspect ratio with BoxFit.contain shows the full photo
              // without vertical cropping or sideways distortion.
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  _detail?.assetImagePath ?? 'assets/images/dummy_species.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/dummy_species.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Image credit (below photo) ────────────────────
              if (_detail?.imageAuthor != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    '${l10n.speciesPhotoCreditLabel}: ${_detail!.imageAuthor}'
                    '${_detail!.imageLicense != null ? ' (${_detail!.imageLicense})' : ''}'
                    '${_detail!.imageSource != null ? ' — ${_detail!.imageSource}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                ),

              // ── Names ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _detail?.commonNameForLocale(
                          ref.watch(effectiveSpeciesLocaleProvider)) ??
                      widget.commonName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ref.watch(showSciNamesProvider)
                    ? Text(
                        widget.scientificName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withAlpha(170),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Loading skeleton (shimmer placeholder for the bio paragraph) ─
              if (_loading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _BioSkeleton(),
                ),

              // ── Description ─────────────────────────────────
              if (!_loading) ...[
                if (_description != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      _description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_detail?.descriptionSource != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        AppLocalizations.of(context)!.speciesDescriptionSource(
                          _detail!.descriptionSource!,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],

                // ── 48-Week Probability Chart ──────────────────────────────
                _WeeklyProbabilityChart(
                  scientificName: widget.scientificName,
                ),

                // ── External links ───────────────────────────────
                if (_detail != null &&
                    (_detail!.ebirdUrl != null ||
                        _detail!.inatUrl != null ||
                        _pickWikipediaUrl(_detail!) != null)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      AppLocalizations.of(context)!.speciesLearnMore,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_detail!.ebirdUrl != null)
                          _LinkChip(
                            label: 'eBird',
                            iconAsset: 'assets/images/icon-ebird.png',
                            url: _detail!.ebirdUrl!,
                          ),
                        if (_detail!.inatUrl != null)
                          _LinkChip(
                            label: 'iNaturalist',
                            iconAsset: 'assets/images/icon-inat.png',
                            url: _detail!.inatUrl!,
                          ),
                        if (_pickWikipediaUrl(_detail!) != null)
                          _LinkChip(
                            label: 'Wikipedia',
                            iconAsset: 'assets/images/icon-wikipedia.png',
                            url: _pickWikipediaUrl(_detail!)!,
                          ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton (shimmer placeholder for the bio paragraph)
// ---------------------------------------------------------------------------

/// Animated grey lines that fade in and out to indicate loading.
///
/// Cheaper than a true shimmer (no shader work) and matches the app's
/// understated visual language.
class _BioSkeleton extends StatefulWidget {
  const _BioSkeleton();

  @override
  State<_BioSkeleton> createState() => _BioSkeletonState();
}

class _BioSkeletonState extends State<_BioSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _line(double widthFactor, Color baseColor) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_controller.value);
          final alpha = (40 + (t * 80)).round().clamp(0, 255);
          return Container(
            height: 12,
            decoration: BoxDecoration(
              color: baseColor.withAlpha(alpha),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(1.0, base),
        const SizedBox(height: 8),
        _line(0.96, base),
        const SizedBox(height: 8),
        _line(0.86, base),
        const SizedBox(height: 8),
        _line(0.62, base),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Link chip widget
// ---------------------------------------------------------------------------

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.iconAsset,
    required this.url,
  });

  final String label;
  final String iconAsset;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Image.asset(
        iconAsset,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 18),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Icon(
            Icons.open_in_new,
            size: 12,
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ],
      ),
      labelStyle: theme.textTheme.bodySmall,
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 48-Week Probability Chart
// ---------------------------------------------------------------------------

class _WeeklyProbabilityChart extends ConsumerWidget {
  const _WeeklyProbabilityChart({required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesAsync = ref.watch(exploreSpeciesProvider);

    return speciesAsync.when(
      data: (speciesList) {
        // Find this species in the already-computed explore list.
        final match = speciesList.where(
          (s) => s.scientificName == scientificName,
        );
        final probs = match.isNotEmpty ? match.first.weeklyScores : null;

        if (probs == null || probs.every((p) => p == 0)) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.speciesChartNoData,
              style: theme.textTheme.bodySmall,
            ),
          );
        }

        final currentWeekIndex = GeoModel.dateTimeToWeek(DateTime.now()) - 1;
        final currentScore = probs[currentWeekIndex];
        final category = _localizedProbabilityCategory(l10n, currentScore);
        final categoryColor = probabilityCategoryColor(currentScore);

        // Normalize to 100 (= the #1 species peak from the provider).
        const maxProb = 100.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    l10n.speciesExpectedFrequency,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.speciesExpectedFrequencySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(48, (index) {
                    final score = probs[index];
                    final normalized = (score / maxProb).clamp(0.0, 1.0);
                    final isCurrentWeek = index == currentWeekIndex;

                    final barHeight =
                        score > 0 ? (normalized * 80).clamp(2.0, 80.0) : 0.0;

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
                                    (50 + (normalized * 150))
                                        .toInt()
                                        .clamp(0, 255),
                                  ),
                            borderRadius: BorderRadius.circular(2),
                            border: isCurrentWeek
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Month labels
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.monthJanShort,
                      style: const TextStyle(fontSize: 10)),
                  Text(l10n.monthAprShort,
                      style: const TextStyle(fontSize: 10)),
                  Text(l10n.monthJulShort,
                      style: const TextStyle(fontSize: 10)),
                  Text(l10n.monthOctShort,
                      style: const TextStyle(fontSize: 10)),
                  Text(l10n.monthDecShort,
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(l10n.speciesChartLoadFailed)),
      ),
    );
  }
}

String _localizedProbabilityCategory(AppLocalizations l10n, double score) {
  if (score >= 80) return l10n.speciesFrequencyAbundant;
  if (score >= 60) return l10n.speciesFrequencyCommon;
  if (score >= 40) return l10n.speciesFrequencyUncommon;
  if (score >= 20) return l10n.speciesFrequencyOccasional;
  return l10n.speciesFrequencyRare;
}
