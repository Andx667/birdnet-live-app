// =============================================================================
// Session Library Screen — Browse saved live sessions
// =============================================================================
//
// Lists all completed sessions stored via [SessionRepository].  Each row
// shows the date, duration, species count, and detection count.  Tapping
// a session opens the [SessionReviewScreen] for playback and editing.
//
// Accessible from the Home screen footer.
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../../shared/widgets/empty_view.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/stat_chip.dart';
import '../explore/explore_providers.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import 'session_review_screen.dart';

/// How sessions are ordered in the library.
enum _SortMode { dateDesc, dateAsc, nameAsc, nameDesc }

/// How sessions are presented in the library.
enum _ViewMode { detailed, compact, bySpecies }

/// Displays a list of all saved sessions from the session repository.
class SessionLibraryScreen extends ConsumerStatefulWidget {
  const SessionLibraryScreen({super.key});

  @override
  ConsumerState<SessionLibraryScreen> createState() =>
      _SessionLibraryScreenState();
}

class _SessionLibraryScreenState extends ConsumerState<SessionLibraryScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  _SortMode _sortMode = _SortMode.dateDesc;
  _ViewMode _viewMode = _ViewMode.detailed;
  SessionType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrefKeys.sessionLibraryViewMode);
    if (stored == null || !mounted) return;
    final mode = _ViewMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => _ViewMode.detailed,
    );
    if (mode != _viewMode) setState(() => _viewMode = mode);
  }

  Future<void> _setViewMode(_ViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.sessionLibraryViewMode, mode.name);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppHelpBottomSheet(
        title: l10n.sessionLibraryHelpTitle,
        sections: [
          AppHelpSection(
            icon: Icons.search,
            body: l10n.sessionLibraryHelpSearch,
          ),
          AppHelpSection(
            icon: _viewModeIcon(_viewMode),
            body: l10n.sessionLibraryHelpView,
          ),
          AppHelpSection(
            icon: Icons.swap_vert,
            body: l10n.sessionLibraryHelpSort,
          ),
          AppHelpSection(
            icon: Icons.library_music_outlined,
            body: l10n.sessionLibraryHelpOpen,
          ),
        ],
      ),
    );
  }

  /// Returns `true` if [session] matches the current search query.
  ///
  /// Matches against: session name, date string, session type label, location name,
  /// lat/lon coordinates, and all detection species (common + scientific).
  bool _matchesQuery(LiveSession session, String query, AppLocalizations l10n) {
    final q = query.toLowerCase();

    // Session display name.
    if (session.displayName.toLowerCase().contains(q)) return true;

    // Date / time.
    final dateStr =
        DateFormat.yMMMd().add_Hm().format(session.startTime).toLowerCase();
    if (dateStr.contains(q)) return true;

    // Session type label.
    if (_sessionTypeLabel(l10n, session.type).toLowerCase().contains(q)) {
      return true;
    }

    // Location name or coordinates.
    final loc = session.locationName?.toLowerCase();
    if (loc != null && loc.contains(q)) return true;
    if (session.latitude != null && session.longitude != null) {
      final coords = '${session.latitude!.toStringAsFixed(4)}, '
          '${session.longitude!.toStringAsFixed(4)}';
      if (coords.contains(q)) return true;
    }

    // Species (common and scientific names).
    for (final d in session.detections) {
      if (d.commonName.toLowerCase().contains(q)) return true;
      if (d.scientificName.toLowerCase().contains(q)) return true;
    }

    return false;
  }

  void _showOptionsSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              void update(VoidCallback fn) {
                setSheetState(fn);
                setState(fn);
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetSectionHeader(l10n.sessionLibrarySortTooltip),
                      _sheetChips<_SortMode>(
                        current: _sortMode,
                        options: [
                          (_SortMode.dateDesc, l10n.sessionSortDateNewest),
                          (_SortMode.dateAsc, l10n.sessionSortDateOldest),
                          (_SortMode.nameAsc, l10n.sessionSortNameAZ),
                          (_SortMode.nameDesc, l10n.sessionSortNameZA),
                        ],
                        onSelected: (m) => update(() => _sortMode = m),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionHeader(l10n.sessionViewTooltip),
                      _sheetChips<_ViewMode>(
                        current: _viewMode,
                        options: [
                          (_ViewMode.detailed, l10n.sessionViewDetailed),
                          (_ViewMode.compact, l10n.sessionViewCompact),
                          (_ViewMode.bySpecies, l10n.sessionViewBySpecies),
                        ],
                        onSelected: (m) => update(() => _setViewMode(m)),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionHeader(l10n.sessionLibraryFilterTooltip),
                      _sheetChips<SessionType?>(
                        current: _typeFilter,
                        options: [
                          (null, l10n.exploreFilterAll),
                          (SessionType.live, l10n.sessionTypeLive),
                          (SessionType.pointCount, l10n.sessionTypePointCount),
                          (SessionType.fileUpload, l10n.sessionTypeFileUpload),
                          (SessionType.survey, l10n.sessionTypeSurvey),
                        ],
                        onSelected: (t) => update(() => _typeFilter = t),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetSectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _sheetChips<T>({
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: current == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }

  static IconData _viewModeIcon(_ViewMode mode) {
    switch (mode) {
      case _ViewMode.detailed:
        return Icons.view_agenda_outlined;
      case _ViewMode.compact:
        return Icons.view_list_outlined;
      case _ViewMode.bySpecies:
        return Icons.category_outlined;
    }
  }

  List<LiveSession> _applySorting(List<LiveSession> sessions) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List.of(sessions);
    switch (_sortMode) {
      case _SortMode.dateDesc:
        sorted.sort((a, b) => b.startTime.compareTo(a.startTime));
      case _SortMode.dateAsc:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
      case _SortMode.nameAsc:
        sorted.sort((a, b) =>
            _sessionCardTitle(l10n, a).compareTo(_sessionCardTitle(l10n, b)));
      case _SortMode.nameDesc:
        sorted.sort((a, b) =>
            _sessionCardTitle(l10n, b).compareTo(_sessionCardTitle(l10n, a)));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sessionLibrarySearchHint,
                  border: InputBorder.none,
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (_) => setState(() {}),
              )
            : Text(l10n.sessionLibraryTitle),
        actions: [
          if (_showSearch)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.tooltipClearSearch,
              onPressed: () => setState(() {
                _searchController.clear();
                _showSearch = false;
              }),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.tooltipSearch,
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: l10n.sessionLibraryHelpTitle,
              onPressed: _showHelp,
            ),
            IconButton(
              icon: const Icon(Icons.filter_list_outlined),
              tooltip: l10n.settings,
              onPressed: _showOptionsSheet,
            ),
          ],
        ],
      ),
      body: ContentWidthConstraint(
          child: sessionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          title: l10n.statusError,
          message: e.toString(),
          onRetry: () => ref.invalidate(sessionListProvider),
          retryLabel: l10n.retry,
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return EmptyView(
              icon: Icons.library_music_outlined,
              title: l10n.sessionLibraryEmpty,
            );
          }

          final query = _searchController.text.trim();
          final matched = sessions.where((s) {
            if (_typeFilter != null && s.type != _typeFilter) return false;
            if (query.isEmpty) return true;
            return _matchesQuery(s, query, l10n);
          }).toList();
          final filtered = _applySorting(matched);

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                l10n.sessionLibraryNoResults,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            );
          }

          if (_viewMode == _ViewMode.bySpecies) {
            return _SpeciesGroupedView(
              sessions: filtered,
              onTap: _openReview,
              onDelete: _confirmDelete,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final session = filtered[index];
              if (_viewMode == _ViewMode.compact) {
                return _CompactSessionTile(
                  session: session,
                  onTap: () => _openReview(session),
                  onDelete: () => _confirmDelete(session),
                );
              }
              return _SessionTile(
                session: session,
                onTap: () => _openReview(session),
                onDelete: () => _confirmDelete(session),
              );
            },
          );
        },
      )),
    );
  }

  void _openReview(LiveSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionReviewScreen(session: session),
      ),
    );
  }

  Future<void> _confirmDelete(LiveSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sessionDiscardTitle,
      body: l10n.sessionDiscardMessage,
      confirmLabel: l10n.sessionDiscard,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed) return;
    await ref.read(sessionRepositoryProvider).delete(session.id);
    ref.invalidate(sessionListProvider);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTile extends ConsumerWidget {
  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final LiveSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.yMMMd().format(session.startTime);
    final timeStr = DateFormat.jm().format(session.startTime);

    final duration = session.duration;
    final speciesCount = session.uniqueSpeciesCount;
    final detectionCount = session.detections.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _sessionTypeIcon(session.type),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sessionCardTitle(
                              AppLocalizations.of(context)!, session),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '$dateStr at $timeStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              session.latitude != null
                                  ? Icons.location_on_outlined
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                session.locationName ??
                                    (session.latitude != null &&
                                            session.longitude != null
                                        ? '${session.latitude!.toStringAsFixed(4)}, '
                                            '${session.longitude!.toStringAsFixed(4)}'
                                        : AppLocalizations.of(context)!
                                            .sessionNoLocation),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    tooltip: l10n.tooltipDeleteSession,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (_topSpeciesSci(session).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _topSpeciesSci(session).map((entry) {
                    final speciesLocale =
                        ref.watch(effectiveSpeciesLocaleProvider);
                    final taxonomy =
                        ref.watch(taxonomyServiceProvider).valueOrNull;
                    final displayName = taxonomy
                            ?.lookup(entry.key)
                            ?.commonNameForLocale(speciesLocale) ??
                        entry.value;
                    return Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label:
                          Text(displayName, style: theme.textTheme.labelSmall),
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatChip(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(duration),
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: MdiIcons.feather,
                    value: '$speciesCount spp.',
                    variant: StatChipVariant.badge,
                  ),
                  StatChip(
                    icon: Icons.music_note_outlined,
                    value: '$detectionCount det.',
                    variant: StatChipVariant.badge,
                  ),
                  _SessionSizeChip(session: session),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _CompactSessionTile extends ConsumerWidget {
  const _CompactSessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final LiveSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.yMMMd().format(session.startTime);

    final duration = session.duration;
    final speciesCount = session.uniqueSpeciesCount;

    return ListTile(
      leading: Icon(
        _sessionTypeIcon(session.type),
        color: theme.colorScheme.primary,
      ),
      title: Text(
        _sessionCardTitle(l10n, session),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$dateStr · ${_formatCompactDuration(duration)} · $speciesCount spp.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            size: 20, color: theme.colorScheme.error),
        tooltip: l10n.tooltipDeleteSession,
        onPressed: onDelete,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: onTap,
    );
  }

  String _formatCompactDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Species-Grouped View
// ─────────────────────────────────────────────────────────────────────────────

class _SpeciesGroupedView extends ConsumerWidget {
  const _SpeciesGroupedView({
    required this.sessions,
    required this.onTap,
    required this.onDelete,
  });

  final List<LiveSession> sessions;
  final void Function(LiveSession) onTap;
  final void Function(LiveSession) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).valueOrNull;
    final showSciNames = ref.watch(showSciNamesProvider);

    // Group: scientificName → set of sessions containing it.
    final speciesMap = <String, _SpeciesGroup>{};
    for (final session in sessions) {
      for (final d in session.detections) {
        final group = speciesMap.putIfAbsent(
          d.scientificName,
          () => _SpeciesGroup(
            scientificName: d.scientificName,
            commonName: d.commonName,
          ),
        );
        group.sessionIds.add(session.id);
      }
    }

    // Sort by number of sessions (descending), then alphabetically.
    final sorted = speciesMap.values.toList()
      ..sort((a, b) {
        final cmp = b.sessionIds.length.compareTo(a.sessionIds.length);
        if (cmp != 0) return cmp;
        return a.commonName.compareTo(b.commonName);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final group = sorted[index];
        final taxon = taxonomy?.lookup(group.scientificName);
        final displayName =
            taxon?.commonNameForLocale(speciesLocale) ?? group.commonName;
        final sessionCount = group.sessionIds.length;

        return ExpansionTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 30,
              child: taxon != null
                  ? Image.asset(
                      taxon.assetImagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(MdiIcons.bird,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(MdiIcons.bird,
                          size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ),
            ),
          ),
          title: Text(displayName, style: theme.textTheme.titleSmall),
          subtitle: Text(
            showSciNames
                ? '${group.scientificName} · ${l10n.sessionSpeciesSessionCount(sessionCount)}'
                : l10n.sessionSpeciesSessionCount(sessionCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            for (final session
                in sessions.where((s) => group.sessionIds.contains(s.id)))
              ListTile(
                dense: true,
                leading: Icon(
                  _sessionTypeIcon(session.type),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  _sessionCardTitle(l10n, session),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(session.startTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => onTap(session),
              ),
          ],
        );
      },
    );
  }
}

class _SpeciesGroup {
  _SpeciesGroup({required this.scientificName, required this.commonName});
  final String scientificName;
  final String commonName;
  final Set<String> sessionIds = {};
}

// ─────────────────────────────────────────────────────────────────────────────
// Session size chip — shows total on-disk size of the recording or all
// per-detection clips for this session. Computed off the UI thread via
// [File.stat]; renders a placeholder while the future resolves and
// silently omits the chip when the session has no audio on disk.
// ─────────────────────────────────────────────────────────────────────────────

class _SessionSizeChip extends StatelessWidget {
  const _SessionSizeChip({required this.session});

  final LiveSession session;

  Future<int> _computeSize() async {
    var total = 0;
    // 1) Continuous session recording (live, point count, file analysis).
    final rec = session.recordingPath;
    if (rec != null) {
      try {
        final f = File(rec);
        if (await f.exists()) total += await f.length();
      } catch (_) {/* ignore */}
    }
    // 2) Per-detection clips (survey, or any session that kept clips
    //    instead of a full recording). Iterate in parallel-friendly
    //    chunks rather than all at once to avoid spamming the I/O pool.
    for (final d in session.detections) {
      final p = d.audioClipPath;
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) total += await f.length();
      } catch (_) {/* ignore */}
    }
    return total;
  }

  String _format(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}KB';
    final mb = kb / 1024.0;
    if (mb < 10) return '${mb.toStringAsFixed(1)}MB';
    if (mb < 1024) return '${mb.toStringAsFixed(0)}MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _computeSize(),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          // Reserve a fixed slot so the row layout doesn't shift when
          // the future resolves. Show a neutral placeholder.
          return const StatChip(
            icon: Icons.sd_storage_outlined,
            value: '…',
            variant: StatChipVariant.badge,
          );
        }
        if (bytes == 0) {
          // Don't bother showing 0B — saves a slot for sessions with
          // no on-disk audio (manual annotations only, or clips were
          // evicted by the survey sampler).
          return const SizedBox.shrink();
        }
        return StatChip(
          icon: Icons.sd_storage_outlined,
          value: _format(bytes),
          variant: StatChipVariant.badge,
        );
      },
    );
  }
}

