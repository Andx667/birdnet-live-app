# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.9] - 2026-04-24

### Added

- **Every session export now ships with full provenance metadata.** ZIP bundles always include a `<prefix>.metadata.json` side-file alongside the audio and selection table, and JSON exports gain a top-level `meta` block. The metadata captures the app version and build number, the audio and geo model names/versions from `model_config.json`, the species locale used to localize labels, the export timestamp (UTC), and a verbatim snapshot of every SharedPreferences setting at the moment of export. This makes exports self-describing — an analyst opening a survey ZIP months later (or receiving one from another recordist) can answer exactly which app version, which model, and which user settings produced the detections without having to ask. Critical for scientific reproducibility, especially when sharing survey data between researchers.

## [0.6.8] - 2026-04-24

### Fixed

- **Survey selection-table exports for sessions started before 0.6.7 now report correct in-clip detection times.** Those sessions were saved without a `clipContextSeconds` value (the field didn't exist yet), so the exporter assumed 0 seconds of pre-roll and printed `Begin Time = 0.000 / End Time = 3.000` for every clip — placing the Raven selection box at the very start of each clip even when the actual call sat 1–2 seconds in. The exporter now falls back to the device's current Survey “Clip Context” setting whenever a session has clip files but no recorded context value, so legacy bundles produce the same selections as freshly recorded ones.

## [0.6.7] - 2026-04-24

### Changed

- **Session exports now use localized common names everywhere they're rendered as text.** Clip filenames inside the ZIP bundle (e.g. `…_clip_001_Amsel.flac` for a German user instead of `…_clip_001_Eurasian_Blackbird.flac`), the `Common Name` column in Raven selection tables, and the `Common Name` column in CSV exports all use the user's species locale. Scientific Name columns are always emitted regardless of the "Show scientific names" UI toggle so exports remain scientifically authoritative.
- **Survey selection tables now report in-clip detection times.** Previously, `Begin Time (s)` / `End Time (s)` were session-relative offsets even for rows referencing per-detection clip files — which made Raven Pro draw the selection box at the wrong place inside the clip (or off the end entirely). Now those columns describe the detection's offset *within the clip file* (i.e. they bracket the model's window after the pre-roll context). A new `Survey Time (s)` column carries the original session-relative offset so analysts can still cross-reference detections against the survey timeline. The CSV export gains the same `Survey Time (s)` column when clip files are present. For sessions exporting a single continuous recording, behavior is unchanged.

## [0.6.6] - 2026-04-24

### Added

- **Session library cards now show on-disk audio size** as a fourth stat chip. The value is the total of the continuous recording (live, point count, file analysis) plus all per-detection clips (survey), so you can spot heavy sessions at a glance before exporting or deleting. Sessions with no audio on disk silently omit the chip.

### Fixed

- **Species names are now localized and respect the "Show scientific names" setting in every place a detection is rendered.** The fullscreen survey-map clip-player sheet showed the English common name and always the sci name; the survey live-screen summary species list, the session library's grouped-by-species view subtitles, and the add/replace-species overlay banner + result tiles had the same gaps. All of them now go through the taxonomy lookup with the active species locale and hide the sci name when the setting is off.

## [0.6.5] - 2026-04-24

### Fixed

- **Detections recorded before the audio recorder fully spun up no longer have broken "00:-1" timestamps.** Session-relative offsets are now clamped to `[00:00, audio duration]` both at storage time (in `LiveSession.addDetection(s)`) and at render/seek time, so these detections display sensibly and play back from a valid position instead of silently failing.

## [0.6.4] - 2026-04-23

### Changed

- **Onboarding flow rewritten end-to-end.** Replaced the `introduction_screen` package + separate Terms-Of-Use gate (which prompted for ToU twice) with a single custom PageView wizard. Pages now use a compact icon badge instead of an oversized centered icon, giving body text the screen real estate it deserves. The Permissions page is now interactive — tapping Grant on Microphone or Location triggers the actual OS prompt (via `record` and `geolocator`) and shows a green check on success. Terms & Privacy is the final page with an inline "I agree" checkbox; Get Started is disabled until checked, and on finish both `onboardingComplete` and `termsAccepted` are persisted in one shot. Skip jumps directly to the Terms page rather than bypassing acceptance.

### Removed

