# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
