# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] - 2026-04-22

### Added
- Expanded the User Guide with workflow pages for Live, Explore, Session Library, Session Review, Point Count, Survey, File Analysis, icons and controls, and settings
- Added a Common Controls section to the in-app Help screen using the same icons used throughout the app

### Changed
- Reworked Help and Explore guidance to explain app navigation and screen behavior rather than field methodology
- Updated localized Help copy across all supported locales for consistency with the current app UI

## [0.4.0] - 2026-04-22

### Added
- Direct User Guide access from the Help screen
- A File Analysis app bar shortcut to the relevant settings panel

### Changed
- Localized remaining user-facing strings in file analysis, explore, settings, and survey notifications across all supported locales
- Updated Help guidance to point users to the User Guide from both Help and About

## [0.3.4] - 2026-04-22

### Added
- Tracked species bundle tooling under `tools/`, including a public taxonomy JSON download helper
- Developer documentation for reproducing bundled species images and metadata through mkdocs

### Changed
- Bundled species images now rebuild at 480x320 WebP with slightly lower quality for better full-size detail rendering

## [0.3.3] - 2026-08-05

### Added
- "(Developer preview)" badge natively shown next to version info on Home Screen and About Screen
- Expanded user guide to cover all settings with the *intuition/rationale* behind changing them
- Updated in-app Help Screen: Replaced dawn chorus tip with explanations of basic mechanics and links to the user guide
- Ensure full translation of UI elements across all 7 supported locales

## [0.3.2] â€” 2025-07-28

### Added
- Confidence threshold slider in survey setup (Parameters step)
- Clip context controls (pre/post buffer seconds) in survey setup when recording mode is detections
- Clip context controls in global settings when recording mode is detections
- Tap species marker on fullscreen survey map to play detection clip with highlight

### Changed
- File analysis step indicator now uses simple progress bars (matching point count and survey setup)
- Smart detection sampling reworked: uses distance (>500 m) and time (>2 min) thresholds instead of fixed spatial bins; keeps only the highest-scoring detection per species at each spot

## [0.3.1] â€” 2026-04-15

### Changed
- Privacy policy updated to reflect offline species data bundle and current data handling
- Terms of use now hosted on the documentation site (was GitHub markdown)

### Added
- Terms of Use page in mkdocs documentation
- User Guide link on the About screen

## [0.3.0] â€” 2025-07-28

### Added
- `Begin File` column in Raven selection tables for multi-file compatibility
- `File` column in CSV exports referencing the audio source
- Latitude / Longitude columns in Raven and CSV exports when detections have coordinates
- GPX file auto-included in survey ZIP bundles
- Species common name in detection clip filenames (e.g. `_clip_001_Eurasian_Blackbird.flac`)
- Custom session name included in export filenames
- JSON export now includes session type, location, and per-detection coordinates
- Export prefix `BirdNET_Live_YYYY-MM-DD_HH-MM-SS` for all exported files (display names unchanged)

### Fixed
- Detection timestamps in exports are always session-relative (no more 0-based times for clips)
- Survey share now correctly produces ZIP bundles with individual detection clips
- `manualGlobal` detection end time in CSV uses session duration (consistent with Raven builder)
- Removed unused local variable in `live_controller.dart`

### Changed
- Session display names no longer use `BirdNET_Live` prefix (cleaner in-app display)

## [0.2.10] â€” 2025-07-27

### Added
- Recording mode setting (Full / Detections only / Off) restored to settings screen as segmented button
- Detection clip playback in session review: when only detection clips were recorded (no full recording), play buttons play individual clips

### Fixed
- Survey sessions with "detections only" recording mode now surface audio clips correctly in session review
- Play buttons hidden in session review when no audio exists (recording mode was off)

## [0.2.9] â€” 2025-07-27

### Added
- Share/export button now available for survey sessions (CSV, JSON, GPX, Raven â€” audio optional)

