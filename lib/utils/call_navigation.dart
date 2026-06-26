import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../screens/incoming_call_screen.dart';
import '../services/incoming_call_ringtone.dart';
import '../services/voice_call_service.dart';
import '../services/zego_voice_service.dart';
import '../utils/guest_gate.dart';
import '../utils/merchant_profile_fields.dart';

/// فتح مكالمة صوتية داخلية عبر ZEGOCLOUD.
class CallNavigation {
  CallNavigation._();

  static bool _incomingCallVisible = false;

  static Future<void> openOutgoing(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    String? receiverPhone,
    String? callerName,
    Map<String, dynamic>? merchantProfile,
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإجراء مكالمة داخل التطبيق.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final blocked =
        MerchantProfileFields.callsUnavailableMessageAr(merchantProfile);
    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final micGranted = await _ensureCallPermissions(context);
    if (!micGranted || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          threadType: threadType,
          threadId: threadId,
          otherPartyName: otherPartyName,
          receiverPhone: receiverPhone,
          callerName: callerName,
          isIncoming: false,
        ),
      ),
    );
  }

  static Future<void> openIncoming(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    String? channelName,
    String? otherPartyPhone,
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك للرد على المكالمة.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final micGranted = await _ensureCallPermissions(context);
    if (!micGranted || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          threadType: threadType,
          threadId: threadId,
          otherPartyName: otherPartyName,
          channelName: channelName,
          otherPartyPhone: otherPartyPhone,
          isIncoming: true,
        ),
      ),
    );
  }

  static Future<void> handlePushData(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final eventKey = data['eventKey']?.toString() ?? '';
    if (eventKey != 'call:incoming') return;
    if (_incomingCallVisible) return;

    final threadType = data['threadType']?.toString() ?? 'order';
    final threadId = data['threadId']?.toString() ?? '';
    if (threadId.isEmpty) return;

    final callerName = data['callerName']?.toString().trim();
    final channelName = data['channelName']?.toString().trim();
    final callerPhone = data['callerPhone']?.toString().trim();

    _incomingCallVisible = true;
    bool accepted = false;
    try {
      await IncomingCallRingtone.instance.start();
      final result = await Navigator.of(context, rootNavigator: true).push<bool>(
        PageRouteBuilder<bool>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (_, __, ___) => IncomingCallScreen(
            callerName: callerName?.isNotEmpty == true ? callerName! : 'متصل',
            threadType: threadType,
            threadId: threadId,
            channelName: channelName,
            callerPhone: callerPhone,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      accepted = result == true;
    } finally {
      _incomingCallVisible = false;
      await IncomingCallRingtone.instance.stop();
    }

    if (!accepted || !context.mounted) return;
    await openIncoming(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: callerName?.isNotEmpty == true ? callerName! : 'متصل',
      channelName: channelName,
      otherPartyPhone: callerPhone,
    );
  }

  static Future<bool> _ensureCallPermissions(BuildContext context) async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }
    if (!micStatus.isGranted) {
      if (!context.mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'إذن الميكروفون',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'يلزم السماح بالوصول إلى الميكروفون لإجراء المكالمات داخل التطبيق.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
      return false;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final btStatus = await Permission.bluetoothConnect.status;
      if (!btStatus.isGranted && !btStatus.isLimited) {
        await Permission.bluetoothConnect.request();
      }
    }

    return true;
  }

  static Future<void> openOrderCall(
    BuildContext context, {
    required String orderId,
    required String otherPartyName,
    required String receiverPhone,
    String? callerName,
  }) {
    return openOutgoing(
      context,
      threadType: 'order',
      threadId: orderId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      callerName: callerName,
    );
  }

  static Future<void> openTaxiCall(
    BuildContext context, {
    required String requestId,
    required String otherPartyName,
    required String receiverPhone,
    String? callerName,
  }) {
    return openOutgoing(
      context,
      threadType: 'taxi',
      threadId: requestId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      callerName: callerName,
    );
  }

  static Future<void> openStoreCall(
    BuildContext context, {
    required String merchantPhone,
    required String storeName,
    String? callerName,
    Map<String, dynamic>? merchantProfile,
  }) {
    final phone = merchantPhone.trim();
    return openOutgoing(
      context,
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
      callerName: callerName,
      merchantProfile: merchantProfile,
    );
  }
}

