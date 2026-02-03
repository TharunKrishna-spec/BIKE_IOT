class SystemState {
  final bool armed;
  final bool alert;
  final int lastSeen;
  final int lastMotion;
  final String deviceUid;
  final int heartbeatSeconds;

  const SystemState({
    required this.armed,
    required this.alert,
    required this.lastSeen,
    required this.lastMotion,
    required this.deviceUid,
    required this.heartbeatSeconds,
  });

  factory SystemState.fromMap(Map<dynamic, dynamic>? data) {
    final armed = data?['armed'];
    final alert = data?['alert'];
    final lastSeen = data?['lastSeen'];
    final lastMotion = data?['lastMotion'];
    final deviceUid = data?['deviceUid'];
    final heartbeatSeconds = data?['heartbeatSeconds'];
    return SystemState(
      armed: armed is bool ? armed : false,
      alert: alert is bool ? alert : false,
      lastSeen: lastSeen is int ? lastSeen : 0,
      lastMotion: lastMotion is int ? lastMotion : 0,
      deviceUid: deviceUid is String ? deviceUid : '',
      heartbeatSeconds: heartbeatSeconds is int ? heartbeatSeconds : 20,
    );
  }
}
