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

Linear amplifier applied to incoming audio before it reaches the spectrogram and the classifier. Leave at **1.0×** unless your input is consistently too quiet — for example a high-impedance lavalier mic on a phone, or a USB interface whose preamp is set too low. Pushing gain above 1.0 will not magically reveal calls that the mic never captured; it just rescales whatever the mic delivered, so loud nearby sounds may clip. Below 1.0 is useful in the rare case where a hot input is saturating the spectrogram.

### High-pass filter (Hz)

Cuts low-frequency content before inference using a 24 dB/octave Butterworth filter — the slider value is the −3 dB cutoff. **0 Hz disables it.** A 100–200 Hz cutoff strips wind, traffic rumble, and handling noise without touching most species; pushing toward 500–1000 Hz starts removing low whoots, owls, grouse, and bittern booms, so only go that high if you are deliberately ignoring those species in exchange for a much cleaner spectrogram in a noisy urban environment. The cutoff you pick should be visible as a sharp horizontal line on the live spectrogram.

### Microphone

Lets you choose a specific input device or keep the **System default**. Your selection is remembered across app launches, so if you regularly use a USB or Bluetooth mic in the field you only need to pick it once. The same picker appears on the Survey setup screen.

## Inference

### Window duration

Controls the length of the analysis window.

### Confidence threshold

Sets how conservative detections should be.

### Sensitivity

Sigmoid steepness applied to the raw classifier output before the confidence threshold is checked. Higher values make the detector more permissive — fainter or more ambiguous calls cross the threshold, at the cost of more false positives. Lower values are stricter and only let confident detections through. The default of **1.0** matches the BirdNET reference. Try **1.25** if you suspect the model is missing distant calls; drop to **0.75** if you are flooded with low-quality detections of common species. Sensitivity is hot-applied: changing it mid-session takes effect on the next inference window.

### Inference rate

Controls how frequently BirdNET runs inference.

### Score pooling

Combines scores across recent inference windows so a single noisy window doesn't dominate the result. **Off** uses each window's raw probability — most reactive, noisiest. **Average** arithmetic-means the recent windows for the smoothest output. **Max** keeps the loudest peak per species, which is the most reactive smoothing mode and good for brief, sharp calls. **LME** (log-mean-exp, the default) is BirdNET's reference soft-maximum: it behaves like *max* when one window dominates and like *average* when several windows agree, which is usually what you want. Switching modes mid-session clears the rolling buffer so old logits don't leak into the new mode.

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

### Auto-start recording (Live mode only)

When enabled, Live mode begins recording as soon as the screen opens and the model finishes loading — no need to tap the microphone button. Useful for kiosk-style deployments, hands-free use (e.g. mounting the device in the field), or any workflow where the user already knows that opening Live always means "start now". Disabled by default so an accidental tap on the Live tile from the home screen does not silently begin a session. The auto-start fires only once per screen visit, so stopping a session and tapping the mic again still works as a manual restart.

## Location

### Use GPS

Use device GPS instead of manual coordinates.

### Latitude / Longitude

Manual coordinates used when GPS is disabled.

### Refresh GPS now

Forces a fresh location fix instead of reusing the last value the app cached. The intuition: GPS lookups are cached per-screen so a setup screen does not block waiting for a satellite fix on every open, but that cache can be miles out of date if you have driven to a new spot since the last session. Tap this when you have moved and want the geo-filter to use *here*, not where you started the morning. The current cached coordinates are shown in the subtitle so you can verify what the app thinks your location is. If GPS cannot get a fix within ~10 seconds, the app falls back to the OS-provided last-known location and warns you with a snackbar so you know the value is stale.

### Download offline maps

Pre-caches OpenStreetMap tiles around your current GPS fix so the Survey live map and the exported HTML report still render a basemap when you're out of signal. The intuition: map tiles are streamed on demand by default, which is fine in town but useless in a forest valley with no cell service. Pick a radius (1, 5, 10, or 25 km) and the app downloads every tile in that square at zoom levels 12 through 16 — coarse enough to navigate, fine enough to read trails. The dialog shows an estimate (typically about 30 KB per tile) before you commit, and the request is rejected if it would exceed 50 MB to keep us a polite OpenStreetMap citizen. Downloads are paced under the 2 req/s tile-usage policy, and you can cancel mid-batch. Tiles land in the same on-disk cache that every map widget reads from, so a download done here is immediately visible everywhere — no extra wiring per feature.

