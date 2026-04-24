// =============================================================================
// Session Export
// =============================================================================
//
// Generates export artifacts for a live session:
//
//   • **Raven selection table** (.selections.txt): Tab-delimited annotation
//     file compatible with Raven Pro / Raven Lite.  Includes a `Begin File`
//     column so Raven can resolve audio references in both single-file and
//     multi-clip bundles.
//
//   • **CSV Export** (.csv): Standard comma-separated values with a `File`
//     column for audio reference.
//
//   • **JSON Export** (.json): Machine-readable JSON structured data.
//
//   • **ZIP bundle** (.zip): Optionally archives audio (full recording or
//     individual detection clips) together with the export document.
//
// Naming convention:
//   Prefix:     BirdNET_Live_YYYY-MM-DD_HH-MM-SS[_#N][_Custom_Name]
//   Full audio: <prefix>.flac / .wav
//   Clips:      <prefix>_clip_001_Species_Name.flac, …
//   Table:      <prefix>.selections.txt / .csv / .json / .gpx
//   Bundle:     <prefix>.zip
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../shared/services/taxonomy_service.dart';
import '../live/live_session.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// Builds the `BirdNET_Live_…` export prefix from a session's start time,
/// optional session number, and optional user-assigned name.
///
/// Examples:
///   `BirdNET_Live_2026-04-15_08-00-00_#3`
///   `BirdNET_Live_2026-04-15_08-00-00_Morning_walk`
String _exportPrefix(LiveSession session) {
  final dt = DateFormat('yyyy-MM-dd_HH-mm-ss').format(session.startTime);
  final suffix =
      session.sessionNumber != null ? '_#${session.sessionNumber}' : '';
  final name = session.customName != null && session.customName!.isNotEmpty
      ? '_${_sanitizeFilename(session.customName!)}'
      : '';
  return 'BirdNET_Live_$dt$suffix$name';
}

/// Replaces characters that are illegal in filenames with underscores and
/// collapses runs of whitespace / underscores.
String _sanitizeFilename(String input) {
  return input
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// Resolves the locale-appropriate common name for a detection.
///
/// Falls back to the detection's stored common name (English label from the
/// classifier) when no taxonomy is supplied or no translation is available.
String _localizedCommon(
  DetectionRecord d, {
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
}) {
  if (taxonomy == null) return d.commonName;
  final sp = taxonomy.lookup(d.scientificName);
  if (sp == null) return d.commonName;
  final localized = sp.commonNameForLocale(speciesLocale);
  return localized.isNotEmpty ? localized : d.commonName;
}

/// Generates a Raven Pro-compatible selection table from session detections.
///
/// When [audioFileName] is provided every row references that single file.
/// When [clipFileMap] is provided (detection index → clip filename), rows with
/// a clip reference that file; rows without a clip get an empty `Begin File`.
///
/// Time semantics:
///   • For rows referencing a per-detection **clip**, `Begin/End Time` are
///     offsets *within the clip*. With pre/post context of
///     [SessionSettings.clipContextSeconds] seconds, the detection sits at
///     `[clipContext, clipContext + windowDuration]`.
///   • For rows referencing the **full recording** (or no audio), `Begin/End
///     Time` are session-relative offsets.
///   • When ANY row references a clip, an extra `Survey Time (s)` column is
///     appended for every row with the session-relative offset, so survey
///     analysts can recover the timeline of detections across clips.
///
/// Common Name is rendered in the user's species locale when [taxonomy] is
/// supplied; Scientific Name is always emitted regardless of any UI toggle
/// so the export remains scientifically authoritative.
///
/// Latitude / Longitude columns are included when any detection has
/// coordinates (typical for surveys).
String buildRavenSelectionTable(
  LiveSession session, {
  String? audioFileName,
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
}) {
  final buf = StringBuffer();
  final hasCoords =
      session.detections.any((d) => d.latitude != null && d.longitude != null);
  final hasClips = clipFileMap != null && clipFileMap.isNotEmpty;
  // Prefer the per-session value, but allow callers to override (e.g. legacy
  // sessions persisted before [SessionSettings.clipContextSeconds] existed,
  // where the field defaults to 0 and would falsely place every detection at
  // the very start of every clip).
  final clipContext = (clipContextSecondsOverride ??
          session.settings.clipContextSeconds)
      .toDouble();

  // Header row — 'Begin File' is a standard Raven column for multi-file
  // selection tables. 'Survey Time (s)' is non-standard but harmless to Raven
  // (extra columns are ignored on import) and lets analysts cross-reference
  // detections back to the survey timeline.
  buf.writeln(
    'Selection\tView\tChannel\tBegin File\t'
    'Begin Time (s)\tEnd Time (s)\t'
    'Low Freq (Hz)\tHigh Freq (Hz)\t'
    'Common Name\tScientific Name\tConfidence'
    '${hasClips ? '\tSurvey Time (s)' : ''}'
    '${hasCoords ? '\tLatitude\tLongitude' : ''}',
  );

  final windowSeconds = session.settings.windowDuration;
  final sessionDurationSec = session.endTime != null
      ? session.endTime!.difference(session.startTime).inMilliseconds / 1000.0
      : 0.0;

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    // File reference: clip name (if available) > full recording > empty.
    final clipName = clipFileMap?[i];
    final beginFile = clipName ?? audioFileName ?? '';
    final referencesClip = clipName != null;

    // Session-relative offset (always computed; used for either Begin Time or
    // the auxiliary Survey Time column).
    final surveySec = isGlobal
        ? 0.0
        : d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;

    // Begin/End times depend on whether the row references a clip file.
    final double beginSec;
    final double endSec;
    if (referencesClip) {
      // Inside the clip: detection sits after the pre-roll context.
      beginSec = clipContext;
      endSec = clipContext + windowSeconds;
    } else if (isGlobal) {
      beginSec = 0.0;
      endSec = sessionDurationSec;
    } else {
      beginSec = surveySec;
      endSec = surveySec + windowSeconds;
    }

    final commonName =
        _localizedCommon(d, taxonomy: taxonomy, speciesLocale: speciesLocale);

    final surveyTimeSuffix =
        hasClips ? '\t${surveySec.toStringAsFixed(3)}' : '';
    final coordSuffix = hasCoords
        ? '\t${d.latitude?.toStringAsFixed(6) ?? ''}'
            '\t${d.longitude?.toStringAsFixed(6) ?? ''}'
        : '';

    buf.writeln(
      '${i + 1}\t'
      'Spectrogram 1\t'
      '1\t'
      '$beginFile\t'
      '${beginSec.toStringAsFixed(3)}\t'
      '${endSec.toStringAsFixed(3)}\t'
      '0\t'
      '$_highFreqHz\t'
      '$commonName\t'
      '${d.scientificName}\t'
      '${d.confidence.toStringAsFixed(4)}'
      '$surveyTimeSuffix'
      '$coordSuffix',
    );
  }

  return buf.toString();
}

