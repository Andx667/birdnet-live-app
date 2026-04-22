# Privacy Policy

**Last updated:** April 2026

BirdNET Live respects your privacy. This document explains how the app handles your data.

## On-Device Processing

All audio analysis and bird species identification happen **entirely on your device**. The app uses two neural network models that run locally:

- **BirdNET+ audio classifier** — analyzes microphone audio to identify bird species.
- **BirdNET geo-model** — predicts which species are likely at your location and time of year.

No audio data is ever transmitted to external servers.

## Data Collection

BirdNET Live does **not** collect, transmit, or share any personal data. There is no analytics, no tracking, and no telemetry.

### Data stored locally on your device:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Audio recordings | Bird identification, playback, export | Local files |
| Detection results | Species, confidence, timestamps | SQLite database |
| GPS coordinates | Geotagging detections, survey tracks, geo-model predictions | SQLite database |
| Session metadata | Session history, review, export | SQLite database |
| App settings | User preferences | SharedPreferences |

### Bundled offline data

Species images, descriptions, and taxonomy data are **bundled in the app** and loaded from local assets. No network requests are made for species information.

## External Resources

The app may access the following external resources:

| Resource | Purpose | When |
|----------|---------|------|
| Map tiles (OpenTopoMap) | GPS track visualization in surveys | When opening a map view (user consent required) |
| Reverse geocoding (OpenStreetMap Nominatim) | Resolving GPS coordinates into a human-readable place name (e.g. "Berlin, Germany") for session display | Once per session when a session with GPS coordinates is reviewed, the device is online, **and the user has approved OpenStreetMap network access** |

Map tile requests are standard HTTPS GET requests to `tile.opentopomap.org`. Only tile coordinates are sent — no personally identifiable information.

Reverse-geocoding requests send the session's latitude and longitude to `nominatim.openstreetmap.org` over HTTPS, together with a generic `BirdNETLive/<version>` user-agent string as required by the [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/). The resolved place name is stored locally with the session so a session is only geocoded once. Reverse geocoding is gated by the same one-time consent prompt as map tiles: until you approve OpenStreetMap network access (shown the first time you open a map view), no reverse-geocoding requests are made. No request is made if the session has no GPS coordinates or the device is offline. Revoking location permission at the OS level prevents new sessions from acquiring coordinates and therefore from being geocoded.

**No other network requests are made.** The app functions fully offline.

## GPS & Location

The app uses GPS location for:

- **Species filtering** — predicting which species are likely at your location.
- **Survey mode** — recording GPS tracks and geotagging detections along a transect.
- **Point count mode** — tagging the observation location.

GPS data is stored locally and included in exports only when you explicitly share or export a session. Location access requires your permission and can be revoked at any time via system settings.

## Data Export

You can export session data in multiple formats (Raven selection tables, CSV, JSON, GPX). Exports are generated locally and shared via the system share sheet. The app does not upload export data to any server.

## Data Deletion

All app data (sessions, recordings, settings) can be deleted via **Settings > Danger Zone > Clear All Data**. Uninstalling the app removes all stored data.

## Contact

For privacy questions: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
