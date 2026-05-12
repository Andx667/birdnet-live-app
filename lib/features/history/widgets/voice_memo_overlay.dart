// =============================================================================
// voice_memo_overlay.dart — Per-detection voice-memo recorder dialog
// =============================================================================
//
// Purpose:
//   Lets a reviewer record (or re-record) a short spoken note that gets
//   attached to a single [DetectionRecord]. The memo file lives next to the
//   session's other audio under `<appDir>/recordings/<sessionId>/memos/`,
//   and its absolute path is persisted on `DetectionRecord.voiceMemoPath`
//   so it survives JSON round-trips and is included in ZIP exports.
//
// Why a dialog (rather than an inline overlay):
//   The recorder needs an exclusive mic — the live capture pipeline must
//   already be torn down by the time Session Review opens, but we still
//   want a clear modal context so the user knows recording is active.
//   `showDialog` gives us a barrier-dismissible modal that auto-disposes
//   the recorder when popped via the back gesture.
//
// Recording format:
//   AAC-LC inside an MP4 container (.m4a). 16 kHz mono, 64 kbps. This is
//   well below the audio classifier's 32 kHz sample rate but more than
//   enough fidelity for spoken commentary, and yields ~8 KB/s — a 30-s
//   memo is ~240 KB, comfortable to bundle in ZIP exports.
//
// Permission handling:
//   Live and Survey modes already prompt for mic permission at startup.
//   File-Analysis sessions never touch the mic, so this is the first
//   point where the permission may need to be requested. We rely on the
//   `record` package's own `hasPermission()` which surfaces the system
//   permission dialog on first call.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';

/// Result returned to the caller when the dialog is dismissed.
///
/// `null` means the user closed the dialog without changing anything
/// (e.g. tapped outside or pressed the back button without saving).
class VoiceMemoResult {
  VoiceMemoResult({this.savedPath, this.deleted = false});

  /// Path to the newly-recorded memo file. `null` when no recording
  /// was made (or the user chose to delete an existing memo — see
  /// [deleted]).
  final String? savedPath;

  /// True when the user explicitly deleted an existing memo.
  /// In that case [savedPath] is `null` and the caller should clear
  /// `voiceMemoPath` on the detection.
  final bool deleted;
}

/// Opens the voice-memo recorder dialog for [sessionId].
///
/// [existingMemoPath] is the current `voiceMemoPath` (if any). When
/// supplied, the dialog opens in playback mode and shows a "Replace"
/// option; otherwise it opens directly in record mode.
Future<VoiceMemoResult?> showVoiceMemoDialog({
  required BuildContext context,
  required String sessionId,
  String? existingMemoPath,
}) {
  return showDialog<VoiceMemoResult>(
    context: context,
    builder: (ctx) => _VoiceMemoDialog(
      sessionId: sessionId,
      existingMemoPath: existingMemoPath,
    ),
  );
}

class _VoiceMemoDialog extends StatefulWidget {
  const _VoiceMemoDialog({required this.sessionId, this.existingMemoPath});

  final String sessionId;
  final String? existingMemoPath;

  @override
  State<_VoiceMemoDialog> createState() => _VoiceMemoDialogState();
}

class _VoiceMemoDialogState extends State<_VoiceMemoDialog> {
  late final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _player = AudioPlayer();
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _pendingPath; // freshly-recorded but not yet committed
  String? _committedExistingPath; // the original memo if any
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _committedExistingPath = widget.existingMemoPath;
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    // If the user opened the dialog, recorded something, then closed it
    // without tapping Save, drop the orphan file so we don't litter the
    // session directory.
    final pending = _pendingPath;
    if (pending != null) {
      // Best-effort cleanup; ignore errors (file may have been moved).
      // ignore: discarded_futures
      File(pending).delete().catchError((_) => File(pending));
    }
    super.dispose();
  }

  Future<String> _newMemoPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(appDir.path, 'recordings', widget.sessionId, 'memos'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'memo_$stamp.m4a');
  }

  Future<void> _startRecording() async {
    setState(() => _errorMessage = null);
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        setState(() {
          _errorMessage =
              AppLocalizations.of(context)!
                  .detectionVoiceMemoMicPermissionDenied;
        });
        return;
      }

      // Stop playback if it's running so the mic isn't competing.
      if (_isPlaying) {
        await _player.stop();
      }

      final path = await _newMemoPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: path,
      );

      _elapsed = Duration.zero;
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => setState(() => _elapsed += const Duration(milliseconds: 250)),
      );

      setState(() {
        _isRecording = true;
        _pendingPath = path;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {
      // The recorder is best-effort; ignore stop errors.
    }
    if (!mounted) return;
    setState(() => _isRecording = false);
  }

  Future<void> _togglePlay() async {
    final path = _pendingPath ?? _committedExistingPath;
    if (path == null) return;
    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    try {
      await _player.setFilePath(path);
      await _player.seek(Duration.zero);
      await _player.play();
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  void _save() {
    if (_pendingPath == null) {
      // Nothing changed.
      Navigator.of(context).pop();
      return;
    }
    // Commit: delete the previous memo file (if any) so we don't orphan it.
    final old = _committedExistingPath;
    final committed = _pendingPath!;
    _pendingPath = null; // prevent dispose() from cleaning it up
    if (old != null && old != committed) {
      // ignore: discarded_futures
      File(old).delete().catchError((_) => File(old));
    }
    Navigator.of(context).pop(VoiceMemoResult(savedPath: committed));
  }

  void _delete() {
    final old = _committedExistingPath;
    if (old != null) {
      // ignore: discarded_futures
      File(old).delete().catchError((_) => File(old));
    }
    Navigator.of(context).pop(VoiceMemoResult(deleted: true));
  }

  String _fmtDuration(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasExisting =
        _committedExistingPath != null && _pendingPath == null;
    final hasPending = _pendingPath != null;
    final canPlay = (hasExisting || hasPending) && !_isRecording;

    return AlertDialog(
      title: Text(l10n.detectionVoiceMemoDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big circular record / stop button.
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? theme.colorScheme.error
                    : theme.colorScheme.primaryContainer,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 48,
                color: _isRecording
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? '${l10n.detectionVoiceMemoRecording} ${_fmtDuration(_elapsed)}'
                : (hasPending || hasExisting)
                    ? _fmtDuration(_elapsed)
                    : l10n.detectionVoiceMemoHint,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _isRecording
                ? l10n.detectionVoiceMemoTapToStop
                : l10n.detectionVoiceMemoTapToRecord,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canPlay) ...[
            const SizedBox(height: 12),
            IconButton.filledTonal(
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              tooltip: l10n.detectionVoiceMemoTooltip,
              onPressed: _togglePlay,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (hasExisting && !hasPending)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.detectionDeleteVoiceMemo),
          ),
        TextButton(
          onPressed: _isRecording ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_isRecording || !hasPending) ? null : _save,
          child: Text(l10n.sessionSave),
        ),
      ],
    );
  }
}
