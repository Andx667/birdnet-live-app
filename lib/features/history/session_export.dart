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
import 'html_report.dart';

/// Upper frequency bound for Raven annotations (Nyquist of 32 kHz).
const int _highFreqHz = 16000;

/// Builds the `BirdNET_Live_…` export prefix from a session's start time,
/// optional session number, and optional user-assigned name.
///
/// Examples:
///   `BirdNET_Live_2026-04-15_08-00-00_#3`
///   `BirdNET_Live_2026-04-15_08-00-00_Morning_walk`
String _exportPrefix(LiveSession session) {
  final dt = DateFormat(
    'yyyy-MM-dd_HH-mm-ss',
  ).format(session.startTime.toLocal());
  final suffix =
      session.sessionNumber != null ? '_#${session.sessionNumber}' : '';
  final name =
      session.customName != null && session.customName!.isNotEmpty
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

/// CSV-quotes [value] when it contains a comma, double quote, or newline.
/// Internal double quotes are doubled per RFC 4180.
String _csvField(String value) {
  if (value.isEmpty) return '';
  final needsQuoting =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuoting) return value;
  return '"${value.replaceAll('"', '""')}"';
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
///   • A `Survey Time` column is always appended so analysts can recover the
///     timeline of every detection regardless of file layout. By default this
///     is `Survey Time (s)` (seconds since session start). When
///     [useAbsoluteSurveyTime] is true the column becomes `Survey Time (UTC)`
///     and carries the detection's wall-clock timestamp as an ISO-8601 UTC
///     string — useful when correlating across surveys, devices, or external
///     data sources that work in absolute time.
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
  bool useAbsoluteSurveyTime = false,
}) {
  final buf = StringBuffer();
  final hasCoords = session.detections.any(
    (d) => d.latitude != null && d.longitude != null,
  );
  final hasNotes = session.detections.any((d) => d.hasNote);
  // Prefer the per-session value, but allow callers to override (e.g. legacy
  // sessions persisted before [SessionSettings.clipContextSeconds] existed,
  // where the field defaults to 0 and would falsely place every detection at
  // the very start of every clip).
  final clipContext =
      (clipContextSecondsOverride ?? session.settings.clipContextSeconds)
          .toDouble();

  // Header row — 'Begin File' is a standard Raven column for multi-file
  // selection tables. 'Survey Time' is non-standard but harmless to Raven
  // (extra columns are ignored on import) and lets analysts cross-reference
  // detections back to the survey timeline. We always emit it: when no clips
  // are involved it duplicates Begin Time, but having a stable column name
  // makes downstream tooling simpler than conditionally including it.
  // 'Confirmed' / 'Confirmed At (UTC)' are likewise always emitted so the
  // schema is stable regardless of whether the session has any confirmed
  // detections; unconfirmed rows carry an empty 'Confirmed At'.
  final surveyTimeHeader =
      useAbsoluteSurveyTime ? 'Survey Time (UTC)' : 'Survey Time (s)';
  buf.writeln(
    'Selection\tView\tChannel\tBegin File\t'
    'Begin Time (s)\tEnd Time (s)\t'
    'Low Freq (Hz)\tHigh Freq (Hz)\t'
    'Common Name\tScientific Name\tConfidence'
    '\t$surveyTimeHeader'
    '\tConfirmed\tConfirmed At (UTC)'
    '${hasCoords ? '\tLatitude\tLongitude' : ''}'
    '${hasNotes ? '\tNote' : ''}',
  );

  final windowSeconds = session.settings.windowDuration;
  final sessionDurationSec =
      session.endTime != null
          ? session.endTime!.difference(session.startTime).inMilliseconds /
              1000.0
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
    final surveySec =
        isGlobal
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

    final commonName = _localizedCommon(
      d,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
    );

    final surveyTimeValue =
        useAbsoluteSurveyTime
            ? d.timestamp.toUtc().toIso8601String()
            : surveySec.toStringAsFixed(3);
    final surveyTimeSuffix = '\t$surveyTimeValue';
    final confirmedSuffix =
        '\t${d.isConfirmed ? 'true' : 'false'}'
        '\t${d.confirmedAt?.toUtc().toIso8601String() ?? ''}';
    final coordSuffix =
        hasCoords
            ? '\t${d.latitude?.toStringAsFixed(6) ?? ''}'
                '\t${d.longitude?.toStringAsFixed(6) ?? ''}'
            : '';
    // Raven selection tables are tab-separated, so collapse any embedded
    // tabs/newlines from a free-form note to spaces to keep one row per
    // detection. Notes longer than ~200 chars are not truncated; Raven
    // tolerates wide cells.
    final noteSuffix =
        hasNotes
            ? '\t${(d.note ?? '').replaceAll(RegExp(r"[\t\r\n]+"), ' ').trim()}'
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
      '$confirmedSuffix'
      '$coordSuffix'
      '$noteSuffix',
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
  bool useAbsoluteSurveyTime = false,
}) {
  final buf = StringBuffer();
  final hasFileRefs = audioFileName != null || clipFileMap != null;
  final hasCoords = session.detections.any(
    (d) => d.latitude != null && d.longitude != null,
  );
  final hasNotes = session.detections.any((d) => d.hasNote);
  final hasMemos = session.detections.any((d) => d.hasVoiceMemo);
  final clipContext =
      (clipContextSecondsOverride ?? session.settings.clipContextSeconds)
          .toDouble();

  // Survey Time is always included (see [buildRavenSelectionTable] for the
  // rationale). When [useAbsoluteSurveyTime] is true the column becomes
  // 'Survey Time (UTC)' and carries an ISO-8601 wall-clock timestamp.
  // 'Confirmed' / 'Confirmed At (UTC)' are always emitted so downstream
  // pipelines see a stable schema; unconfirmed rows carry an empty
  // 'Confirmed At'.
  final surveyTimeHeader =
      useAbsoluteSurveyTime ? 'Survey Time (UTC)' : 'Survey Time (s)';
  buf.writeln(
    'Timestamp (UTC),Begin Time (s),End Time (s),'
    'Common Name,Scientific Name,Confidence'
    '${hasFileRefs ? ',File' : ''}'
    ',$surveyTimeHeader'
    ',Confirmed,Confirmed At (UTC)'
    '${hasCoords ? ',Latitude,Longitude' : ''}'
    '${hasNotes ? ',Note' : ''}'
    '${hasMemos ? ',Voice Memo' : ''}',
  );

  final windowSeconds = session.settings.windowDuration;
  final sessionDurationSec =
      session.endTime != null
          ? session.endTime!.difference(session.startTime).inMilliseconds /
              1000.0
          : 0.0;

  for (var i = 0; i < session.detections.length; i++) {
    final d = session.detections[i];
    final isGlobal = d.source == DetectionSource.manualGlobal;

    final clipName = clipFileMap?[i];
    final referencesClip = clipName != null;

    // Session-relative offset.
    final surveySec =
        isGlobal
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

    final localizedCommon = _localizedCommon(
      d,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
    );
    final commonName =
        localizedCommon.contains(',') ? '"$localizedCommon"' : localizedCommon;
    final sciName =
        d.scientificName.contains(',')
            ? '"${d.scientificName}"'
            : d.scientificName;

    final fileRef = hasFileRefs ? ',${clipName ?? audioFileName ?? ''}' : '';
    final surveyTimeValue =
        useAbsoluteSurveyTime
            ? d.timestamp.toUtc().toIso8601String()
            : surveySec.toStringAsFixed(3);
    final surveyTimeRef = ',$surveyTimeValue';
    final confirmedRef =
        ',${d.isConfirmed ? 'true' : 'false'}'
        ',${d.confirmedAt?.toUtc().toIso8601String() ?? ''}';
    final coordRef =
        hasCoords
            ? ',${d.latitude?.toStringAsFixed(6) ?? ''}'
                ',${d.longitude?.toStringAsFixed(6) ?? ''}'
            : '';
    final noteRef = hasNotes ? ',${_csvField(d.note ?? '')}' : '';
    final memoRef =
        hasMemos
            ? ',${d.hasVoiceMemo ? 'memos/${p.basename(d.voiceMemoPath!)}' : ''}'
            : '';

    buf.writeln(
      '${d.timestamp.toUtc().toIso8601String()},'
      '${beginSec.toStringAsFixed(3)},'
      '${endSec.toStringAsFixed(3)},'
      '$commonName,'
      '$sciName,'
      '${d.confidence.toStringAsFixed(4)}'
      '$fileRef'
      '$surveyTimeRef'
      '$confirmedRef'
      '$coordRef'
      '$noteRef'
      '$memoRef',
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
  LiveSession? session,
}) {
  // Slim the model blocks to *what produced these detections* — model
  // identity, not the bundled defaults. The defaults under
  // audioModel.inference and geoModel.defaultThreshold are confusing
  // here because they're overridden at runtime by the user; the actual
  // applied values live in `appliedSettings` below.
  Map<String, dynamic>? slimAudioModel;
  if (audioModel != null) {
    slimAudioModel = Map<String, dynamic>.from(audioModel)
      ..remove('inference')
      ..remove('onnx')
      ..remove('labels');
  }
  Map<String, dynamic>? slimGeoModel;
  if (geoModel != null) {
    slimGeoModel = Map<String, dynamic>.from(geoModel)
      ..remove('defaultThreshold');
  }

  // Snapshot of the actually-applied audio + geomodel settings for this
  // session. Pulled from `session.settings`, which the controller fills
  // with the runtime values (not the model_config defaults).
  Map<String, dynamic>? appliedSettings;
  if (session != null) {
    final s = session.settings;
    appliedSettings = <String, dynamic>{
      'windowDurationSeconds': s.windowDuration,
      'confidenceThresholdPercent': s.confidenceThreshold,
      'inferenceRateHz': s.inferenceRate,
      'speciesFilterMode': s.speciesFilterMode,
      if (s.sensitivity != null) 'sensitivity': s.sensitivity,
      if (s.poolingMode != null) 'poolingMode': s.poolingMode,
      if (s.poolingWindows != null) 'poolingWindows': s.poolingWindows,
      if (s.gainLinear != null) 'gainLinear': s.gainLinear,
      if (s.highPassHz != null) 'highPassHz': s.highPassHz,
      if (s.clipContextSeconds > 0)
        'clipContextSeconds': s.clipContextSeconds,
    };
  }

  return {
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'app': {
      'name': 'BirdNET Live',
      if (appVersion != null) 'version': appVersion,
      if (appBuildNumber != null) 'buildNumber': appBuildNumber,
      if (appPackageName != null) 'packageName': appPackageName,
    },
    if (session != null)
      'session': {
        'id': session.id,
        'type': session.type.name,
        'startTime': session.startTime.toUtc().toIso8601String(),
        if (session.endTime != null)
          'endTime': session.endTime!.toUtc().toIso8601String(),
        if (session.customName != null && session.customName!.isNotEmpty)
          'customName': session.customName,
        if (session.sessionNumber != null)
          'sessionNumber': session.sessionNumber,
        if (session.observerName != null && session.observerName!.isNotEmpty)
          'observerName': session.observerName,
        if (session.transectId != null && session.transectId!.isNotEmpty)
          'transectId': session.transectId,
        'detectionCount': session.detections.length,
      },
    if (slimAudioModel != null) 'audioModel': slimAudioModel,
    if (slimGeoModel != null) 'geoModel': slimGeoModel,
    if (appliedSettings != null) 'appliedSettings': appliedSettings,
    if (speciesLocale != null) 'speciesLocale': speciesLocale,
    if (prefs != null && prefs.isNotEmpty) 'settings': prefs,
  };
}

/// Generates a JSON representation of the session and its detections.
///
/// When [metadata] is provided it is embedded under a top-level `meta` key.
String buildJsonExport(LiveSession session, {Map<String, dynamic>? metadata}) {
  final map = {
    if (metadata != null) 'meta': metadata,
    'session': session.displayName,
    if (session.customName != null && session.customName!.isNotEmpty)
      'customName': session.customName,
    if (session.sessionNumber != null) 'sessionNumber': session.sessionNumber,
    if (session.type != SessionType.live) 'type': session.type.name,
    'startTime': session.startTime.toUtc().toIso8601String(),
    'endTime': session.endTime?.toUtc().toIso8601String(),
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
    'settings': session.settings.toJson(),
    if (session.trimStartSec != null) 'trimStartSec': session.trimStartSec,
    if (session.trimEndSec != null) 'trimEndSec': session.trimEndSec,
    'detections':
        session.detections.map((d) {
          final beginSec =
              d.timestamp.difference(session.startTime).inMilliseconds / 1000.0;
          return {
            'timestamp': d.timestamp.toUtc().toIso8601String(),
            'beginTimeSec': num.parse(beginSec.toStringAsFixed(3)),
            'commonName': d.commonName,
            'scientificName': d.scientificName,
            'confidence': num.parse(d.confidence.toStringAsFixed(4)),
            if (d.latitude != null) 'latitude': d.latitude,
            if (d.longitude != null) 'longitude': d.longitude,
            if (d.source != DetectionSource.auto) 'source': d.source.name,
            'confirmed': d.isConfirmed,
            if (d.confirmedAt != null)
              'confirmedAt': d.confirmedAt!.toUtc().toIso8601String(),
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
  bool useAbsoluteSurveyTime = false,
  bool includeHtmlReport = false,
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
  final audioExt =
      hasFullRecording
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
        useAbsoluteSurveyTime: useAbsoluteSurveyTime,
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
        useAbsoluteSurveyTime: useAbsoluteSurveyTime,
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
        archive.addFile(ArchiveFile(entry.value, clipBytes.length, clipBytes));
      }
    }

    archive.addFile(ArchiveFile('$prefix$extension', bytes.length, bytes));

    // Bundle voice memos under a memos/ folder so the CSV's "Voice
    // Memo" column (relative path: memos/<basename>) resolves inside
    // the archive. Best-effort: skip any memo whose file is missing.
    for (final d in session.detections) {
      final memoPath = d.voiceMemoPath;
      if (memoPath == null) continue;
      final memoFile = File(memoPath);
      if (!await memoFile.exists()) continue;
      final memoBytes = await memoFile.readAsBytes();
      archive.addFile(
        ArchiveFile(
          'memos/${p.basename(memoPath)}',
          memoBytes.length,
          memoBytes,
        ),
      );
    }

    // Same treatment for session-level annotation memos.
    for (final a in session.annotations) {
      final memoPath = a.voiceMemoPath;
      if (memoPath == null) continue;
      final memoFile = File(memoPath);
      if (!await memoFile.exists()) continue;
      final memoBytes = await memoFile.readAsBytes();
      archive.addFile(
        ArchiveFile(
          'memos/${p.basename(memoPath)}',
          memoBytes.length,
          memoBytes,
        ),
      );
    }

    // Always drop a metadata side-file when the caller provided one, so
    // the provenance information travels with the bundle regardless of
    // which document format the user picked (Raven / CSV / GPX).
    if (metadata != null) {
      final metaJson = const JsonEncoder.withIndent('  ').convert(metadata);
      final metaBytes = Uint8List.fromList(utf8.encode(metaJson));
      archive.addFile(
        ArchiveFile('$prefix.metadata.json', metaBytes.length, metaBytes),
      );
    }

    if (session.annotations.isNotEmpty) {
      final annotationsTxt = _buildAnnotationsText(session);
      final annotationsBytes = Uint8List.fromList(utf8.encode(annotationsTxt));
      archive.addFile(
        ArchiveFile(
          '$prefix.annotations.txt',
          annotationsBytes.length,
          annotationsBytes,
        ),
      );
    }

    // Auto-include GPX for surveys (if the export format isn't already GPX).
    if (session.type == SessionType.survey && format != 'gpx') {
      final gpxContent = buildGpxExport(session);
      final gpxBytes = Uint8List.fromList(utf8.encode(gpxContent));
      archive.addFile(ArchiveFile('$prefix.gpx', gpxBytes.length, gpxBytes));
    }

    // Pragmatic, single-file HTML report at the ZIP root. Lives next to
    // the audio so its relative `<audio src="...">` references resolve
    // once the user unzips. Species images come from the BirdNET
    // taxonomy API at view time — keeps the report tiny but means the
    // thumbnails need internet (graceful fallback to a placeholder when
    // offline).
    if (includeHtmlReport) {
      final reportHtml = buildHtmlReport(
        session,
        clipFileMap: clipFileMap,
        audioFileName: hasFullRecording ? audioFileName : null,
        taxonomy: taxonomy,
        speciesLocale: speciesLocale,
      );
      final reportBytes = Uint8List.fromList(utf8.encode(reportHtml));
      archive.addFile(
        ArchiveFile('report.html', reportBytes.length, reportBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    final zipDir =
        hasFullRecording
            ? p.dirname(audioPath)
            : p.dirname(clipEntries.values.first.path);
    final zipPath = p.join(zipDir, '$prefix.zip');
    await File(zipPath).writeAsBytes(zipBytes);

    return zipPath;
  } else {
    final dir =
        hasFullRecording
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
  buf.writeln('# Session: ${session.startTime.toUtc().toIso8601String()}');
  buf.writeln();

  for (final a in session.annotations) {
    if (a.offsetInRecording != null) {
      final m = a.offsetInRecording! ~/ 60;
      final s = (a.offsetInRecording! % 60).toInt();
      buf.write(
        '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}] ',
      );
    } else {
      buf.write('[Global] ');
    }
    // Optional title is prefixed in bold-ish "Title: " form so the
    // exported text mirrors what the user sees on the chip.
    if (a.title.trim().isNotEmpty) {
      buf.write('${a.title.trim()}: ');
    }
    if (a.text.trim().isNotEmpty) {
      buf.write(a.text);
      if (a.hasVoiceMemo) {
        buf.write(' (voice memo: memos/${p.basename(a.voiceMemoPath!)})');
      }
      buf.writeln();
    } else if (a.hasVoiceMemo) {
      buf.writeln('(voice memo: memos/${p.basename(a.voiceMemoPath!)})');
    } else {
      buf.writeln();
    }
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
  buf.writeln(
    '  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
    'http://www.topografix.com/GPX/1/1/gpx.xsd">',
  );

  // Metadata.
  buf.writeln('  <metadata>');
  buf.writeln('    <name>${_xmlEscape(session.displayName)}</name>');
  buf.writeln(
    '    <time>${session.startTime.toUtc().toIso8601String()}</time>',
  );
  if (session.observerName != null && session.observerName!.isNotEmpty) {
    buf.writeln(
      '    <author><name>${_xmlEscape(session.observerName!)}</name></author>',
    );
  }
  buf.writeln('  </metadata>');

  // Detection waypoints.
  for (final d in session.detections) {
    if (d.latitude == null || d.longitude == null) continue;
    buf.writeln('  <wpt lat="${d.latitude}" lon="${d.longitude}">');
    buf.writeln('    <time>${d.timestamp.toUtc().toIso8601String()}</time>');
    buf.writeln('    <name>${_xmlEscape(d.commonName)}</name>');
    buf.writeln(
      '    <desc>${_xmlEscape(d.scientificName)} (${(d.confidence * 100).toStringAsFixed(1)}%)</desc>',
    );
    if (d.isConfirmed) {
      // GPX <sym> is a free-form symbol hint; downstream tools (QGIS,
      // GPSBabel, Garmin BaseCamp) treat unknown values as a tag rather
      // than failing to load the waypoint, so 'confirmed' here doubles as
      // a filterable attribute. The <cmt> note carries the confirmation
      // timestamp so the audit trail survives the export.
      buf.writeln('    <sym>confirmed</sym>');
      buf.writeln(
        '    <cmt>Confirmed at ${d.confirmedAt!.toUtc().toIso8601String()}</cmt>',
      );
    }
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
