// =============================================================================
// Timestamp Formatter Service
// =============================================================================
//
// Utility functions for formatting timestamps in both absolute (wall-clock)
// and relative (session-start) formats. Used across Live, Point Count, Survey,
// and File Analysis views.
//
// • Absolute format: "HH:MM:SS" (24-hour time)
// • Relative format: "MM:SS" (elapsed time since session start)
// =============================================================================

import 'package:intl/intl.dart';

/// Formats a timestamp as either absolute (wall-clock) or relative (elapsed).
///
/// [timestamp] — The absolute DateTime to format.
/// [sessionStart] — The start time of the session/recording. Required for
///   relative timestamps; ignored if [useAbsolute] is true.
/// [useAbsolute] — If true, shows HH:MM:SS format. If false, shows MM:SS
///   relative to [sessionStart].
///
/// Returns formatted timestamp string.
String formatTimestamp({
  required DateTime timestamp,
  required DateTime sessionStart,
  required bool useAbsolute,
}) {
  if (useAbsolute) {
    return _formatAbsoluteTime(timestamp);
  } else {
    return _formatRelativeTime(timestamp, sessionStart);
  }
}

/// Format absolute wall-clock time as HH:MM:SS.
String _formatAbsoluteTime(DateTime dateTime) {
  final formatter = DateFormat('HH:mm:ss');
  return formatter.format(dateTime);
}

/// Format elapsed time relative to session start as MM:SS.
String _formatRelativeTime(DateTime timestamp, DateTime sessionStart) {
  final elapsed = timestamp.difference(sessionStart);
  final totalSeconds = elapsed.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Formats a duration as MM:SS.
///
/// Used for display of elapsed time in Point Count, Survey, and similar modes.
String formatDurationMinutesSeconds(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Formats a duration as HH:MM:SS.
///
/// Used for display of survey elapsed time or other long-running sessions.
String formatDurationHoursMinutesSeconds(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

  return '$hours:$minutes:$seconds';
}
