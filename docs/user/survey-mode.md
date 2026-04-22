# Survey Mode

Survey Mode is the route-based workflow for long-running moving surveys.

## How to Open It

From Home, tap the **Survey Mode** card with the :material-routes: icon.

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

#### Detection sampling

A long survey can produce thousands of detections, and saving an audio clip for every one of them quickly fills up storage. Detection sampling controls **which clips are kept on disk** — *the detection records themselves are always kept*, so your full session log stays intact regardless of mode. Records whose audio was dropped simply have no playable clip in Session Review.

Three modes are available:

| Mode | What it does |
|---|---|
| **All** | Keep every clip. Most disk usage. Recommended for short surveys or when you want every detection's audio for later analysis. |
| **Top N** | Keep only the **N highest-confidence clips per species**. Other clips are deleted as the survey runs. Default N is 10, configurable from 1 to 50. |
| **Smart** | Same per-species cap of N as Top N, **plus** spatial distribution: if a new detection lands at the same "spot" as an already-kept clip (within ~500 m and ~2 min of each other), only the higher-confidence one keeps its clip. This prevents one stationary singer from monopolizing all N slots and biases the kept clips toward covering the full transect. |

The N limit is **per species, not global** — if you record 10 robins and 10 chaffinches, you keep 20 clips. There is no overall cap on the number of clips a survey can produce.

In Smart mode, if GPS is missing on a detection the same-spot check falls back to a time-only window (~2 min). With GPS available, both distance and time must overlap for two detections to count as the same spot.

### 3. Field tips

This is a short pre-start checklist inside the setup flow.

### 4. Ready

The ready screen summarizes the active survey configuration before you start with :material-play:.

## Live Survey Dashboard

The live Survey screen has three main tabs plus a recent detections list.

### Top bar

- :material-stop: — end the survey
- :material-timer: — elapsed time
- :material-help-circle-outline: — open the Survey help sheet
- :material-tune: — open Survey settings

### Tabs

- :material-map-outline: — route map and mapped detections
- :material-equalizer: — spectrogram
- chart icon — summary statistics and species breakdown

### Stats and detections

Below the tab content, the survey dashboard shows a stats bar and a recent detections list. Tapping a detection opens the species details overlay.

## Background Operation

Survey Mode is the workflow that relies most heavily on notifications and background operation. If the app requests notification permission, it is doing so to keep the foreground survey service visible and controllable.

## After Stopping

BirdNET Live saves the finished survey and opens [Session Review](session-review.md).