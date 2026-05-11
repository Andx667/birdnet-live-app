// =============================================================================
// Location Service — GPS position provider
// =============================================================================
//
// Wraps the `geolocator` package to provide a clean, reusable interface for
// obtaining the device's GPS coordinates.  Used by:
//
//   - **Explore screen** — to fetch species for the current location
//   - **Live mode** — to run the geo-model before starting inference
//   - **Survey / Point Count** — for geotagging sessions
//
// The service handles permission checking, position fetching, and error
// reporting.  It does NOT request permissions — that responsibility lies
// with the UI layer (onboarding, permission prompts).
//
// ### Position caching
//
// The last known position is cached so that callers can display stale data
// while a fresh fix is being acquired.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Simplified location data — lat/lon only.
class AppLocation {
  const AppLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'AppLocation(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

/// GPS location provider.
///
/// Provides current position, permission status, and a cached last position.
/// Designed to be held as a long-lived singleton or Riverpod provider.
class LocationService {
  LocationService();

  AppLocation? _lastKnownLocation;

  /// Whether the most recent [getCurrentLocation] call returned a cached
  /// last-known position because the live fix timed out. Callers can read
  /// this immediately after the future resolves to surface a "GPS is
  /// stale" warning to the user.
  bool _lastFetchUsedCachedFallback = false;

  /// The most recently fetched location (may be stale).
  AppLocation? get lastKnownLocation => _lastKnownLocation;

  /// True when the most recent [getCurrentLocation] returned a cached
  /// position because the live fix could not be acquired in time.
  bool get lastFetchUsedCachedFallback => _lastFetchUsedCachedFallback;

  /// Check whether the device's location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check the current location permission status.
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission from the user.
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Returns true if we have at least [LocationPermission.whileInUse].
  Future<bool> hasPermission() async {
    final perm = await checkPermission();
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Get the current GPS position.
  ///
  /// Returns the position or `null` if location services are disabled or
  /// permission is denied.  Updates [lastKnownLocation] on success.
  Future<AppLocation?> getCurrentLocation() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] location services disabled');
        return _lastKnownLocation;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        debugPrint('[LocationService] permission denied: $permission');
        return _lastKnownLocation;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        _lastKnownLocation = AppLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _lastFetchUsedCachedFallback = false;
        debugPrint('[LocationService] got position: $_lastKnownLocation');
        return _lastKnownLocation;
      } on TimeoutException {
        // No fresh fix within the timeout (e.g. weak GPS signal or first cold
        // start indoors). Fall back to the OS-cached last-known position so
        // callers still get something usable, then return whatever we have.
        debugPrint(
          '[LocationService] no fresh fix within 10s, using last known',
        );
        final cached = await Geolocator.getLastKnownPosition();
        if (cached != null) {
          _lastKnownLocation = AppLocation(
            latitude: cached.latitude,
            longitude: cached.longitude,
          );
        }
        _lastFetchUsedCachedFallback = true;
        return _lastKnownLocation;
      }
    } catch (e) {
      debugPrint('[LocationService] error getting position: $e');
      return _lastKnownLocation;
    }
  }

  /// Set a manual location (for testing or user override).
  void setManualLocation(double latitude, double longitude) {
    _lastKnownLocation = AppLocation(latitude: latitude, longitude: longitude);
  }
}
