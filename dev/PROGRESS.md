# BirdNET Live - Development Progress

This file tracks development progress. Update after each work session.

---

## Current Status

| Item | Status |
|------|--------|
| Current Step | GPS Jitter Fix & Notification Species Count |
| Last Updated | 2026-04-13 |
| Version | 0.2.6+35 |
| Unit Tests | 480 passing |
| Integration Tests | 3 (geo_soundscape, memory_stress, model_output) |
| Blockers | None |

---

## Progress Log

### 2026-04-13 — GPS Jitter Fix & Notification Species Count

**Completed:**
- GPS jitter filtering improved in `SurveyGpsTracker`: accuracy gate (reject >30 m), speed gate (reject >30 km/h implied speed), jitter threshold raised 3 m → 5 m
- Survey foreground notification now shows species count: "42 det · 12 spp" format
- All 480 tests passing, `flutter analyze` clean

**Files Modified:**
- `lib/features/survey/survey_gps_tracker.dart` — accuracy filter in `_onPosition`, speed-based rejection in `_addPoint`, constants updated
- `lib/features/survey/survey_controller.dart` — `_buildNotificationText()` includes species count
- `pubspec.yaml` — version 0.2.6+35
- `CHANGELOG.md` — v0.2.6 entry
- `README.md` — version badge synced

### 2026-04-13 — Survey Setup Mic Input & Summary Ranking

**Completed:**
- Microphone input selector in survey setup: added device picker tile to `_ParametersStep` using `inputDevicesProvider` + `selectedDeviceProvider` with bottom-sheet radio picker (System default + device list)
- Survey summary tab ranking: species sorted by detection count descending, then max confidence as tiebreaker; rank numbers shown next to each species; max confidence display bolded
- 3 new l10n keys (EN + DE): `surveyMicrophone`, `surveyMicSystemDefault`, `surveyMicSelect`
- All 480 tests passing, `flutter analyze` clean

**Files Modified:**
- `lib/features/survey/survey_setup_screen.dart` — import `audio_providers.dart`, mic picker tile + `_showDevicePicker()` in `_ParametersStep`
- `lib/features/survey/survey_live_screen.dart` — summary sort by count+confidence, rank numbers, bold max score
- `lib/l10n/app_en.arb` — 3 new keys
- `lib/l10n/app_de.arb` — 3 new keys (German)
- `pubspec.yaml` — version 0.2.5+34
- `CHANGELOG.md` — v0.2.5 entry
- `README.md` — version badge synced

### 2026-04-13 — Help Screen & Home Footer

**Completed:**
- Help screen: dedicated screen (`help_screen.dart`) accessible from home footer — comprehensive guide with expandable ExpansionTile sections for each mode (Live, Point Count, Survey, File Analysis, Explore, Sessions) plus general tips
- Home footer restructured: 5 items in two rows (3: Settings, Explore, Sessions + 2: Help, About) replacing horizontal-scrolling single row
- Inline survey map interactivity: removed `IgnorePointer`, map now supports pinch-zoom, pinch-move, and double-tap zoom in session review
- Map tile loading fix: deferred `fitCamera` in `SurveyMapWidget.onMapReady` to post-frame callback so tiles render correctly on first load
- Audio quality indicator: replaced emoji with mic icon + 3 ascending signal bars (green/amber/red)
- Survey live help overlay: added help button (?) to `_SurveyStatusBar` with DraggableScrollableSheet explaining dashboard icons
- 30+ new l10n keys (EN + DE): help screen content (18), survey live help (6), signal bars context
- All 480 tests passing, `flutter analyze` clean (zero errors)

**Files Created:**
- `lib/features/home/help_screen.dart` — HelpScreen with mode-clustered ExpansionTile sections and tips

**Files Modified:**
- `lib/features/home/home_screen.dart` — footer restructured to 3+2 rows, `_FooterButton` extracted, Help import added
- `lib/features/survey/widgets/survey_map_widget.dart` — `interactionOptions` parameter, deferred `fitCamera` to post-frame callback
- `lib/features/history/session_review_screen.dart` — removed `IgnorePointer` from inline map, added `ClipRRect`
- `lib/features/survey/widgets/survey_stats_bar.dart` — signal bars (mic + 3 ascending bars) replacing emoji
- `lib/features/survey/survey_live_screen.dart` — help button + `_SurveyLiveHelpSheet`
- `lib/l10n/app_en.arb` — 30+ new keys
- `lib/l10n/app_de.arb` — 30+ new keys (German)
- `pubspec.yaml` — version 0.2.4+33
- `CHANGELOG.md` — v0.2.4 entry
- `README.md` — version badge synced

### 2026-04-13 — Session Library & Explore UX

**Completed:**
- Audio quality emoji: replaced mic icon + animated bar in `SurveyStatsBar` with thumbs-up/sideways/down emoji (👍/👉/👎) based on audio quality color thresholds
- Survey field tips: added 4th step to survey setup wizard (Field Tips) with 7 best-practice tips (walk steady, wind, mic placement, silence, timing, repeatability, battery)
- Map scroll freeze fix: replaced `AbsorbPointer` with `IgnorePointer` on inline survey map in session review; map is now a non-interactive preview with separate fullscreen button overlay
- Resume confirmation: `_continueSurvey()` now shows AlertDialog asking user to confirm before resuming a survey session
- Explore help consistency: converted `_showExploreHelp` from `AlertDialog` to `DraggableScrollableSheet` bottom sheet matching session review's `_SessionHelpSheet` pattern
- Session view modes: added detailed (existing), compact (ListTile-based), and by-species (ExpansionTile grouped by species with thumbnails) views to session library; view toggle in AppBar
- Removed unused `_onMapCameraMove` method from session review (inline map is now non-interactive)
- 16 new l10n keys (EN + DE): survey field tips (8), resume dialog (3), session view modes (5)
- All 480 tests passing, `flutter analyze` clean (zero errors)

**Files Modified:**
- `lib/features/survey/widgets/survey_stats_bar.dart` — emoji audio quality indicator
- `lib/features/survey/survey_setup_screen.dart` — 4th step (Field Tips), `_FieldTipsStep` widget
- `lib/features/history/session_review_screen.dart` — map freeze fix (IgnorePointer), resume confirmation dialog, removed unused `_onMapCameraMove`
- `lib/features/explore/explore_screen.dart` — help overlay converted to bottom sheet (`_ExploreHelpSheet`)
- `lib/features/history/session_library_screen.dart` — `_ViewMode` enum, view toggle, `_CompactSessionTile`, `_SpeciesGroupedView`
- `lib/l10n/app_en.arb` — 16 new keys
- `lib/l10n/app_de.arb` — 16 new keys (German)

### 2026-04-13 — Survey Mode UX Polish

**Completed:**
- Tab content area reduced to 40% in survey live screen (flex 2:3 with detection list)
- Home screen logo increased from 96px to 120px
- Species names in session library now translated via TaxonomyService based on species locale setting
- Survey defaults: inference rate 0.3 Hz, max duration 8 hours (smart sampling was already default)
- Fixed survey map initial zoom: added `initialCenter` parameter to `SurveyMapWidget` — uses device GPS location at start instead of Berlin default when no track points yet
- Review map height reduced from 35% to 25% of screen
- Fullscreen survey map: tapping inline map in session review opens fullscreen `SurveyMapWidget` with `fitAllPoints` showing entire track and all species markers
- Resume icon now shows for all survey sessions (corrupted and complete), not just active ones
- 1 new l10n key (EN + DE): surveyTrackMap
- All 480 tests passing, `flutter analyze` clean (zero errors)

**Files Modified:**
- `lib/features/survey/survey_live_screen.dart` — 40% tab area, pass initialCenter to map, add latlong2 import
- `lib/features/survey/widgets/survey_map_widget.dart` — `initialCenter` parameter for GPS-aware initial zoom
- `lib/features/home/home_screen.dart` — logo 96→120px
- `lib/shared/providers/settings_providers.dart` — survey defaults: 0.3 Hz, 8h max
- `lib/features/history/session_review_screen.dart` — map 25%, fullscreen map navigation, resume for all surveys
- `lib/features/history/session_library_screen.dart` — translated species names via TaxonomyService
- `lib/l10n/app_en.arb` — surveyTrackMap
- `lib/l10n/app_de.arb` — surveyTrackMap

### 2026-04-13 — Survey Mode UX Enhancements

