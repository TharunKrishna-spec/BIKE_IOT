import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/system_state.dart';

class FirebaseRepo {
  FirebaseRepo();

  final DatabaseReference _systemRef =
      FirebaseDatabase.instance.ref('system');
  final DatabaseReference _provisioningRef =
      FirebaseDatabase.instance.ref('provisioning');

  Future<void> setArmed(bool armed) =>
      _systemRef.child('armed').set(armed);

  Future<void> setAlert(bool alert) =>
      _systemRef.child('alert').set(alert);

  Future<void> setDeviceUid(String deviceUid) =>
      _systemRef.child('deviceUid').set(deviceUid);

  Future<void> setHeartbeatSeconds(int seconds) =>
      _systemRef.child('heartbeatSeconds').set(seconds);

  Future<void> setProvisioning({
    required String ssid,
    required String password,
  }) async {
    await _provisioningRef.child('ssid').set(ssid);
    await _provisioningRef.child('password').set(password);
  }

  Future<void> ensureOwnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await _systemRef.child('ownerUid').get();
    if (!snapshot.exists) {
      await _systemRef.child('ownerUid').set(user.uid);
    }
  }

  Stream<SystemState> watchSystem() {
    return _systemRef.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map<dynamic, dynamic>) {
        return SystemState.fromMap(value);
      }
      return const SystemState(
        armed: false,
        alert: false,
        lastSeen: 0,
        lastMotion: 0,
        deviceUid: '',
        heartbeatSeconds: 20,
      );
    });
  }

  Stream<bool> watchAlert() {
    return _systemRef.child('alert').onValue.map((event) {
      final value = event.snapshot.value;
      return value is bool ? value : false;
    });
  }
}
