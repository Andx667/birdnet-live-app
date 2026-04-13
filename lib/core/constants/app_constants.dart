/// BirdNET Live — Real-time bird species identification.
///
/// Application constants used across the app.
library;

/// App-wide string constants.
abstract final class AppConstants {
  /// Application display name.
  static const String appName = 'BirdNET Live';

  /// GitHub repository URL.
  static const String githubUrl =
      'https://github.com/birdnet-team/birdnet-live-app';

  /// Documentation site URL.
  static const String docsUrl =
      'https://birdnet-team.github.io/birdnet-live-app';

  /// Support email address.
  static const String supportEmail = 'ccb-birdnet@cornell.edu';

  /// BirdNET website URL.
  static const String birdnetUrl = 'https://birdnet.cornell.edu';

  /// Path to the model configuration JSON asset.
  ///
  /// The config file describes the ONNX model, its label format, tensor
  /// names, and inference defaults.  All model-specific parameters are
  /// read from this file at runtime — no values are hardcoded.
  static const String modelConfigAssetPath = 'assets/models/model_config.json';

  /// Base directory for model assets.
  static const String modelAssetsDir = 'assets/models';

  /// Default audio sample rate in Hz.
  ///
  /// Used by audio capture and spectrogram before a model config is loaded.
  /// The actual rate used for inference comes from the model config JSON.
  static const int sampleRate = 32000;

  /// Default species count for display purposes.
  ///
  /// Overridden at runtime once the model config and labels are loaded.
  static const int speciesCount = 5250;
}

/// SharedPreferences key constants.
abstract final class PrefKeys {
  static const String onboardingComplete = 'onboarding_complete';
  static const String termsAccepted = 'terms_accepted';
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String speciesLanguage = 'species_language';

  // Audio settings
  static const String audioGain = 'audio_gain';
  static const String highPassFilter = 'high_pass_filter';

  // Inference settings
  static const String windowDuration = 'window_duration';
  static const String confidenceThreshold = 'confidence_threshold';
  static const String inferenceRate = 'inference_rate';
  static const String speciesFilterMode = 'species_filter_mode';
  static const String sensitivity = 'sensitivity';
  static const String scorePooling = 'score_pooling';

  // Spectrogram settings
  static const String fftSize = 'fft_size';
  static const String colorMap = 'color_map';
  static const String dbFloor = 'db_floor';
  static const String dbCeiling = 'db_ceiling';
  static const String spectrogramDuration = 'spectrogram_duration';
  static const String spectrogramMaxFreq = 'spectrogram_max_freq';
  static const String logAmplitude = 'log_amplitude';

  // Recording settings
  static const String recordingFormat = 'recording_format';
  static const String recordingMode = 'recording_mode';
  static const String preBuffer = 'pre_buffer';
  static const String postBuffer = 'post_buffer';

  // Export settings
  static const String exportFormat = 'export_format';
  static const String includeAudio = 'include_audio';

  // Location / geo settings
  static const String useGps = 'use_gps';
  static const String geoThreshold = 'geo_threshold';
  static const String manualLatitude = 'manual_latitude';
  static const String manualLongitude = 'manual_longitude';
  static const String mapTileConsent = 'map_tile_consent';

  // Display settings
  static const String showSciNames = 'show_sci_names';

  // Point count settings
  static const String pointCountDuration = 'point_count_duration';

  // Survey settings
  static const String surveyInferenceRate = 'survey_inference_rate';
  static const String surveyGpsInterval = 'survey_gps_interval';
  static const String surveyMaxDuration = 'survey_max_duration';
  static const String surveyAutoStopBattery = 'survey_auto_stop_battery';
  static const String surveyRecordingMode = 'survey_recording_mode';
  static const String surveyClipPreBuffer = 'survey_clip_pre_buffer';
  static const String surveyClipPostBuffer = 'survey_clip_post_buffer';
  static const String surveyDetectionSampling = 'survey_detection_sampling';
  static const String surveyTopNPerSpecies = 'survey_top_n_per_species';
  static const String surveyMicDeviceId = 'survey_mic_device_id';
  static const String surveyLastObserver = 'survey_last_observer';
  static const String surveyLastTransectId = 'survey_last_transect_id';
}
