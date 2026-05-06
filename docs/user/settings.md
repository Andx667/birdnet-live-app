# Settings

BirdNET Live reuses one Settings screen across multiple workflows. The :material-tune: button opens the sections that are relevant to the screen you came from.

## How Settings Scope Works

- Opening Settings from Home shows the full screen.
- Opening Settings from Live, Survey, Point Count, or File Analysis filters the screen to the relevant sections.

## General

### Theme

Choose **Dark**, **Light**, or **System**.

### App Language

Sets the interface language.

### Species Names

Controls the language used for species names. **Follow app language** uses the same language as the interface when that name is available.

### Show scientific names

Shows scientific names below common names across the app.

### Timestamp display

Controls how per-detection times appear in session review.

- **Relative** shows the offset from the start of the recording, e.g. `00:12:34`. Best for reviewing a single session and matching the spectrogram playhead.
- **Absolute** shows the local clock time when the detection was captured, e.g. `08:42:17`. Best for cross-referencing field notes, weather logs, or simultaneous recordings.

If a detection lands on a different calendar day from the session start (e.g. an overnight survey), the absolute time gains a `+1d` suffix so reviewers don't accidentally read tomorrow's dawn chorus as today's.

When **Absolute** is selected, an additional **Show seconds in timestamps** toggle appears. Disable it if you prefer the more compact `08:42` over `08:42:17` — useful when scanning long detection lists. Relative offsets always show seconds because reviewers need sub-minute precision to align with the spectrogram playhead.

Storage and exports always use UTC instants regardless of this setting, so the choice never affects the data — only the way it's displayed.

## Audio

These controls appear in audio-driven live workflows.

### Gain

Adjusts the input gain shown in the app. Use this only when you need to compensate for very quiet recordings or inputs.

### High-pass filter (Hz)

Reduces low-frequency rumble before inference.

### Microphone

Lets you choose a specific input device or keep the **System default**.

## Inference

### Window duration

Controls the length of the analysis window.

### Confidence threshold

Sets how conservative detections should be.

### Sensitivity

Higher values make the detector more permissive, which can recover fainter calls at the cost of more false positives.

### Inference rate

Controls how frequently BirdNET runs inference.

### Score pooling

Controls how overlapping analysis windows are combined.

### Pooling window count

Controls how many consecutive inference windows participate in score pooling.
A larger value smooths each species' score over a longer time horizon, which
suppresses spurious one-off detections — useful for steady, distant calls
where you'd rather wait for a few corroborating windows before raising a
detection. A smaller value reacts faster to brief vocalizations but lets
through more noise. The default of **5** matches the value historically
hard-coded into the model and is a sensible starting point for live use.

## Spectrogram

### FFT size

Controls frequency resolution in the spectrogram.

### Color map

Choose **Viridis**, **Magma**, or **Grayscale**.

### Duration (scroll speed)

Controls how much time is visible in the spectrogram window.

### Frequency range

Sets the upper display frequency.

### Log amplitude

Applies logarithmic scaling to the spectrogram for easier visual reading.

## Recording

### Mode

- **Full** — save the whole recording
- **Detections only** — save clips around detections
- **Off** — no audio recording

### Clip context

When **Detections only** is active, the app shows a single **Clip context** slider (0–5 s) that sets how much audio is preserved on **both sides** of each detection. Each clip is `analysis window + 2 × clip context` long, so with a 3 s analysis window and the default 1 s context the saved clip is 5 s. Setting the context to 2 s yields a 7 s clip (2 s pre-roll + 3 s analyzed audio + 2 s post-roll). Larger values give you more room for visual inspection or external review tools at the cost of disk space; 0 saves only the analyzed window itself.

### Format

Choose **WAV** or **FLAC**.

## Location

### Use GPS

Use device GPS instead of manual coordinates.

### Latitude / Longitude

Manual coordinates used when GPS is disabled.

### Species filter

- **Off** — no geographic filtering
- **Location filter** — exclude species that fall below the geographic threshold
- **Location weighting** — use the geo-model as an additional weighting signal

### Geo-filter threshold

Appears when a location-based filter mode is active.

## Export & Sync

### Format

Choose one export target:

- Raven Selection Table
- CSV
- JSON
- GPX (track + waypoints)

### Include audio files

Include saved audio alongside the exported tables or metadata when supported by the export workflow.

## About

The **About** row opens the in-app About screen.

## Danger Zone

### Reset Onboarding

Shows the onboarding sequence again the next time the app launches.

### Clear All Data

Opens a confirmation flow for permanently removing stored app data.

## Workflow-Specific Parameters Outside Settings

Some parameters are configured inside their own setup screens rather than in the shared Settings screen.

- [Point Count Mode](point-count-mode.md) has its own duration and location setup.
- [Survey Mode](survey-mode.md) has its own survey parameters screen.
- [File Analysis](file-analysis.md) has its own analysis-parameter step.