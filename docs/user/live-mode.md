# Live Mode

Live Mode is the fastest way to listen through the phone microphone and review detections as they appear.

## How to Open It

From the Home screen, tap the **Live Mode** card with the :material-microphone: icon.

## Top Bar

The top bar contains three elements:

- :material-arrow-left: — leave Live Mode
- center status text — `Initializing`, `Loading model`, `Ready`, `Identifying species`, `Paused`, or `Error`
- :material-tune: — open the Live-specific Settings view

## Main Action Button

The large circular button at the bottom center changes state:

- :material-microphone: — start listening
- :material-stop: — stop the active session
- :material-play: — resume from a paused-ready state

## What You See While Listening

### Spectrogram

The spectrogram scrolls continuously while capture is active. It shows frequency content over time and uses the color map, FFT size, frequency range, and duration from Settings.

### Detection list

Recent detections appear below the spectrogram. Each row can show:

- species image
- common name
- optional scientific name
- confidence value

Tap a species row to open the species details overlay.

### Session info bar

The compact info line under the spectrogram summarizes the current session, for example:

- current detections shown now
- unique species count (`spp`)
- total detections (`det`)
- elapsed duration
- estimated recording size when recording is enabled

## Recording Behavior

Recording is controlled in [Settings](settings.md).

- **Full** records the whole session.
- **Detections only** records clips around detections.
- **Off** disables recording.

When you stop Live Mode, BirdNET Live saves the session and opens [Session Review](session-review.md).