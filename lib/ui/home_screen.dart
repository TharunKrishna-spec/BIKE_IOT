import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openInMaps(SystemState state) async {
    if (!_hasGpsFix(state)) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${state.gpsLat},${state.gpsLng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _hasGpsFix(SystemState state) {
    return state.gpsFixTime > 0 && state.gpsLat != 0 && state.gpsLng != 0;
  }

  bool _isGpsStale(SystemState state) {
    if (!_hasGpsFix(state)) return true;
    final fix = DateTime.fromMillisecondsSinceEpoch(_epochMsFromDb(state.gpsFixTime));
    return DateTime.now().difference(fix) > const Duration(minutes: 2);
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
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(_epochMsFromDb(state.lastSeen));
    return DateTime.now().difference(lastSeen) > heartbeat;
  }

  int _epochMsFromDb(int value) {
    return value < 100000000000 ? value * 1000 : value;
  }

  String _formatEpoch(int epoch) {
    if (epoch == 0) return 'Never';
    final dt = DateTime.fromMillisecondsSinceEpoch(_epochMsFromDb(epoch));
    return dt.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<SystemState>(
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
                gpsLat: 0,
                gpsLng: 0,
                gpsFixTime: 0,
                gpsSats: 0,
                gpsHdop: 0,
                gpsAltMeters: 0,
              );
          final scheme = Theme.of(context).colorScheme;

          if (state.alert) {
            WakelockPlus.enable();
          } else {
            WakelockPlus.disable();
          }

          final statusColor = _statusColor(state, scheme);
          final hasGps = _hasGpsFix(state);
          final gpsStale = _isGpsStale(state);
          final gpsBadgeColor = hasGps && !gpsStale ? scheme.primary : scheme.outline;

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.surface,
                      const Color(0xFF0B1D2A),
                      const Color(0xFF1A1034),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: -120,
                right: -80,
                child: _GlowOrb(color: scheme.primary, size: 240),
              ),
              Positioned(
                bottom: -140,
                left: -80,
                child: _GlowOrb(color: scheme.secondary, size: 260),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_moon, size: 28),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TharunKrishnaAPP',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'TroonLabs',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings_outlined),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _auth.signOut();
                            },
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Sleep Mode',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _AnimatedToggleCard(
                        isOn: state.armed,
                        onChanged: (value) async {
                          await _repo.setArmed(value);
                        },
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'System Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isOffline(state)
                            ? 'Last seen: ${_formatEpoch(state.lastSeen)}'
                            : 'Heartbeat: ${state.heartbeatSeconds}s',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.45),
                              blurRadius: 18,
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt, color: statusColor),
                            const SizedBox(width: 10),
                            Text(
                              _statusLabel(state),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: statusColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bike Location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: gpsBadgeColor.withOpacity(0.15),
                              border: Border.all(color: gpsBadgeColor),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              hasGps
                                  ? (gpsStale ? 'GPS Stale' : 'GPS Live')
                                  : 'No GPS Fix',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Fix: ${_formatEpoch(state.gpsFixTime)}',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasGps
                            ? 'Lat: ${state.gpsLat.toStringAsFixed(6)}, Lng: ${state.gpsLng.toStringAsFixed(6)} | Sats: ${state.gpsSats}'
                            : 'Waiting for GPS coordinates from Neo-6M',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 170,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: hasGps
                              ? FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(state.gpsLat, state.gpsLng),
                                    initialZoom: 16,
                                    interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.none,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.tharunkrishna.homebike',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(state.gpsLat, state.gpsLng),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(Icons.location_on, size: 34),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Container(
                                  color: scheme.surfaceContainerHighest.withOpacity(0.35),
                                  alignment: Alignment.center,
                                  child: const Text('No map yet'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: hasGps ? () => _openInMaps(state) : null,
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Open In Maps'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: !state.alert
                                  ? () async {
                                      await AlarmPlayer.instance.start();
                                      await NotificationService.showAlertNotification();
                                    }
                                  : null,
                              child: const Text('Test Alert'),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (state.alert)
                        Text(
                          hasGps
                              ? 'Alert location: ${state.gpsLat.toStringAsFixed(6)}, ${state.gpsLng.toStringAsFixed(6)}'
                              : 'Alert active. GPS not fixed yet.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: state.alert
                            ? SizedBox(
                                key: const ValueKey('alert'),
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _setAlertStopped,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.error,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text('Stop Alert'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.45),
              color.withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedToggleCard extends StatelessWidget {
  const _AnimatedToggleCard({
    required this.isOn,
    required this.onChanged,
  });

  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glow = isOn ? scheme.primary : scheme.outline;
    final label = isOn ? 'ARMED' : 'DISARMED';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glow, width: 1.4),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0E1527),
            const Color(0xFF111B33),
            isOn ? const Color(0xFF153B4A) : const Color(0xFF1B1630),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.4),
            blurRadius: 22,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: isOn ? 1 : 0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Container(
                width: 12,
                height: 40,
                decoration: BoxDecoration(
                  color: glow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 12,
                  height: 12 + 22 * value,
                  decoration: BoxDecoration(
                    color: glow,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                isOn ? 'Security system armed' : 'System sleeping',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          Switch(
            value: isOn,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
