import '../core/network/api_client.dart';

class AgoraCallConfig {
  final bool enabled;
  final String appId;

  const AgoraCallConfig({
    required this.enabled,
    required this.appId,
  });

  factory AgoraCallConfig.fromMap(Map<String, dynamic> map) {
    return AgoraCallConfig(
      enabled: map['enabled'] == true,
      appId: map['appId']?.toString() ?? '',
    );
  }
}

class AgoraCallSession {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String threadType;
  final String threadId;

  const AgoraCallSession({
    required this.appId,
    required this.token,
    required this.channelName,
    required this.uid,
    required this.threadType,
    required this.threadId,
  });

  factory AgoraCallSession.fromMap(Map<String, dynamic> map) {
    return AgoraCallSession(
      appId: map['appId']?.toString() ?? '',
      token: map['token']?.toString() ?? '',
      channelName: map['channelName']?.toString() ?? '',
      uid: _readUid(map['uid']),
      threadType: map['threadType']?.toString() ?? 'order',
      threadId: map['threadId']?.toString() ?? '',
    );
  }

  static int _readUid(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class VoiceCallService {
  static Future<AgoraCallConfig> fetchConfig() async {
    final data = await ApiClient.instance.get('/db/agora/config');
    if (data is! Map) {
      return const AgoraCallConfig(enabled: false, appId: '');
    }
    return AgoraCallConfig.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<AgoraCallSession> fetchToken({
    required String threadType,
    required String threadId,
    String? channelName,
  }) async {
    final data = await ApiClient.instance.post(
      '/db/agora/token',
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
    return AgoraCallSession.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<AgoraCallSession> startCall({
    required String threadType,
    required String threadId,
    required String receiverPhone,
    String? callerName,
  }) async {
    final data = await ApiClient.instance.post(
      '/db/agora/call',
      body: {
        'threadType': threadType,
        'threadId': threadId,
        'receiverPhone': receiverPhone.trim(),
        if (callerName != null && callerName.trim().isNotEmpty)
          'callerName': callerName.trim(),
      },
    );
    if (data is! Map) {
      throw StateError('تعذّر بدء المكالمة.');
    }
    return AgoraCallSession.fromMap(Map<String, dynamic>.from(data));
  }
}
