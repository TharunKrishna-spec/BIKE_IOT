import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground/foreground_task_handler.dart';
import 'services/foreground_service_manager.dart';
import 'services/notification_service.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'services/auth_service.dart';
import 'ui/loading_screen.dart';

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
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5CF2FF),
          secondary: Color(0xFFB28DFF),
          surface: Color(0xFF0C1220),
          error: Color(0xFFFF4D6D),
        ),
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }
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
