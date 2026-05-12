// =============================================================================
// OpenStreetMap Tile Layer — Shared safe network tile configuration
// =============================================================================
//
// Centralizes the app's OpenStreetMap tile configuration so every map uses the
// same provider and tile error behavior. Tiles are cached to disk via
// `flutter_cache_manager` so repeated panning/zooming and revisits don't
// re-download the same tiles — and so the app keeps working in offline-ish
// situations (e.g. mid-survey when signal drops). The default `ImageCache`
// used by `NetworkTileProvider` is memory-only and bounded, which means tiles
// were previously fetched again on every cold start.
//
// Tile error behavior: failed downloads degrade to blank tiles instead of
// surfacing Flutter error screens to the user.
// =============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

const String kOpenStreetMapUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

TileLayer buildOpenStreetMapTileLayer() {
  return TileLayer(
    urlTemplate: kOpenStreetMapUrlTemplate,
    userAgentPackageName: 'birdnet_live',
    tileProvider: _CachedNetworkTileProvider(),
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
  );
}

// ---------------------------------------------------------------------------
// _OsmTileCacheManager
// ---------------------------------------------------------------------------
//
// Dedicated cache for OSM tiles, kept separate from any other on-disk caches
// the app might add later. We give tiles a long retention period (90 days)
// because OSM tile content rarely changes — and we cap at 4000 objects so a
// heavy survey session doesn't blow up the user's storage. At ~30 KB per
// tile the worst-case footprint is ~120 MB, similar in size to the bundled
// species image set.
// ---------------------------------------------------------------------------

class _OsmTileCacheManager extends CacheManager {
  static const _key = 'osm_tile_cache';
  static final _OsmTileCacheManager _instance = _OsmTileCacheManager._();

  factory _OsmTileCacheManager() => _instance;

  _OsmTileCacheManager._()
    : super(
        Config(
          _key,
          stalePeriod: const Duration(days: 90),
          maxNrOfCacheObjects: 4000,
        ),
      );
}

// ---------------------------------------------------------------------------
// _CachedNetworkTileProvider
// ---------------------------------------------------------------------------
//
// Drop-in replacement for `NetworkTileProvider` that goes through the
// shared [_OsmTileCacheManager]. flutter_map calls `getImage` for every
// tile coordinate; we hand back a custom [ImageProvider] that resolves
// the bytes via the cache manager (disk-first, network-fallback).
// ---------------------------------------------------------------------------

class _CachedNetworkTileProvider extends TileProvider {
  _CachedNetworkTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(getTileUrl(coordinates, options));
  }
}

// ---------------------------------------------------------------------------
// _CachedTileImage
// ---------------------------------------------------------------------------
//
// Minimal ImageProvider that delegates fetching to flutter_cache_manager.
// Equality is based on the tile URL so Flutter's in-memory ImageCache
// continues to dedupe identical tiles within a single session.
// ---------------------------------------------------------------------------

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage(this.url);

  final String url;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<Codec> _loadAsync(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final file = await _OsmTileCacheManager().getSingleFile(url);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Empty tile bytes for $url');
    }
    final buffer = await ImmutableBuffer.fromUint8List(
      Uint8List.fromList(bytes),
    );
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedTileImage(url: $url)';
}
