// =============================================================================
// Survey Map Widget — Live map with GPS track and detection pins
// =============================================================================
//
// Displays OpenStreetMap tiles with the GPS track as a polyline and detection
// locations as species-icon markers.  Used both during an active survey
// and in session review.
//
// Privacy: Requires map tile consent (checked via SharedPreferences).
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/score_colors.dart';
import '../../../shared/models/gps_point.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/open_street_map_tile_layer.dart';
import '../../explore/explore_providers.dart';
import '../../live/live_session.dart';

/// Live map showing GPS track and detection markers.
///
/// [fitAllPoints] — if true, auto-fits the camera to show the entire track
/// and all detection markers (used in session review).  When false, the camera
/// auto-follows the latest GPS point (used during active survey).
///
/// [highlightedDetection] — if non-null, the map centers on this detection
/// and shows a pulsing ring around its marker.
///
/// [onCameraMove] — called whenever the camera moves, with the current
/// visible bounds.  Used by the review screen for map-based filtering.
class SurveyMapWidget extends ConsumerStatefulWidget {
  const SurveyMapWidget({
    super.key,
    required this.gpsTrack,
    required this.detections,
    this.autoFollow = true,
    this.fitAllPoints = false,
    this.highlightedDetection,
    this.onCameraMove,
    this.onMarkerTap,
    this.initialCenter,
    this.interactionOptions,
  });

  /// GPS track points.
  final List<GpsPoint> gpsTrack;

  /// Detections to show as markers.
  final List<DetectionRecord> detections;

  /// Whether the map auto-centers on the latest GPS point.
  final bool autoFollow;

  /// If true, fit camera to show all track points and detections.
  final bool fitAllPoints;

  /// Detection to highlight (center + pulsing ring).
  final DetectionRecord? highlightedDetection;

  /// Called when the camera moves with the visible bounds.
  final void Function(LatLngBounds bounds)? onCameraMove;

  /// Called when a species marker is tapped.
  final void Function(DetectionRecord detection)? onMarkerTap;

  /// Starting center when no GPS track points are available yet.
  /// Falls back to Berlin (52.52, 13.405) if null.
  final LatLng? initialCenter;

  /// Custom interaction options for controlling which gestures the map
  /// responds to.  When null, all gestures are enabled (the default).
  final InteractionOptions? interactionOptions;

  @override
  ConsumerState<SurveyMapWidget> createState() => _SurveyMapWidgetState();
}

class _SurveyMapWidgetState extends ConsumerState<SurveyMapWidget> {
  final MapController _mapController = MapController();
  bool? _hasConsent;
  int _lastTrackLength = 0;
  bool _initialFitDone = false;

  /// Tracks the current camera zoom so species markers can degrade to a
  /// solid colored dot when zoomed out (where the bird silhouette is too
  /// small to read), and the cluster layer can be turned off once the user
  /// is zoomed in enough to disambiguate individual pins.
  double _currentZoom = 14;

  /// Zoom at and above which species markers render the full silhouette.
  /// Below this zoom we show a solid colored dot sized by score, since the
  /// silhouette glyph collapses to a few pixels and reads as visual noise.
  static const double _silhouetteZoomThreshold = 14.5;

