// =============================================================================
// Session Export
// =============================================================================
//
// Generates export artifacts for a live session:
//
//   • **Raven selection table** (.txt): Tab-delimited annotation file
//     compatible with Raven Pro / Raven Lite.
//
//   • **CSV Export** (.csv): Standard comma-separated values.
//
//   • **JSON Export** (.json): Machine-readable JSON structured data.
//
//   • **ZIP bundle** (.zip): Optionally archives the full WAV/FLAC recording
//     together with the export document for convenient sharing.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../live/live_session.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// Generates a Raven Pro-compatible selection table from session detections.
String buildRavenSelectionTable(LiveSession session) {
  final buf = StringBuffer();

  // Header row.
  buf.writeln(
    'Selection\tView\tChannel\t'
    'Begin Time (s)\tEnd Time (s)\t'
    'Low Freq (Hz)\tHigh Freq (Hz)\t'
    'Common Name\tScientific Name\tConfidence',
  );

  final windowSeconds = session.settings.windowDuration;
  final sessionDurationSec = session.endTime != null
      ? session.endTime!.difference(session.startTime).inMilliseconds / 1000.0
      : 0.0;

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    final beginSec = isGlobal
        ? 0.0
        : d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;
    final endSec = isGlobal ? sessionDurationSec : beginSec + windowSeconds;

    buf.writeln(
      '${i + 1}\t'
      'Spectrogram 1\t'
      '1\t'
      '${beginSec.toStringAsFixed(3)}\t'
      '${endSec.toStringAsFixed(3)}\t'
      '0\t'
      '$_highFreqHz\t'
      '${d.commonName}\t'
      '${d.scientificName}\t'
      '${d.confidence.toStringAsFixed(4)}',
    );
  }

  return buf.toString();
}

/// Generates a standard CSV representation of session detections.
String buildCsvExport(LiveSession session) {
  final buf = StringBuffer();

  // Header row.
  buf.writeln(
      'Timestamp,Begin Time (s),Common Name,Scientific Name,Confidence');

  for (final d in session.detections) {
    final isGlobal = d.source == DetectionSource.manualGlobal;
    final beginSec = isGlobal
        ? 0.0
        : d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;

    // Simple CSV escaping for species names
    final commonName =
        d.commonName.contains(',') ? '"${d.commonName}"' : d.commonName;
    final sciName = d.scientificName.contains(',')
        ? '"${d.scientificName}"'
        : d.scientificName;

    buf.writeln(
      '${d.timestamp.toIso8601String()},'
      '${beginSec.toStringAsFixed(3)},'
      '$commonName,'
      '$sciName,'
      '${d.confidence.toStringAsFixed(4)}',
    );
  }

  return buf.toString();
}