- `introduction_screen` dependency (no longer needed) and the standalone `TermsGateScreen` (its role is folded into the onboarding flow).

## [0.6.3] - 2026-04-23

### Changed

- **Explore screen header decluttered** — the search bar and group-filter chip row are now hidden by default. Tap the AppBar lens icon to slide in the search field, or the filter icon to reveal the chip row. A small dot on the filter icon indicates when a non-default group filter is active. Toggling one collapses the other so only one control is visible at a time.

## [0.6.2] - 2026-04-23

### Added

- **Explore screen species search** — search field at the top of the Explore screen runs over the full audio-model species list, not only the geo-filtered subset. Matches are split into "At your location" and "Other species" sections so distant species (e.g. Blue Jay or Gray Wolf in Europe) can still be opened to view their info card.
- **Explore taxonomic group filter** — horizontal chip row to restrict the list to All / Birds / Mammals / Amphibians / Insects. Filter applies to both the geo-likely list and the search results.

## [0.6.1] - 2026-04-23

### Fixed

- **Session review species search** — search now matches localized common names (German, French, Spanish, Czech, Italian, Portuguese), not only English. Results are ranked by text relevance: full-string prefix > word prefix > substring, with observation count as a tie-breaker. Geo-likely species are softly boosted but never demoted from a strong text match.
- **Multi-token search** — typing multiple words (e.g. "barn owl") now correctly matches species containing all tokens in any order.

### Changed

- **Add/Replace species overlay redesign** — when invoked from "Replace this detection" on a specific cluster, the picker now shows a banner with the detection being replaced (thumbnail, common name, scientific name) and skips the redundant mode selector and dropdown — the user only chooses the new species.
- **Add species (FAB)** — defaults to "Insert at playback position" (the more useful mode) and drops the unused "Replace" segment from this entry path.
- **Result tiles** include a 48×48 species thumbnail.
- **Empty / no-result states** — clear hint when the search field is empty (with "Unknown / Other" surfaced as a quick action) and a friendly "no results" message when nothing matches.

## [0.6.0] - 2026-04-23

### Added
- Spectrogram render quality is now user-configurable (Low / Medium / High) under Settings → Spectrogram, with High as the default for sharp live spectrograms and Low as a fallback for older phones
- Survey foreground notification now uses a monochrome blue jay silhouette as the status-bar small icon instead of a generic circle
- Species info overlay opens to the user's locale Wikipedia page when bundled (interface locales: en, de, fr, es, cs, pt, it), falling back to English

### Changed
- Default visible spectrogram duration raised from 15 s to 20 s for a wider live view
- Live and Point Count spectrograms render with the configured filter quality (was hardcoded low) for noticeably crisper detail when upscaled
- Session review spectrogram now uses FFT 2048 + high filter quality for sharper detection-clip previews
- Live mode keeps the recording running across pause so audio and detection timestamps remain continuous; detections are now timestamped at the start of the analyzed window for accurate review playback
- Recording capture uses a unified clip-context setting and now captures true pre+post audio around each detection
- Survey detection markers only show the play badge when the audio clip actually exists on disk; markers gain a stronger audio affordance (accent ring, larger badge, grey border for silent markers)
- Tapping the active play button in session review now pauses playback (works for both Live and Survey clips)
- Species info overlay now uses fully bundled taxonomy data — eBird link is shown only when an `ebird_code` exists (insects and other non-birds correctly hide it), iNaturalist only when an `inat_id` exists, and Wikipedia only when a bundled URL exists for the active locale
- eBird link chip uses the Cornell Lab sapsucker silhouette as its icon
- German UI uses "Detektion" / "Detektionen" instead of "Erkennung" / "Erkennungen" throughout for clearer detection terminology

### Fixed
- Survey detection clip player honors the pause toggle (previously kept playing when tapping the active play button)

### Privacy / Hardening
- Verified the app makes no network calls beyond OSM map tiles and OSM Nominatim reverse geocoding (both gated by a single one-time consent); no taxonomy API, no analytics, no telemetry
- Removed the unused `cached_network_image` dependency and dead taxonomy-API URL helpers (`thumbUrl` / `mediumUrl` getters and the static API base URL) so future code cannot accidentally reintroduce taxonomy-API fetches

## [0.5.4] - 2026-04-22

