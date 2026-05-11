// =============================================================================
// detection_sharing_service_test.dart
// =============================================================================
// Validates the slice extraction used by the live-session "share detection"
// cascade for both WAV and FLAC full recordings. The platform `Share.share*`
// calls themselves are not exercised here (they require a real platform
// channel); instead we drive [extractClipFromFullAudio] end-to-end against
// synthetic recordings produced by the real [WavWriter] and [FlacEncoder]
// so any framing or header bug surfaces as a failed assertion on the
// staged file.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/features/history/services/detection_sharing_service.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/flac_encoder.dart';
import 'package:birdnet_live/features/recording/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tmp);
  final String tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;

  @override
  Future<String?> getApplicationSupportPath() async => tmp;
}

LiveSession _session({
  required String recordingPath,
  required DateTime start,
  int windowDuration = 3,
  int clipContextSeconds = 1,
}) {
  return LiveSession(
    id: 'test',
    startTime: start,
    recordingPath: recordingPath,
    settings: SessionSettings(
      windowDuration: windowDuration,
      confidenceThreshold: 25,
      inferenceRate: 1.0,
      speciesFilterMode: 'off',
      clipContextSeconds: clipContextSeconds,
    ),
  );
}

DetectionRecord _det(DateTime ts) {
  return DetectionRecord(
    scientificName: 'Troglodytes troglodytes',
    commonName: 'Eurasian Wren',
    confidence: 0.9,
    timestamp: ts,
  );
}

