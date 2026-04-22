# Survey Mode

Survey Mode is the route-based workflow for long-running moving surveys.

## How to Open It

From Home, tap the **Survey Mode** card with the `route_rounded` icon.

## Setup Flow

Survey setup currently uses four steps.

### 1. Details

You can enter:

- survey name
- transect ID
- observer name
- GPS, manual coordinates, or no starting location

This step also exposes the map picker and background-GPS permission reminder when needed.

### 2. Parameters

This step contains Survey-specific parameters such as:

- microphone selection
- inference rate
- confidence threshold
- GPS interval
- maximum duration
- recording mode
- clip context for detection-only recording
- detection sampling mode
- top-N-per-species limit when sampling is limited

### 3. Field tips

This is a short pre-start checklist inside the setup flow.

### 4. Ready

The ready screen summarizes the active survey configuration before you start with `play_arrow_rounded`.

## Live Survey Dashboard

The live Survey screen has three main tabs plus a recent detections list.

### Top bar

- `stop_rounded` — end the survey
- `timer_rounded` — elapsed time
- `help_outline_rounded` — open the Survey help sheet
- `tune_rounded` — open Survey settings

### Tabs

- `map_outlined` — route map and mapped detections
- `graphic_eq` — spectrogram
- chart icon — summary statistics and species breakdown

### Stats and detections

Below the tab content, the survey dashboard shows a stats bar and a recent detections list. Tapping a detection opens the species details overlay.

## Background Operation

Survey Mode is the workflow that relies most heavily on notifications and background operation. If the app requests notification permission, it is doing so to keep the foreground survey service visible and controllable.

## After Stopping

BirdNET Live saves the finished survey and opens [Session Review](session-review.md).