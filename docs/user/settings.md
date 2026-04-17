# Settings

BirdNET Live offers a wide range of settings to configure audio capture, AI inference, spectrogram visuals, and data recording. Access the settings from the gear icon on the live screen or the home screen.

Understanding the *intuition* behind each setting will help you adapt the app to your specific environment and goals—whether you're maximizing detections in a quiet forest or filtering out noise in a busy urban area.

---

## General

These settings affect the basic language and appearance of the application.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **Theme** | System | Light, Dark, or System. | Switch to **Dark** mode to save battery life on OLED screens and preserve your night vision during early morning birding. |
| **Language** | System | Application interface language. | If you are contributing screenshots or helping non-native speakers, you can force the app into English or another language regardless of your phone's setting. |
| **Species Language** | System | The language used for common bird names. | You may prefer the app interface in your native language, but wish to learn or display bird names in English for international communication. |

---

## Audio Settings

These settings control how sound enters the app before it reaches the AI or the spectrogram.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **Input Device** | Default | Select which microphone to use. | Phones have multiple microphones. If you attach an external parabolic microphone or USB mic, select it here to greatly improve range and quality. |
| **Audio Gain** | 1.0 | Digital amplification applied to captured audio (0.5–4.0). | Increase gain (e.g., 2.0x) if birds are very distant and quiet. Decrease gain if you are near loud sources (like a river) that are clipping/distorting the audio. |
| **High-Pass Filter** | 0 Hz | Cuts off low frequencies (0–500 Hz). | **Highly recommended** to set to 150-250 Hz if it's windy, or if there is heavy traffic/highway noise nearby. This removes low-frequency rumble that can confuse the AI or clutter the spectrogram, without affecting high-pitched bird calls. |

---

## Inference Settings

These settings are the core of the BirdNET AI. They dictate how aggressively the app searches for birds and how it balances false positives vs. missing a call.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **Window Duration** | 3 s | Length of the audio chunk analyzed by the AI (3, 5, or 10s). | The model is trained on 3s chunks (best balance). Use 5s or 10s if you want the app to take wider context into account, though this updates the screen less frequently. |
| **Inference Rate** | 1.0 Hz | How often the AI analyzes the audio (0.5–4.0 Hz). | Increase this (e.g., 2.0 Hz) to analyze overlapping windows and catch very brief calls. Decrease it (e.g., 0.5 Hz) to save battery on long surveys. |
| **Confidence Threshold** | 25% | Minimum model confidence required to display a bird (1–99%). | Lower this to ~10% if you don't mind false positives but want to ensure you miss *nothing*. Raise it to ~50% if you only want definitive, undeniable identifications. |
| **Sensitivity** | 1.0 | Artificial bias applied to the model's logits (0.5–1.5). | If the AI is generally missing faint calls, push this slightly above 1.0. If you are getting too many confident false positives, lower it below 1.0. |
| **Score Pooling** | LME | How the app smooths out scores over time (Off, Average, Max, LME). | **LME** (Linear Mean Exponential) is best for continuous live listening as it prevents flickering. Use **Max** if you want the absolute highest instantaneous peak confidence to be recorded. |
| **Species Filter** | Off | Uses the GPS geo-model to filter out birds not native to your area. | **Geo Exclude** removes impossible birds (great for reducing false positives). **Geo Merge** boosts the confidence of highly likely local birds. Turn this **Off** if you are analyzing audio recorded in a completely different country or visiting a zoo. |

---

## Spectrogram Settings

The spectrogram is your visual window into the audio. Tweaking these settings helps you "see" bird calls more clearly.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **FFT Size** | 1024 | Frequency resolution (512–4096). | Higher values (2048) give crisper, sharper lines for bird calls, but require more CPU power and may look "smeared" in time. Lower values (512) update faster. |
| **Color Map** | Viridis | Color palette of the spectrogram. | **Viridis** is great for general contrast. **Magma** or **Inferno** often make faint high-frequency calls pop out against a dark background. |
| **dB Floor** | −90 dB | Minimum amplitude (quietest sound) drawn. | If the background of your spectrogram is entirely bright/noisy, raise the floor (e.g., to −70 dB) to make the background black, leaving only the loud bird calls visible. |
| **dB Ceiling** | −10 dB | Maximum amplitude (loudest sound) drawn. | Lower this if you want moderately loud calls to appear at maximum brightness. |
| **Duration** | 20 s | How many seconds of history fit on the screen. | Shrink to 10s on small phones so calls appear wider and easier to tap. Expand to 30s+ on tablets to see the long-term pattern of a songbird's chorus. |
| **Max Frequency** | 12,000 Hz | The highest pitch shown on the Y-axis. | Most birds vocalize between 2,000 and 8,000 Hz. If you are looking for specific high-pitched sounds (like bats or insects), raise this. If you are looking for low-frequency owls/pigeons, lower it to visually zoom in on the bottom half. |
| **Log Amplitude** | On | Compresses dynamic range. | Keep On to see faint sounds and loud sounds at the same time. Turn Off if you only want the absolute loudest sounds to register visually. |

---

## Recording Settings

Determine how the app saves audio to your device.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **Recording Mode** | Full | What to record: Off, Full (continuous), or Detections Only. | Use **Detections Only** to save massive amounts of storage space; it only saves the few seconds around a bird call rather than gigabytes of silence. |
| **Recording Format** | FLAC | Audio compression format (WAV or FLAC). | **FLAC** is mathematically lossless but takes 50% less space than WAV. Use WAV only if you plan to import the files into legacy audio software that doesn't support FLAC. |
| **Pre-Buffer** | 3 s | Seconds of audio saved *before* a detection triggers. | When using Detections Only mode, a 3s buffer ensures the very beginning of a sudden bird call isn't cut off. Increase to 5s for long, winding songs. |
| **Post-Buffer** | 3 s | Seconds of audio saved *after* a detection ends. | Ensures the trailing echoes or answering calls of a bird aren't abruptly chopped off at the end of the file. |

---

## Location Settings

These options feed coordinates to the Geo-Model for species filtering.

| Setting | Default | Description | Intuition / Why Change? |
|---------|---------|-------------|-------------------------|
| **Use GPS** | On | Allows the app to request location from the device. | Turn this Off to save battery if you are stationary for exactly one location, and instead manually type the coordinates below. |
| **Manual Latitude** | 0.0 | Manual override latitude. | Use when analyzing imported files from another country, or if you are deep in a canyon with zero GPS signal but know your coordinates. |
| **Manual Longitude** | 0.0 | Manual override longitude. | Same as above. |
| **Geo Threshold** | 0.03 | Minimum expected weekly occurrence rate for a species to be "allowed." | Raise this (e.g., 0.05) if you only want extremely common, everyday birds to pass the filter. Lower it (e.g., 0.01) if you don't want the filter accidentally blocking a rare migrant or vagrant. |

---

## Danger Zone

| Setting | Description | Intuition / Why Change? |
|---------|-------------|-------------------------|
| **Reset Onboarding** | Shows the initial setup and tutorial screens on the next launch. | Useful if you handed the app to a friend and want them to experience the tutorial, or if you skipped through permissions too fast the first time. |
| **Clear All Data** | Deletes all saved sessions, audio recordings, and resets settings. | Use this if your phone is running out of storage space, or if you want a clean slate before starting a completely new season of surveying. Requires typing "DELETE" to confirm. |
