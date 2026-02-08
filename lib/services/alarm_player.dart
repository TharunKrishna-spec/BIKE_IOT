import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class AlarmPlayer {
  AlarmPlayer._internal();

  static final AlarmPlayer instance = AlarmPlayer._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setAudioSource(
      AudioSource.asset('assets/audio/alarm.wav'),
    );
    _player.setLoopMode(LoopMode.one);
    _initialized = true;
  }

  Future<void> start() async {
    await _ensureInitialized();
    await _player.setVolume(1.0);
    await _player.play();
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _player.stop();
  }
}
