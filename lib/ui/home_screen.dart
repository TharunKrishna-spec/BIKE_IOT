import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/system_state.dart';
import '../services/alarm_player.dart';
import '../services/auth_service.dart';
import '../services/firebase_repo.dart';
import '../services/foreground_service_manager.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseRepo _repo = FirebaseRepo();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _initBackgroundMonitoring();
    _repo.ensureOwnerUid();
  }

  Future<void> _initBackgroundMonitoring() async {
    await NotificationService.requestPermissions();
    await ForegroundServiceManager.requestPermissions();
    await ForegroundServiceManager.ensureRunning();
  }

  Future<void> _setAlertStopped() async {
    await _repo.setAlert(false);
    await AlarmPlayer.instance.stop();
    await NotificationService.cancelAlertNotification();
    await WakelockPlus.disable();
  }

  String _statusLabel(SystemState state) {
    if (_isOffline(state)) return 'Device Offline';
    if (state.alert) return 'Alert Active';
    return state.armed ? 'Armed' : 'Disarmed';
  }

  Color _statusColor(SystemState state, ColorScheme scheme) {
    if (_isOffline(state)) return scheme.outline;
    if (state.alert) return scheme.error;
    return state.armed ? scheme.primary : scheme.outline;
  }

  bool _isOffline(SystemState state) {
    if (state.lastSeen == 0) return true;
    final heartbeat = Duration(seconds: state.heartbeatSeconds);
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(state.lastSeen);
    return DateTime.now().difference(lastSeen) > heartbeat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TharunKrishnaAPP'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<SystemState>(
            stream: _repo.watchSystem(),
            builder: (context, snapshot) {
              final state = snapshot.data ??
                  const SystemState(
                    armed: false,
                    alert: false,
                    lastSeen: 0,
                    lastMotion: 0,
                    deviceUid: '',
                    heartbeatSeconds: 20,
                  );
              final scheme = Theme.of(context).colorScheme;

              if (state.alert) {
                WakelockPlus.enable();
              } else {
                WakelockPlus.disable();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await _auth.signOut();
                      },
                      child: const Text('Sign Out'),
                    ),
                  ),
                  Text(
                    'Sleep Mode',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.armed ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Switch(
                        value: state.armed,
                        onChanged: (value) async {
                          await _repo.setArmed(value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'System Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isOffline(state)
                        ? 'Last seen: ${state.lastSeen == 0 ? 'Never' : DateTime.fromMillisecondsSinceEpoch(state.lastSeen)}'
                        : 'Heartbeat: ${state.heartbeatSeconds}s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(state, scheme).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor(state, scheme),
                      ),
                    ),
                    child: Text(
                      _statusLabel(state),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _statusColor(state, scheme),
                          ),
                    ),
                  ),
                  const Spacer(),
                  if (state.alert)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _setAlertStopped,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Stop Alert'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
