# File Analysis

File Analysis processes an existing recording through the same BirdNET pipeline used by the live workflows.

## How to Open It

From Home, tap the **File Analysis** card with the :material-file-music: icon.

## App Bar

- :material-tune: — open File Analysis settings
- :material-close: — cancel an active analysis run

## Supported Inputs

The current file picker accepts:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Four-Step Wizard

### 1. Pick File

Choose a file and review its metadata card:

- file name
- format
- duration
- file size
- sample rate

### 2. Location and date

You can:

- use current GPS
- enter coordinates manually
- skip location
- pick a point on the map
- set an optional recording date

### 3. Parameters

The wizard exposes:

- window duration
- overlap
- sensitivity
- confidence threshold
- species filter mode

### 4. Analyze

The progress screen shows:

- windows processed
- detections found
- species found
- cancel button

## Result

When analysis finishes, BirdNET Live converts the output into a saved session and opens [Session Review](session-review.md).