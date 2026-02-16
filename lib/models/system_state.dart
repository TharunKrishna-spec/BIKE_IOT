class SystemState {
  final bool armed;
  final bool alert;
  final int lastSeen;
  final int lastMotion;
  final String deviceUid;
  final int heartbeatSeconds;
  final double gpsLat;
  final double gpsLng;
  final int gpsFixTime;
  final int gpsSats;
  final double gpsHdop;
  final double gpsAltMeters;

  const SystemState({
    required this.armed,
    required this.alert,
    required this.lastSeen,
    required this.lastMotion,
    required this.deviceUid,
    required this.heartbeatSeconds,
    required this.gpsLat,
    required this.gpsLng,
    required this.gpsFixTime,
    required this.gpsSats,
    required this.gpsHdop,
    required this.gpsAltMeters,
  });

  factory SystemState.fromMap(Map<dynamic, dynamic>? data) {
    final armed = data?['armed'];
    final alert = data?['alert'];
    final lastSeen = data?['lastSeen'];
    final lastMotion = data?['lastMotion'];
    final deviceUid = data?['deviceUid'];
    final heartbeatSeconds = data?['heartbeatSeconds'];
    final gps = data?['gps'];
    final gpsLat = gps is Map<dynamic, dynamic> ? gps['lat'] : null;
    final gpsLng = gps is Map<dynamic, dynamic> ? gps['lng'] : null;
    final gpsFixTime = gps is Map<dynamic, dynamic> ? gps['fixTime'] : null;
    final gpsSats = gps is Map<dynamic, dynamic> ? gps['sats'] : null;
    final gpsHdop = gps is Map<dynamic, dynamic> ? gps['hdop'] : null;
    final gpsAltMeters = gps is Map<dynamic, dynamic> ? gps['altMeters'] : null;
    return SystemState(
      armed: armed is bool ? armed : false,
      alert: alert is bool ? alert : false,
      lastSeen: lastSeen is int ? lastSeen : 0,
      lastMotion: lastMotion is int ? lastMotion : 0,
      deviceUid: deviceUid is String ? deviceUid : '',
      heartbeatSeconds: heartbeatSeconds is int ? heartbeatSeconds : 20,
      gpsLat: gpsLat is num ? gpsLat.toDouble() : 0,
      gpsLng: gpsLng is num ? gpsLng.toDouble() : 0,
      gpsFixTime: gpsFixTime is int ? gpsFixTime : 0,
      gpsSats: gpsSats is int ? gpsSats : 0,
      gpsHdop: gpsHdop is num ? gpsHdop.toDouble() : 0,
      gpsAltMeters: gpsAltMeters is num ? gpsAltMeters.toDouble() : 0,
    );
  }
}