/// Generates a standard CSV representation of session detections.
///
/// When [audioFileName] or [clipFileMap] are provided, a `File` column is
/// included referencing the audio source. For rows referencing a clip, the
/// `Begin/End Time (s)` columns describe the detection's offset *within the
/// clip* (after the pre-roll context); a separate `Survey Time (s)` column
/// is added with the session-relative offset.
///
/// Common Name is rendered in the user's species locale when [taxonomy] is
/// supplied; Scientific Name is always emitted.
///
/// Latitude / Longitude columns are included when any detection has
/// coordinates.
String buildCsvExport(
  LiveSession session, {
  String? audioFileName,
  Map<int, String>? clipFileMap,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
}) {
  final buf = StringBuffer();
  final hasFileRefs = audioFileName != null || clipFileMap != null;
  final hasCoords =
      session.detections.any((d) => d.latitude != null && d.longitude != null);
  final hasClips = clipFileMap != null && clipFileMap.isNotEmpty;
  final clipContext = (clipContextSecondsOverride ??
          session.settings.clipContextSeconds)
      .toDouble();

  buf.writeln(
    'Timestamp,Begin Time (s),End Time (s),'
    'Common Name,Scientific Name,Confidence'
    '${hasFileRefs ? ',File' : ''}'
    '${hasClips ? ',Survey Time (s)' : ''}'
    '${hasCoords ? ',Latitude,Longitude' : ''}',
  );

  final windowSeconds = session.settings.windowDuration;
  final sessionDurationSec = session.endTime != null
      ? session.endTime!.difference(session.startTime).inMilliseconds / 1000.0
      : 0.0;

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    final clipName = clipFileMap?[i];
    final referencesClip = clipName != null;

    // Session-relative offset.
    final surveySec = isGlobal
        ? 0.0
        : d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;

    final double beginSec;
    final double endSec;
    if (referencesClip) {
      beginSec = clipContext;
      endSec = clipContext + windowSeconds;
    } else if (isGlobal) {
      beginSec = 0.0;
      endSec = sessionDurationSec;
    } else {
      beginSec = surveySec;
      endSec = surveySec + windowSeconds;
    }

    final localizedCommon =
        _localizedCommon(d, taxonomy: taxonomy, speciesLocale: speciesLocale);
    final commonName =
        localizedCommon.contains(',') ? '"$localizedCommon"' : localizedCommon;
    final sciName = d.scientificName.contains(',')
        ? '"${d.scientificName}"'
        : d.scientificName;

    final fileRef = hasFileRefs ? ',${clipName ?? audioFileName ?? ''}' : '';
    final surveyTimeRef = hasClips ? ',${surveySec.toStringAsFixed(3)}' : '';
    final coordRef = hasCoords
        ? ',${d.latitude?.toStringAsFixed(6) ?? ''}'
            ',${d.longitude?.toStringAsFixed(6) ?? ''}'
        : '';

    buf.writeln(
      '${d.timestamp.toIso8601String()},'
      '${beginSec.toStringAsFixed(3)},'
      '${endSec.toStringAsFixed(3)},'
      '$commonName,'
      '$sciName,'
      '${d.confidence.toStringAsFixed(4)}'
      '$fileRef'
      '$surveyTimeRef'
      '$coordRef',
    );
  }

  return buf.toString();
}