**Completed:**
- Tabbed survey live screen: Map / Spectrogram / Summary tabs (TabBar + TabBarView, 50/50 split with detections list)
- Spectrogram tab reuses `SpectrogramWidget` with all settings from Riverpod providers
- Summary tab shows species count, detection count, rate (det/min), sorted species list with best confidence
- Species thumbnail markers on map: `CachedNetworkImage` in confidence-colored circular borders replacing plain colored dots
- Map auto-fit in session review: `CameraFit.bounds()` shows entire route with padding 32, maxZoom 17
- Map-based species filtering in session review: species list dynamically filters by visible map viewport via `onCameraMove` callback
- Tap-to-show on map: `_ClusterRow` gains location pin button for survey sessions; tapping highlights detection on map with blue border
- `SurveyMapWidget` gains `fitAllPoints`, `highlightedDetection`, `onCameraMove` parameters
- Session review map height: 35% of screen (was fixed 200dp)
- 7 new l10n keys (EN + DE): surveyTabMap, surveyTabSpectrogram, surveyTabSummary, surveyTabSummarySpecies, surveyTabSummaryDetections, surveyTabSummaryRate, sessionShowOnMap
- Updated `dev/survey_mode.md` sections 3 and 7 to reflect implementation
- All 480 tests passing, `flutter analyze` clean (zero errors)

**Files Modified:**
- `lib/features/survey/survey_live_screen.dart` — major rewrite: tabbed UI, spectrogram + summary widgets
- `lib/features/survey/widgets/survey_map_widget.dart` — species markers, fitAllPoints, highlight, onCameraMove
- `lib/features/history/session_review_screen.dart` — map filtering, highlight, 35% height
- `lib/features/history/widgets/session_review_widgets.dart` — isSurvey + onShowOnMap on _SpeciesTile/_ClusterRow
- `lib/l10n/app_en.arb` — 7 new keys
- `lib/l10n/app_de.arb` — 7 new keys (German)
- `dev/survey_mode.md` — sections 3 and 7 updated

### 2026-04-12 — Step 11: Survey Mode

**Completed:**
- Design document: `dev/survey_mode.md` (16 sections, comprehensive)
- `GpsPoint` data model with compact JSON serialization (`shared/models/gps_point.dart`)
- Extended `LiveSession` and `DetectionRecord` with GPS track, distance, transect ID, observer name, per-detection lat/lon
- 12 survey PrefKeys in `app_constants.dart` (inference rate, GPS interval, max duration, auto-stop battery, recording mode, clip buffers, sampling, topN, mic device, last observer/transect)
- 12 survey settings providers in `settings_providers.dart`
- `SurveyGpsTracker` — geolocator position stream, manual GPS mode, cumulative Haversine distance, Douglas-Peucker track simplification, detection location interpolation
- `DetectionSampler` — three modes: All (keep everything), TopN (per-species min-heap eviction), Smart (spatially-distributed per-species per-bin budgets with global cap)
- `SurveyController` — composition-based orchestrator with model loading, inference loop, GPS tracking, detection sampling, incremental persistence (30s write-ahead + recovery), auto-stop on max duration
- `SurveyProviders` — separate Riverpod provider graph (recording service, controller, state, detections, session)
- `SurveySetupScreen` — 3-step wizard: Details (name, transect ID, observer, GPS mode), Parameters (inference rate, GPS interval, max duration, recording mode, sampling), Ready (summary + warnings)
- `SurveyLiveScreen` — real-time dashboard with map, stats bar, recent detections list, app lifecycle handling for manual GPS captures
- `SurveyMapWidget` — OpenTopoMap tile layer with GPS track polyline, confidence-colored detection pins, start/end markers, tile consent handling
- `SurveyStatsBar` — compact row: elapsed time, distance, detection count, species count
- GPX 1.1 export (`buildGpxExport`) — track segment + detection waypoints + metadata/author, XML-safe escaping
- GPX added as export format option in settings
- Survey track map integrated into SessionReviewScreen (200dp inline map for survey sessions)
- Survey-specific info (distance, transect ID, observer) shown in session review summary header
- Home screen wired: Survey mode card navigates to SurveySetupScreen (removed "Coming Soon" badge)
- L10n: 50 new keys in EN + DE arb files
- 30 new unit tests: GpsPoint serialization, DetectionSampler (all/topN/smart modes + global cap), GPX export (structure, waypoints, tracks, XML escaping), survey session serialization roundtrips
- All 493 tests passing, `flutter analyze` clean (zero errors)