### Added
- Survey map markers now show a small play badge on detections whose audio clip was retained, making it visually obvious which icons can be played back
- Tapping a marker with audio opens a modal player overlay with a spectrogram preview, scrubber, and play/pause controls (replaces the old silent in-place playback)

### Changed
- Smart sampling: same-spot distance threshold reduced from 500 m to 250 m and a per-species minimum of 3 retained clips is always honored — the first three high-confidence detections of a species always survive, even when they share a spot
- Survey foreground notification now refreshes about once per second so the lock-screen timer matches actual recording time (session disk persistence stays on its 30 s cadence)
- Survey "elapsed" / total recorded time now excludes pause/resume gaps. `LiveSession` persists `recordedDurationSeconds`; resumed sessions accumulate active time across segments instead of measuring wall-clock from the original start
- Detection map widget prefers audio-bearing detections when collapsing duplicates at the same location so the play badge is accurate
- "Smart" sampling label kept untranslated across all locales (was "Intelligent" / "Inteligente" / etc.) to prevent layout overflow on narrow devices

## [0.5.3] - 2026-04-22

### Changed
- Onboarding pages use a more compact layout (smaller icons, smaller title, tighter padding) so the Terms & Privacy page — including the Privacy Policy link — fits on one screen on compact devices

## [0.5.2] - 2026-04-22

### Fixed
- Onboarding dots indicator no longer overflows on narrow displays now that the carousel has 6 pages (smaller dot size, tighter spacing, narrower active dot)

## [0.5.1] - 2026-04-22

### Changed
- Onboarding screens now use smaller icons and reduced top padding to prevent overflow on compact displays
- Terms of Use and Privacy Policy text (onboarding gate and Terms step) updated to reflect that both map tiles and reverse geocoding share a single one-time consent
- User-facing copy made taxonomically agnostic across all 7 locales — replaced "bird species", "bird identification", "bird detection", and "bird calls" with "species", "species identification", "detection", and "animal calls" respectively (the app supports more than birds)
- Terms gate now also explicitly forbids use for poaching, illegal wildlife trade, and military purposes, matching the published Terms of Use

## [0.5.0] - 2026-04-22

### Added
- Point Count setup now collects a custom name and observer name (parity with Survey); observer is remembered across sessions
- Onboarding gained a dedicated Terms & Privacy step with deep links to the full Terms of Use and Privacy Policy
- Session auto-stop reasons (manual, duration, battery, storage) and ETA hints during long-running sessions
- Loading skeleton for species info while taxonomy data resolves
- Accessibility labels for live capture controls and confidence metrics; haptic feedback on selection changes
- Session review now tracks playback position and highlights the active detection window
- New shared `WizardScaffold` for multi-step setup wizards (Live, Point Count, Survey, File Analysis)
- Shared loading, error, empty-state, and confirmation-dialog widgets across the app
- `ScoreColors` theme extension providing a consistent five-step confidence color scale
- Settings help tooltips and expanded UI tooltips throughout the app
- JSON export now includes full session metadata (custom name, session number, observer, transect ID, distance, stop reason)
- Detection windows now record end timestamps (live and survey) for accurate review and export

### Changed
- Reverse geocoding is now gated by the same one-time consent prompt as map tiles (no requests to OpenStreetMap until the user approves)
- Detection sampling for surveys reworked with clearer logic, expanded test coverage, and improved documentation
- Map handling and location services hardened (permission flow, lifecycle, and error states)
- Survey finalization flow hardened against edge cases during cleanup
- Documentation updated to use Material Design icon names consistently

### Fixed
- Runtime cleanup edge cases on session stop and screen disposal
- Integration test warnings cleaned up

## [0.4.0] - 2026-04-22

### Added
- Direct User Guide access from the Help screen
- A File Analysis app bar shortcut to the relevant settings panel
- Expanded the User Guide with workflow pages for Live, Explore, Session Library, Session Review, Point Count, Survey, File Analysis, icons and controls, and settings
- Added screen-level help overlays across operational workflows, including a common help-sheet layout and icon explanations that match the current UI

### Changed
- Localized remaining user-facing strings in file analysis, explore, settings, and survey notifications across all supported locales
- Updated Help guidance to point users to the User Guide from both Help and About
- Reworked Help and Explore guidance to explain app navigation and screen behavior rather than field methodology
- Localized the new help-overlay copy across all supported locales

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

