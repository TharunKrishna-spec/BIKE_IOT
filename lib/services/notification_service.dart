import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';

import 'alarm_player.dart';
import 'firebase_repo.dart';

const String alertChannelId = 'bike_alerts';
const String alertChannelName = 'Bike Alerts';
const String alertChannelDescription = 'Full screen alerts for bike motion';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );
  }

  static Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  static Future<void> showAlertNotification() async {
    const androidDetails = AndroidNotificationDetails(
      alertChannelId,
      alertChannelName,
      channelDescription: alertChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: false,
      ongoing: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alert',
          'Stop Alert',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      1001,
      'Bike Alert',
      'Motion detected',
      details,
    );
  }

  static Future<void> cancelAlertNotification() async {
    await _plugin.cancel(1001);
  }

  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId == 'stop_alert') {
      await FirebaseRepo().setAlert(false);
      await AlarmPlayer.instance.stop();
      await cancelAlertNotification();
    }
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();

  if (response.actionId == 'stop_alert') {
    await FirebaseRepo().setAlert(false);
    await AlarmPlayer.instance.stop();
  }
}
