// =============================================================================
// Explore Screen — Browse species in your area
// =============================================================================
//
// Shows a scrollable list of species. By default, the list is restricted to
// species that the geo-model predicts as likely present at the user's
// current location and time of year, ranked by probability.
//
// The user can:
//   • Filter by taxonomic group (Birds, Mammals, Amphibians, Insects).
//   • Search by common or scientific name. The search runs over the full
//     audio-model species list (not only the geo-filtered subset), so
//     species that do not occur at the current location can still be
//     opened. Local matches are shown first, with a separate "Other
//     species" section for distant matches.
//
// Each species is displayed as a [SpeciesCard]. Tapping a card opens the
// [SpeciesInfoOverlay] with detailed information.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/empty_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'explore_providers.dart';
import 'widgets/species_card.dart';
import 'widgets/species_info_overlay.dart';

/// Taxonomic group filter for the explore list.
enum _TaxonGroup {
  all,
  aves,
  mammalia,
  amphibia,
  insecta;

  /// Matches the `taxon_group` column in the bundled taxonomy CSV.
  String? get csvValue => switch (this) {
        _TaxonGroup.all => null,
        _TaxonGroup.aves => 'Aves',
        _TaxonGroup.mammalia => 'Mammalia',
        _TaxonGroup.amphibia => 'Amphibia',
        _TaxonGroup.insecta => 'Insecta',
      };

  String label(AppLocalizations l10n) => switch (this) {
        _TaxonGroup.all => l10n.exploreFilterAll,
        _TaxonGroup.aves => l10n.exploreFilterBirds,
        _TaxonGroup.mammalia => l10n.exploreFilterMammals,
        _TaxonGroup.amphibia => l10n.exploreFilterAmphibians,
        _TaxonGroup.insecta => l10n.exploreFilterInsects,
      };
}