/// Generates a JSON representation of the session and its detections.
String buildJsonExport(LiveSession session) {
  final map = {
    'session': session.displayName,
    'startTime': session.startTime.toIso8601String(),
    'endTime': session.endTime?.toIso8601String(),
    'recordingPath': session.recordingPath,
    'settings': {
      'windowDuration': session.settings.windowDuration,
      'confidenceThreshold': session.settings.confidenceThreshold,
      'inferenceRate': session.settings.inferenceRate,
      'speciesFilterMode': session.settings.speciesFilterMode,
    },
    if (session.trimStartSec != null) 'trimStartSec': session.trimStartSec,
    if (session.trimEndSec != null) 'trimEndSec': session.trimEndSec,
    'detections': session.detections.map((d) {
      final beginSec =
          d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;
      return {
        'timestamp': d.timestamp.toIso8601String(),
        'beginTimeSec': num.parse(beginSec.toStringAsFixed(3)),
        'commonName': d.commonName,
        'scientificName': d.scientificName,
        'confidence': num.parse(d.confidence.toStringAsFixed(4)),
        if (d.source != DetectionSource.auto) 'source': d.source.name,
      };
    }).toList(),
    if (session.annotations.isNotEmpty)
      'annotations': session.annotations.map((a) => a.toJson()).toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Creates an export bundle containing the session data and optionally audio.
///
/// If [includeAudio] is true and audio exists, returns a path to a .zip file.
/// If [includeAudio] is false or no audio exists, returns a path to the raw
/// text/json file.
Future<String?> buildSessionExport(
  LiveSession session, {
  required String format,
  required bool includeAudio,
}) async {
  final baseName = session.displayName;
  final audioPath = session.recordingPath;
  final hasAudio = audioPath != null && File(audioPath).existsSync();

  String fileContent;
  String extension;

  switch (format) {
    case 'csv':
      fileContent = buildCsvExport(session);
      extension = '.csv';
      break;
    case 'json':
      fileContent = buildJsonExport(session);
      extension = '.json';
      break;
    case 'gpx':
      fileContent = buildGpxExport(session);
      extension = '.gpx';
      break;
    case 'raven':
    default:
      fileContent = buildRavenSelectionTable(session);
      extension = '.selections.txt';
      break;
  }

  final bytes = Uint8List.fromList(utf8.encode(fileContent));

  if (includeAudio && hasAudio) {
    final archive = Archive();
    final audioExt = p.extension(audioPath);
    final audioBytes = await File(audioPath).readAsBytes();

    archive.addFile(
      ArchiveFile('$baseName$audioExt', audioBytes.length, audioBytes),
    );
    archive.addFile(
      ArchiveFile('$baseName$extension', bytes.length, bytes),
    );

    // Include annotations as a plain-text file if present.
    if (session.annotations.isNotEmpty) {
      final annotationsTxt = _buildAnnotationsText(session);
      final annotationsBytes = Uint8List.fromList(utf8.encode(annotationsTxt));
      archive.addFile(
        ArchiveFile('$baseName.annotations.txt', annotationsBytes.length,
            annotationsBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);

    final zipName = '$baseName.zip';
    final zipPath = p.join(p.dirname(audioPath), zipName);
    await File(zipPath).writeAsBytes(zipBytes);

    return zipPath;
  } else {
    // If no audio or user opted out of including audio, just write and share the doc file.
    final dir = hasAudio ? p.dirname(audioPath) : Directory.systemTemp.path;
    final filePath = p.join(dir, '$baseName$extension');
    await File(filePath).writeAsBytes(bytes);

    return filePath;
  }
}

/// Builds a human-readable text file of session annotations.
String _buildAnnotationsText(LiveSession session) {
  final buf = StringBuffer();
  buf.writeln('# Annotations for ${session.displayName}');
  buf.writeln('# Session: ${session.startTime.toIso8601String()}');
  buf.writeln();

  for (final a in session.annotations) {
    if (a.offsetInRecording != null) {
      final m = a.offsetInRecording! ~/ 60;
      final s = (a.offsetInRecording! % 60).toInt();
      buf.write(
          '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}] ');
    } else {
      buf.write('[Global] ');
    }
    buf.writeln(a.text);
  }

  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// GPX Export — GPS track + detection waypoints
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a GPX 1.1 document from a survey session.
///
/// Contains:
///   • `<trk>` with `<trkseg>` of GPS track points
///   • `<wpt>` for each detection with lat/lon coordinates
String buildGpxExport(LiveSession session) {
  final buf = StringBuffer();

  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln('<gpx version="1.1" creator="BirdNET Live"');
  buf.writeln('  xmlns="http://www.topografix.com/GPX/1/1"');
  buf.writeln('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
  buf.writeln('  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd">');

  // Metadata.
  buf.writeln('  <metadata>');
  buf.writeln('    <name>${_xmlEscape(session.displayName)}</name>');
  buf.writeln(
      '    <time>${session.startTime.toUtc().toIso8601String()}</time>');
  if (session.observerName != null && session.observerName!.isNotEmpty) {
    buf.writeln(
        '    <author><name>${_xmlEscape(session.observerName!)}</name></author>');
  }
  buf.writeln('  </metadata>');

  // Detection waypoints.
  for (final d in session.detections) {
    if (d.latitude == null || d.longitude == null) continue;
    buf.writeln('  <wpt lat="${d.latitude}" lon="${d.longitude}">');
    buf.writeln('    <time>${d.timestamp.toUtc().toIso8601String()}</time>');
    buf.writeln('    <name>${_xmlEscape(d.commonName)}</name>');
    buf.writeln(
        '    <desc>${_xmlEscape(d.scientificName)} (${(d.confidence * 100).toStringAsFixed(1)}%)</desc>');
    buf.writeln('  </wpt>');
  }

  // GPS track.
  if (session.gpsTrack.isNotEmpty) {
    final trackName = session.transectId ?? session.displayName;
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_xmlEscape(trackName)}</name>');
    buf.writeln('    <trkseg>');
    for (final pt in session.gpsTrack) {
      buf.write('      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">');
      if (pt.altitude != null) {
        buf.write('<ele>${pt.altitude!.toStringAsFixed(1)}</ele>');
      }
      buf.write('<time>${pt.timestamp.toUtc().toIso8601String()}</time>');
      buf.writeln('</trkpt>');
    }
    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
  }

  buf.writeln('</gpx>');
  return buf.toString();
}

/// XML-safe escaping for attribute and text content.
String _xmlEscape(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
