// =============================================================================
// OpenStreetMap Tile Layer — Shared safe network tile configuration
// =============================================================================
//
// Centralizes the app's OpenStreetMap tile configuration so every map uses the
// same provider and tile error behavior. Network tile failures should degrade
// to blank tiles instead of surfacing Flutter error screens to the user.
// =============================================================================

import 'package:flutter_map/flutter_map.dart';

const String kOpenStreetMapUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

TileLayer buildOpenStreetMapTileLayer() {
  return TileLayer(
    urlTemplate: kOpenStreetMapUrlTemplate,
    userAgentPackageName: 'birdnet_live',
    tileProvider: NetworkTileProvider(silenceExceptions: true),
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
  );
}
