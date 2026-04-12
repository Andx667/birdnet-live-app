# Point Count Mode

Timed survey sessions at fixed locations for formal avian point-count observations.

## Overview

Point Count Mode is designed for structured field surveys. It enforces a fixed duration and location, runs continuous audio capture and species identification, and automatically finalizes the session when the timer reaches zero. Results are saved as a session that you can review, edit, and export — just like Live Mode.

## Setup Wizard

Before starting a count, a three-step wizard collects the session parameters.

### Step 1: Duration & Location

- **Duration**: Choose from 3, 5, 10, 15, or 20 minutes. The last selection is remembered for future counts.
- **Location**: Pick one of three modes:
    - **GPS** — Auto-acquires your coordinates. A refresh button retries if the signal is weak.
    - **Manual** — Enter latitude and longitude by hand, or tap **Pick on Map** to place a pin on an interactive map.
    - **Skip** — Record without location data (geo-model species filtering is disabled).
- **Date**: The current date and time are shown for reference.

### Step 2: Field Tips

Six best-practice reminders to help you get clean data:

1. Place phone on a stable surface (tree stump, tripod, fence post).
2. Avoid windy conditions — wind noise masks bird calls.
3. Stay quiet and minimize movement during the count.
4. Keep the microphone unobstructed — don't cover it with your hand or a case.
5. Avoid starting near loud anthropogenic noise sources (roads, machinery).
6. Use the same duration and settings for all counts in a study.

### Step 3: Ready

A confirmation screen summarizes the duration and reminds you that audio capture and identification begin immediately when you press **Start Count**.

## Live Session

Once started, the screen shows a real-time spectrogram, detection list, and countdown timer.

### Screen Layout

| Area | Description |
|------|-------------|
| **Stop button** | Red stop icon (top left) — ends the count early with a confirmation dialog |
| **Countdown timer** | `MM:SS` display (top center) — turns red when ≤ 30 seconds remain |
| **Settings gear** | Adjust inference settings mid-session (top right) |
| **Progress bar** | Linear indicator of elapsed time; turns red when ≤ 30 seconds remain |
| **Spectrogram** | Scrolling FFT visualization (~40% of screen) |
| **Info bar** | Detection count and unique species tally (visible when active) |
| **Detection list** | Species detections sorted by confidence (~60% of screen) |

### Countdown & Auto-Stop

- The countdown ticks every second.
- When it reaches zero, the session automatically finalizes and navigates to Session Review.
- A "Point count complete" notification appears briefly.

### Early Stop

Tap the red stop button at any time. A confirmation dialog asks "Stop Early?" — confirm to finalize, or cancel to continue the count.

!!! note "No Pause"
    Point Count Mode does not have a pause button. Protocol compliance requires uninterrupted recording for the full duration.

## After the Count

The session is saved as a **Point Count** type with an auto-incremented number (e.g., "Point Count #1", "#2"). It appears in the Session Library alongside Live sessions, and you can:

- Review and edit detections
- Play back the audio recording
- Add annotations
- Export in any supported format (Raven Pro, CSV, JSON, ZIP)

See [Session Review](session-review.md) and [Export & Sync](export-sync.md) for full details.

## Settings

Point Count uses the same inference, spectrogram, and recording settings as Live Mode. Open the settings gear during a count (or from the home screen) to adjust:

- Window duration, inference rate, confidence threshold, sensitivity
- Species filter mode (Off / Geo Exclude / Geo Merge / Custom)
- Spectrogram color map, FFT size, frequency range
- Recording format (WAV / FLAC)

## Tips

- **Consistency matters**: Use the same duration, settings, and placement method across all counts in a study for comparable data.
- **GPS before you start**: If using GPS, wait for coordinates to appear in Step 1 before proceeding.
- **Export for analysis**: Use Raven Pro format for compatibility with Cornell's acoustic analysis software.
