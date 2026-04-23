// =============================================================================
// Taxonomy Service — Species metadata from bundled CSV
// =============================================================================
//
// Provides species information from the bundled taxonomy CSV, parsed once at
// startup.  Covers names, IDs, image metadata, and localized common names
// for all ~5,250 model species.
//
// ### Usage
//
// ```dart
// final service = TaxonomyService();
// service.loadFromCsv(csvContent);
// final species = service.lookup('Parus major');
// final imagePath = service.assetImagePath('Parus major');
// ```
//
// ### Caching
//
// The CSV lookup is O(1) via a HashMap keyed by scientific name.
//
// ### Reusability
//
// This service has no UI or feature dependencies.  It can be used by any
// screen that needs species metadata (explore, live, survey, info overlays).
// =============================================================================

import 'package:flutter/foundation.dart';

import '../models/taxonomy_species.dart';

/// Species metadata service — CSV-backed, fully offline.
class TaxonomyService {
  TaxonomyService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// CSV-sourced species indexed by scientific name.
  final Map<String, TaxonomySpecies> _csvIndex = {};

  /// Whether the CSV has been loaded.
  bool get isLoaded => _csvIndex.isNotEmpty;

  /// Number of species in the CSV index.
  int get speciesCount => _csvIndex.length;

  // ---------------------------------------------------------------------------
  // CSV Loading
  // ---------------------------------------------------------------------------

  /// Parse the bundled taxonomy CSV and build the lookup index.
  ///
  /// The CSV is comma-delimited with a header row.
  void loadFromCsv(String csvContent) {
    _csvIndex.clear();

    final lines = csvContent.split('\n');
    if (lines.isEmpty) return;

    // Parse header.
    final header = _parseCsvLine(lines.first);
    if (header.isEmpty) return;

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      if (values.length < header.length) continue;

      final row = <String, String>{};
      for (var j = 0; j < header.length && j < values.length; j++) {
        row[header[j]] = values[j];
      }

      final sciName = row['scientific_name'];
      if (sciName != null && sciName.isNotEmpty) {
        _csvIndex[sciName] = TaxonomySpecies.fromCsvRow(row);
      }
    }

    debugPrint('[TaxonomyService] loaded ${_csvIndex.length} species from CSV');
  }

  /// Simple CSV line parser handling commas within quotes.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Look up a species by scientific name (CSV only, offline).
  TaxonomySpecies? lookup(String scientificName) {
    return _csvIndex[scientificName];
  }

  /// Look up multiple species by scientific name.
  List<TaxonomySpecies> lookupAll(Iterable<String> scientificNames) {
    return scientificNames
        .map((name) => lookup(name))
        .where((s) => s != null)
        .cast<TaxonomySpecies>()
        .toList();
  }

  /// Search species by common name or scientific name (prefix match).
  List<TaxonomySpecies> search(String query, {int limit = 50}) {
    if (query.isEmpty) return const [];

    final lower = query.toLowerCase();
    final results = <TaxonomySpecies>[];

    for (final species in _csvIndex.values) {
      if (species.commonName.toLowerCase().contains(lower) ||
          species.scientificName.toLowerCase().contains(lower)) {
        results.add(species);
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Image helpers
  // ---------------------------------------------------------------------------

  /// Bundled asset image path for a species.
  ///
  /// Looks up the BirdNET ID from the CSV index.  Returns the placeholder
  /// image path when the species is not found.
  String assetImagePath(String scientificName) {
    final species = _csvIndex[scientificName];
    return species?.assetImagePath ?? 'assets/images/dummy_species.png';
  }
}
