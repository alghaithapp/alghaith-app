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

class AgoraVoiceService {
  RtcEngine? _engine;
  AgoraCallState _state = AgoraCallState.idle;
  int? _remoteUid;

  AgoraCallState get state => _state;
  int? get remoteUid => _remoteUid;

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

    _setState(AgoraCallState.connecting);
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId.trim()));
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Agora: joined ${connection.channelId}');
          if (_remoteUid == null) {
            _setState(AgoraCallState.ringing);
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Agora: remote joined $remoteUid');
          _remoteUid = remoteUid;
          _setState(AgoraCallState.connected);
          onRemoteUserJoined?.call(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Agora: remote left $remoteUid');
          if (_remoteUid == remoteUid) {
            _remoteUid = null;
            _setState(AgoraCallState.ended);
            onRemoteUserLeft?.call();
          }
        },
        onError: (err, msg) {
          debugPrint('Agora error $err: $msg');
          _setState(AgoraCallState.failed);
        },
      ),
    );

    await engine.enableAudio();
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );

    _engine = engine;
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setSpeakerphone(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    _remoteUid = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (_) {}
      try {
        await engine.release();
      } catch (_) {}
    }
    _setState(AgoraCallState.idle);
  }

  void _setState(AgoraCallState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(next);
  }
}
