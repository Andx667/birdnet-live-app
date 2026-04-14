# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.8] — 2025-07-27

### Added
- Offline species data bundle: 5,241 species images (240×160 WebP) and descriptions in 7 languages bundled into the APK
- `dev/build_species_bundle.py` — re-runnable Python build script to download, resize, and package species assets
- `SpeciesDescriptionService` — lazy gzip JSON loader with per-locale caching and English fallback
- Italian (`it`) and Korean (`ko`) common name columns added to `taxonomy.csv`

### Changed
- All species images now load from bundled assets instead of network (CachedNetworkImage → Image.asset)
- Species detail overlay uses bundled descriptions instead of taxonomy API fetch
- `TaxonomyService` is now fully offline — removed `fetchDetail()` and API cache

## [0.2.7] — 2025-07-27

### Added
- French (fr), Spanish (es), Czech (cs), Brazilian Portuguese (pt), and Italian (it) translations (~290 keys each)
- Language picker in settings expanded from 3 to 8 options (System, English, Deutsch, Français, Español, Čeština, Português, Italiano)
- Landscape layouts for Home, Live, Point Count, Survey Live, and Session Review screens
- Tablet max-width constraint (600 dp) applied to 8 screens via shared `ContentWidthConstraint` widget
- Comprehensive localization: ~40 new l10n keys covering settings labels, live screen status texts, detection list states, color map names, recording mode options, and microphone settings (English + German)
- German technical term consistency: Point Count, Survey, and Session kept in English across the German UI

### Changed
- Home screen footer: single `Wrap` with all 5 buttons replacing two-row layout
- Mode card descriptions rewritten as action-oriented phrases (English + German)
- Help text updated to be taxonomically agnostic ("species" instead of "bird species", "animal sounds" instead of "birdsong")

## [0.2.6] — 2026-04-13

### Fixed
- GPS jitter filtering: reject fixes with >30 m horizontal accuracy, speed gate (>30 km/h) discards teleport jumps, jitter threshold raised from 3 m to 5 m

### Changed
- Survey notification now shows species count alongside detections (“42 det · 12 spp”)

## [0.2.5] — 2026-04-13

### Added
- Microphone input selector in survey setup wizard (Parameters step) — pick input device before starting a survey
- Survey summary tab now shows rank numbers and sorts species by detection count then max confidence as tiebreaker

## [0.2.4] — 2026-04-13

### Added
- Help screen accessible from the home screen footer — comprehensive guide clustered by mode (Live, Point Count, Survey, File Analysis, Explore, Sessions) with expandable sections and general tips
- Home screen footer reorganized: 5 items in two rows (3 + 2) replacing the horizontal scroll

### Changed
- Inline survey map in session review is now interactive (pinch-zoom, pan, double-tap zoom) instead of static
- Deferred map `fitCamera` to post-frame callback to fix tiles not rendering until first touch

### Fixed
- Survey live help overlay with signal quality bar explanation and dashboard icons

## [0.2.3] — 2026-04-13

### Added
- Project foundation: Flutter project setup, folder structure, dependencies
- Dark theme with teal accent (field-optimized)
- Navigation scaffold with four mode tabs (Live, Survey, Point Count, File Analysis)
- Settings screen with categorized preferences (Audio, Inference, Spectrogram, Recording, Export, General)
- Onboarding carousel (welcome, features, permissions, ready)
- Terms of Use and Privacy Policy acceptance gate
- About screen with version info, model details, credits, and legal links
- Localization support (English, German)
- Permission handling service (microphone, location, storage, notifications)
- External resource consent system (map tiles, API sync)
- Settings infrastructure with Riverpod + SharedPreferences
- Repository documentation (README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG)
- MkDocs documentation site structure
- Audio capture service with 32kHz mono PCM streaming
- Ring buffer for audio sample storage
- Audio level meter widget with peak-hold indicator
- Spectrogram visualization (FFT, color maps, scrolling painter)
- ONNX inference integration (classifier model, label parser, post-processor)
- Inference isolate for background processing
- Geo-model for location-based species filtering (dummy implementation)
- Species filter with four modes (off, geo-exclude, geo-merge, custom list)
- Custom species list import and persistence
- Model-agnostic inference configuration (JSON-driven model, label, and pipeline settings)
- Live Mode end-to-end pipeline (audio → spectrogram → inference → detection list)
- LiveController orchestrator (model loading, inference timer loop, session management)
- Detection list widget with confidence bars, time-ago display, and playback icons
- WAV writer (streaming and one-shot modes, 16-bit PCM, RIFF header)
- Recording service (off, full, detections-only modes)
- Session repository (JSON file persistence, save/load/list/delete)
- LiveSession data model with settings snapshot and detection records
- Audio playback for detection clips (just_audio integration)
- Session info bar showing species and detection counts during active sessions