/// The Explore screen — browse species expected in your area, with optional
/// search across the full species list.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  _TaxonGroup _group = _TaxonGroup.all;

  /// Whether the inline search field is currently visible. Toggled by the
  /// search icon in the AppBar; the filter chip row is shown otherwise.
  bool _searchVisible = false;

  /// Whether the taxonomic-group filter chip row is currently visible.
  bool _filterVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim());
  }

  void _toggleSearch() {
    setState(() {
      if (_searchVisible) {
        _searchVisible = false;
        _searchController.clear();
        _query = '';
      } else {
        _searchVisible = true;
        _filterVisible = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocusNode.requestFocus(),
        );
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _filterVisible = !_filterVisible;
      if (_filterVisible) _searchVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final speciesAsync = ref.watch(exploreSpeciesProvider);
    final locationAsync = ref.watch(currentLocationProvider);
    final theme = Theme.of(context);
    final filterActive = _group != _TaxonGroup.all;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exploreTitle),
        actions: [
          // Filter toggle (badge dot when a non-"All" group is active).
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_filterVisible
                    ? Icons.filter_list
                    : Icons.filter_list_outlined),
                if (filterActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: l10n.exploreFilterTooltip,
            onPressed: _toggleFilter,
          ),
          // Search toggle.
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            tooltip: _searchVisible
                ? l10n.tooltipClearSearch
                : l10n.exploreSearchTooltip,
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.exploreRefresh,
            onPressed: () {
              ref.invalidate(currentLocationProvider);
              ref.invalidate(exploreSpeciesProvider);
            },
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: speciesAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            title: l10n.statusError,
            message: error.toString(),
            onRetry: () {
              ref.invalidate(currentLocationProvider);
              ref.invalidate(exploreSpeciesProvider);
            },
            retryLabel: l10n.retry,
          ),
          data: (localSpecies) {
            return Column(
              children: [
                // ── Location & count header ─────────────────
                _LocationHeader(speciesCount: localSpecies.length),
                const Divider(height: 1),

                // ── Collapsible filter chip row ─────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _filterVisible
                      ? _GroupFilterBar(
                          selected: _group,
                          onChanged: (g) => setState(() => _group = g),
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),

                // ── Collapsible search field ────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _searchVisible
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onQueryChanged,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: l10n.exploreSearchHint,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      tooltip: l10n.tooltipClearSearch,
                                      onPressed: () {
                                        _searchController.clear();
                                        _onQueryChanged('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),

                // ── Body: either geo list or search results ──
                Expanded(
                  child: _query.isEmpty
                      ? _GeoList(
                          species: localSpecies,
                          group: _group,
                          locationAvailable:
                              locationAsync.valueOrNull != null,
                        )
                      : _SearchResults(
                          query: _query,
                          group: _group,
                          localSpecies: localSpecies,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group filter chip bar
// ---------------------------------------------------------------------------

class _GroupFilterBar extends StatelessWidget {
  const _GroupFilterBar({required this.selected, required this.onChanged});

  final _TaxonGroup selected;
  final ValueChanged<_TaxonGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final g in _TaxonGroup.values) ...[
            FilterChip(
              label: Text(g.label(l10n)),
              selected: selected == g,
              onSelected: (_) => onChanged(g),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geo list (no active search)
// ---------------------------------------------------------------------------

class _GeoList extends ConsumerWidget {
  const _GeoList({
    required this.species,
    required this.group,
    required this.locationAvailable,
  });

  final List<ExploreSpecies> species;
  final _TaxonGroup group;
  final bool locationAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = group == _TaxonGroup.all
        ? species
        : species
            .where((s) => s.taxonomy?.taxonGroup == group.csvValue)
            .toList();

    if (filtered.isEmpty) {
      return EmptyView(
        icon: locationAvailable ? Icons.search_off : Icons.location_off,
        title: locationAvailable
            ? l10n.exploreNoSpecies
            : l10n.exploreNoLocation,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final s = filtered[index];
        return SpeciesCard(
          scientificName: s.scientificName,
          commonName: s.commonName,
          geoScore: s.geoScore,
          weeklyScores: s.weeklyScores,
          onTap: () => SpeciesInfoOverlay.show(
            context,
            ref,
            scientificName: s.scientificName,
            commonName: s.commonName,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search results — runs over the full taxonomy, partitions by location
// ---------------------------------------------------------------------------

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.group,
    required this.localSpecies,
  });

  final String query;
  final _TaxonGroup group;
  final List<ExploreSpecies> localSpecies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final audioLabelsAsync = ref.watch(audioLabelsSetProvider);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);

    final taxonomy = taxonomyAsync.valueOrNull;
    final audioLabels = audioLabelsAsync.valueOrNull;
    if (taxonomy == null || audioLabels == null) {
      return const LoadingView();
    }

    // Index local species by scientific name for fast lookup.
    final localByName = <String, ExploreSpecies>{
      for (final s in localSpecies) s.scientificName: s,
    };

    // Search across the entire taxonomy, then keep only species the audio
    // model knows about (so opening them is meaningful), and apply the
    // taxonomic-group filter.
    final hits = taxonomy
        .search(query, limit: 200)
        .where((sp) => audioLabels.contains(sp.scientificName))
        .where((sp) =>
            group == _TaxonGroup.all || sp.taxonGroup == group.csvValue)
        .toList();

    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.exploreNoResultsFor(query),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    // Partition into "at your location" and "other species" while
    // preserving search-relevance order within each bucket.
    final atLocation = <_SearchHit>[];
    final elsewhere = <_SearchHit>[];
    for (final sp in hits) {
      final local = localByName[sp.scientificName];
      final hit = _SearchHit(
        species: sp,
        local: local,
        speciesLocale: speciesLocale,
      );
      if (local != null) {
        atLocation.add(hit);
      } else {
        elsewhere.add(hit);
      }
    }
    // Within "at your location", prefer higher geo scores.
    atLocation.sort((a, b) =>
        (b.local?.geoScore ?? 0).compareTo(a.local?.geoScore ?? 0));

    final items = <_ListEntry>[];
    if (atLocation.isNotEmpty) {
      items.add(_ListEntry.header(
        l10n.exploreSectionAtLocation(atLocation.length),
        Icons.location_on,
      ));
      items.addAll(atLocation.map(_ListEntry.hit));
    }
    if (elsewhere.isNotEmpty) {
      items.add(_ListEntry.header(
        l10n.exploreSectionElsewhere(elsewhere.length),
        Icons.public,
      ));
      items.addAll(elsewhere.map(_ListEntry.hit));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = items[index];
        if (entry.isHeader) {
          return _SectionHeader(label: entry.label!, icon: entry.icon!);
        }
        final hit = entry.hit!;
        return SpeciesCard(
          scientificName: hit.species.scientificName,
          commonName: hit.displayName,
          geoScore: hit.local?.geoScore,
          weeklyScores: hit.local?.weeklyScores,
          onTap: () => SpeciesInfoOverlay.show(
            context,
            ref,
            scientificName: hit.species.scientificName,
            commonName: hit.species.commonName,
          ),
        );
      },
    );
  }
}

class _SearchHit {
  _SearchHit({
    required this.species,
    required this.local,
    required this.speciesLocale,
  });

  final TaxonomySpecies species;
  final ExploreSpecies? local;
  final String speciesLocale;

  String get displayName => species.commonNameForLocale(speciesLocale);
}

class _ListEntry {
  _ListEntry.header(this.label, this.icon)
      : isHeader = true,
        hit = null;
  _ListEntry.hit(this.hit)
      : isHeader = false,
        label = null,
        icon = null;

  final bool isHeader;
  final String? label;
  final IconData? icon;
  final _SearchHit? hit;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location header — shows coordinates and species count
// ---------------------------------------------------------------------------

class _LocationHeader extends ConsumerStatefulWidget {
  const _LocationHeader({required this.speciesCount});

  final int speciesCount;

  @override
  ConsumerState<_LocationHeader> createState() => _LocationHeaderState();
}

class _LocationHeaderState extends ConsumerState<_LocationHeader> {
  String? _locationName;
  bool _geocoded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryGeocode();
  }

  Future<void> _tryGeocode() async {
    final loc = ref.read(currentLocationProvider).valueOrNull;
    if (loc == null || _geocoded) return;
    _geocoded = true;
    final name = await reverseGeocode(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );
    if (mounted && name != null) {
      setState(() => _locationName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locationAsync = ref.watch(currentLocationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: locationAsync.when(
                  data: (loc) {
                    if (loc == null) {
                      return Text(
                        l10n.exploreNoLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      );
                    }
                    // Prefer the reverse-geocoded place name; fall back to
                    // raw lat/lon so we don't waste a second row showing
                    // both. While geocoding is in flight, show coordinates.
                    final label = _locationName ??
                        '${loc.latitude.toStringAsFixed(4)}, '
                            '${loc.longitude.toStringAsFixed(4)}';
                    return Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    );
                  },
                  loading: () => Text(
                    l10n.exploreLocating,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  error: (_, __) => Text(
                    l10n.exploreLocationError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showExploreHelp(context),
                icon: Icon(
                  Icons.help_outline,
                  size: 22,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                tooltip: l10n.exploreHelpTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExploreHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ExploreHelpSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Help bottom sheet (matches session review style)
// ---------------------------------------------------------------------------

class _ExploreHelpSheet extends StatelessWidget {
  const _ExploreHelpSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppHelpBottomSheet(
      title: l10n.exploreHelpTitle,
      initialChildSize: 0.62,
      sections: [
        AppHelpSection(
          icon: Icons.info_outline,
          body: l10n.exploreHelpBody,
        ),
        AppHelpSection(
          icon: Icons.refresh,
          body: l10n.exploreHelpRefresh,
        ),
        AppHelpSection(
          icon: Icons.help_outline_rounded,
          body: l10n.exploreHelpLocation,
        ),
        AppHelpSection(
          icon: Icons.search_rounded,
          body: l10n.exploreHelpCards,
        ),
      ],
      footer: _ExploreHelpLink(label: l10n.exploreHelpLearnMore),
    );
  }
}

class _ExploreHelpLink extends StatelessWidget {
  const _ExploreHelpLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://birdnet-team.github.io/geomodel/');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          Icon(
            Icons.open_in_new,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