### Fixed
- Survey sessions now always record full audio (like live sessions) so playback and trim work in review
- Recording mode default changed from "off" to "full" for live sessions (live controller already recorded full regardless)

### Changed
- Recording mode setting removed from general settings screen (only exposed in survey setup where it applies)
- Observer name and track distance shown in a single row in session review header
- Survey map in session review reduced from 25% to 18% of screen height

## [0.2.8] â€” 2025-07-27

### Added
- Offline species data bundle: 5,241 species images (240Ã—160 WebP) and descriptions in 7 languages bundled into the APK
- `tools/build_species_bundle.py` â€” re-runnable Python build script to download, resize, and package species assets
- `SpeciesDescriptionService` â€” lazy gzip JSON loader with per-locale caching and English fallback
- Italian (`it`) and Korean (`ko`) common name columns added to `taxonomy.csv`

### Changed
- All species images now load from bundled assets instead of network (CachedNetworkImage â†’ Image.asset)
- Species detail overlay uses bundled descriptions instead of taxonomy API fetch
- `TaxonomyService` is now fully offline â€” removed `fetchDetail()` and API cache

## [0.2.7] â€” 2025-07-27

### Added
- French (fr), Spanish (es), Czech (cs), Brazilian Portuguese (pt), and Italian (it) translations (~290 keys each)
- Language picker in settings expanded from 3 to 8 options (System, English, Deutsch, FranÃ§ais, EspaÃ±ol, ÄŒeÅ¡tina, PortuguÃªs, Italiano)
- Landscape layouts for Home, Live, Point Count, Survey Live, and Session Review screens
- Tablet max-width constraint (600 dp) applied to 8 screens via shared `ContentWidthConstraint` widget
- Comprehensive localization: ~40 new l10n keys covering settings labels, live screen status texts, detection list states, color map names, recording mode options, and microphone settings (English + German)
- German technical term consistency: Point Count, Survey, and Session kept in English across the German UI

### Changed
- Home screen footer: single `Wrap` with all 5 buttons replacing two-row layout
- Mode card descriptions rewritten as action-oriented phrases (English + German)
- Help text updated to be taxonomically agnostic ("species" instead of "bird species", "animal sounds" instead of "birdsong")

## [0.2.6] â€” 2026-04-13

### Fixed
- GPS jitter filtering: reject fixes with >30 m horizontal accuracy, speed gate (>30 km/h) discards teleport jumps, jitter threshold raised from 3 m to 5 m

### Changed
- Survey notification now shows species count alongside detections (â€œ42 det Â· 12 sppâ€)

## [0.2.5] â€” 2026-04-13

### Added
- Microphone input selector in survey setup wizard (Parameters step) â€” pick input device before starting a survey
- Survey summary tab now shows rank numbers and sorts species by detection count then max confidence as tiebreaker

## [0.2.4] â€” 2026-04-13

### Added
- Help screen accessible from the home screen footer â€” comprehensive guide clustered by mode (Live, Point Count, Survey, File Analysis, Explore, Sessions) with expandable sections and general tips
- Home screen footer reorganized: 5 items in two rows (3 + 2) replacing the horizontal scroll

### Changed
- Inline survey map in session review is now interactive (pinch-zoom, pan, double-tap zoom) instead of static
- Deferred map `fitCamera` to post-frame callback to fix tiles not rendering until first touch

### Fixed
- Survey live help overlay with signal quality bar explanation and dashboard icons

## [0.2.3] â€” 2026-04-13

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
- Live Mode end-to-end pipeline (audio â†’ spectrogram â†’ inference â†’ detection list)
- LiveController orchestrator (model loading, inference timer loop, session management)
- Detection list widget with confidence bars, time-ago display, and playback icons
- WAV writer (streaming and one-shot modes, 16-bit PCM, RIFF header)
- Recording service (off, full, detections-only modes)
- Session repository (JSON file persistence, save/load/list/delete)
- LiveSession data model with settings snapshot and detection records
- Audio playback for detection clips (just_audio integration)
- Session info bar showing species and detection counts during active sessions

