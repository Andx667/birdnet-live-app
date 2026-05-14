// =============================================================================
// WeatherService
// =============================================================================
//
// Thin Open-Meteo client used to capture a one-shot [WeatherSnapshot]
// for a session at save time. Open-Meteo is free, key-less, and does
// not require attribution beyond a polite User-Agent header.
//
// Design notes:
//   • This is *fire-and-forget* from the controller's perspective: a
//     network failure must never block saving a session, so every call
//     site wraps the future in a `try/catch` (or simply ignores the
//     null return).
//   • Privacy gate: the [PrefKeys.privacyAllowWeather] toggle is
//     checked on every call. When the user has not consented, this
//     service returns `null` *without* hitting the network.
//   • The lookup picks the hour closest to [observedAt] from the
//     hourly forecast/observation block returned by Open-Meteo, which
//     gives consistent values regardless of whether the session ended
//     a few minutes into a new hour.
//   • A small in-process cache deduplicates repeated lookups for the
//     same coarse cell + hour during a single app run (e.g. when a
//     point-count session and the live mode finish back-to-back at the
//     same site). On top of that, every successful fetch is persisted
//     to [SharedPreferences] under [PrefKeys.weatherCachePrefix] so that
//     a fresh app launch within [_cacheTtl] reuses the same snapshot
//     for nearby coordinates instead of re-hitting Open-Meteo. The
//     persistent cache is keyed by a 0.1° cell (~10 km) so trips that
//     stay around the same site share one fetch for several sessions.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/weather_snapshot.dart';

class WeatherService {
  WeatherService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;
  final Map<String, WeatherSnapshot> _cache = {};

  /// How long a persisted snapshot stays valid. Birds don't care if the
  /// wind shifts by 0.5 m/s mid-morning, so a coarse 6 h window is plenty
  /// for survey-context use and avoids hammering Open-Meteo on days when
  /// the user runs many short sessions back-to-back.
  static const Duration _cacheTtl = Duration(hours: 6);

  /// Open-Meteo forecast endpoint. Returns hourly observations for the
  /// current day; we extract the hour closest to [observedAt].
  static const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Builds the persistent-cache key for a 0.1° cell.
  String _cellKey(double lat, double lon) {
    final cellLat = (lat * 10).round() / 10;
    final cellLon = (lon * 10).round() / 10;
    return '${PrefKeys.weatherCachePrefix}${cellLat.toStringAsFixed(1)}_'
        '${cellLon.toStringAsFixed(1)}';
  }

  /// Fetches a [WeatherSnapshot] for the given coordinates and time.
  ///
  /// Returns `null` when:
  ///   • the user has not enabled the weather privacy gate,
  ///   • the network request fails, times out, or returns a malformed
  ///     payload, or
  ///   • Open-Meteo returns no hourly data for the requested cell
  ///     (e.g. polar regions outside the model's coverage).
  Future<WeatherSnapshot?> fetch({
    required double latitude,
    required double longitude,
    DateTime? observedAt,
  }) async {
    // Privacy gate.
    final prefs = await SharedPreferences.getInstance();
    final allowed = prefs.getBool(PrefKeys.privacyAllowWeather) ?? false;
    if (!allowed) return null;

    final at = (observedAt ?? DateTime.now()).toUtc();

    // Cache key: 0.1° cell + truncated hour. Open-Meteo's spatial
    // resolution is much coarser than 0.1°, so this is a safe dedupe
    // key without losing meaningful precision.
    final cellLat = (latitude * 10).round() / 10;
    final cellLon = (longitude * 10).round() / 10;
    final hourKey = DateTime.utc(at.year, at.month, at.day, at.hour);
    final cacheKey = '$cellLat,$cellLon,${hourKey.toIso8601String()}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    // Persistent (cross-launch) cache: any successful fetch for the
    // same 0.1° cell within the last [_cacheTtl] is considered fresh
    // enough to reuse, so multiple short sessions at the same site
    // don't repeatedly hit the network.
    final persistentKey = _cellKey(latitude, longitude);
    final persistedRaw = prefs.getString(persistentKey);
    if (persistedRaw != null) {
      try {
        final decoded = json.decode(persistedRaw) as Map<String, dynamic>;
        final snap = WeatherSnapshot.fromJson(decoded);
        if (snap != null) {
          final age = DateTime.now().toUtc().difference(snap.fetchedAt);
          if (age >= Duration.zero && age < _cacheTtl) {
            _cache[cacheKey] = snap;
            return snap;
          }
        }
      } catch (_) {
        // Ignore corrupt cache entries; we'll overwrite on success.
      }
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'hourly':
            'temperature_2m,precipitation,wind_speed_10m,'
            'wind_direction_10m,cloud_cover,weather_code',
        'wind_speed_unit': 'ms',
        'timezone': 'UTC',
        'past_days': '1',
        'forecast_days': '1',
      },
    );

    try {
      final resp = await _client
          .get(uri, headers: const {'User-Agent': 'BirdNET-Live/1.0'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final hourly = body['hourly'];
      if (hourly is! Map<String, dynamic>) return null;
      final times = hourly['time'];
      if (times is! List || times.isEmpty) return null;

      // Find the index of the hour closest to `at`.
      var bestIdx = 0;
      var bestDelta = const Duration(days: 365);
      for (var i = 0; i < times.length; i++) {
        final raw = times[i];
        if (raw is! String) continue;
        final t = DateTime.tryParse(raw);
        if (t == null) continue;
        final delta = (t.difference(at)).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          bestIdx = i;
        }
      }

      double? readDouble(String key) {
        final list = hourly[key];
        if (list is! List || bestIdx >= list.length) return null;
        final v = list[bestIdx];
        if (v is num) return v.toDouble();
        return null;
      }

      int? readInt(String key) => readDouble(key)?.toInt();

      final observedRaw = times[bestIdx];
      final observed =
          observedRaw is String ? DateTime.tryParse(observedRaw) : null;

      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime.now().toUtc(),
        observedAt: observed,
        temperatureC: readDouble('temperature_2m'),
        precipitationMm: readDouble('precipitation'),
        windSpeedMs: readDouble('wind_speed_10m'),
        windDirectionDeg: readDouble('wind_direction_10m'),
        cloudCoverPercent: readInt('cloud_cover'),
        weatherCode: readInt('weather_code'),
      );

      _cache[cacheKey] = snapshot;
      // Best-effort persist; ignore errors so a failing prefs write
      // never blocks returning a fresh snapshot to the caller.
      try {
        await prefs.setString(persistentKey, json.encode(snapshot.toJson()));
      } catch (_) {
        /* non-fatal */
      }
      return snapshot;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

/// App-wide singleton [WeatherService]. Disposed when the provider
/// container is disposed (which only happens at app shutdown).
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final svc = WeatherService();
  ref.onDispose(svc.dispose);
  return svc;
});