/// Returns a localized display label for the given [SessionType].
String _sessionTypeLabel(AppLocalizations l10n, SessionType type) {
  switch (type) {
    case SessionType.live:
      return l10n.sessionTypeLive;
    case SessionType.fileUpload:
      return l10n.sessionTypeFileUpload;
    case SessionType.pointCount:
      return l10n.sessionTypePointCount;
    case SessionType.survey:
      return l10n.sessionTypeSurvey;
  }
}

/// Returns the icon matching the session type used on the home screen.
IconData _sessionTypeIcon(SessionType type) {
  switch (type) {
    case SessionType.live:
      return Icons.mic_rounded;
    case SessionType.fileUpload:
      return Icons.audio_file_rounded;
    case SessionType.pointCount:
      return Icons.location_on_rounded;
    case SessionType.survey:
      return Icons.route_rounded;
  }
}

/// Returns the top 5 most-detected species as (scientificName, commonName)
/// pairs, ordered by detection count.  The common name is the raw English
/// fallback — callers should translate via [TaxonomyService] if available.
List<MapEntry<String, String>> _topSpeciesSci(LiveSession session) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final d in session.detections) {
    counts[d.scientificName] = (counts[d.scientificName] ?? 0) + 1;
    names.putIfAbsent(d.scientificName, () => d.commonName);
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => MapEntry(e.key, names[e.key]!)).toList();
}

/// Returns a numbered card title such as "Live Session #3".
///
/// Falls back to the plain type label for legacy sessions without a number.
String _sessionCardTitle(AppLocalizations l10n, LiveSession session) {
  if (session.customName != null && session.customName!.isNotEmpty) {
    return session.customName!;
  }
  final n = session.sessionNumber;
  if (n == null) return _sessionTypeLabel(l10n, session.type);
  switch (session.type) {
    case SessionType.live:
      return l10n.sessionCardLiveNum(n);
    case SessionType.fileUpload:
      return l10n.sessionCardFileUploadNum(n);
    case SessionType.pointCount:
      return l10n.sessionCardPointCountNum(n);
    case SessionType.survey:
      return l10n.sessionCardSurveyNum(n);
  }
}
