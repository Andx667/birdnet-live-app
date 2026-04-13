// =============================================================================
// Survey Notification Service — Foreground service + persistent notification
// =============================================================================
//
// Wraps [flutter_foreground_task] to keep the app alive during long-running
// surveys.  The foreground service runs with type `microphone|location`
// (required on Android 14+).
//
// The persistent notification shows live stats (elapsed time, detection
// count, distance walked, battery level) and is updated every 30 seconds
// from the main isolate via [update].
//
// ### Notification layout
//
//   BirdNET Live — Survey Recording
//   ⏱ 01:23:45   🐦 42 detections   📍 2.3 km   🔋 72 %
//
// ### Usage
//
//   SurveyNotificationService.init();          // once, at app startup
//   final svc = SurveyNotificationService();
//   await svc.start(...);                      // on survey start
//   await svc.update(...);                     // every 30 s
//   await svc.stop();                          // on survey stop
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// =============================================================================
// Task handler (runs in a separate isolate — kept minimal)
// =============================================================================

/// Top-level callback required by flutter_foreground_task.
@pragma('vm:entry-point')
void surveyTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_SurveyTaskHandler());
}

/// Minimal task handler.  Survey logic runs in the main isolate; this
/// handler exists only to satisfy the flutter_foreground_task API.
class _SurveyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[SurveyTaskHandler] onStart');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: notification updates are driven from the main isolate.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[SurveyTaskHandler] onDestroy');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.sendDataToMain({'action': 'stop'});
    } else if (id == 'open') {
      FlutterForegroundTask.launchApp();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

// =============================================================================
// Service wrapper
// =============================================================================

/// Manages the Android foreground service for survey background operation.
class SurveyNotificationService {
  bool _running = false;

  /// Whether the foreground service is currently active.
  bool get isRunning => _running;

  /// Initialize the foreground task configuration.  Call once at app startup.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // New channel ID forces Android to create a fresh channel (the old
        // 'birdnet_survey' channel cached LOW importance and cannot be
        // changed programmatically).
        channelId: 'birdnet_survey_fg',
        channelName: 'BirdNET Survey',
        channelDescription: 'Active bird survey recording',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Request notification permission (Android 13+).
  ///
  /// Call this early (e.g. during survey setup) so the permission dialog
  /// does not interrupt the foreground-service start call.
  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  /// Start the foreground service with an initial notification.
  Future<void> start({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;

    // Best-effort permission check — don't bail if denied; Android will
    // still create a foreground service (just with a default notification
    // on some OEMs).
    final granted = await ensurePermission();
    if (!granted) {
      debugPrint('[SurveyNotification] permission not granted — '
          'attempting startService anyway');
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: title,
      notificationText: text,
      notificationButtons: [
        const NotificationButton(id: 'stop', text: 'Stop'),
        const NotificationButton(id: 'open', text: 'Open'),
      ],
      callback: surveyTaskCallback,
    );
    if (result is ServiceRequestSuccess) {
      _running = true;
      debugPrint('[SurveyNotification] started');
    } else {
      _running = false;
      debugPrint('[SurveyNotification] startService failed: $result');
    }
  }

  /// Update the notification text with current survey stats.
  Future<void> update({
    required String title,
    required String text,
  }) async {
    if (!_running) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Stop the foreground service.
  Future<void> stop() async {
    if (!_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
    debugPrint('[SurveyNotification] stopped');
  }
}
