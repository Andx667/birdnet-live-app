# Session Review

Session Review is where BirdNET Live turns detections into an editable record.

## How You Reach It

BirdNET Live opens Session Review automatically after completing:

- a Live session
- a Point Count
- a Survey
- a File Analysis run

You can also reopen any saved session from [Session Library](session-library.md).

## Main Areas

### Summary and playback

Session Review combines playback, spectrogram navigation, and a species list. For survey sessions it can also show mapped context.

### Species list

Species are grouped into expandable rows. You can inspect detections by species and move through the recording while reviewing them.

### Survey track map

Survey sessions show a small inline map of the GPS track and detection markers. Tap a marker on the inline map to focus a detection — the inline map centers on it. Tap the :material-fullscreen: **expand** button (top-right of the inline map) to open the **fullscreen map**; if a detection was focused, the fullscreen map opens centered and zoomed in on that detection so you keep your place.

#### Marker encoding

- **Confidence is color-coded** with a CVD-safe ramp: low → high confidence runs from purple-blue through teal/yellow to red. The ramp's lightness changes monotonically so it stays readable in monochrome and for users with red-green color vision deficiency.
- **Audio-bearing detections** show a colored ring around the species photo plus a corner play badge — tap them to play the recorded clip in a sheet.
- **Silent detections** (no clip on disk) render smaller, faded, and with a neutral-grey ring so audio detections always read as the primary content.
- **Overlapping markers at the same spot** are z-ordered by importance: highlighted > audio > higher confidence, so a low-confidence silent marker can never obscure a strong audio detection.
- **Below zoom 14.5** silhouettes degrade to colored dots sized by confidence, and dense clusters collapse to a count bubble (clustering disables at zoom 15).

#### Filtering

The fullscreen map has a persistent **filter chip** anchored top-right of the map. Tap it to open the filter sheet; the chip's label always shows what's currently in effect (*"All species"*, *"With audio"*, *"≥ 80%"*, or a single species name). Available filters:

- **All detections** (default).
- **With audio clip** — only detections whose clip is still on disk and playable.
- **Manual additions** — only detections you added in Session Review (excludes auto-detected ones).

You can also restrict the detections by confidence level. The slider configures the confidence floor (starts at 10%).

Below the confidence slider is a **Limit to species** picker that lets you collapse the map to a single species — useful for asking "where exactly along the route did I hear the wood thrush?". An *All species* entry clears the species restriction. The filters combine: e.g. *With audio clip* + *Wood Thrush* + *> 80%* shows only the playable Wood Thrush markers that scored above 80%.

When a filter is active, the app-bar title gains a match-count subtitle (e.g. *"7 detections"*). *Reset* in the sheet returns to the default.

## Toolbar Icons

The toolbar uses the same icon meanings described in [Icons & Controls](icons-and-controls.md):

- :material-plus-circle-outline: — add content
- :material-undo-variant: / :material-redo-variant: — step through edits
- :material-content-cut: — trim mode
- :material-content-save: — save edits
- :material-share-variant: — export or share
- :material-delete-outline: — discard session
- :material-play: — continue a survey when that action is available
- :material-help-circle-outline: — open the Session Review help sheet
- :material-tune: — open Settings

## Typical Review Tasks

- check detections against playback and spectrogram context
- add a species or annotation
- trim the recording to the useful interval
- export the reviewed result set

## Export

Export behavior depends on the options selected in [Settings](settings.md). The app can package detections and, optionally, audio into the chosen export format. Every export now ships with full provenance metadata — the app version, model name and version, species locale, export timestamp, and a snapshot of all settings at export time — written to a `<prefix>.metadata.json` side-file (ZIP) or a top-level `meta` block (JSON) so that exports are self-describing and reproducible.