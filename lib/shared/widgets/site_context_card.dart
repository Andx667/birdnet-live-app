// =============================================================================
// SiteContextCard
// =============================================================================
//
// Compact, network-aware card showing the two pieces of *site context*
// the app collects from external services for any GPS-located session:
//
//   • Place name  (Nominatim reverse geocoding)
//   • Weather     (Open-Meteo)
//
// Used by the survey and point-count setup wizards' "Ready" step so the
// user can see *what will be captured* before they tap Start. Both calls
// hit the persistent caches (reverse-geocode no-TTL, weather 6 h) which
// means visiting the same site twice never re-hits the network, and
// session-end captures will be cache-fast too.
//
// Both calls are best-effort:
//   • If consent is off or the network is unreachable, the corresponding
//     row is hidden and the card simply gets smaller.
//   • If both fail, the card renders nothing (returns SizedBox.shrink).
//
// Layout follows the same compact chip style used in session review:
// icon + value, single line per service. No headings, no borders \u2014
// the parent's Card wraps it.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reverse_geocoding_service.dart';
import '../models/weather_snapshot.dart';
import '../services/weather_service.dart';
import '../utils/weather_format.dart';

class SiteContextCard extends ConsumerStatefulWidget {
  const SiteContextCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.observedAt,
  });

  final double latitude;
  final double longitude;

  /// Timestamp the weather should describe. Defaults to "now" when null,
  /// which is the right choice for the setup wizard (the user is about
  /// to start recording).
  final DateTime? observedAt;

  @override
  ConsumerState<SiteContextCard> createState() => _SiteContextCardState();
}

class _SiteContextCardState extends ConsumerState<SiteContextCard> {
  String? _locationName;
  WeatherSnapshot? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SiteContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when the user changes the location (manual entry,
    // re-tap GPS, etc.). Cache hits make this cheap.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _locationName = null;
        _weather = null;
        _loading = true;
      });
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final lat = widget.latitude;
    final lon = widget.longitude;

    String? name;
    try {
      name = await reverseGeocode(latitude: lat, longitude: lon);
    } catch (_) {
      /* non-fatal */
    }

    WeatherSnapshot? weather;
    try {
      final svc = ref.read(weatherServiceProvider);
      weather = await svc.fetch(
        latitude: lat,
        longitude: lon,
        observedAt: widget.observedAt ?? DateTime.now(),
      );
    } catch (_) {
      /* non-fatal */
    }

    if (!mounted) return;
    setState(() {
      _locationName = name;
      _weather = weather;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    if (_loading && _locationName == null && _weather == null) {
      // Single-line placeholder while both lookups are in flight \u2014
      // avoids a layout pop when results arrive.
      return SizedBox(
        height: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    if (_locationName != null) {
      rows.add(
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationName!,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    if (_weather != null) {
      final cond = weatherConditionFromCode(_weather!.weatherCode);
      rows.add(
        Row(
          children: [
            Icon(
              weatherConditionIcon(cond),
              size: 18,
              color: onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              formatTemperature(_weather!.temperatureC),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
      ],
    );
  }
}
