// =============================================================================
// Reverse Geocoding Service
// =============================================================================
//
// Thin wrapper around the OpenStreetMap Nominatim API for reverse geocoding.
//
// The service converts latitude/longitude coordinates into a human-readable
// place name such as "Berlin, Germany".  Results are NOT cached in-memory here
// because LiveSession persists the resolved `locationName` to disk.
//
// The Nominatim Usage Policy requires:
//   • A descriptive User-Agent header (no generic strings).
//   • At most 1 request per second.
//   • No bulk/automated geocoding.
// We satisfy these by sending a single request per session review.
//
// Privacy: gated by [PrefKeys.mapTileConsent].  Both reverse geocoding and
// map tile fetches send coordinates to OpenStreetMap infrastructure, so we
// reuse the same user consent gate.  When the user has not yet approved
// map tiles, this function returns `null` without making any network call.
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Attempts to reverse-geocode [latitude]/[longitude] into a short place name.
///
/// Returns a human-readable string (e.g. "Berlin, Germany") or `null` when
/// the user has not consented to OpenStreetMap network requests, the network
/// is unavailable, or the API response is unusable.
///
/// Uses the OpenStreetMap Nominatim API which is free and GDPR-friendly.
/// Reuses [PrefKeys.mapTileConsent] as the consent gate since both endpoints
/// belong to OpenStreetMap.
Future<String?> reverseGeocode({
  required double latitude,
  required double longitude,
}) async {
  // Privacy gate: only proceed when the user has approved OSM network access.
  final prefs = await SharedPreferences.getInstance();
  final hasConsent = prefs.getBool(PrefKeys.mapTileConsent) ?? false;
  if (!hasConsent) return null;

  final uri = Uri.https(
    'nominatim.openstreetmap.org',
    '/reverse',
    {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'zoom': '10',
      'addressdetails': '1',
    },
  );

  try {
    final response = await http
        .get(uri, headers: {'User-Agent': 'BirdNET-Live/1.0'}).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final address = json['address'] as Map<String, dynamic>?;
    if (address == null) return json['display_name'] as String?;

    // Build a short, readable label from the address components.
    final city = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'];
    final state = address['state'];
    final country = address['country'];

    final parts = <String>[
      if (city != null) city as String,
      if (state != null && state != city) state as String,
      if (country != null) country as String,
    ];

    return parts.isNotEmpty
        ? parts.join(', ')
        : json['display_name'] as String?;
  } catch (_) {
    // Network error, timeout, or bad JSON — fail silently.
    return null;
  }
}
