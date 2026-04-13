// =============================================================================
// GPS Point — A single timestamped location on a survey GPS track
// =============================================================================
//
// Lightweight, immutable data class used for:
//
//   - Building the polyline track during survey mode.
//   - Tagging detections with their approximate location.
//   - Exporting survey tracks as GPX files.
//
// The [measured] flag distinguishes real GPS fixes from positions
// interpolated during finalization (when background location was denied).
// =============================================================================

/// A single point on the GPS track with timestamp.
class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.accuracy,
    this.measured = true,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Meters above sea level (null if unavailable).
  final double? altitude;

  /// Horizontal accuracy in meters (null if unavailable).
  final double? accuracy;

  /// When this point was recorded.
  final DateTime timestamp;

  /// Whether this is a real GPS measurement or an interpolated point.
  final bool measured;

  /// Deserialize from JSON.
  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    return GpsPoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      altitude: (json['alt'] as num?)?.toDouble(),
      accuracy: (json['acc'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['t'] as String),
      measured: json['m'] as bool? ?? true,
    );
  }

  /// Serialize to JSON (compact keys to minimize file size for long tracks).
  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        if (altitude != null) 'alt': altitude,
        if (accuracy != null) 'acc': accuracy,
        't': timestamp.toIso8601String(),
        if (!measured) 'm': false,
      };

  @override
  String toString() =>
      'GpsPoint($latitude, $longitude, ${measured ? "measured" : "interpolated"})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPoint &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(latitude, longitude, timestamp);
}
