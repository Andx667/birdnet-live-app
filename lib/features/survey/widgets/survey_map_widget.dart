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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/gps_point.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
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
        _mapController.move(
          LatLng(d.latitude!, d.longitude!),
          18,
        );
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
      builder: (context) => AlertDialog(
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
    final markers = <Marker>[];

    // Group detections by location to prevent overlapping.
    // We show each unique species at each location once.
    final detectionsByLocation = <String, DetectionRecord>{};
    for (final det in widget.detections) {
      if (det.latitude == null || det.longitude == null) continue;
      // Key by rounded position + species to avoid duplicate icons.
      final key =
          '${det.latitude!.toStringAsFixed(5)}_${det.longitude!.toStringAsFixed(5)}_${det.scientificName}';
      final existing = detectionsByLocation[key];
      if (existing == null || det.confidence > existing.confidence) {
        detectionsByLocation[key] = det;
      }
    }

    for (final det in detectionsByLocation.values) {
      final isHighlighted = widget.highlightedDetection != null &&
          det.scientificName == widget.highlightedDetection!.scientificName &&
          det.timestamp == widget.highlightedDetection!.timestamp;

      markers.add(
        Marker(
          point: LatLng(det.latitude!, det.longitude!),
          width: isHighlighted ? 44 : 32,
          height: isHighlighted ? 44 : 32,
          child: _SpeciesMarker(
            scientificName: det.scientificName,
            confidence: det.confidence,
            isHighlighted: isHighlighted,
          ),
        ),
      );
    }

    // Add start/end markers.
    if (trackPoints.isNotEmpty) {
      markers.insert(
        0,
        Marker(
          point: trackPoints.first,
          width: 28,
          height: 28,
          child:
              Icon(Icons.flag_rounded, color: Colors.green.shade700, size: 28),
        ),
      );
      if (trackPoints.length > 1 && !widget.fitAllPoints) {
        markers.add(
          Marker(
            point: trackPoints.last,
            width: 28,
            height: 28,
            child: Icon(Icons.person_pin_circle_rounded,
                color: theme.colorScheme.primary, size: 28),
          ),
        );
      }
    }

    // Determine center and zoom.
    LatLng center;
    double zoom;
    if (widget.fitAllPoints) {
      // Will be adjusted via fitBounds after first frame.
      center = trackPoints.isNotEmpty
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
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'birdnet_live',
          tileProvider: _CachingTileProvider(),
        ),
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
        MarkerLayer(markers: markers),
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
            Icon(Icons.map_outlined,
                size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Species marker with thumbnail image
// ─────────────────────────────────────────────────────────────────────────────

class _SpeciesMarker extends StatelessWidget {
  const _SpeciesMarker({
    required this.scientificName,
    required this.confidence,
    this.isHighlighted = false,
  });

  final String scientificName;
  final double confidence;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final borderColor = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.5
            ? Colors.amber.shade700
            : Colors.red;

    final size = isHighlighted ? 40.0 : 28.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighlighted ? Colors.blue : borderColor,
          width: isHighlighted ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.blue.withAlpha(100)
                : Colors.black.withAlpha(50),
            blurRadius: isHighlighted ? 8 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: TaxonomyService.thumbUrl(scientificName),
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: borderColor.withAlpha(60),
            child:
                Icon(Icons.music_note, size: size * 0.45, color: borderColor),
          ),
          errorWidget: (_, __, ___) => Container(
            color: borderColor.withAlpha(60),
            child:
                Icon(Icons.music_note, size: size * 0.45, color: borderColor),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caching tile provider
// ─────────────────────────────────────────────────────────────────────────────

class _CachingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
    );
  }
}
