# BirdNET Live

**Real-time bird species identification using on-device ONNX inference.**

BirdNET Live is a Flutter app built for field researchers, conservationists, and serious birders. It runs the BirdNET+ model directly on your device — no internet required.

## Features

- **Live Mode** — Real-time spectrogram with scrolling detection list
- **Explore** — Browse species expected at your location using the geo-model
- **Session Library** — Review, edit, and export past sessions with audio playback
- **Export** — Raven Pro, CSV, JSON, GPX, and ZIP bundle formats
- **Point Count Mode** — Timed survey sessions with countdown timer and station metadata
- **File Analysis** — Offline analysis of existing audio recordings (WAV, FLAC, MP3, and more)
- **Survey Mode** — Long-running transect surveys with GPS tracking, background monitoring, and detection sampling

<p align="center">
  <img src="assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="assets/screenshots/survey.png" alt="Survey Mode" width="150">
  <img src="assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Quick Start

See the [User Guide](user/index.md) for an overview, then open [Getting Started](user/getting-started.md) to install and run BirdNET Live.

## Install on Android

BirdNET Live is available as a signed APK for sideloading. Download the latest release from the [GitHub Releases page](https://github.com/birdnet-team/birdnet-live-app/releases/latest), transfer the `.apk` file to your phone, and open it to install. You may need to allow installation from unknown sources in your device settings.

> **Note:** The APK is ~227 MB because it includes the full BirdNET+ audio model (~145 MB) for offline inference.

## For Developers

Check the [Developer Guide](developer/index.md) for architecture, building, and contributing.

## License

BirdNET Live is open source under the [MIT License](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE).
