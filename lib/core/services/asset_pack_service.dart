// =============================================================================
// AssetPackService — Resolves ONNX model files across release flows
// =============================================================================
//
// BirdNET Live ships in two release shapes:
//
//   1. **Play Store (AAB)** — the two large `.onnx` model files (~152 MB
//      audio classifier + ~6 MB geo model) live in an *install-time*
//      Play Asset Delivery pack named `models_pack`. The pack is
//      downloaded together with the app at install time. Install-time
//      packs are **merged into the app's standard `AssetManager`
//      namespace** (`<packName>/assets/<path>` becomes `<path>` in
//      `Context.getAssets()`), and `AssetPackManager.getPackLocation()`
//      returns `null` for them by design — that API only resolves
//      fast-follow / on-demand packs. We therefore extract the model
//      bytes via the platform `AssetManager` and write them to
//      `filesDir` so ONNX Runtime can mmap a real file path.
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
// hand-rolling the extraction logic. The resolver tries sources in
// order:
//
//   1. Native `extractAsset` (Android only) → reads from the merged
//      AssetManager namespace, which surfaces files from install-time
//      asset packs as well as the base APK's `assets/`. Returns null
//      when the asset is not present (true sideload APK, since the
//      `.onnx` files are stripped from the base module's `assets/` for
//      AAB builds and live in `flutter_assets/` for APK builds).
//   2. `rootBundle.load()` extraction → used for sideload APK builds
//      where the `.onnx` lives in `flutter_assets`.
//
// On non-Android platforms (iOS, Windows, tests) only path (2) applies.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class AssetPackService {
  AssetPackService._();

  static const MethodChannel _channel = MethodChannel('com.birdnet/asset_pack');

  /// Resolve a model file living at `assets/models/<fileName>` to an
  /// absolute on-device path suitable for passing to ONNX Runtime.
  ///
  /// [fileName] — bare file name, e.g. `BirdNET+_V3.0-...-FP16.onnx`.
  /// [version] — model version string used to suffix the extracted
  ///   copy (`<fileName>_v<version>`), so model upgrades trigger a
  ///   fresh extraction.
  static Future<String> resolveModelPath({
    required String fileName,
    required String version,
  }) async {
    final destName = '${fileName}_v$version';

    // Path 1 — Android AssetManager (covers Play Store install-time
    // asset packs, since they're merged into the app namespace).
    if (_isAndroid) {
      try {
        final assetPath = 'models/$fileName';
        final extracted = await _channel.invokeMethod<String>('extractAsset', {
          'assetPath': assetPath,
          'destName': destName,
        });
        if (extracted != null && extracted.isNotEmpty) {
          debugPrint(
            '[AssetPackService] resolved $fileName via AssetManager: $extracted',
          );
          return extracted;
        }
        debugPrint(
          '[AssetPackService] $fileName not in AssetManager — '
          'falling back to rootBundle (sideload APK)',
        );
      } on MissingPluginException catch (e) {
        // Old build / hot-restart against an APK without the new
        // method handler. Fall through to the bundle path.
        debugPrint('[AssetPackService] extractAsset unavailable: $e');
      } catch (e) {
        debugPrint('[AssetPackService] extractAsset error: $e');
      }
    }

    // Path 2 — Flutter rootBundle (sideload APK / iOS / desktop).
    return _extractFromBundle(fileName, version);
  }

  /// Fallback path: extract the model bytes from `rootBundle` into the
  /// app's documents directory the first time the app runs (or after a
  /// version bump). Used by sideload APK installs and non-Android
  /// platforms.
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
