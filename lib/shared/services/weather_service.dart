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
//     same site).
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/weather_snapshot.dart';

class WeatherService {
  WeatherService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;
  final Map<String, WeatherSnapshot> _cache = {};

  /// Open-Meteo forecast endpoint. Returns hourly observations for the
  /// current day; we extract the hour closest to [observedAt].
  static const String _endpoint =
      'https://api.open-meteo.com/v1/forecast';

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
    final allowed =
        prefs.getBool(PrefKeys.privacyAllowWeather) ?? false;
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
          .get(
            uri,
            headers: const {'User-Agent': 'BirdNET-Live/1.0'},
          )
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
