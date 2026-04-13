// =============================================================================
// Survey Session Serialization Tests — GPS track, distance, metadata
// =============================================================================

import 'dart:convert';

import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2025, 7, 1, 8, 0, 0);
  final settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 25,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  group('LiveSession survey fields', () {
    test('roundtrips gpsTrack through JSON', () {
      final session = LiveSession(
        id: 'test-survey',
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        type: SessionType.survey,
        settings: settings,
        gpsTrack: [
          GpsPoint(
            latitude: 52.52,
            longitude: 13.405,
            timestamp: start,
            altitude: 34.5,
          ),
          GpsPoint(
            latitude: 52.521,
            longitude: 13.406,
            timestamp: start.add(const Duration(seconds: 10)),
          ),
        ],
        distanceMeters: 150.5,
        transectId: 'T-001',
        observerName: 'Jane Doe',
      );

      final json = session.toJson();
      final restored = LiveSession.fromJson(json);

      expect(restored.type, SessionType.survey);
      expect(restored.gpsTrack.length, 2);
      expect(restored.gpsTrack[0].latitude, 52.52);
      expect(restored.gpsTrack[0].altitude, 34.5);
      expect(restored.gpsTrack[1].latitude, 52.521);
      expect(restored.distanceMeters, 150.5);
      expect(restored.transectId, 'T-001');
      expect(restored.observerName, 'Jane Doe');
    });

    test('omits survey fields from JSON when null/empty', () {
      final session = LiveSession(
        id: 'test-live',
        startTime: start,
        settings: settings,
      );

      final json = session.toJson();
      expect(json.containsKey('gpsTrack'), isFalse);
      expect(json.containsKey('distanceMeters'), isFalse);
      expect(json.containsKey('transectId'), isFalse);
      expect(json.containsKey('observerName'), isFalse);
    });

    test('gpsTrack defaults to empty list', () {
      final session = LiveSession(
        id: 'test',
        startTime: start,
        settings: settings,
      );

      expect(session.gpsTrack, isEmpty);
    });

    test('DetectionRecord roundtrips lat/lon', () {
      final det = DetectionRecord(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        confidence: 0.85,
        timestamp: start,
        latitude: 52.52,
        longitude: 13.405,
      );

      final json = det.toJson();
      final restored = DetectionRecord.fromJson(json);

      expect(restored.latitude, 52.52);
      expect(restored.longitude, 13.405);
    });

    test('DetectionRecord without lat/lon serializes without those keys', () {
      final det = DetectionRecord(
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        confidence: 0.85,
        timestamp: start,
      );

      final json = det.toJson();
      expect(json.containsKey('detLat'), isFalse);
      expect(json.containsKey('detLon'), isFalse);
    });

    test('full round-trip through JSON encode/decode', () {
      final session = LiveSession(
        id: 'roundtrip-survey',
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        type: SessionType.survey,
        settings: settings,
        gpsTrack: [
          GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: start),
        ],
        distanceMeters: 500,
        transectId: 'T-002',
        observerName: 'John',
        detections: [
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.9,
            timestamp: start.add(const Duration(minutes: 5)),
            latitude: 52.52,
            longitude: 13.405,
          ),
        ],
      );

      final jsonStr = jsonEncode(session.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = LiveSession.fromJson(decoded);

      expect(restored.type, SessionType.survey);
      expect(restored.gpsTrack.length, 1);
      expect(restored.detections.length, 1);
      expect(restored.detections.first.latitude, 52.52);
      expect(restored.distanceMeters, 500);
      expect(restored.transectId, 'T-002');
      expect(restored.observerName, 'John');
    });
  });
}