**Architecture Decisions:**
- SurveyController uses composition (not inheritance) with LiveController's components
- Separate provider graph for survey mode to avoid interference with live mode
- GPS tracker supports 3 modes: background GPS, manual capture, skip
- Write-ahead persistence pattern for crash resilience during long surveys
- Detection sampling runs post-inference (inference always runs; sampling controls what's kept)

**Files Created:**
- `lib/shared/models/gps_point.dart`
- `lib/features/survey/survey_gps_tracker.dart`
- `lib/features/survey/detection_sampler.dart`
- `lib/features/survey/survey_controller.dart`
- `lib/features/survey/survey_providers.dart`
- `lib/features/survey/survey_setup_screen.dart`
- `lib/features/survey/survey_live_screen.dart`
- `lib/features/survey/widgets/survey_map_widget.dart`
- `lib/features/survey/widgets/survey_stats_bar.dart`
- `test/shared/models/gps_point_test.dart`
- `test/features/survey/detection_sampler_test.dart`
- `test/features/survey/gpx_export_test.dart`
- `test/features/survey/survey_session_test.dart`
- `dev/survey_mode.md`

**Files Modified:**
- `lib/features/live/live_session.dart` — GPS track, distance, transect ID, observer name, detection lat/lon
- `lib/core/constants/app_constants.dart` — 12 survey PrefKeys
- `lib/shared/providers/settings_providers.dart` — 12 survey providers
- `lib/features/home/home_screen.dart` — Survey card wiring
- `lib/features/history/session_review_screen.dart` — Survey track map + SurveyMapWidget import
- `lib/features/history/widgets/session_review_widgets.dart` — Survey-specific summary info
- `lib/features/history/session_export.dart` — GPX export + format option
- `lib/features/settings/settings_screen.dart` — GPX format option
- `lib/l10n/app_en.arb` — 50 new survey l10n keys
- `lib/l10n/app_de.arb` — 50 new survey l10n keys (German)

**Next Steps:**
- Android foreground service for background survey operation
- Battery monitoring auto-stop
- Survey settings section in SettingsScreen
- Version bump + sync

### 2025-07-11 — Step 0+1: Project Setup & Foundation

**Completed:**
- README.md at repo root (comprehensive, per design doc spec)
- Flutter 3.27.4 project created with iOS/Android platforms
- Full folder structure: `lib/core/`, `lib/features/`, `lib/shared/`, `lib/l10n/`
- pubspec.yaml with all Step 1 dependencies (Riverpod, SharedPreferences, permission_handler, etc.)
- Localization setup (en/de ARB files, l10n.yaml, flutter generate: true)
- Dark theme (teal/cyan accent, OLED-friendly, Material 3)
- Light theme alternative
- Navigation scaffold with 4 mode tabs (Live, Survey, Point Count, File Analysis)
- Placeholder screens for all 4 modes
- Settings screen with all design doc categories (Audio, Inference, Spectrogram, Recording, Export, General)
- All settings backed by Riverpod + SharedPreferences
- Onboarding carousel (4 pages: welcome, features, permissions, ready)
- Terms of Use / Privacy Policy gate screen
- About screen (version, model info, credits, legal links)
- Permission handling service
- External resource consent service (map tiles, API sync)
- Repository docs: CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, CHANGELOG.md
- MkDocs setup: mkdocs.yml, Material theme, full nav structure
- Documentation stubs: 23 doc pages across user/, developer/, api/
- GitHub Actions: ci.yml, docs.yml, release.yml
- 43 unit tests (all passing) for providers, settings, consent

**Decisions Made:**
- Default theme: Dark (per design doc for field use)
- Teal/cyan color scheme with amber accents for alerts
- Settings use generic notifiers (DoubleSettingNotifier, IntSettingNotifier, etc.) for DRY code
- Consent system uses family provider pattern for extensibility

**Blockers:**
- None

**Next Steps:**
- Step 2: Audio Capture (native platform channels, ring buffer, audio level meter)

### 2026-02-28 — Step 2: Audio Capture

**Completed:**
- Added `record` package (v5.2.1) for native audio capture
- Ring buffer implementation (`Float32List`, lock-free, 640K samples = 2×10s@32kHz)
- `AudioCaptureService` wrapping `record` package: PCM16 streaming at 32kHz mono, converts to float32
- Riverpod providers: `ringBufferProvider`, `audioCaptureServiceProvider`, `captureStateProvider`, `audioLevelProvider`, `inputDevicesProvider`, `selectedDeviceProvider`
- `CaptureStateNotifier` with start/stop/toggle actions
- `AudioLevelMeter` widget with peak-hold indicator and gradient coloring
- `VerticalAudioLevelMeter` variant for compact layouts
- `DeviceSelector` dropdown widget for input device selection
- Integrated audio controls into Live screen (start/stop button, level meter, device selector)
- Live screen layout with spectrogram and detection list placeholder areas
- Barrel export file (`audio.dart`)
- 35 new unit tests (ring buffer: write, read, wrap, RMS, peak; audio service: lifecycle; PCM16 conversion)
- Total: 78 tests passing, `flutter analyze` clean

**Decisions Made:**
- Used `record` package (wraps native Oboe/AVAudioEngine) instead of raw platform channels — same native APIs, less boilerplate, can swap later if needed
- Ring buffer capacity = 2× max window (10s × 32kHz = 640K samples) per design doc
- PCM16-to-float32 conversion in Dart (simple, fast enough for 32kHz mono)
- Level metering via periodic RMS calculation (~15Hz) from ring buffer
- `InputDeviceInfo` data class to avoid leaking `record` package types into UI

**Blockers:**
- None

**Next Steps:**
- Step 3: Spectrogram Visualization (FFT, CustomPainter, scrolling, color maps)

### 2025-07-11 — Step 3: Spectrogram Visualization + Color Palette + Comments

**Completed:**
- Brand color palette: migrated from teal to #0d6efd blue across entire app
  - Light theme primary: `Color(0xFF0D6EFD)` (exact brand hex)
  - Dark theme primary: `Color(0xFF5B9CFF)` (lightened for dark-background readability)
  - Static palette constants on `AppTheme` for shared access
  - `AudioLevelMeter` now uses `theme.colorScheme.primary` instead of hardcoded teal
- Added `fftea` package (^1.2.0) for pure-Dart FFT computation
- FFT processor (`fft_processor.dart`):
  - Configurable FFT size (power of 2), dB floor/ceiling
  - Hann window pre-computed for spectral leakage reduction
  - `process()` → normalized [0,1] Float64List, `processRawDb()` → raw dB values
  - Frequency helpers: `binHz()`, `binFrequency()`, `binCount`
- Color maps (`color_maps.dart`):
  - 5 named palettes: viridis, magma, inferno, grayscale, birdnet (brand-themed)
  - 256-entry ARGB LUT per palette, pre-computed and cached
  - Gradient stop interpolation with `_lerpInt`
- Spectrogram painter (`spectrogram_painter.dart`):
  - CustomPainter with rolling column buffer (oldest-first)
  - Off-screen pixel image via `ui.decodeImageFromPixels` (RGBA8888)
  - Frequency axis labels (1k, 2k, 4k, 8k, 16k Hz) with horizontal guides
  - Time axis labels showing seconds ago
  - Empty-state rendering with instructional text
- Spectrogram widget (`spectrogram_widget.dart`):
  - Ticker-driven 60fps animation loop
  - Reads from RingBuffer, runs FFT, pushes columns to painter
  - Hop-based processing: catches up if UI was blocked
  - RepaintBoundary isolation for GPU compositing
- Wired spectrogram into Live screen:
  - `_LiveSpectrogram` ConsumerWidget connects RingBuffer to SpectrogramWidget
  - Reads spectrogram settings providers (fftSize, colorMap, dbFloor, dbCeiling)
- Enhanced code comments across all audio and spectrogram files:
  - File-level block comment headers with module purpose, data flow, and threading notes
  - Inline dartdoc comments on all public and private members
- 58 new unit tests:
  - `fft_processor_test.dart` (25 tests): construction, frequency helpers, process output
  - `color_maps_test.dart` (22 tests): LUT generation, caching, spot checks
  - `spectrogram_painter_test.dart` (10 tests): column management, shouldRepaint
  - Plus 1 fixed existing test
- Total: 136 tests passing, `flutter analyze` clean (0 issues)

**Decisions Made:**
- Used `fftea` package over raw FFT implementation: well-tested, pure Dart, no native dependencies
- Hann windowing chosen for good frequency resolution with acceptable spectral leakage
- 5 color palettes including brand "birdnet" palette centered on #0d6efd
- LUT-based color mapping (256 entries) for O(1) pixel coloring
- Ticker-driven rendering (~60fps) with hop-based catch-up for smooth scrolling
- Off-screen pixel image via `decodeImageFromPixels` for efficient column-based rendering
- Brand color #0d6efd with lightened variant for dark theme readability

**Blockers:**
- None

**Next Steps:**
- Step 4: ONNX Inference Integration (load model, parse labels, inference isolate, top-K)

### 2025-07-12 — Step 4: ONNX Inference Integration + URL/Email Cleanup

**Completed:**
- Fixed all placeholder URLs/emails to real BirdNET values:
  - GitHub org: `your-org` → `birdnet-team` in app_constants.dart, mkdocs.yml, docs/index.md, CONTRIBUTING.md
  - Email: `support@birdnet.live` / `security@birdnet.live` → `ccb-birdnet@cornell.edu` in app_constants.dart, SECURITY.md, docs/privacy.md
  - MkDocs theme primary color: `teal` → `blue`
- Added `onnxruntime: ^1.4.1` package (dart:ffi based, supports isolates)
- Labels CSV (`labels.csv`) copied to `assets/models/` (790 KB, 11,560 species)
- Data models:
  - `BirdSpecies` — immutable label data class (index, id, scientificName, commonName, className, order)
  - `BirdDetection` — detection result pairing species with confidence score and timestamp
- `LabelParser` — pure Dart semicolon-delimited CSV parser with header validation
- `PostProcessor` — full inference post-processing pipeline:
  - `sigmoid()` with overflow clamping
  - `applySensitivity()` using BirdNET PWA logit-bias formula
  - `topK()` extraction with confidence threshold filtering
  - `logMeanExp()` temporal pooling across recent windows (α=5.0)
- `BirdNetModel` — low-level ONNX session wrapper:
  - `loadModel(path)` reads .onnx from filesystem, creates OrtSession via `fromBuffer`
  - `predict()` zero-pads/truncates input, runs `session.runAsync()`, returns ModelOutput
  - `ModelOutput` with predictions (logits) and optional embeddings
- `InferenceService` — high-level coordinator:
  - `initialize()` loads model + parses labels
  - `infer()` runs model → sigmoid → temporal pooling → sensitivity → top-K
  - Rolling buffer of 5 recent windows for Log-Mean-Exp pooling
- `InferenceIsolate` — background Dart isolate for ONNX inference:
  - `start()/stop()` lifecycle, `infer()` via SendPort/ReceivePort messaging
  - `resetPooling()` to clear temporal buffer
  - Typed message protocol (_WorkerRequest/_WorkerResponse/_WorkerResetPooling)
- Riverpod providers: `inferenceServiceProvider`, `inferenceStateProvider`, `latestDetectionsProvider`, `inferenceErrorProvider`
- Barrel export (`inference.dart`)
- 49 new unit tests:
  - `label_parser_test.dart` (14 tests): CSV parsing, error conditions, real labels file, equality
  - `post_processor_test.dart` (30 tests): sigmoid, sensitivity, top-K, full pipeline, LME pooling, BirdDetection
  - `bird_net_model_test.dart` (5 tests): pre-load state, predict errors, ModelOutput
- Total: 185 tests passing, `flutter analyze` clean (0 issues)

**Decisions Made:**
- `onnxruntime ^1.4.1` over `flutter_onnxruntime ^1.6.3`: latter requires Dart >=3.7.0, project uses Dart 3.6.2
- ONNX model (~259 MB) loaded from filesystem at runtime, not bundled as Flutter asset
- Labels CSV (~790 KB) bundled as Flutter asset in `assets/models/`
- Temporal pooling via Log-Mean-Exp (α=5.0, window of 5 recent inferences) matching BirdNET PWA
- Sensitivity formula: `bias = (sensitivity - 1.0) * 5.0; result = σ(logit + bias)` from reference PWA
- Default confidence threshold: 0.15, default top-K: 5

**Blockers:**
- None

**Next Steps:**
- Step 5: Live Mode End-to-End (audio → spectrogram → inference pipeline, detection list UI, playback, recording, session history)

### 2025-07-13 — Step 4b: Geo-Model, Species Filtering & Generic Renames

**Completed:**
- **Generic renames** (model classifies more than birds):
  - `BirdSpecies` → `Species`, `BirdDetection` → `Detection`, `BirdNetModel` → `ClassifierModel`
  - Renamed files: `bird_species.dart` → `species.dart`, `bird_detection.dart` → `detection.dart`, `bird_net_model.dart` → `classifier_model.dart`
  - All imports, barrel exports, tests, and comments updated accordingly
- **Model bundled as Flutter asset**:
  - ONNX model copied to `assets/models/` (bundled via rootBundle, loaded as bytes)
  - `ClassifierModel.loadModel(Uint8List bytes)` now primary loading method (bytes-based)
  - `ClassifierModel.loadModelFromFile(String path)` retained as convenience method
  - `*.onnx` gitignored (`assets/models/*.onnx`) — model will be smaller soon
  - Constants: `AppConstants.modelAssetPath`, `AppConstants.labelsAssetPath`
- **Geo-model** (`geo_model.dart`):
  - Dummy implementation (real ONNX model to be provided later)
  - Interface: `loadLabels(csv)`, `loadModel()`, `predict(lat, lon, week)` → `Map<String, double>`, `expectedSpecies(...)` → `Set<String>`
  - `dateTimeToWeek(DateTime)` static helper: weeks 1–48, 4 per month
  - Dummy produces deterministic pseudo-random scores seeded from location/week hash
- **Species filter** (`species_filter.dart`):
  - `SpeciesFilterMode` enum: `off`, `geoExclude`, `geoMerge`, `customList`
  - `SpeciesFilter.apply()` dispatches to mode-specific filtering logic
  - `geoExclude`: keep only species present in geo-model above threshold
  - `geoMerge`: multiply audio × geo scores, re-sort, re-filter by confidence
  - `customList`: keep only species in user-defined set
- **Custom species list** (`custom_species_list.dart`):
  - `parse()`: one scientific name per line, `#` comments, deduplication
  - Persistence: `save/load/delete/listSaved` via `.txt` files in app documents dir
- **Providers & settings**:
  - `geoModelProvider` (GeoModel singleton), `customSpeciesProvider` (StateProvider)
  - `speciesFilterModeProvider` (default 'off'), `geoModelThresholdProvider` (default 0.03), `selectedSpeciesListProvider` (default '')
  - New `PrefKeys`: `speciesFilterMode`, `geoModelThreshold`, `selectedSpeciesList`
- **48 new tests** (10 custom_species_list + 17 species_filter + 21 geo_model):
  - Geo-model: lifecycle, prediction, expected species, week calculation
  - Species filter: all 4 modes, edge cases
  - Custom species list: parsing, comments, deduplication, edge cases
- Total: **233 tests passing**, `flutter analyze` clean (0 issues)

**Decisions Made:**
- Generic naming chosen because BirdNET model classifies beyond birds
- Model bundled as asset (not filesystem) for simpler deployment; gitignored due to size (~259 MB, will shrink)
- Geo-model uses dummy implementation: deterministic pseudo-random scores for testing until real ONNX model arrives
- Geo-model week convention: 1–48 (4 per month, mapping month → (month - 1) * 4 + day-of-month quartile)
- Species filter multiplication (geoMerge): `merged = audioScore × geoScore` — simple, weights geo as attenuator
- Geo threshold default 0.03 (3% — permissive, avoids false negatives)
- Custom species lists stored as plain `.txt` files for easy manual editing/sharing

**Blockers:**
- None

**Next Steps:**
- Step 4c: Model-agnostic inference config

### 2025-07-13 — Step 4c: Model-Agnostic Inference Config

**Completed:**
- **ModelConfig class hierarchy** (`model_config.dart`):
  - `ModelConfig` (top-level): name, version, description, audio, onnx, labels, inference
  - `AudioConfig`: sampleRate, channels
  - `OnnxConfig`: modelFile, inputName, outputNames map, computed `predictionsName`/`embeddingsName`
  - `LabelsConfig`: file, delimiter, hasHeader, columns mapping
  - `InferenceDefaults`: supportedWindowSeconds, defaultWindowSeconds, defaultSensitivity, defaultConfidenceThreshold, defaultTopK, temporalPooling
  - `TemporalPoolingConfig`: maxWindows, alpha
  - Full JSON serialization (`fromJson`/`toJson`) with sensible BirdNET-compatible defaults
- **Default model config** (`assets/models/model_config.json`):
  - BirdNET+ V3.0-preview3 Global (FP16) settings
  - 32kHz sample rate, tensor names, semicolon-delimited labels, LME pooling (5 windows, α=5.0)
- **ClassifierModel** updated:
  - Configurable tensor names (`inputName`, `predictionsName`, `embeddingsName`)
  - `loadModel()` accepts optional tensor name params, defaults to BirdNET conventions
  - `predict()` uses configurable names instead of hardcoded strings
- **LabelParser** rewritten:
  - Accepts optional `LabelsConfig` parameter
  - Configurable delimiter, column mapping (`Map<String,String>`), header/no-header mode
  - Auto-generates index from row position when no index column
  - Case-insensitive header matching via `_resolveColumnIndices()`
  - Backward compatible: no config → BirdNET semicolon-delimited defaults
- **InferenceService** rewritten:
  - All hardcoded constants removed (sampleRate, maxPoolWindows, poolingAlpha)
  - `initialize()` requires `ModelConfig config` — reads all values from config
  - Passes config to `LabelParser.parse()` and `ClassifierModel.loadModel()`
  - `infer()` params now nullable with config-driven fallbacks
- **InferenceIsolate** updated:
  - `start()` requires `ModelConfig config`
  - Config serialized to `Map<String, dynamic>` for isolate transfer, deserialized in worker
  - `infer()` params now nullable
- **Providers & constants**:
  - Added `modelConfigProvider` (`StateProvider<ModelConfig?>`) to `inference_providers.dart`
  - `AppConstants`: removed `modelName`, `modelAssetPath`, `labelsAssetPath`, `embeddingDimension`
  - `AppConstants`: added `modelConfigAssetPath`, `modelAssetsDir`
  - `sampleRate` and `speciesCount` kept as app-level defaults (overridden at runtime by config)
- **Barrel export** updated: added `model_config.dart` to `inference.dart`
- **18 new/revised tests** (251 total, was 233):
  - `model_config_test.dart` (21 tests): all config classes, round-trip JSON, defaults, real file integration
  - `label_parser_test.dart` rewritten (18 tests): 12 default format + 6 custom config (comma/tab/auto-index/headerless/case-insensitive)
- `flutter analyze` clean (0 issues), `flutter test` → **251 tests passing**

**Decisions Made:**
- JSON over YAML: `dart:convert` built-in, no extra dependency needed
- Config passed through isolate via `toJson()`/`fromJson()` — complex objects can't cross isolate boundary directly
- All config fields have BirdNET-compatible defaults for backward compatibility
- `sampleRate` kept in `AppConstants` as default for audio capture before model loads
- Label parser redesigned to be lenient (auto-index, optional columns, case-insensitive headers)

**Blockers:**
- None

**Next Steps:**
- Step 5: Live Mode End-to-End (audio → spectrogram → inference pipeline, detection list UI, playback, recording, session history)

### 2025-07-14 — Step 5: Live Mode (End-to-End)

**Completed:**
- **LiveSession data model** (`live_session.dart`):
  - `SessionSettings` — snapshot of inference settings (windowDuration, confidenceThreshold, inferenceRate, speciesFilterMode) with JSON serde
  - `DetectionRecord` — timestamped detection for persistence (scientificName, commonName, confidence, timestamp, audioClipPath?), `fromDetection()` factory, JSON serde, equality
  - `LiveSession` — complete session model (id, startTime, endTime?, detections list, recordingPath?, settings), `isActive`, `duration`, `uniqueSpeciesCount`, `addDetection()`, `addDetections()`, `end()`, JSON serde
- **WAV writer** (`wav_writer.dart`):
  - Streaming: `WavWriter(filePath, sampleRate)` → `open()` → `writeSamples(Float32List)` → `close()` with header rewrite
  - One-shot: `WavWriter.writeFile()` static method for single-call WAV creation
  - In-memory: `WavWriter.toBytes()` for testing (no filesystem)
  - 16-bit PCM encoding with float32→int16 clamped conversion, proper RIFF header
- **Recording service** (`recording_service.dart`):
  - `RecordingMode` enum: off, full, detectionsOnly
  - Continuous recording: periodic 1s timer reads from ring buffer → appends to streaming WAV writer
  - Detection-only: `saveDetectionClip()` saves pre+post buffer around detection
  - File layout: `<appDir>/recordings/<sessionId>/full.wav` or `clip_<ts>.wav`
- **LiveController** (`live_controller.dart`):
  - `LiveState` enum: idle, loading, ready, active, error
  - `loadModel()` — loads config JSON, ONNX bytes, labels CSV from rootBundle → starts InferenceIsolate
  - `startSession()` — starts inference timer, recording, creates session
  - `stopSession()` — stops timer, finalizes recording, returns completed session
  - `_runInference()` — reads window from ring buffer → isolate.infer() → accumulates DetectionRecords
  - `playClip()` / `stopPlayback()` — just_audio audio playback
  - `onStateChanged` callback for Riverpod integration
  - Timer interval = 1000/inferenceRate ms, skips silent audio
- **Session repository** (`session_repository.dart`):
  - JSON-file-based persistence (chose over Isar — simpler, no code gen, no native binaries)
  - File layout: `<appDir>/sessions/<id>.json`
  - Methods: save, load, listAll (sorted newest first), delete (+ recordings dir), deleteAll, count
  - `basePath` setter for testing
- **Detection list widget** (`detection_list_widget.dart`):
  - `DetectionList` — scrollable ListView with empty state
  - `DetectionTile` — shows commonName (bold), scientificName (italic), confidence bar (color-coded red/amber/green), time ago, play icon if clip available
  - `_EmptyState` — context-aware ("Listening…" when active vs "Start a session" when idle)
- **Live providers** (`live_providers.dart`):
  - `recordingServiceProvider`, `liveControllerProvider`, `liveStateProvider`
  - `sessionDetectionsProvider`, `latestLiveDetectionsProvider`, `currentSessionProvider`
  - `sessionRepositoryProvider`, `sessionListProvider`
- **Live screen rewrite** (`live_screen.dart`):
  - ConsumerStatefulWidget with eager model loading in `initState()`
  - `_toggleSession()` orchestrates full start/stop: model load → capture → inference → session save
  - `_StatusBanner` — model loading/error banner with spinner and retry
  - `_SessionInfoBar` — "X species · Y detections" during active session
  - `_CaptureButton` — loading state with CircularProgressIndicator
  - Detection list replaces placeholder
- **Barrel exports**: `live.dart`, `recording.dart`, `history.dart`
- **Dependency**: added `just_audio ^0.10.5` for detection audio playback
- **66 new tests** (317 total, was 251):
  - `live_session_test.dart` (19 tests): SessionSettings, DetectionRecord, LiveSession — JSON serde, equality, state management
  - `wav_writer_test.dart` (20 tests): RIFF header, PCM encoding, clamping, streaming, file write, duration
  - `session_repository_test.dart` (15 tests): save/load, overwrite, listAll sorted, corrupt file handling, delete, deleteAll, count, ID sanitisation
  - `recording_service_test.dart` (12 tests): mode parsing, initial state, off mode, silence detection, enum values
- `flutter analyze` clean (0 issues), `flutter test` → **317 tests passing**

**Decisions Made:**
- JSON file persistence over Isar: no code generation, no native binaries, adequate for session data sizes
- ConsumerStatefulWidget for live screen: needed `initState()` for eager model loading and state callback registration
- LiveController as self-contained orchestrator: manages model, inference loop, session, recording, playback — decoupled from providers via callback
- Timer-based inference at configurable Hz rate (default 1 Hz): reads latest `windowDuration * sampleRate` samples from ring buffer each tick
- just_audio for playback: plays saved detection clips from filesystem
- Detection list accumulates all detections (newest first), no deduplication in MVP
- WAV writer supports both streaming (for full recording) and one-shot (for detection clips)

**Blockers:**
- None

**Next Steps:**
- Step 6: GPS & Location (GPS service, map view, offline tiles, detection pins)

### 2026-03-01 — UX Polish: Icons, Wakelock, Edge-to-Edge, Onboarding

**Completed:**
- **BirdNET launcher icon**: set `logo-birdnet-circle.png` as the app launcher icon for Android (adaptive) and iOS via `flutter_launcher_icons`
- **BirdNET logo in onboarding & about screens**: replaced `Icons.flutter_dash` with the BirdNET logo PNG in the onboarding welcome page and the about screen header
- **Wakelock for live mode**: implemented native Android platform channel (`WakelockService`) to keep the screen on during active capture. Uses `FLAG_KEEP_SCREEN_ON` via `MethodChannel('com.birdnet.birdnet_live/wakelock')`. Chose native implementation after `wakelock_plus` caused cross-drive Gradle build failures.
- **Edge-to-edge nav bar flicker fix**: moved `SystemChrome.setEnabledSystemUIMode` and `setSystemUIOverlayStyle` calls from widget `build()` methods to `main.dart` (one-time setup), preventing flicker on navigation transitions
- **Onboarding nav bar padding fix**: changed `controlsPadding` from `const EdgeInsets.all(16)` to `EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom)` so next/skip/done buttons are not hidden under the system nav bar
- **Gradle upgraded** from 8.3 → 8.9 for Java 21 compatibility
- **Jetifier disabled** (`android.enableJetifier=false`)
- **Kotlin incremental compilation disabled** (`kotlin.incremental=false`) to fix cross-drive build issue (project on D:, pub cache on C:)
- Total: **309 tests passing**, `flutter analyze` clean

**Decisions Made:**
- Native platform channel for wakelock over `wakelock_plus` package: avoided Gradle cross-drive build failures
- System UI configuration in `main.dart` instead of per-screen: eliminates flicker, single source of truth

**Blockers:**
- None

### 2026-03-02 — Spectrogram Enhancements, Settings UX, App Icon

**Completed:**
- **Log amplitude scaling**: added configurable `logAmplitude` toggle to spectrogram (default: on). Applies `log(1 + v*10) / log(11)` curve to normalized FFT magnitudes, compressing dynamic range and making quieter sounds more visible. New `logAmplitudeProvider` (BoolSettingNotifier) + `PrefKeys.logAmplitude`. Wired through `SpectrogramWidget` → `_LiveSpectrogram`.
- **Spectrogram defaults updated**: `spectrogramDuration` 15 → 20 seconds, `spectrogramMaxFreq` 10000 → 12000 Hz.
- **Microphone input selector**: added device picker in Audio settings. Uses existing `inputDevicesProvider` + `selectedDeviceProvider`. Bottom-sheet radio picker (replaces inline dropdown that caused "Microphone" to wrap to 3 lines on narrow screens).
- **Default theme changed**: system (follows device light/dark) instead of hardcoded dark.
- **Context-aware settings**: `SettingsContext` enum (`all`, `live`, `survey`, `pointCount`, `fileAnalysis`). Each settings section tagged with relevant contexts via static map. `_showSection()` filters sections based on context. Live screen passes `SettingsContext.live`; home screen uses `SettingsContext.all`.
- **App icon generation script** (`dev/generate_app_icon.py`):
  - Takes `dev/BirdNET+_Logo.png` → generates 3 outputs:
    - `assets/images/app-icon.png` (1024×1024, gradient bg + centered logo)
    - `assets/images/app-icon-foreground.png` (logo on transparent, adaptive safe-zone inset)
    - `assets/images/app-icon-background.png` (gradient only for adaptive bg)
  - Gradient: deep navy #0A1628 → #1A3A5C
  - `remove_alpha_ios: true` for App Store compliance
  - Regenerate: `python dev/generate_app_icon.py && dart run flutter_launcher_icons`
- **Updated IMPLEMENTATION.md** with all changes
- Total: **309 tests passing**, `flutter analyze` clean

**Decisions Made:**
- Log amplitude default ON: `log(1+v*10)/log(11)` chosen as a good balance between contrast enhancement and preserving relative loudness
- Bottom-sheet radio picker for mic selector: avoids text overflow on narrow screens that occurred with inline `DropdownButton`
- System theme as default: more user-friendly than forcing dark mode
- Context-aware settings via static section→context map: simple, extensible, no per-widget registration needed. New screens just pass their `SettingsContext` enum value.
- Adaptive icon separate fg/bg layers: background is gradient image (not solid color), foreground respects Android 108dp/66dp safe-zone ratio

**Blockers:**
- None

**Next Steps:**
- Step 6: GPS & Location (GPS service, map view, offline tiles, detection pins)

### 2026-03-02 — Step 6: GPS, Geo-Model, Explore & Taxonomy

**Completed:**
- **GPS location service** (`core/services/location_service.dart`):
  - `LocationService` wrapping `geolocator` package: permission checks, GPS position, manual override
  - `AppLocation` data class (lat/lon)
  - Cached `lastKnownLocation`, 10s timeout, medium accuracy
  - Reusable across all features (live, explore, survey)
- **Geo-model real ONNX implementation** (`features/inference/geo_model.dart`):
  - Complete rewrite from dummy implementation to real ONNX inference
  - Input tensor: float32 [1, 3] = [lat, lon, week], output: [1, N] probability vector
  - Tab-delimited labels parser (id, sci_name, com_name)
  - `predict()`, `expectedSpecies()`, `geoScoresForFilter()` methods
  - `dateTimeToWeek()`: weeks 1–48, 4 per month
  - Configurable tensor names (input/output) from model config
- **Taxonomy species model** (`shared/models/taxonomy_species.dart`):
  - Rich species metadata: names, IDs (eBird, iNat, BirdNET), images, descriptions, localized names
  - Factory constructors: `fromCsvRow()` (CSV parser), `fromApiJson()` (API response)
  - Convenience getters: `thumbUrl`, `mediumUrl`, `ebirdUrl`, `inatUrl`, `descriptionForLocale()`, `commonNameForLocale()`
  - Equality based on scientific name
- **Taxonomy service** (`shared/services/taxonomy_service.dart`):
  - CSV loading with quote-aware comma parser
  - O(1) lookup by scientific name, prefix search, batch lookupAll
  - API enrichment: `/api/species/{name}` with in-memory cache, locale support
  - Static URL builders: `thumbUrl()`, `mediumUrl()`
- **Explore providers** (`features/explore/explore_providers.dart`):
  - `locationServiceProvider` (singleton), `currentLocationProvider` (respects useGps setting)
  - `taxonomyServiceProvider` (loads CSV from assets), `geoModelProvider` (extracts ONNX to disk)
  - `exploreSpeciesProvider` (combines geo+taxonomy), `geoScoresProvider` (for live mode filter)
- **Explore screen** (`features/explore/explore_screen.dart`):
  - Browse species in user's area with location header, species list, refresh
  - `SpeciesCard` widget: 4:3 thumbnail (CachedNetworkImage), names, geo score indicator
  - `SpeciesInfoOverlay` modal sheet: medium image, names, Wikipedia excerpt, external link chips (eBird, iNat, Wikipedia), image credit
- **Live mode geo-integration** (`features/live/live_controller.dart`, `live_screen.dart`):
  - Loads geo-scores before session start, passes to controller
  - `SpeciesFilter.apply()` runs after each inference with `geoExclude` mode
  - Filtered detections used for both display and session history
- **Detection thumbnails** (`features/live/widgets/detection_list_widget.dart`):
  - 60×45 CachedNetworkImage thumbnail on each detection tile
- **Home screen** (`features/home/home_screen.dart`):
  - Replaced Point Count card with Explore card → navigates to ExploreScreen
- **Settings integration** (`features/settings/settings_screen.dart`):
  - Location section: GPS toggle, manual lat/lon sliders, geo threshold slider
  - Wired to `useGpsProvider`, `manualLatitudeProvider`, `manualLongitudeProvider`, `geoThresholdProvider`
- **L10n** (16 new keys in EN + DE): explore mode, location settings, geo threshold labels
- **Copilot instructions** (`.github/copilot-instructions.md`): project overview, architecture, models, API, conventions
- **Assets**:
  - Copied geomodel ONNX (7 MB) + labels (11,827 species) + taxonomy CSV (13,968 species) to `assets/models/`
  - Updated `model_config.json` with geoModel section
  - Added `geolocator ^13.0.2`, `http ^1.2.2`, `cached_network_image ^3.4.1` to pubspec.yaml
- **55 new tests** (372 total, was 317):
  - `geo_model_test.dart` rewritten (24 tests): label parsing, lifecycle, week calculation, data classes
  - `taxonomy_species_test.dart` (28 tests): CSV/API factories, URL getters, descriptions, equality
  - `taxonomy_service_test.dart` (20 tests): CSV loading, lookup, search, URL builders
  - `location_service_test.dart` (5 tests): AppLocation data class, manual override
  - `settings_providers_test.dart` (+4 tests): useGps, geoThreshold, manualLatitude, manualLongitude defaults
- `flutter analyze` clean (0 issues), `flutter test` → **372 tests passing**

**Decisions Made:**
- Geo-model rewrite: real ONNX inference via `onnxruntime` FFI, replacing dummy pseudo-random implementation
- Tab-delimited labels (matching reference labels file format) instead of semicolon CSV
- Taxonomy API for enrichment (descriptions, localized names, images) with in-memory cache
- CachedNetworkImage for species thumbnails: lazy loading + disk cache out of the box
- Explore screen uses same geo-model providers as live mode (DRY)
- SpeciesInfoOverlay as DraggableScrollableSheet: reusable, doesn't require navigation
- GPS fallback: manual lat/lon settings when GPS is off or unavailable
- Detection thumbnails 60×45 px (matches 4:3 aspect ratio of API images)
- geo-model extracted to disk (temp directory) on first use — required by onnxruntime session loader

**Blockers:**
- None

**Next Steps:**
- Step 7: Session History, Export & Recording Formats

### 2026-03 — Step 7: Session History, Export & Recording Formats

**Completed:**
- **Session library screen** (`session_library_screen.dart`):
  - Browse all saved sessions with search and sorting
  - Each row shows date, duration, species count, detection count
  - Tap to open session review
- **Session review screen** (`session_review_screen.dart`):
  - Species-collapsed detection list with consecutive clustering
  - Audio playback with real-time spectrogram strip
  - Playback highlighting: species row pulses when audio reaches detection timestamp
  - Undo/redo snapshot system for all editing operations
  - Add/edit/delete detections with confirmation dialogs
  - Trim recording with draggable handle UI
  - Add annotations (global or timestamped text notes)
  - Session renaming (editable session names)
  - Auto-numbered sessions ("Live Session #1", "#2", etc.)
- **Session map screen** (`session_map_screen.dart`):
  - Recording location on OpenStreetMap via flutter_map
  - Map tile privacy consent dialog (first use)
- **Session export** (`session_export.dart`):
  - Raven Pro selection table (.txt, tab-delimited, compatible with Raven Pro/Lite)
  - CSV export (.csv)
  - JSON export (.json)
  - ZIP bundle (.zip) — archives recording + metadata for sharing
- **FLAC encoder** (`flac_encoder.dart`):
  - Pure Dart FLAC encoder (~350 lines), no platform dependencies
  - Fixed predictors with Rice coding, 50–60% compression on bird audio
  - Mono 16-bit, works with any sample rate
- **Audio decoder** (`audio_decoder.dart`):
  - Decode WAV and FLAC back to PCM for session review playback
- **Session review widgets** (`session_review_widgets.dart`):
  - Summary header, species groups, detection clustering, playback highlighting
- **L10n**: ~60 new keys (EN + DE) for session management, export, editing
- **New tests**: session_export_test.dart, flac_encoder_test.dart
- Total: **426 tests** passing

**Decisions Made:**
- Pure Dart FLAC encoder over platform encoders: cross-platform parity, no native dependencies
- Undo/redo via immutable session snapshots: simple, reliable state management
- Species-collapsed list with consecutive clustering: reduces noise from continuous calling
- Raven Pro format: standard in ornithology, compatible with Cornell's own software

### 2026-03 — Step 7b: Model Build Pipeline

**Completed:**
- **Model pruning pipeline** (`dev/build_models.py`):
  - Orchestrator script running 3 steps: prune → fix audio → fix geomodel
  - `prune_models.py`: intersect audio + geo species to 5,250-species subset
  - `fix_audio_model.py`: ARM64 FP16 precision fix — inserts Cast(FP16→FP32) before every weight, downgrade opset 20→17, IR 10→9, convert Reduce axes from graph input to attribute
  - `fix_geomodel.py`: decompose LayerNormalization into primitive ops for ORT 1.15
- **Documentation** (`dev/MODELS.md`): full explanation of model build pipeline
- **APK size reduction**: 419 MB debug → 185 MB release via ABI filter (arm64-v8a only), R8 shrink, ProGuard rules
- **Memory leak fixes**: various leak fixes identified during stress testing
- **Integration tests**:
  - `model_output_test.dart`: validates ONNX model output against reference detections
  - `memory_stress_test.dart`: long-running session memory profiling
  - `geo_soundscape_test.dart`: geo-model + explore screen end-to-end

### 2026-04-10 — Step 8: UX & Documentation Polish

**Completed:**
- **About screen overhaul** (`about_screen.dart`):
  - Added Geo-Model card (name + description)
  - Added Funding card (full K. Lisa Yang Center + German ministry acknowledgments)
  - Added BirdNET Website link (birdnet.cornell.edu)
  - Removed Open Source Licenses link
  - Terms of Use now opens GitHub repo file externally
- **Privacy policy** (`docs/privacy.md`): overhauled to mention on-device inference (audio + geo-model), taxonomy API, no analytics/tracking
- **Terms of use** (`TERMS_OF_USE.md`): rewritten for both app + bundled models, MIT code + CC BY-SA 4.0 weights, prohibited uses
- **Explore screen improvements** (`explore_screen.dart`):
  - Reverse geocoding for location names
  - Lat/lon on separate row below location name
  - Enlarged help icon (22px), removed species count text
  - Help dialog with geo-model explanation + "Learn more" link
- **Species info overlay enhancements** (`species_info_overlay.dart`):
  - Image credit moved directly below photo (before names)
  - Description source attribution
  - Real brand logos (eBird, iNaturalist, Wikipedia) as link chip icons
  - Weekly 48-week probability chart
  - "Learn more" section header
- **Settings improvements** (`settings_screen.dart`):
  - Danger Zone with double-confirm: reset onboarding shows confirmation dialog, clear data requires typing "DELETE"
  - Section descriptions expanded with practical guidance for each category
  - Removed all leading icons from General section for consistency
  - Sensitivity slider (0.5–1.5)
  - Score pooling dropdown (off/average/max/lme)
- **Brand icons**: Processed real logos from source images via Python PIL (48×48 PNGs)
- **Copilot instructions** (`.github/copilot-instructions.md`): comprehensive project overview
- **L10n**: ~30 new keys (EN + DE) for about, settings, explore, species overlay
- **Documentation overhaul**:
  - README updated: features list (Explore, Session Library, FLAC, export formats), platforms badge (Android/iOS/Windows), screenshot placeholders
  - User docs: rewrote settings.md (all 7 sections with complete tables), export-sync.md (4 export formats + Raven table spec), getting-started.md (added Windows), FAQ (fixed species count to 5,250)
  - New user docs: explore.md, session-library.md
  - Developer docs: testing.md (426 tests + integration test table), database.md (FLAC mention)
  - Fixed privacy.md (duplicate contact section, "Local database" → "JSON files")
  - MkDocs nav restructured: added Explore, Session Library, Session Review; renamed Database to Storage
  - Updated docs/index.md features list
  - design.md: fixed species count (5,250), platforms (Windows), audio capture (record package), database (JSON), tech stack, renumbered steps 1–14
- Total: **426 tests** passing, `flutter analyze` clean

### 2026-04-10 — Step 9a: About Screen Refinements

**Completed:**
- **Species count corrected**: `AppConstants.speciesCount` updated from 11,560 to 5,250 (matching pruned model)
- **Geo-model card**: added species count display to geo-model info card
- **Funding card removed**: removed K. Lisa Yang Center + German ministry funding card from about screen + all l10n strings (EN + DE)
- **BirdNET website link icon**: blue jay PNG (`icon-birdnet.png`) with `ColorFiltered(onSurfaceVariant)` to match other ListTile icons
- **GitHub link text**: changed to "This App on GitHub" / "Diese App auf GitHub"
- **Model names**: simplified display from "5K-pruned" to "(pruned, FP16)"
- Version bumped to `0.1.26+26`
- Total: **445 tests** passing

### 2026-04-10 — Step 9b: File Analysis Wizard

**Completed:**
- **File analysis screen** (`file_analysis_screen.dart`):
  - 4-step wizard: Pick File → Location & Date → Parameters → Analyze
  - Multi-format audio support: WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA, AMR
  - Audio resampler (`DecodedAudio.resampleTo()`) for files not at 32 kHz
  - File metadata display (name, format, duration, size, sample rate, channels)
- **Location step**:
  - Auto-fetch GPS when entering step with GPS selected
  - Manual coordinate entry (lat/lon text fields)
  - Map picker (`_MapPickerScreen`) — full-screen FlutterMap with tap-to-place pin, consent check
  - Three modes: Current GPS, Manual, Skip (now unified into SegmentedButton)
- **Date picker**: optional recording date, defaults to "Today (default)", used for seasonal filtering
- **Analysis parameters**: window duration, overlap, sensitivity, confidence threshold, species filter mode
- **Progress UI**: window count, detections, species found with real-time stat cards
- **Session integration**: results saved to session repository, navigates to SessionReviewScreen
- **File analysis controller** (`file_analysis_controller.dart`):
  - `inspectFile()` — reads metadata (format, duration, sample rate, channels, size)
  - `analyze()` — decodes audio, resamples to 32 kHz, windows with configurable overlap, runs inference
  - Cancellable analysis with progress callbacks
- **L10n**: ~30 new keys (EN + DE) for file analysis wizard
- **Tests**: file_analysis_controller_test.dart
- Version bumped to `0.1.27+27`
- Total: **445 tests** passing

### 2026-04-11 — Step 10: Point Count Mode

**Completed:**
- **Setup wizard** (`point_count_setup_screen.dart`): 3-step flow — duration picker (3/5/10/15/20 min ChoiceChips) + GPS coords + date, field protocol tips (6 items with icons), ready confirmation with "Start Count" button
- **Live survey screen** (`point_count_live_screen.dart`): auto-starts inference on entry, countdown timer (mm:ss monospace, red at ≤30 s), linear progress bar, spectrogram + detection list, auto-finalizes to session review at zero, "End Count Early" with confirmation dialog
- **PrefKey + provider**: `PrefKeys.pointCountDuration` + `pointCountDurationProvider` (IntSettingNotifier, default 5 min)
- **LiveSession.type made mutable**: changed `final SessionType type` → `SessionType type` so point count screen can set type post-creation
- **Home screen wiring**: removed `comingSoon: true` from Point Count card, added `_openPointCount()` navigation
- **Localization**: 20+ new strings in EN + DE (setup titles, duration labels, tip strings, countdown, completion, early stop dialog)
- Total: **445 tests** passing, `flutter analyze` clean (0 errors)

**Decisions Made:**
- Reuse entire Live mode infrastructure (LiveController, audio capture, ring buffer, spectrogram, recording, inference isolate) — point count adds countdown + auto-stop only
- No FAB or pause button — protocol compliance requires uninterrupted recording
- Session type set after finalization rather than at creation (avoids modifying LiveController)

**Next Steps:**
- Step 9 (Survey Mode) is the next major planned feature
- Step 12: Export & API Sync improvements

### 2026-04-10 — Step 9c: Version Management & Icon Standardization

**Completed:**
- **Single-source version**: created `dev/sync_version.dart` — reads version from `pubspec.yaml` (single source of truth), updates README badge via regex replacement. Updated copilot-instructions with workflow.
- **Location selector compacted**: replaced 3 `_ChoiceTile` cards (GPS / Manual / Skip) with a single `SegmentedButton<_LocationChoice>` — labels "Current" / "Manual" / "None". Removed `_ChoiceTile` widget class entirely.
- **Species icon standardized**: unified to `Icons.eco` / `Icons.eco_outlined` across all screens:
  - `file_analysis_screen.dart`: `Icons.pets` → `Icons.eco`
  - `session_library_screen.dart`: `Icons.pets_outlined` → `Icons.eco_outlined`
  - `session_review_widgets.dart`: `Icons.flutter_dash` → `Icons.eco`
- **Removed `Icons.flutter_dash`**: Flutter's Dash mascot ("bird with headphones") no longer used anywhere
- **Removed unused l10n strings**: `_ChoiceTile` subtitle strings (GPS/Manual/Skip subtitles) in EN + DE
- **Created UI style guide** (`dev/STYLE_GUIDE.md`): comprehensive icon inventory, color system, component patterns, typography
- **Updated `IMPLEMENTATION.md`**: fixed architecture tree (added explore, file_analysis), corrected model config example (5K-pruned)
- Total: **445 tests** passing

### 2026-04-11 — Housekeeping: Stale Refs, App Icon & Label, Documentation

**Completed:**
- **Stale model references fixed**:
  - `model_config.json`: version "opset18" → "opset17" (matches actual deployed audio model)
  - `dev/run_onnx_reference.py`: model paths 11K → 5K-pruned (local only, gitignored)
  - `dev/reference_detections.json`: modelFile 11K → 5K-pruned (local only, gitignored)
  - `dev/test_windows_meta.json`: modelFile 11K → 5K-pruned (local only, gitignored)
- **App label fixed**: `android:label` in AndroidManifest.xml changed from "birdnet_live" → "BirdNET Live"
- **App icons regenerated**: ran `dart run flutter_launcher_icons` to refresh all mipmap/drawable resources
- **MkDocs documentation updated**:
  - Point Count mode: full user guide (setup wizard, countdown, early stop, tips)
  - File Analysis: full user guide (wizard steps, supported formats, resampling)
  - Removed "Coming Soon" banners from Point Count and File Analysis docs
  - Updated index.md feature list (Point Count + File Analysis marked as implemented)
  - FAQ: added Point Count section, updated File Analysis answer
  - Session Library: now mentions Point Count and File Analysis sessions
  - Session Review: now mentions Point Count and File Analysis
  - Live Mode: fixed species count (11,000+ → 5,250)
  - Settings: removed duplicate sections at bottom of page
- **PROGRESS.md**: updated step checklists, fixed Step 11 (File Analysis) as complete, updated Step 14 (Documentation)
- **IMPLEMENTATION.md**: added Point Count section, updated test count, added File Analysis section

### Step 0: README
- [x] Create comprehensive README.md at repo root
- [x] Add project logo reference
- [x] Add features list
- [x] Add quick start instructions
- [x] Add links to dev resources (design.md, PROGRESS.md, use_cases.md)
- [x] Add project structure overview

### Step 1: Project Foundation
- [x] Flutter project created (`flutter create`)
- [x] Folder structure set up (`lib/core/`, `lib/features/`, `lib/shared/`)
- [x] Repository docs (README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY)
- [x] MkDocs setup (mkdocs.yml, initial docs/)
- [x] GitHub Actions for docs deployment
- [x] Localization (flutter_localizations, app_en.arb, app_de.arb)
- [x] Navigation scaffold (mode tabs)
- [x] Dark theme
- [x] Permission handling service
- [x] External resource consent service
- [x] Settings infrastructure (Riverpod + SharedPreferences)
- [x] Onboarding flow
- [x] Terms/Privacy acceptance gate
- [x] About screen

### Step 2: Audio Capture
- [x] Native audio capture service (platform channels)
- [x] 32kHz mono capture working
- [x] Ring buffer implementation
- [x] Audio stream to isolate
- [x] Audio level meter widget
- [x] Microphone selection

### Step 3: Spectrogram Visualization
- [x] FFT processor
- [x] CustomPainter spectrogram
- [x] Scrolling animation (60fps)
- [x] Color maps
- [x] Axis labels

### Step 4: ONNX Inference Integration
- [x] Load ONNX model
- [x] Parse labels CSV
- [x] Inference isolate
- [x] Configurable window size
- [x] Top-K extraction
- [x] Confidence filtering
- [x] Generic class names (Species, Detection, ClassifierModel)
- [x] Bytes-based model loading (bundled as Flutter asset)
- [x] Geo-model dummy implementation (lat, lon, week → species scores)
- [x] Species filter (off, geoExclude, geoMerge, customList)
- [x] Custom species list persistence (parse, save, load, delete)
- [x] Providers & settings for geo-model and species filtering
- [x] Model-agnostic JSON config (ModelConfig, configurable tensors/labels/defaults)
- [x] Geo-model real ONNX implementation (replacing dummy)

### Step 5: Live Mode (End-to-End)
- [x] Audio → spectrogram → inference pipeline
- [x] Detection list UI
- [x] Tap to playback
- [x] Recording service
- [x] Session history (JSON file persistence)

### Step 6: GPS, Geo-Model, Explore & Taxonomy
- [x] GPS location service (geolocator)
- [x] Location provider (with manual fallback)
- [x] Geo-model real ONNX inference
- [x] Taxonomy species model (CSV + API)
- [x] Taxonomy service (lookup, search, API enrichment)
- [x] Explore screen (species list by location)
- [x] Species card widget (thumbnail + names)
- [x] Species info overlay (image, description, links)
- [x] Detection thumbnails in live mode
- [x] Live mode geo-filter integration
- [x] Location settings (GPS, manual coords, threshold)
- [x] L10n strings (EN + DE, 16 keys)
- [x] Copilot instructions (.github)
- [ ] Map view (flutter_map + OpenTopoMap)
- [ ] Offline tile caching (flutter_map_tile_caching)
- [ ] Download region UI
- [ ] Track rendering
- [ ] Detection pins

### Step 7: Session History, Export & Recording
- [x] Session library screen (browse, search, sort)
- [x] Session review screen (species-collapsed list, clustering)
- [x] Audio playback with spectrogram strip
- [x] Undo/redo editing system
- [x] Add/edit/delete detections
- [x] Trim recording with handles
- [x] Annotations (global + timestamped)
- [x] Session renaming + auto-numbering
- [x] Session map screen (OSM + tile consent)
- [x] Raven Pro export (.txt selection tables)
- [x] CSV / JSON export
- [x] ZIP bundle export (recording + metadata)
- [x] FLAC encoder (pure Dart, 50–60% compression)
- [x] Audio decoder (WAV + FLAC → PCM)
- [x] Model build pipeline (prune, ARM64 fix, geomodel fix)
- [x] Integration tests (model output, memory stress, geo soundscape)
- [x] APK size optimization (419 → 185 MB release)

### Step 8: UX & Documentation Polish (Complete)
- [x] About screen overhaul (geomodel, funding, website, remove licenses)
- [x] Privacy policy & terms of use docs
- [x] Explore screen: reverse geocoding, help dialog, lat/lon layout
- [x] Species overlay: image credit placement, brand logos, probability chart
- [x] Settings: danger zone double-confirm, section descriptions, icon cleanup
- [x] Brand icons (eBird, iNat, Wikipedia from real logos)
- [x] README updated (features, platforms, screenshot placeholders)
- [x] User documentation (MkDocs: settings, export, explore, session library, FAQ, getting started)
- [x] Developer documentation (testing, storage)
- [x] design.md updated (species count, platforms, tech stack, steps 1–14)

### Step 9: Survey Mode (Planned)
- [ ] Android foreground service
- [ ] iOS background audio
- [ ] Reduced-rate inference
- [ ] Snippet recording
- [ ] Detection queue with GPS
- [ ] Session summary

### Step 10: Point Count Mode (Complete)
- [x] Timed session manager (setup wizard + auto-stop)
- [x] Countdown UI (mm:ss timer, progress bar, red warning)
- [x] Full recording (via LiveController recording service)
- [x] Station metadata (GPS coords, date/time in setup wizard)
- [ ] Transect mode
- [x] Session history (saves as SessionType.pointCount)

### Step 11: File Analysis Mode (Complete)
- [x] File picker
- [x] Chunked analysis with configurable overlap
- [x] Multi-format support (WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA, AMR)
- [x] Audio resampling to 32 kHz
- [x] Detection list with timestamps
- [x] Progress UI (window count, detections, species)
- [x] Cancellable analysis
- [x] Session integration (results saved + opens SessionReviewScreen)
- [x] Location step (GPS / Manual / Map / Skip)
- [x] Date picker for seasonal filtering

### Step 12: Export & API Sync (Planned)
- [x] Export formats (Raven, CSV, JSON, ZIP)
- [x] Share sheet integration
- [ ] USB/MTP access
- [ ] API sync implementation
- [ ] Placeholder API settings UI

### Step 13: Polish & Optimization (Planned)
- [ ] Performance profiling
- [ ] Battery optimization
- [x] Memory management (leak fixes, stress tests)
- [ ] Error handling improvements
- [ ] Cross-platform testing (iOS)
- [ ] UI refinements

### Step 14: Documentation (Planned)
- [x] MkDocs site structure complete
- [ ] MkDocs all pages fleshed out
- [ ] GitHub Actions verified
- [ ] README with screenshots
- [x] CONTRIBUTING guide
- [x] User docs: live mode, explore, session library, session review, settings, export, FAQ
- [x] User docs: point count mode, file analysis
- [ ] Developer docs complete
- [ ] API docs
- [x] CHANGELOG

---

## Notes

Space for general notes, links, or ideas discovered during development.
