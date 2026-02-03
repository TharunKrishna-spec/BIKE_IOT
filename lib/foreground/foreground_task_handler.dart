import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/alarm_player.dart';
import '../services/firebase_repo.dart';
import '../services/notification_service.dart';

class ForegroundTaskHandler extends TaskHandler {
  final FirebaseRepo _repo = FirebaseRepo();
  StreamSubscription<bool>? _alertSub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp();
    await NotificationService.initialize();

    _alertSub = _repo.watchAlert().listen((alert) async {
      if (alert) {
        await AlarmPlayer.instance.start();
        await NotificationService.showAlertNotification();
      } else {
        await AlarmPlayer.instance.stop();
        await NotificationService.cancelAlertNotification();
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _alertSub?.cancel();
    await AlarmPlayer.instance.stop();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {}
}
