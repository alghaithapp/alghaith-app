import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

enum AgoraCallState {
  idle,
  connecting,
  ringing,
  connected,
  ended,
  failed,
}

/// خدمة Agora صوتية — مثيل واحد مع تنظيف آمن عند مغادرة القناة.
class AgoraVoiceService {
  AgoraVoiceService._();

  static final AgoraVoiceService instance = AgoraVoiceService._();

  RtcEngine? _engine;
  AgoraCallState _state = AgoraCallState.idle;
  int? _remoteUid;
  int _joinGeneration = 0;
  bool _released = false;

  AgoraCallState get state => _state;
  int? get remoteUid => _remoteUid;
  bool get isInChannel =>
      _state == AgoraCallState.ringing ||
      _state == AgoraCallState.connected ||
      _state == AgoraCallState.connecting;

  void Function(AgoraCallState state)? onStateChanged;
  void Function(int remoteUid)? onRemoteUserJoined;
  void Function()? onRemoteUserLeft;

  Future<void> joinVoiceCall({
    required String appId,
    required String token,
    required String channelName,
    required int uid,
  }) async {
    await leave();

    if (appId.trim().isEmpty) {
      _setState(AgoraCallState.failed);
      throw StateError('Agora غير مفعّل على الخادم.');
    }
    if (token.trim().isEmpty) {
      _setState(AgoraCallState.failed);
      throw StateError('رمز المكالمة غير صالح.');
    }
    if (channelName.trim().isEmpty) {
      _setState(AgoraCallState.failed);
      throw StateError('قناة المكالمة غير صالحة.');
    }

    final generation = ++_joinGeneration;
    _released = false;
    _setState(AgoraCallState.connecting);

    final engine = createAgoraRtcEngine();
    _engine = engine;

    try {
      await engine.initialize(RtcEngineContext(appId: appId.trim()));
      if (!_isJoinActive(generation)) {
        await _releaseEngine(engine);
        return;
      }

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!_isJoinActive(generation)) return;
            debugPrint('Agora: joined ${connection.channelId}');
            if (_remoteUid == null) {
              _setState(AgoraCallState.ringing);
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!_isJoinActive(generation)) return;
            debugPrint('Agora: remote joined $remoteUid');
            _remoteUid = remoteUid;
            _setState(AgoraCallState.connected);
            onRemoteUserJoined?.call(remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!_isJoinActive(generation)) return;
            debugPrint('Agora: remote left $remoteUid ($reason)');
            if (_remoteUid == remoteUid) {
              _remoteUid = null;
              _setState(AgoraCallState.ended);
              onRemoteUserLeft?.call();
            }
          },
          onError: (err, msg) {
            if (!_isJoinActive(generation)) return;
            debugPrint('Agora error $err: $msg');
            _setState(AgoraCallState.failed);
          },
        ),
      );

      await engine.enableAudio();
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.joinChannel(
        token: token,
        channelId: channelName.trim(),
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );

      if (!_isJoinActive(generation)) {
        await _releaseEngine(engine);
      }
    } catch (error) {
      debugPrint('Agora join failed: $error');
      if (_isJoinActive(generation)) {
        _setState(AgoraCallState.failed);
      }
      await _releaseEngine(engine);
      rethrow;
    }
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  Future<void> leave() async {
    _joinGeneration++;
    _remoteUid = null;
    final engine = _engine;
    _engine = null;
    await _releaseEngine(engine);
    _setState(AgoraCallState.idle);
  }

  bool _isJoinActive(int generation) {
    return !_released && generation == _joinGeneration && _engine != null;
  }

  Future<void> _releaseEngine(RtcEngine? engine) async {
    if (engine == null) return;
    _released = true;
    try {
      await engine.leaveChannel();
    } catch (error) {
      debugPrint('Agora leaveChannel: $error');
    }
    try {
      await engine.release();
    } catch (error) {
      debugPrint('Agora release: $error');
    }
    if (identical(_engine, engine)) {
      _engine = null;
    }
  }

  void _setState(AgoraCallState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(next);
  }
}
