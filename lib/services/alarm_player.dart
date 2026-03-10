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
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    await _player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.alarm,
      ),
    );
    await _player.setAudioSource(AudioSource.asset('assets/audio/alarm.wav'));
    _player.setLoopMode(LoopMode.one);
    _initialized = true;
  }

  Future<void> start() async {
    await _ensureInitialized();
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (_player.position > Duration.zero) {
      await _player.seek(Duration.zero);
    }
    await _player.setVolume(1.0);
    await _player.play();
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _player.stop();
  }
}
