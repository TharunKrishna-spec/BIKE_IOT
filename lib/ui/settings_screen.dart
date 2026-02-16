import 'package:flutter/material.dart';

import '../models/system_state.dart';
import '../services/firebase_repo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseRepo _repo = FirebaseRepo();

  final TextEditingController _deviceUidController = TextEditingController();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _heartbeatController =
      TextEditingController(text: '20');

  bool _isSaving = false;
  String? _status;

  @override
  void dispose() {
    _deviceUidController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _status = null;
    });

    try {
      final deviceUid = _deviceUidController.text.trim();
      final ssid = _ssidController.text.trim();
      final pass = _passwordController.text;
      final heartbeat = int.tryParse(_heartbeatController.text.trim()) ?? 20;

      if (deviceUid.isNotEmpty) {
        await _repo.setDeviceUid(deviceUid);
      }
      await _repo.setHeartbeatSeconds(heartbeat);

      if (ssid.isNotEmpty || pass.isNotEmpty) {
        await _repo.setProvisioning(ssid: ssid, password: pass);
      }

      setState(() {
        _status = 'Saved';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
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
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _GlowOrb(color: scheme.primary, size: 220),
            ),
            Positioned(
              bottom: -140,
              left: -90,
              child: _GlowOrb(color: scheme.secondary, size: 240),
            ),
            SafeArea(
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
                          gpsLat: 0,
                          gpsLng: 0,
                          gpsFixTime: 0,
                          gpsSats: 0,
                          gpsHdop: 0,
                          gpsAltMeters: 0,
                        );

                    if (_deviceUidController.text.isEmpty &&
                        state.deviceUid.isNotEmpty) {
                      _deviceUidController.text = state.deviceUid;
                    }
                    if (_heartbeatController.text.isEmpty ||
                        _heartbeatController.text == '0') {
                      _heartbeatController.text =
                          state.heartbeatSeconds.toString();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_ios_new),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Settings',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Device Pairing',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _deviceUidController,
                          decoration: const InputDecoration(
                            labelText: 'Device UID (from ESP32)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Wi-Fi Provisioning',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ssidController,
                          decoration: const InputDecoration(
                            labelText: 'Wi-Fi SSID',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Wi-Fi Password',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Heartbeat Timeout (seconds)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _heartbeatController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'e.g. 20',
                          ),
                        ),
                        const Spacer(),
                        if (_status != null)
                          Text(
                            _status!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _save,
                            child:
                                Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