/// Writes a synthetic 16-bit PCM WAV file with [seconds] of audio at
/// 32 kHz mono via the real [WavWriter], so the on-disk header layout
/// matches what live recordings produce.
Future<File> _writeFakeWav(Directory dir, double seconds) async {
  const sampleRate = 32000;
  final path = p.join(dir.path, 'full.wav');
  final writer = WavWriter(filePath: path, sampleRate: sampleRate);
  await writer.open();
  // Push samples in 0.5-second chunks so we exercise the streaming path
  // (header placeholder + multiple flushes) just like live recordings do.
  final chunk = Float32List((sampleRate * 0.5).round());
  for (var i = 0; i < chunk.length; i++) {
    // Triangle wave at ~441 Hz so the bytes aren't all-zero (a silent
    // file would still pass the slicer but is harder to debug).
    chunk[i] = ((i % 73) / 73.0) * 2.0 - 1.0;
  }
  final totalChunks = (seconds / 0.5).round();
  for (var i = 0; i < totalChunks; i++) {
    await writer.writeSamples(chunk);
  }
  await writer.close();
  return File(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('share_extract_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  group('extractClipFromFullAudio', () {
    test('extracts a window from a finalized full.wav', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec')).create();
      // 10 seconds of audio total.
      final wav = await _writeFakeWav(sessionDir, 10.0);
      expect(wav.existsSync(), isTrue);
      expect(await wav.length(), greaterThan(44 + 32000 * 2 * 9));

      // Recording path can be either the session directory (mid-recording)
      // or the file itself (post-stop). Cover both shapes.
      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      final detection = _det(start.add(const Duration(seconds: 5)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'extractor should find session dir');
      expect(out!.existsSync(), isTrue);

      // Expected slice: detOffset=5s, clipContext=1s, window=3s
      // → start=4s, duration=5s → 5 * 32000 * 2 = 320_000 PCM bytes
      // → file size = 44 + 320_000 = 320_044 bytes.
      final length = await out.length();
      expect(length, 44 + 5 * 32000 * 2);

      // Header sanity: RIFF / WAVE / fmt  / data tags in the right slots.
      final header = await out
          .openRead(0, 44)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(header.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(header.sublist(36, 40)), 'data');
      // Sample rate at offset 24 (uint32 LE) should be 32000.
      final view = ByteData.sublistView(Uint8List.fromList(header));
      expect(view.getUint32(24, Endian.little), 32000);
      expect(view.getUint16(22, Endian.little), 1); // channels
      expect(view.getUint16(34, Endian.little), 16); // bits per sample
    });

    test('accepts a direct file path (post-stop shape)', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec2')).create();
      final wav = await _writeFakeWav(sessionDir, 8.0);

      final session = _session(
        recordingPath: wav.path, // file, not directory
        start: start,
      );
      final detection = _det(start.add(const Duration(seconds: 4)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull);
      expect(await out!.length(), greaterThan(44));
    });

    test('clamps when the requested window runs past EOF', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec3')).create();
      // Only 4 seconds recorded so far.
      await _writeFakeWav(sessionDir, 4.0);

      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      // Detection at t=3.5s → window would want [2.5, 7.5), only [2.5, 4.0)
      // is available.
      final detection = _det(start.add(const Duration(milliseconds: 3500)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'partial slice is better than nothing');
      // 1.5 seconds × 32000 × 2 = 96_000 bytes of PCM.
      expect(await out!.length(), 44 + (1.5 * 32000).floor() * 2);
    });

    test('returns null when recordingPath is null', () async {
      final session = _session(
        recordingPath: '',
        start: DateTime.utc(2026, 5, 11),
      );
      // Manually clear the field — the constructor required a non-null
      // path above to set up the rest of the object.
      session.recordingPath = null;
      final out = await extractClipFromFullAudio(
        session,
        _det(session.startTime),
      );
      expect(out, isNull);
    });

    test('extracts a window from a finalized full.flac', () async {
      // Mirror the WAV path but with a real FLAC encoder so we exercise
      // the FLAC slicing branch end-to-end. The output is still WAV
      // (we always re-wrap PCM as WAV for the share sheet).
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec_flac')).create();
      const sampleRate = 32000;
      final flacPath = p.join(sessionDir.path, 'full.flac');
      final encoder = FlacEncoder(filePath: flacPath, sampleRate: sampleRate);
      await encoder.open();
      final chunk = Float32List((sampleRate * 0.5).round());
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] = ((i % 73) / 73.0) * 2.0 - 1.0;
      }
      for (var i = 0; i < 20; i++) {
        // 10 seconds total
        await encoder.writeSamples(chunk);
      }
      await encoder.close();
      expect(File(flacPath).existsSync(), isTrue);

      final session = _session(
        recordingPath: sessionDir.path,
        start: start,
        windowDuration: 3,
        clipContextSeconds: 1,
      );
      // Detection at t=5s → window [4, 9) → 5 s slice.
      final detection = _det(start.add(const Duration(seconds: 5)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull, reason: 'FLAC full recordings must slice');
      expect(out!.existsSync(), isTrue);

      // Output is always WAV regardless of source container.
      expect(p.extension(out.path), '.wav');
      final length = await out.length();
      // 5 seconds × 32_000 × 2 bytes + 44-byte header.
      expect(length, 44 + 5 * 32000 * 2);

      // Header sanity check.
      final header = await out
          .openRead(0, 44)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(header.sublist(36, 40)), 'data');
      final view = ByteData.sublistView(Uint8List.fromList(header));
      expect(view.getUint32(24, Endian.little), 32000);
    });

    test('FLAC: accepts a direct file path (post-stop shape)', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(
        p.join(tmp.path, 'rec_flac2'),
      ).create();
      const sampleRate = 32000;
      final flacPath = p.join(sessionDir.path, 'full.flac');
      final encoder = FlacEncoder(filePath: flacPath, sampleRate: sampleRate);
      await encoder.open();
      final chunk = Float32List(sampleRate);
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] = ((i % 91) / 91.0) * 2.0 - 1.0;
      }
      for (var i = 0; i < 8; i++) {
        await encoder.writeSamples(chunk);
      }
      await encoder.close();

      final session = _session(
        recordingPath: flacPath, // file, not directory (post-stop shape)
        start: start,
      );
      final detection = _det(start.add(const Duration(seconds: 4)));

      final out = await extractClipFromFullAudio(session, detection);
      expect(out, isNotNull);
      expect(p.extension(out!.path), '.wav');
      expect(await out.length(), greaterThan(44));
    });

    test('returns null when no full recording exists at all', () async {
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(
        p.join(tmp.path, 'rec_empty'),
      ).create();
      // Empty session dir — no full.wav and no full.flac.
      final session = _session(recordingPath: sessionDir.path, start: start);
      final out = await extractClipFromFullAudio(session, _det(start));
      expect(out, isNull);
    });

    test('extracts while the writer is still open (mid-recording)', () async {
      // Reproduces the live-survey path: WavWriter is still holding the
      // file open with placeholder header sizes, the slicer must trust
      // file length on disk rather than the header field.
      final start = DateTime.utc(2026, 5, 11, 10, 0, 0);
      final sessionDir = await Directory(p.join(tmp.path, 'rec5')).create();
      const sampleRate = 32000;
      final path = p.join(sessionDir.path, 'full.wav');
      final writer = WavWriter(filePath: path, sampleRate: sampleRate);
      await writer.open();
      try {
        // 6 seconds of audio in 0.5 s chunks, no close() yet.
        final chunk = Float32List((sampleRate * 0.5).round())
          ..fillRange(0, (sampleRate * 0.5).round(), 0.5);
        for (var i = 0; i < 12; i++) {
          await writer.writeSamples(chunk);
        }

        final session = _session(
          recordingPath: sessionDir.path,
          start: start,
          windowDuration: 3,
          clipContextSeconds: 1,
        );
        // Detection at t=3s → window [2, 7) → clamped to [2, ~6).
        final detection = _det(start.add(const Duration(seconds: 3)));

        final out = await extractClipFromFullAudio(session, detection);
        expect(
          out,
          isNotNull,
          reason: 'mid-recording slice must succeed despite placeholder header',
        );
        expect(await out!.length(), greaterThan(44));
      } finally {
        await writer.close();
      }
    });
  });
}