/// Builds the provenance metadata block embedded in JSON exports and
/// written to `<prefix>.metadata.json` inside ZIP bundles.
///
/// The block records *what produced this export* so an analyst opening it
/// months later can answer: which app version, which model, which user
/// settings. All fields are optional — callers pass whatever they have.
///
/// `prefs` should be a flat map of every relevant SharedPreferences key/value
/// (the caller supplies it; the export module has no Riverpod / SharedPrefs
/// dependency on purpose). `audioModel` typically contains `name`, `version`,
/// `description`, `speciesCount`, `sampleRate` from `model_config.json`.
Map<String, dynamic> buildExportMetadata({
  String? appVersion,
  String? appBuildNumber,
  String? appPackageName,
  Map<String, dynamic>? audioModel,
  Map<String, dynamic>? geoModel,
  Map<String, dynamic>? prefs,
  String? speciesLocale,
}) {
  return {
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'app': {
      'name': 'BirdNET Live',
      if (appVersion != null) 'version': appVersion,
      if (appBuildNumber != null) 'buildNumber': appBuildNumber,
      if (appPackageName != null) 'packageName': appPackageName,
    },
    if (audioModel != null) 'audioModel': audioModel,
    if (geoModel != null) 'geoModel': geoModel,
    if (speciesLocale != null) 'speciesLocale': speciesLocale,
    if (prefs != null && prefs.isNotEmpty) 'settings': prefs,
  };
}

