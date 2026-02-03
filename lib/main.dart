import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground/foreground_task_handler.dart';
import 'services/foreground_service_manager.dart';
import 'services/notification_service.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await ForegroundServiceManager.initialize();
  runApp(const TharunKrishnaApp());
}

class TharunKrishnaApp extends StatelessWidget {
  const TharunKrishnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'TharunKrishnaAPP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F8A70),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
