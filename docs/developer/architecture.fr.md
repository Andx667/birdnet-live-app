<!-- TRANSLATION TODO (fr) -->

# Architecture

Application architecture and design patterns.

## Feature-Based Architecture

The codebase is organized by feature rather than by layer. Each feature module contains its own screen, providers, widgets, and services:

```
lib/features/
  live/              # Real-time identification pipeline + UI
  point_count/       # Timed point-count survey mode
  survey/            # Long-running transect survey mode (GPS, sampling, map)
  file_analysis/     # Offline file analysis wizard
  explore/           # Species exploration by location (geo-model)
  audio/             # Audio capture, ring buffer
  inference/         # ONNX model wrappers (classifier, geo-model)
  history/           # Session persistence, library, review, export
  settings/          # Settings screen (context-aware filtering)
  home/              # Home screen / main menu + help screen
  about/             # Credits, links, legal
  onboarding/        # Intro carousel + terms gate
  recording/         # WAV/FLAC writing (full + detection clips)
  spectrogram/       # FFT, color maps, CustomPainter
```

Shared utilities live under `lib/shared/` (models, providers, services) and `lib/core/` (constants, theme). Reusable widgets such as `ContentWidthConstraint` (600 dp max-width for tablet layouts) are in `lib/shared/widgets/`.

## Key Design Decisions

### On-Device Inference

All classification runs locally using ONNX Runtime. No audio data leaves the device. The model file (~152 MB) is extracted from the APK asset bundle to disk on first launch, and the inference isolate loads it by file path to avoid serializing large byte arrays.

### Background Isolate for Inference

ONNX inference runs in a dedicated Dart isolate (`InferenceIsolate`) to keep the UI responsive. Communication uses typed messages via `SendPort` / `ReceivePort`.

### Ring Buffer Audio Pipeline

Audio flows through a shared `RingBuffer`:

```
Microphone → PCM16 → Float32 → RingBuffer → { Spectrogram, Inference, Recording }
```

Multiple consumers read from the same buffer without copies.

### JSON-Driven Model Config

All model parameters (tensor names, sample rate, inference defaults, label format) come from `assets/models/model_config.json`. No model-specific values are hardcoded.

### Riverpod State Management

Providers bridge services to the widget tree. Settings use generic `StateNotifierProvider` types (`DoubleSettingNotifier`, `IntSettingNotifier`) backed by `SharedPreferences`.

## State Machine

The live identification pipeline follows a strict state machine:

```
idle → loading → ready → active ↔ paused → ready
                      ↘ error
```
