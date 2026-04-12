# File Analysis

Analyze existing audio recordings offline.

## Overview

File Analysis mode lets you run BirdNET+ inference on audio files stored on your device — no live microphone needed. It supports multiple audio formats and saves results as a session you can review and export.

## Supported Formats

WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA, and AMR. Files not recorded at 32 kHz are automatically resampled.

## Wizard Steps

### Step 1: Pick File

Select an audio file from your device. The app displays file metadata (name, format, duration, size, sample rate, channels).

### Step 2: Location & Date

- **Location**: Choose GPS, manual coordinates, map picker, or skip. Location enables geographic species filtering via the geo-model.
- **Date**: Optionally set the recording date. Defaults to today. Used for seasonal species filtering.

### Step 3: Parameters

Configure analysis settings:

| Parameter | Description |
|-----------|-------------|
| **Window duration** | Length of each analysis window (3 / 5 / 10 s) |
| **Overlap** | Window overlap percentage |
| **Sensitivity** | Model sensitivity bias |
| **Confidence threshold** | Minimum score to keep a detection |
| **Species filter** | Geographic filtering mode |

### Step 4: Analyze

Tap **Analyze** to start. A progress bar shows the current window and running statistics:

- Windows processed
- Detections found
- Unique species count

Analysis can be cancelled at any time.

## Results

When analysis completes, the results are saved as a session and automatically opened in the Session Review screen. From there you can edit detections, add annotations, and export in any supported format.

## Tips

- **Long files**: Processing time scales linearly with audio duration. A 60-minute file at 1 Hz inference rate processes ~1,200 windows.
- **Overlap**: Higher overlap catches calls that fall between window boundaries, at the cost of more processing time.
- **Resampling**: Files at sample rates other than 32 kHz are resampled automatically. This adds a brief preprocessing step.