  /// Zoom at and above which clustering is disabled — at high zoom the
  /// pins are spatially distinct and grouping them just hides information.
  static const double _disableClusteringAtZoom = 15;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  @override
  void didUpdateWidget(covariant SurveyMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle highlight change — center on highlighted detection.
    if (widget.highlightedDetection != null &&
        widget.highlightedDetection != oldWidget.highlightedDetection) {
      final d = widget.highlightedDetection!;
      if (d.latitude != null && d.longitude != null) {
        _mapController.move(LatLng(d.latitude!, d.longitude!), 18);
      }
      return;
    }

    // Auto-follow: move camera when new GPS points arrive.
    if (widget.autoFollow &&
        !widget.fitAllPoints &&
        widget.gpsTrack.length != _lastTrackLength &&
        widget.gpsTrack.isNotEmpty) {
      _lastTrackLength = widget.gpsTrack.length;
      final last = widget.gpsTrack.last;
      _mapController.move(
        LatLng(last.latitude, last.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _checkConsent() {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _hasConsent = prefs.getBool(PrefKeys.mapTileConsent) ?? false;
    });
  }

  Future<void> _requestConsent() async {
    final l10n = AppLocalizations.of(context)!;
    final agreed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.mapTileConsentTitle),
            content: Text(l10n.mapTileConsentBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.mapTileConsentCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.mapTileConsentAllow),
              ),
            ],
          ),
    );
    if (agreed == true) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(PrefKeys.mapTileConsent, true);
      setState(() => _hasConsent = true);
    }
  }

  /// Compute bounds that contain all track points and detection locations.
  LatLngBounds? _allPointsBounds() {
    final points = <LatLng>[
      ...widget.gpsTrack.map((p) => LatLng(p.latitude, p.longitude)),
      ...widget.detections
          .where((d) => d.latitude != null && d.longitude != null)
          .map((d) => LatLng(d.latitude!, d.longitude!)),
    ];
    if (points.length < 2) return null;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasConsent != true) {
      return _buildConsentPlaceholder(context);
    }
    return _buildMap(context);
  }

  Widget _buildMap(BuildContext context) {
    final theme = Theme.of(context);

    // Build polyline from GPS track.
    final trackPoints =
        widget.gpsTrack.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Build detection markers with species icons.
    //
    // Species markers go into a separate list so they can be wrapped in a
    // [MarkerClusterLayerWidget] — overlapping pins at low zoom would
    // otherwise turn the map into a single unreadable blob (#33). Auxiliary
    // pins (start flag, current position) stay in a plain MarkerLayer above
    // the cluster layer because clustering them would defeat their purpose.
    final speciesMarkers = <Marker>[];
    final auxMarkers = <Marker>[];

    // When zoomed out, swap the bird silhouette for a solid colored dot
    // sized by score. The silhouette is only legible above roughly
    // [_silhouetteZoomThreshold] — below that the artwork collapses to a
    // few pixels and the dot's color (which already encodes confidence
    // after the CVD-safe palette swap) is the only thing that survives.
    final useDot = _currentZoom < _silhouetteZoomThreshold;

    // Group detections by location to prevent overlapping.
    // We show each unique species at each location once. When multiple
    // detections share a spot, prefer the one whose audio clip survived
    // the sampler AND is still on disk so the map's audio badge is
    // accurate; otherwise pick the highest-confidence record.
    final detectionsByLocation = <String, DetectionRecord>{};
    for (final det in widget.detections) {
      if (det.latitude == null || det.longitude == null) continue;
      // Key by rounded position + species to avoid duplicate icons.
      final key =
          '${det.latitude!.toStringAsFixed(5)}_${det.longitude!.toStringAsFixed(5)}_${det.scientificName}';
      final existing = detectionsByLocation[key];
      if (existing == null) {
        detectionsByLocation[key] = det;
        continue;
      }
      final existingHasAudio = _hasPlayableClip(existing);
      final candidateHasAudio = _hasPlayableClip(det);
      if (candidateHasAudio && !existingHasAudio) {
        detectionsByLocation[key] = det;
      } else if (candidateHasAudio == existingHasAudio &&
          det.confidence > existing.confidence) {
        detectionsByLocation[key] = det;
      }
    }

    for (final det in detectionsByLocation.values) {
      final isHighlighted =
          widget.highlightedDetection != null &&
          det.scientificName == widget.highlightedDetection!.scientificName &&
          det.timestamp == widget.highlightedDetection!.timestamp;
      final hasAudio = _hasPlayableClip(det);

      speciesMarkers.add(
        Marker(
          point: LatLng(det.latitude!, det.longitude!),
          // Uniform bounding box so audio and silent markers visually match —
          // the corner play badge needs a few extra pixels of padding either
          // way. Slightly larger than the pre-#33 sizes so silhouettes stay
          // legible when zoomed in.
          width: isHighlighted ? 56 : 44,
          height: isHighlighted ? 56 : 44,
          child: GestureDetector(
            onTap:
                widget.onMarkerTap != null
                    ? () => widget.onMarkerTap!(det)
                    : null,
            child: _SpeciesMarker(
              scientificName: det.scientificName,
              confidence: det.confidence,
              isHighlighted: isHighlighted,
              hasAudio: hasAudio,
              useDot: useDot,
            ),
          ),
        ),
      );
    }

    // Add start (flag) marker.
    if (trackPoints.isNotEmpty) {
      auxMarkers.add(
        Marker(
          point: trackPoints.first,
          width: 28,
          height: 28,
          child: Icon(
            Icons.flag_rounded,
            color: Colors.green.shade700,
            size: 28,
          ),
        ),
      );
    }

    // Current-position marker (live mode only). Falls back to the initial
    // center when no GPS fix has been recorded yet, so the user always sees
    // where the map is centered.
    if (!widget.fitAllPoints) {
      final LatLng? currentPosition =
          trackPoints.isNotEmpty ? trackPoints.last : widget.initialCenter;
      if (currentPosition != null) {
        auxMarkers.add(
          Marker(
            point: currentPosition,
            width: 28,
            height: 28,
            child: Icon(
              Icons.person_pin_circle_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
        );
      }
    }

    // Determine center and zoom.
    LatLng center;
    double zoom;
    if (widget.fitAllPoints) {
      // Will be adjusted via fitBounds after first frame.
      center =
          trackPoints.isNotEmpty
              ? trackPoints.first
              : const LatLng(52.52, 13.405);
      zoom = 14;
    } else if (trackPoints.isNotEmpty) {
      center = trackPoints.last;
      zoom = 18;
    } else {
      center = widget.initialCenter ?? const LatLng(52.52, 13.405);
      zoom = widget.initialCenter != null ? 18 : 10;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        maxZoom: 19,
        interactionOptions:
            widget.interactionOptions ?? const InteractionOptions(),
        onMapReady: () {
          // Initial zoom may have been adjusted by `fitCamera` below; sync
          // the cached value so the species markers pick the right
          // dot/silhouette form on the very first frame.
          if (mounted) {
            final z = _mapController.camera.zoom;
            if (z != _currentZoom) {
              setState(() => _currentZoom = z);
            }
          }
          if (widget.fitAllPoints && !_initialFitDone) {
            // Defer fitCamera to the next frame so the tile layer has
            // finished its initial layout and will request tiles for the
            // fitted bounds immediately.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitBoundsIfNeeded();
            });
          }
          // Report initial bounds.
          if (widget.onCameraMove != null) {
            widget.onCameraMove!(_mapController.camera.visibleBounds);
          }
        },
        onPositionChanged: (pos, hasGesture) {
          if (widget.onCameraMove != null) {
            widget.onCameraMove!(_mapController.camera.visibleBounds);
          }
          // Only rebuild when crossing the silhouette/dot threshold —
          // every camera tick would otherwise thrash the marker tree.
          final newZoom = pos.zoom;
          final wasDot = _currentZoom < _silhouetteZoomThreshold;
          final isDot = newZoom < _silhouetteZoomThreshold;
          if (wasDot != isDot && mounted) {
            setState(() => _currentZoom = newZoom);
          } else {
            _currentZoom = newZoom;
          }
        },
      ),
      children: [
        buildOpenStreetMapTileLayer(),
        if (trackPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: trackPoints,
                strokeWidth: 3,
                color: theme.colorScheme.primary.withAlpha(180),
              ),
            ],
          ),
        // Species pins live inside a cluster layer so dense surveys stay
        // legible at low zoom. Clustering automatically disables once the
        // user is zoomed in past [_disableClusteringAtZoom].
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,
            disableClusteringAtZoom: _disableClusteringAtZoom.toInt(),
            size: const Size(40, 40),
            padding: const EdgeInsets.all(50),
            markers: speciesMarkers,
            polygonOptions: PolygonOptions(
              borderColor: theme.colorScheme.primary.withAlpha(150),
              color: theme.colorScheme.primary.withAlpha(40),
              borderStrokeWidth: 2,
            ),
            builder: (context, clusterMarkers) {
              return _ClusterBubble(count: clusterMarkers.length);
            },
          ),
        ),
        // Auxiliary markers (start flag, current position) sit above the
        // cluster layer so they're never folded into a count bubble.
        MarkerLayer(markers: auxMarkers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap (ODbL)', onTap: () {}),
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }

  void _fitBoundsIfNeeded() {
    final bounds = _allPointsBounds();
    if (bounds == null) return;
    _initialFitDone = true;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
        maxZoom: 17,
      ),
    );
  }

  Widget _buildConsentPlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _requestConsent,
              icon: const Icon(Icons.map),
              label: Text(l10n.mapLoadButton),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mapLoadHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns true when a detection has a recorded clip that is still on disk.