### Species filter

- **Off** — no geographic filtering
- **Location filter** — exclude species that fall below the geographic threshold
- **Location weighting** — use the geo-model as an additional weighting signal

### Geo-filter threshold

Appears when a location-based filter mode is active.

## Export & Sync

### Formats

Tick any combination of export formats — every save / share will bundle all the selected formats together inside a single ZIP. Pick a single format with no audio clips and no HTML report and you'll get a raw file (e.g. `session.csv`) instead of a ZIP, for backwards compatibility:

- Raven Selection Table — for use in Cornell Raven Pro.
- CSV — opens in any spreadsheet.
- JSON — easiest for programmatic processing; carries the full per-session metadata.
- GPX — track and waypoints for use in mapping tools (only meaningful when GPS was on).

The intuition: many workflows need more than one format at the same time — a CSV for the spreadsheet, a Raven table for the desktop reviewer, and a JSON for the analysis script. Untangling that with a single-format toggle used to mean exporting the same session three times. Now you tick all three once and they ride together in the ZIP.

### Include audio files

Include saved audio alongside the exported tables or metadata when supported by the export workflow.

### Include HTML report

When on, every export ZIP also contains a `report.html` file alongside the table, audio clips, and GPX. Open it in any web browser and you get a print-ready summary of the session: header card with date, location, observer, and totals; an interactive map of the GPS track and detection markers; a card per detection with the Cornell taxonomy thumbnail, names, score pill, your confirmation, any note you typed, and the original audio clip inline as a player; and the analysis settings used. The intuition: a CSV is great for analysis pipelines but useless for sharing with a non-technical collaborator or printing a quick field summary — the HTML report fills that gap with one tap. Species thumbnails and map tiles need a connection the first time the file is opened (they're fetched live from the BirdNET taxonomy API and OpenStreetMap), but everything else — text, layout, audio playback, links — works fully offline. Turn this off if you only need the raw data and want to keep the ZIP a few KB smaller.

## Privacy

This section controls **which third-party services BirdNET Live may contact on your behalf**. Inference itself runs entirely on your device — these toggles only govern optional network features that enrich the experience. All three toggles are **off by default** on a fresh install; nothing reaches out until you say so. The intuition: each toggle is scoped to one concrete service and one concrete benefit, so you can opt into exactly what's useful to your workflow and nothing else.

### Allow map tiles

Required for any interactive map in the app (the location picker, the Survey live map, the session map, and the map tiles inside the offline-tile downloader). When on, map widgets fetch raster tiles from the public **OpenStreetMap** servers; tile-coordinate requests reveal which area of the world you're viewing. When off, every map screen falls back to a placeholder card so the rest of the app still works without network leakage.

### Allow place name lookup

When on, the app sends your recorded coordinates to **OpenStreetMap's Nominatim** service to resolve a short place name (e.g. *"Berlin, Germany"*) that is shown next to the session in Session Library and Session Review. The intuition: numeric coordinates are precise but hard to scan when scrolling through a long list of sessions — a place name turns the list into something you can read at a glance. When off, sessions show the raw lat/lon only, and Nominatim is never contacted.

### Allow weather lookup

When on, every saved session captures a one-shot snapshot of local conditions (temperature, precipitation, wind, cloud cover) at the recording coordinates and end time via **Open-Meteo**. The snapshot lands in Session Review under the location row and is mirrored into the JSON export, the per-session metadata block, and the HTML report. The intuition: weather is one of the strongest predictors of bird activity, and capturing it automatically — without you having to remember to check a separate app — turns every session into a more complete record. Open-Meteo is a free service and requires neither an account nor an API key. When off, no weather data is fetched or stored.

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