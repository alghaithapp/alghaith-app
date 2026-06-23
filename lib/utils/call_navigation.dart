import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../services/agora_voice_service.dart';
import '../services/voice_call_service.dart';
import '../utils/guest_gate.dart';

/// فتح مكالمة صوتية داخلية عبر Agora.
class CallNavigation {
  CallNavigation._();

  static Future<void> openOutgoing(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    required String receiverPhone,
    String? callerName,
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإجراء مكالمة داخل التطبيق.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final micGranted = await _ensureMicrophonePermission(context);
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
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك للرد على المكالمة.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final micGranted = await _ensureMicrophonePermission(context);
    if (!micGranted || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          threadType: threadType,
          threadId: threadId,
          otherPartyName: otherPartyName,
          channelName: channelName,
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

    final threadType = data['threadType']?.toString() ?? 'order';
    final threadId = data['threadId']?.toString() ?? '';
    if (threadId.isEmpty) return;

    final callerName = data['callerName']?.toString().trim();
    final channelName = data['channelName']?.toString().trim();

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'مكالمة واردة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'مكالمة من ${callerName?.isNotEmpty == true ? callerName! : 'مستخدم'}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رفض', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('رد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (accepted != true || !context.mounted) return;
    await openIncoming(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: callerName?.isNotEmpty == true ? callerName! : 'متصل',
      channelName: channelName,
    );
  }

  static Future<bool> _ensureMicrophonePermission(BuildContext context) async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

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
  }) {
    final phone = merchantPhone.trim();
    return openOutgoing(
      context,
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
      callerName: callerName,
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
  final bool isIncoming;

  const VoiceCallScreen({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.callerName,
    this.channelName,
    this.isIncoming = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final AgoraVoiceService _voice = AgoraVoiceService();
  bool _muted = false;
  bool _speaker = true;
  String _statusText = 'جاري الاتصال...';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _voice.onStateChanged = _onCallStateChanged;
    _voice.onRemoteUserLeft = () {
      if (!mounted) return;
      _endCall(popRoute: true);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCall());
  }

  @override
  void dispose() {
    _voice.onStateChanged = null;
    _voice.onRemoteUserLeft = null;
    unawaited(_voice.leave());
    super.dispose();
  }

  Future<void> _startCall() async {
    try {
      final config = await VoiceCallService.fetchConfig();
      if (!config.enabled || config.appId.isEmpty) {
        throw StateError('خدمة الاتصال الداخلي غير مفعّلة حالياً.');
      }

      final AgoraCallSession session;
      if (widget.isIncoming) {
        session = await VoiceCallService.fetchToken(
          threadType: widget.threadType,
          threadId: widget.threadId,
          channelName: widget.channelName,
        );
      } else {
        final receiver = widget.receiverPhone?.trim() ?? '';
        if (receiver.isEmpty) {
          throw StateError('رقم الطرف الآخر غير متوفر.');
        }
        session = await VoiceCallService.startCall(
          threadType: widget.threadType,
          threadId: widget.threadId,
          receiverPhone: receiver,
          callerName: widget.callerName,
        );
      }

      await _voice.joinVoiceCall(
        appId: session.appId.isNotEmpty ? session.appId : config.appId,
        token: session.token,
        channelName: session.channelName,
        uid: session.uid,
      );
      await _voice.setSpeakerphone(_speaker);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString().replaceFirst('StateError: ', '');
        _statusText = 'تعذّر الاتصال';
      });
    }
  }

  void _onCallStateChanged(AgoraCallState state) {
    if (!mounted) return;
    setState(() {
      switch (state) {
        case AgoraCallState.connecting:
          _statusText = 'جاري الاتصال...';
        case AgoraCallState.ringing:
          _statusText = widget.isIncoming ? 'متصل' : 'يرن...';
        case AgoraCallState.connected:
          _statusText = 'متصل';
        case AgoraCallState.ended:
          _statusText = 'انتهت المكالمة';
        case AgoraCallState.failed:
          _statusText = 'فشل الاتصال';
        case AgoraCallState.idle:
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