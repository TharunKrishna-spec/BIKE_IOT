import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../main.dart';

class ForegroundServiceManager {
  static Future<void> initialize() async {
    await FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bike_monitoring',
        channelName: 'Bike Monitoring',
        channelDescription: 'Background monitoring for bike motion',
        channelImportance: NotificationChannelImportance.low,
        priority: NotificationPriority.low,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
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
