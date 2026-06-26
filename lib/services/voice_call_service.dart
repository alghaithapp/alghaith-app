import '../core/network/api_client.dart';
import '../models/voice_call_log.dart';

class VoiceCallConfig {
  final bool enabled;
  final int appId;

  const VoiceCallConfig({
    required this.enabled,
    required this.appId,
  });

  factory VoiceCallConfig.fromMap(Map<String, dynamic> map) {
    return VoiceCallConfig(
      enabled: map['enabled'] == true,
      appId: _readAppId(map['appId']),
    );
  }

  static int _readAppId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class VoiceCallSession {
  final int appId;
  final String token;
  final String roomId;
  final String channelName;
  final String userId;
  final String streamId;
  final String threadType;
  final String threadId;
  final String? callLogId;

  const VoiceCallSession({
    required this.appId,
    required this.token,
    required this.roomId,
    required this.channelName,
    required this.userId,
    required this.streamId,
    required this.threadType,
    required this.threadId,
    this.callLogId,
  });

  factory VoiceCallSession.fromMap(Map<String, dynamic> map) {
    final roomId = map['roomId']?.toString().trim() ?? '';
    final channelName = map['channelName']?.toString().trim() ?? '';
    return VoiceCallSession(
      appId: VoiceCallConfig._readAppId(map['appId']),
      token: map['token']?.toString() ?? '',
      roomId: roomId.isNotEmpty ? roomId : channelName,
      channelName: channelName.isNotEmpty ? channelName : roomId,
      userId: map['userId']?.toString() ?? '',
      streamId: map['streamId']?.toString() ?? '',
      threadType: map['threadType']?.toString() ?? 'order',
      threadId: map['threadId']?.toString() ?? '',
      callLogId: map['callLogId']?.toString(),
    );
  }
}

class VoiceCallService {
  static const _basePath = '/db/voice';

  static Future<VoiceCallConfig> fetchConfig() async {
    final data = await ApiClient.instance.get('$_basePath/config');
    if (data is! Map) {
      return const VoiceCallConfig(enabled: false, appId: 0);
    }
    return VoiceCallConfig.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<List<VoiceCallLog>> fetchHistory({
    String? threadType,
    String? threadId,
    int limit = 50,
  }) async {
    final query = <String, String>{
      if (threadType != null && threadType.trim().isNotEmpty)
        'threadType': threadType.trim(),
      if (threadId != null && threadId.trim().isNotEmpty) 'threadId': threadId.trim(),
      'limit': '$limit',
    };
    final data = await ApiClient.instance.get(
      '$_basePath/history',
      queryParameters: query,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => VoiceCallLog.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<VoiceCallSession> fetchToken({
    required String threadType,
    required String threadId,
    String? channelName,
  }) async {
    final data = await ApiClient.instance.post(
      '$_basePath/token',
      body: {
        'threadType': threadType,
        'threadId': threadId,
        if (channelName != null && channelName.trim().isNotEmpty)
          'channelName': channelName.trim(),
      },
    );
    if (data is! Map) {
      throw StateError('تعذّر الحصول على رمز المكالمة.');
    }
    return VoiceCallSession.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<VoiceCallSession> startCall({
    required String threadType,
    required String threadId,
    String? receiverPhone,
    String? callerName,
  }) async {
    final data = await ApiClient.instance.post(
      '$_basePath/call',
      body: {
        'threadType': threadType,
        'threadId': threadId,
        if (receiverPhone != null && receiverPhone.trim().isNotEmpty)
          'receiverPhone': receiverPhone.trim(),
        if (callerName != null && callerName.trim().isNotEmpty)
          'callerName': callerName.trim(),
      },
    );
    if (data is! Map) {
      throw StateError('تعذّر بدء المكالمة.');
    }
    return VoiceCallSession.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<void> completeCall({
    String? callLogId,
    required String threadType,
    required String threadId,
    String? otherPartyPhone,
    required String direction,
    required String status,
    required int durationSeconds,
    String? channelName,
  }) async {
    await ApiClient.instance.post(
      '$_basePath/call/complete',
      body: {
        if (callLogId != null && callLogId.trim().isNotEmpty) 'callLogId': callLogId.trim(),
        'threadType': threadType,
        'threadId': threadId,
        if (otherPartyPhone != null && otherPartyPhone.trim().isNotEmpty)
          'otherPartyPhone': otherPartyPhone.trim(),
        'direction': direction,
        'status': status,
        'durationSeconds': durationSeconds,
        if (channelName != null && channelName.trim().isNotEmpty)
          'channelName': channelName.trim(),
      },
    );
  }
}