/// Generates a JSON representation of the session and its detections.
///
/// When [metadata] is provided it is embedded under a top-level `meta` key.
String buildJsonExport(
  LiveSession session, {
  Map<String, dynamic>? metadata,
}) {
  final map = {
    if (metadata != null) 'meta': metadata,
    'session': session.displayName,
    if (session.customName != null && session.customName!.isNotEmpty)
      'customName': session.customName,
    if (session.sessionNumber != null) 'sessionNumber': session.sessionNumber,
    if (session.type != SessionType.live) 'type': session.type.name,
    'startTime': session.startTime.toIso8601String(),
    'endTime': session.endTime?.toIso8601String(),
    if (session.observerName != null && session.observerName!.isNotEmpty)
      'observerName': session.observerName,
    if (session.transectId != null && session.transectId!.isNotEmpty)
      'transectId': session.transectId,
    if (session.latitude != null) 'latitude': session.latitude,
    if (session.longitude != null) 'longitude': session.longitude,
    if (session.locationName != null) 'locationName': session.locationName,
    if (session.distanceMeters != null)
      'distanceMeters': session.distanceMeters,
    if (session.stopReason != null) 'stopReason': session.stopReason!.name,
    if (session.stopReasonValue != null)
      'stopReasonValue': session.stopReasonValue,
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
        if (d.latitude != null) 'latitude': d.latitude,
        if (d.longitude != null) 'longitude': d.longitude,
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
/// All exported files use the `BirdNET_Live_…` prefix regardless of the
/// session's display name.  When [includeAudio] is true and audio exists
/// (full recording or detection clips), returns a .zip path.  Otherwise
/// returns the path to the raw document file.
Future<String?> buildSessionExport(
  LiveSession session, {
  required String format,
  required bool includeAudio,
  TaxonomyService? taxonomy,
  String speciesLocale = 'en',
  int? clipContextSecondsOverride,
  Map<String, dynamic>? metadata,
}) async {
  final prefix = _exportPrefix(session);
  final audioPath = session.recordingPath;

  // Full recording: single file at recordingPath.
  final hasFullRecording = audioPath != null && File(audioPath).existsSync();

  // Detection clips: collect per-detection audio files that exist on disk,
  // indexed by detection position so we can build a clip-file map.
  final clipEntries = <int, File>{};
  if (!hasFullRecording) {
    for (var i = 0; i < session.detections.length; i++) {
      final clip = session.detections[i].audioClipPath;
      if (clip != null) {
        final f = File(clip);
        if (f.existsSync()) clipEntries[i] = f;
      }
    }
  }
  final hasClips = clipEntries.isNotEmpty;
  final hasAnyAudio = hasFullRecording || hasClips;

  // ── Build export clip names (sequential, 1-indexed, zero-padded) ────
  final audioExt = hasFullRecording
      ? p.extension(audioPath)
      : (hasClips ? p.extension(clipEntries.values.first.path) : '.flac');
  final audioFileName = '$prefix$audioExt';

  // Map detection index → export clip filename.
  Map<int, String>? clipFileMap;
  final clipExportNames = <int, String>{};
  if (hasClips) {
    final pad = clipEntries.length.toString().length.clamp(3, 6);
    var seq = 1;
    for (final i in clipEntries.keys.toList()..sort()) {
      final localized = _localizedCommon(
        session.detections[i],
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
      );
      final species = _sanitizeFilename(localized);
      final name =
          '${prefix}_clip_${seq.toString().padLeft(pad, '0')}_$species$audioExt';
      clipExportNames[i] = name;
      seq++;
    }
    clipFileMap = clipExportNames;
  }

  // ── Generate document content ─────────────────────────────────────
  String fileContent;
  String extension;

  switch (format) {
    case 'csv':
      fileContent = buildCsvExport(
        session,
        audioFileName: hasFullRecording ? audioFileName : null,
        clipFileMap: clipFileMap,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        clipContextSecondsOverride: clipContextSecondsOverride,
      );
      extension = '.csv';
      break;
    case 'json':
      fileContent = buildJsonExport(session, metadata: metadata);
      extension = '.json';
      break;
    case 'gpx':
      fileContent = buildGpxExport(session);
      extension = '.gpx';
      break;
    case 'raven':
    default:
      fileContent = buildRavenSelectionTable(
        session,
        audioFileName: hasFullRecording ? audioFileName : null,
        clipFileMap: clipFileMap,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
        clipContextSecondsOverride: clipContextSecondsOverride,
      );
      extension = '.selections.txt';
      break;
  }

  final bytes = Uint8List.fromList(utf8.encode(fileContent));

  // ── Bundle into ZIP when audio is available and requested ──────────
  if (includeAudio && hasAnyAudio) {
    final archive = Archive();

    if (hasFullRecording) {
      final audioBytes = await File(audioPath).readAsBytes();
      archive.addFile(
        ArchiveFile(audioFileName, audioBytes.length, audioBytes),
      );
    } else {
      for (final entry in clipExportNames.entries) {
        final clipBytes = await clipEntries[entry.key]!.readAsBytes();
        archive.addFile(
          ArchiveFile(entry.value, clipBytes.length, clipBytes),
        );
      }
    }

    archive.addFile(
      ArchiveFile('$prefix$extension', bytes.length, bytes),
    );

    // Always drop a metadata side-file when the caller provided one, so
    // the provenance information travels with the bundle regardless of
    // which document format the user picked (Raven / CSV / GPX).
    if (metadata != null) {
      final metaJson =
          const JsonEncoder.withIndent('  ').convert(metadata);
      final metaBytes = Uint8List.fromList(utf8.encode(metaJson));
      archive.addFile(
        ArchiveFile(
            '$prefix.metadata.json', metaBytes.length, metaBytes),
      );
    }

    // Always drop a metadata side-file when the caller provided one, so
    // the provenance information travels with the bundle regardless of
    // which document format the user picked (Raven / CSV / GPX).
    if (metadata != null) {
      final metaJson =
          const JsonEncoder.withIndent('  ').convert(metadata);
      final metaBytes = Uint8List.fromList(utf8.encode(metaJson));
      archive.addFile(
        ArchiveFile(
            '$prefix.metadata.json', metaBytes.length, metaBytes),
      );
    }

    if (session.annotations.isNotEmpty) {
      final annotationsTxt = _buildAnnotationsText(session);
      final annotationsBytes = Uint8List.fromList(utf8.encode(annotationsTxt));
      archive.addFile(
        ArchiveFile('$prefix.annotations.txt', annotationsBytes.length,
            annotationsBytes),
      );
    }

    // Auto-include GPX for surveys (if the export format isn't already GPX).
    if (session.type == SessionType.survey && format != 'gpx') {
      final gpxContent = buildGpxExport(session);
      final gpxBytes = Uint8List.fromList(utf8.encode(gpxContent));
      archive.addFile(
        ArchiveFile('$prefix.gpx', gpxBytes.length, gpxBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    final zipDir = hasFullRecording
        ? p.dirname(audioPath)
        : p.dirname(clipEntries.values.first.path);
    final zipPath = p.join(zipDir, '$prefix.zip');
    await File(zipPath).writeAsBytes(zipBytes);

    return zipPath;
  } else {
    final dir = hasFullRecording
        ? p.dirname(audioPath)
        : (hasClips
            ? p.dirname(clipEntries.values.first.path)
            : Directory.systemTemp.path);
    final filePath = p.join(dir, '$prefix$extension');
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
