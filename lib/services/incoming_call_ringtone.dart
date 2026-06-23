import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// تشغيل رنين المكالمة الواردة (حلقة مستمرة حتى الإيقاف).
class IncomingCallRingtone {
  IncomingCallRingtone._();

  static final IncomingCallRingtone instance = IncomingCallRingtone._();

  static const _assetPath = 'sounds/alghaith_incoming_call.wav';

  AudioPlayer? _player;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;

    try {
      final player = AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1);
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await player.play(AssetSource(_assetPath));
    } catch (error) {
      _playing = false;
      _player = null;
      debugPrint('IncomingCallRingtone: failed to play — $error');
    }
  }

  Future<void> stop() async {
    if (!_playing && _player == null) return;
    _playing = false;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      debugPrint('IncomingCallRingtone: failed to stop — $error');
    }
  }
}
