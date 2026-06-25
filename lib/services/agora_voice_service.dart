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
  RtcEngineEventHandler? _eventHandler;
  AgoraCallState _state = AgoraCallState.idle;
  int? _remoteUid;
  int _joinGeneration = 0;
  Future<void>? _joinFuture;

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

    final joinTask = _joinVoiceCallInternal(
      appId: appId.trim(),
      token: token,
      channelName: channelName.trim(),
      uid: uid,
    );
    _joinFuture = joinTask;
    try {
      await joinTask;
    } finally {
      if (identical(_joinFuture, joinTask)) {
        _joinFuture = null;
      }
    }
  }

  Future<void> _joinVoiceCallInternal({
    required String appId,
    required String token,
    required String channelName,
    required int uid,
  }) async {
    final generation = _joinGeneration;
    _setState(AgoraCallState.connecting);

    final engine = createAgoraRtcEngine();
    _engine = engine;

    final handler = RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (!_isJoinActive(generation, engine)) return;
        debugPrint('Agora: joined ${connection.channelId}');
        if (_remoteUid == null) {
          _setState(AgoraCallState.ringing);
        }
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!_isJoinActive(generation, engine)) return;
        debugPrint('Agora: remote joined $remoteUid');
        _remoteUid = remoteUid;
        _setState(AgoraCallState.connected);
        onRemoteUserJoined?.call(remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!_isJoinActive(generation, engine)) return;
        debugPrint('Agora: remote left $remoteUid ($reason)');
        if (_remoteUid == remoteUid) {
          _remoteUid = null;
          _setState(AgoraCallState.ended);
          onRemoteUserLeft?.call();
        }
      },
      onError: (err, msg) {
        if (!_isJoinActive(generation, engine)) return;
        debugPrint('Agora error $err: $msg');
        _setState(AgoraCallState.failed);
      },
    );
    _eventHandler = handler;

    try {
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (!_isJoinActive(generation, engine)) {
        await _releaseEngine(engine, handler);
        return;
      }

      engine.registerEventHandler(handler);

      await engine.enableAudio();
      if (!_isJoinActive(generation, engine)) {
        await _releaseEngine(engine, handler);
        return;
      }

      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      await engine.setDefaultAudioRouteToSpeakerphone(true);
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

      if (!_isJoinActive(generation, engine)) {
        await _releaseEngine(engine, handler);
      }
    } catch (error) {
      debugPrint('Agora join failed: $error');
      if (_isJoinActive(generation, engine)) {
        _setState(AgoraCallState.failed);
      }
      await _releaseEngine(engine, handler);
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

    final pendingJoin = _joinFuture;
    if (pendingJoin != null) {
      try {
        await pendingJoin;
      } catch (_) {}
    }

    final engine = _engine;
    final handler = _eventHandler;
    _engine = null;
    _eventHandler = null;
    await _releaseEngine(engine, handler);
    _setState(AgoraCallState.idle);
  }

  bool _isJoinActive(int generation, RtcEngine engine) {
    return generation == _joinGeneration && identical(_engine, engine);
  }

  Future<void> _releaseEngine(
    RtcEngine? engine,
    RtcEngineEventHandler? handler,
  ) async {
    if (engine == null) return;
    try {
      if (handler != null) {
        engine.unregisterEventHandler(handler);
      }
    } catch (error) {
      debugPrint('Agora unregisterEventHandler: $error');
    }
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
      _eventHandler = null;
    }
  }

  void _setState(AgoraCallState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(next);
  }
}