/// We must check existence (not just the path) because clips may have been
/// deleted out-of-band (sampler eviction, manual cleanup, expired temp dir),
/// and we don't want to render a play badge for a marker whose tap would
/// silently no-op.
bool _hasPlayableClip(DetectionRecord det) {
  final path = det.audioClipPath;
  if (path == null) return false;
  return File(path).existsSync();
}

// ─────────────────────────────────────────────────────────────────────────────
// Species marker with thumbnail image
// ─────────────────────────────────────────────────────────────────────────────

class _SpeciesMarker extends ConsumerWidget {
  const _SpeciesMarker({
    required this.scientificName,
    required this.confidence,
    this.isHighlighted = false,
    this.hasAudio = false,
    this.useDot = false,
  });

  final String scientificName;
  final double confidence;
  final bool isHighlighted;
  final bool hasAudio;

  /// When true, render as a solid colored dot sized by score instead of the
  /// species silhouette. Used at low zoom where the silhouette collapses to
  /// a few unreadable pixels — the dot's color (CVD-safe) and outline weight
  /// still encode confidence, and clusters take care of overlap.
  final bool useDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Audio markers use the unified [ScoreColors] ramp for the avatar border;
    // silent markers fall back to a neutral grey so audio-bearing detections
    // visually stand out at a glance. The border *width* is also scaled by the
    // confidence bucket (1.5 px for very-low up to 3.5 px for very-high) so
    // the strength of a detection survives complete loss of color vision —
    // a heavier ring still reads as "stronger" in monochrome.
    final scoreColors = ScoreColors.of(context);
    final confidenceColor = scoreColors.forScore(confidence);
    final borderColor = hasAudio ? confidenceColor : Colors.grey.shade500;
    final bucket = ScoreColors.bucketIndexForScore(confidence);
    // 0 → 1.5, 1 → 2.0, 2 → 2.5, 3 → 3.0, 4 → 3.5
    final scoreBorderWidth = 1.5 + bucket * 0.5;

