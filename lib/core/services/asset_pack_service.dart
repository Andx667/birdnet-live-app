// =============================================================================
// AssetPackService — Resolves ONNX model files across release flows
// =============================================================================
//
// BirdNET Live ships in two release shapes:
//
//   1. **Play Store (AAB)** — the two large `.onnx` model files (~152 MB
//      audio classifier + ~6 MB geo model) live in an *install-time*
//      Play Asset Delivery pack named `models_pack`. The pack is
//      downloaded together with the app at install time and unpacked
//      into a directory on the device. The Play Console requires the
//      base module download to stay under 200 MB compressed, which is
//      why we split the models out.
//
//   2. **Sideload APK (GitHub release)** — there is no asset pack. The
//      `.onnx` files are bundled inside `flutter_assets` exactly as
//      before. On first launch we extract them to the app's documents
//      directory so they can be memory-mapped by ONNX Runtime.
//
// Both flows are fully **offline** — no network access is required at
// install or runtime.
//
// Callers should always go through [resolveModelPath] rather than
// hand-rolling the extraction logic. The resolver picks the right source
// transparently per file:
//
//   • If the asset pack is present and contains the file → return its
//     on-device path directly (no copy needed; install-time pack files
//     are already plain files on disk).
//   • Otherwise → extract the file from `rootBundle` to the documents
//     directory under `<fileName>_v<version>` (idempotent, mirrors the
//     historical behavior).
//
// On non-Android platforms (iOS, Windows, tests) the pack is always
// absent and the bundle fallback is used.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class AssetPackService {
  AssetPackService._();

  static const MethodChannel _channel = MethodChannel('com.birdnet/asset_pack');

  /// Name of the install-time pack defined in `android/models_pack/`.
  static const String _packName = 'models_pack';

  /// Cached lookup result. Pack location never changes during a process
  /// lifetime, so we resolve once and reuse.
  static String? _cachedPackPath;
  static bool _resolved = false;

  /// Returns the on-device path of the install-time asset pack's
  /// `assets/` directory, or `null` if the pack is unavailable (sideload
  /// APK, non-Android platform, or platform channel error).
  static Future<String?> getPackPath() async {
    if (_resolved) return _cachedPackPath;
    if (!_isAndroid) {
      _resolved = true;
      return null;
    }
    try {
      final result = await _channel.invokeMethod<String>(
        'getPackPath',
        {'packName': _packName},
      );
      _cachedPackPath = result;
      if (result != null) {
        debugPrint('[AssetPackService] models_pack at $result');
      } else {
        debugPrint(
          '[AssetPackService] models_pack not present — sideload mode',
        );
      }
    } catch (e) {
      debugPrint('[AssetPackService] platform channel error: $e');
      _cachedPackPath = null;
    }
    _resolved = true;
    return _cachedPackPath;
  }

  /// Resolve a model file living at `assets/models/<fileName>` to an
  /// absolute on-device path suitable for passing to ONNX Runtime.
  ///
  /// [fileName] — bare file name, e.g. `BirdNET+_V3.0-...-FP16.onnx`.
  /// [version] — model version string used to suffix the extracted
  ///   sideload copy (`<fileName>_v<version>`), so model upgrades
  ///   trigger a fresh extraction.
  static Future<String> resolveModelPath({
    required String fileName,
    required String version,
  }) async {
    final packPath = await getPackPath();
    if (packPath != null) {
      final candidate = File('$packPath/models/$fileName');
      if (candidate.existsSync()) {
        return candidate.path;
      }
      debugPrint(
        '[AssetPackService] pack present but missing $fileName — '
        'falling back to rootBundle extraction',
      );
    }
    return _extractFromBundle(fileName, version);
  }

  /// Fallback path: extract the model bytes from `rootBundle` into the
  /// app's documents directory the first time the app runs (or after a
  /// version bump). Used by sideload APK installs.
  static Future<String> _extractFromBundle(
    String fileName,
    String version,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final versionedName = '${fileName}_v$version';
    final modelFile = File('${appDir.path}/$versionedName');
    if (!modelFile.existsSync()) {
      debugPrint(
        '[AssetPackService] extracting $fileName v$version to '
        '${modelFile.path}',
      );
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      debugPrint(
        '[AssetPackService] extraction complete '
        '(${modelFile.lengthSync()} bytes)',
      );
    }
    return modelFile.path;
  }

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }
}
