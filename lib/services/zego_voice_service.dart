import 'package:flutter/foundation.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

enum ZegoCallState {
  idle,
  connecting,
  ringing,
  connected,
  ended,
  failed,
}

/// خدمة ZEGOCLOUD صوتية — مثيل واحد مع تنظيف آمن عند مغادرة الغرفة.
class ZegoVoiceService {
  ZegoVoiceService._();

  static final ZegoVoiceService instance = ZegoVoiceService._();

  ZegoCallState _state = ZegoCallState.idle;
  String? _roomId;
  String? _streamId;
  final Set<String> _playingStreams = {};
  int _joinGeneration = 0;
  Future<void>? _joinFuture;

  ZegoCallState get state => _state;
  bool get isInChannel =>
      _state == ZegoCallState.ringing ||
      _state == ZegoCallState.connected ||
      _state == ZegoCallState.connecting;

  void Function(ZegoCallState state)? onStateChanged;
  void Function(String remoteStreamId)? onRemoteUserJoined;
  void Function()? onRemoteUserLeft;

  Future<void> joinVoiceCall({
    required int appId,
    required String token,
    required String roomId,
    required String userId,
    required String streamId,
  }) async {
    await leave();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (appId <= 0) {
      _setState(ZegoCallState.failed);
      throw StateError('ZEGOCLOUD غير مفعّل على الخادم.');
    }
    if (token.trim().isEmpty) {
      _setState(ZegoCallState.failed);
      throw StateError('رمز المكالمة غير صالح.');
    }
    if (roomId.trim().isEmpty || userId.trim().isEmpty || streamId.trim().isEmpty) {
      _setState(ZegoCallState.failed);
      throw StateError('بيانات غرفة المكالمة غير صالحة.');
    }

    final joinTask = _joinVoiceCallInternal(
      appId: appId,
      token: token.trim(),
      roomId: roomId.trim(),
      userId: userId.trim(),
      streamId: streamId.trim(),
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
    required int appId,
    required String token,
    required String roomId,
    required String userId,
    required String streamId,
  }) async {
    final generation = _joinGeneration;
    _setState(ZegoCallState.connecting);

    void onRoomUserUpdate(
      String roomID,
      ZegoUpdateType updateType,
      List<ZegoUser> userList,
    ) {
      if (!_isJoinActive(generation, roomId)) return;
      if (roomID != roomId) return;

      if (updateType == ZegoUpdateType.Add) {
        for (final user in userList) {
          if (user.userID == userId) continue;
          debugPrint('Zego: remote user joined ${user.userID}');
          _setState(ZegoCallState.connected);
          onRemoteUserJoined?.call(user.userID);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final user in userList) {
          if (user.userID == userId) continue;
          debugPrint('Zego: remote user left ${user.userID}');
          onRemoteUserLeft?.call();
          _setState(ZegoCallState.ended);
        }
      }
    }

    void onStreamUpdate(
      String roomID,
      ZegoUpdateType updateType,
      List<ZegoStream> streamList,
      Map<String, dynamic> extendedData,
    ) {
      if (!_isJoinActive(generation, roomId)) return;
      if (roomID != roomId) return;

      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          if (stream.streamID == streamId) continue;
          if (!_playingStreams.add(stream.streamID)) continue;
          debugPrint('Zego: remote stream ${stream.streamID}');
          ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          _setState(ZegoCallState.connected);
          onRemoteUserJoined?.call(stream.streamID);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final stream in streamList) {
          if (!_playingStreams.remove(stream.streamID)) continue;
          ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          onRemoteUserLeft?.call();
          _setState(ZegoCallState.ended);
        }
      }
    }

    void onRoomStateUpdate(
      String roomID,
      ZegoRoomState state,
      int errorCode,
      Map<String, dynamic> extendedData,
    ) {
      if (!_isJoinActive(generation, roomId)) return;
      if (roomID != roomId) return;
      if (state == ZegoRoomState.Disconnected && errorCode != 0) {
        debugPrint('Zego room error $errorCode');
        _setState(ZegoCallState.failed);
      }
    }

    try {
      final profile = ZegoEngineProfile(
        appId,
        ZegoScenario.StandardVoiceCall,
        appSign: '',
      );
      await ZegoExpressEngine.createEngineWithProfile(profile);
      if (!_isJoinActive(generation, roomId)) {
        await _destroyEngine(roomId: roomId, streamId: streamId);
        return;
      }

      ZegoExpressEngine.onRoomStreamUpdate = onStreamUpdate;
      ZegoExpressEngine.onRoomStateUpdate = onRoomStateUpdate;
      ZegoExpressEngine.onRoomUserUpdate = onRoomUserUpdate;

      final roomConfig = ZegoRoomConfig.defaultConfig();
      roomConfig.token = token;

      final loginResult = await ZegoExpressEngine.instance.loginRoom(
        roomId,
        ZegoUser(userId, userId),
        config: roomConfig,
      );
      if (!_isJoinActive(generation, roomId)) {
        await _destroyEngine(roomId: roomId, streamId: streamId);
        return;
      }
      if (loginResult.errorCode != 0) {
        throw StateError('Zego login failed (${loginResult.errorCode})');
      }

      _roomId = roomId;
      _streamId = streamId;

      await ZegoExpressEngine.instance.enableCamera(false);
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      await ZegoExpressEngine.instance.startPublishingStream(streamId);

      if (!_isJoinActive(generation, roomId)) {
        await _destroyEngine(roomId: roomId, streamId: streamId);
        return;
      }

      debugPrint('Zego: joined $roomId as $userId');
      _setState(ZegoCallState.ringing);
    } catch (error) {
      debugPrint('Zego join failed: $error');
      if (_isJoinActive(generation, roomId)) {
        _setState(ZegoCallState.failed);
      }
      await _destroyEngine(roomId: roomId, streamId: streamId);
      rethrow;
    }
  }

  Future<void> setMuted(bool muted) async {
    await ZegoExpressEngine.instance.muteMicrophone(muted);
  }

  Future<void> setSpeakerphone(bool enabled) async {
    await ZegoExpressEngine.instance.setAudioRouteToSpeaker(enabled);
  }

  Future<void> leave() async {
    _joinGeneration++;
    final roomId = _roomId;
    final streamId = _streamId;
    _playingStreams.clear();
    _roomId = null;
    _streamId = null;

    final pendingJoin = _joinFuture;
    if (pendingJoin != null) {
      try {
        await pendingJoin;
      } catch (_) {}
    }

    await _destroyEngine(roomId: roomId, streamId: streamId);
    _setState(ZegoCallState.idle);
  }

  bool _isJoinActive(int generation, String roomId) {
    return generation == _joinGeneration;
  }

  Future<void> _destroyEngine({String? roomId, String? streamId}) async {
    final activeRoomId = roomId ?? _roomId;
    final activeStreamId = streamId ?? _streamId;

    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateUpdate = null;
    ZegoExpressEngine.onRoomUserUpdate = null;

    try {
      if (activeStreamId != null && activeStreamId.isNotEmpty) {
        await ZegoExpressEngine.instance.stopPublishingStream();
      }
    } catch (error) {
      debugPrint('Zego stopPublishingStream: $error');
    }

    for (final remoteStream in _playingStreams.toList()) {
      try {
        await ZegoExpressEngine.instance.stopPlayingStream(remoteStream);
      } catch (error) {
        debugPrint('Zego stopPlayingStream: $error');
      }
    }
    _playingStreams.clear();

    try {
      if (activeRoomId != null && activeRoomId.isNotEmpty) {
        await ZegoExpressEngine.instance.logoutRoom(activeRoomId);
      }
    } catch (error) {
      debugPrint('Zego logoutRoom: $error');
    }

    try {
      await ZegoExpressEngine.destroyEngine();
    } catch (error) {
      debugPrint('Zego destroyEngine: $error');
    }
  }

  void _setState(ZegoCallState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(next);
  }
}