    // Low-zoom dot form: render a small colored circle whose diameter scales
    // with the confidence bucket (10 px → 18 px). Highlighted markers stay
    // larger so the user can still spot the focused detection. The audio
    // play badge is suppressed in this form because it would dominate a
    // 12 px dot and re-introduce the visual noise this branch is meant to
    // eliminate.
    if (useDot && !isHighlighted) {
      final dotSize = 10.0 + bucket * 2.0;
      final fill = hasAudio ? confidenceColor : Colors.grey.shade500;
      return Center(
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: hasAudio ? scoreBorderWidth : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    // Silent (no-audio) markers are noticeably smaller than audio ones so
    // the visual hierarchy reads at a glance — audio detections are the
    // primary content, silent ones are context. The highlighted size is also
    // shrunk for silent markers so a stray rebuild can never make a silent
    // marker visually outweigh an unhighlighted audio one.
    final size =
        isHighlighted
            ? (hasAudio ? 48.0 : 36.0)
            : (hasAudio ? 36.0 : 24.0);

    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final path =
        taxonomyAsync.valueOrNull?.assetImagePath(scientificName) ??
        'assets/images/dummy_species.png';

    // Silent markers are desaturated to grayscale so the user can tell at
    // a glance which detections have audio without having to spot the
    // small corner play badge. The confidence-colored border is preserved
    // (silent markers use a neutral grey there too) but the photo itself
    // reads as monochrome until a clip is attached.
    final ColorFilter? silentFilter =
        hasAudio
            ? null
            : const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]);

    Widget image = Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Container(
            color: borderColor.withAlpha(60),
            child: Icon(
              Icons.music_note,
              size: size * 0.45,
              color: borderColor,
            ),
          ),
    );
    if (silentFilter != null) {
      image = ColorFiltered(colorFilter: silentFilter, child: image);
    }

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighlighted ? Colors.blue : borderColor,
          width: isHighlighted ? 3 : (hasAudio ? scoreBorderWidth : 2),
        ),
        boxShadow: [
          BoxShadow(
            color:
                isHighlighted
                    ? Colors.blue.withAlpha(100)
                    : Colors.black.withAlpha(50),
            blurRadius: isHighlighted ? 8 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(child: image),
    );

    if (!hasAudio) return avatar;

    // Audio-bearing markers get a single affordance: a play badge anchored
    // to the avatar's bottom-right. We deliberately don't draw an outer
    // accent ring — that ring used to mask the confidence color encoded by
    // the avatar's own border, defeating the CVD-safe ramp. The play badge
    // alone is enough to signal "tap to hear this".
    final badgeColor = Theme.of(context).colorScheme.primary;
    final badgeSize = (size * 0.55).clamp(14.0, 22.0);
    final badgeOffset = badgeSize * 0.25;

    return SizedBox(
      width: size + badgeOffset,
      height: size + badgeOffset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Center(child: avatar),
          // Play badge anchored to the avatar's bottom-right.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: badgeSize * 0.85,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cluster bubble — shown by [MarkerClusterLayerWidget] when several species
// markers occupy the same screen region. The bubble's size grows with the
// log of the count so a 3-pin and a 300-pin cluster look meaningfully
// different at a glance.
// ─────────────────────────────────────────────────────────────────────────────

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scale 40 px → 64 px across log10(count) ≈ 0..3 (1 → 1000+).
    final scale = (count > 1) ? (1 + (count.bitLength - 1) * 0.06) : 1.0;
    final size = (40.0 * scale).clamp(40.0, 64.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
