import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../main.dart';

class ForegroundServiceManager {
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bike_monitoring',
        channelName: 'Bike Monitoring',
        channelDescription: 'Background monitoring for bike motion',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> requestPermissions() async {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  static Future<void> ensureRunning() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Bike Security Active',
      notificationText: 'Monitoring for motion',
      callback: startCallback,
    );
  }
}