class VoiceCallScreen extends StatefulWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;
  final String? callerName;
  final String? channelName;
  final String? otherPartyPhone;
  final bool isIncoming;

  const VoiceCallScreen({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.callerName,
    this.channelName,
    this.otherPartyPhone,
    this.isIncoming = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final ZegoVoiceService _voice = ZegoVoiceService.instance;
  bool _muted = false;
  bool _speaker = true;
  String _statusText = 'جاري الاتصال...';
  String? _errorText;
  String? _callLogId;
  String? _channelName;
  DateTime? _startedAt;
  DateTime? _connectedAt;
  bool _logFinalized = false;
  bool _wasConnected = false;
  bool _disposing = false;
  Future<void>? _startCallFuture;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _voice.onStateChanged = _onCallStateChanged;
    _voice.onRemoteUserLeft = () {
      if (!mounted || _disposing) return;
      if (!_wasConnected) return;
      _endCall(popRoute: true);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCallFuture = _startCall();
    });
  }

  @override
  void dispose() {
    _disposing = true;
    _voice.onStateChanged = null;
    _voice.onRemoteUserLeft = null;
    unawaited(_disposeCallSafely());
    super.dispose();
  }

  Future<void> _disposeCallSafely() async {
    final pendingStart = _startCallFuture;
    if (pendingStart != null) {
      try {
        await pendingStart;
      } catch (_) {}
    }
    await _cleanupCall();
  }

  Future<void> _cleanupCall() async {
    await IncomingCallRingtone.instance.stop();
    await _finalizeCallLog(status: _errorText != null ? 'failed' : 'ended');
    await _voice.leave();
  }

  Future<void> _startCall() async {
    try {
      final config = await VoiceCallService.fetchConfig();
      if (!mounted || _disposing) return;
      if (!config.enabled || config.appId <= 0) {
        throw StateError('خدمة الاتصال الداخلي غير مفعّلة حالياً.');
      }

      final VoiceCallSession session;
      if (widget.isIncoming) {
        session = await VoiceCallService.fetchToken(
          threadType: widget.threadType,
          threadId: widget.threadId,
          channelName: widget.channelName,
        );
      } else {
        final receiver = widget.receiverPhone?.trim() ?? '';
        if (receiver.isEmpty && widget.threadType != 'taxi') {
          throw StateError('رقم الطرف الآخر غير متوفر.');
        }
        session = await VoiceCallService.startCall(
          threadType: widget.threadType,
          threadId: widget.threadId,
          receiverPhone: receiver.isNotEmpty ? receiver : null,
          callerName: widget.callerName,
        );
        _callLogId = session.callLogId;
      }

      if (!mounted || _disposing) return;
      _channelName = session.channelName;

      // إيقاف الرنين قبل تفعيل ZEGO لتجنب تعارض جلسة الصوت على أندرويد.
      await IncomingCallRingtone.instance.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await _voice.joinVoiceCall(
        appId: session.appId > 0 ? session.appId : config.appId,
        token: session.token,
        roomId: session.roomId,
        userId: session.userId,
        streamId: session.streamId,
      );
      if (!mounted || _disposing) return;
      await _voice.setSpeakerphone(_speaker);
    } catch (error, stack) {
      debugPrint('VOICE_CALL_START_ERROR: $error\n$stack');
      if (!mounted || _disposing) return;
      setState(() {
        _errorText = _friendlyCallError(error);
        _statusText = 'تعذّر الاتصال';
      });
      unawaited(_finalizeCallLog(status: 'failed'));
    }
  }

  String _friendlyCallError(Object error) {
    final raw = error.toString().replaceFirst('StateError: ', '');
    if (raw.contains('not configured') || raw.contains('غير مفعّل')) {
      return 'خدمة الاتصال الداخلي غير مفعّلة حالياً.';
    }
    if (raw.contains('401') || raw.contains('authorization')) {
      return 'انتهت جلسة الدخول. أعد تسجيل الدخول.';
    }
    return raw.length > 120 ? 'تعذّر بدء المكالمة. حاول مجدداً.' : raw;
  }

  Future<void> _finalizeCallLog({required String status}) async {
    if (_logFinalized) return;
    _logFinalized = true;

    final started = _startedAt ?? DateTime.now();
    final duration = _connectedAt != null
        ? DateTime.now().difference(_connectedAt!).inSeconds
        : 0;
    final normalizedStatus =
        duration > 0 || status == 'ended' ? 'ended' : status;

    try {
      await VoiceCallService.completeCall(
        callLogId: _callLogId,
        threadType: widget.threadType,
        threadId: widget.threadId,
        otherPartyPhone: widget.isIncoming
            ? widget.otherPartyPhone
            : widget.receiverPhone,
        direction: widget.isIncoming ? 'incoming' : 'outgoing',
        status: normalizedStatus,
        durationSeconds: duration,
        channelName: _channelName,
      );
    } catch (_) {}
  }

  void _onCallStateChanged(ZegoCallState state) {
    if (!mounted || _disposing) return;
    switch (state) {
      case ZegoCallState.ringing:
        // لا نشغّل رنين audioplayers أثناء جلسة ZEGO — يسبب تعارض صوت/خروج التطبيق.
        break;
      case ZegoCallState.connected:
      case ZegoCallState.ended:
      case ZegoCallState.failed:
      case ZegoCallState.idle:
        unawaited(IncomingCallRingtone.instance.stop());
        break;
      case ZegoCallState.connecting:
        break;
    }
    if (!mounted || _disposing) return;
    setState(() {
      switch (state) {
        case ZegoCallState.connecting:
          _statusText = 'جاري الاتصال...';
        case ZegoCallState.ringing:
          _statusText = widget.isIncoming ? 'متصل' : 'يرن...';
        case ZegoCallState.connected:
          _wasConnected = true;
          _connectedAt ??= DateTime.now();
          _statusText = 'متصل';
        case ZegoCallState.ended:
          _statusText = 'انتهت المكالمة';
        case ZegoCallState.failed:
          _statusText = 'فشل الاتصال';
        case ZegoCallState.idle:
          break;
      }
    });
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _voice.setMuted(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speaker;
    await _voice.setSpeakerphone(next);
    if (!mounted) return;
    setState(() => _speaker = next);
  }

  Future<void> _endCall({bool popRoute = false}) async {
    await _finalizeCallLog(status: 'ended');
    await _voice.leave();
    if (!mounted) return;
    if (popRoute) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            'مكالمة داخلية',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.otherPartyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorText ?? _statusText,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    color: _errorText != null ? Colors.redAccent : Colors.white70,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionButton(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      label: _muted ? 'إلغاء كتم' : 'كتم',
                      onPressed: _toggleMute,
                    ),
                    _CallActionButton(
                      icon: _speaker ? Icons.volume_up : Icons.hearing,
                      label: _speaker ? 'سماعة' : 'أذن',
                      onPressed: _toggleSpeaker,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _endCall(popRoute: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.call_end),
                    label: const Text(
                      'إنهاء المكالمة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            iconSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}