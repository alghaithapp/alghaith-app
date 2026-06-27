import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../core/notifications/push_notification_inbox.dart';
import '../core/theme/app_colors.dart';
import '../services/incoming_call_ringtone.dart';
import '../services/voice_call_service.dart';

/// شاشة مكالمة واردة بملء الشاشة — مشابهة لواتساب.
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String threadType;
  final String threadId;
  final String? channelName;
  final String? callerPhone;
  final String? callLogId;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.threadType,
    required this.threadId,
    this.channelName,
    this.callerPhone,
    this.callLogId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    unawaited(_startRinging());
  }

  Future<void> _startRinging() async {
    await IncomingCallRingtone.instance.start();
    if (!mounted || _resolved) return;
    await PushNotificationInbox.dismissIncomingCallNotification(
      threadId: widget.threadId,
    );
  }

  Future<void> _stopRinging() async {
    await IncomingCallRingtone.instance.stop();
  }

  Future<void> _onAccept() async {
    if (_resolved) return;
    _resolved = true;
    await _stopRinging();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _onDecline() async {
    if (_resolved) return;
    _resolved = true;
    await _stopRinging();
    unawaited(_logMissedCall());
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _logMissedCall() async {
    try {
      await VoiceCallService.rejectCall(
        callLogId: widget.callLogId,
        threadType: widget.threadType,
        threadId: widget.threadId,
        channelName: widget.channelName,
      );
    } catch (_) {
      try {
        await VoiceCallService.completeCall(
          callLogId: widget.callLogId,
          threadType: widget.threadType,
          threadId: widget.threadId,
          otherPartyPhone: widget.callerPhone,
          direction: 'incoming',
          status: 'missed',
          durationSeconds: 0,
          channelName: widget.channelName,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(_stopRinging());
    _pulseController.dispose();
    super.dispose();
  }

  String get _displayName =>
      widget.callerName.trim().isNotEmpty ? widget.callerName.trim() : 'متصل';

  String get _initial {
    final name = _displayName;
    if (name.isEmpty) return '?';
    return name.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_onDecline());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B141A), Color(0xFF1F2C34), Color(0xFF111B21)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: const Text(
                        'الغيث',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white54,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    _PulsingAvatar(
                      controller: _pulseController,
                      initial: _initial,
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      delay: const Duration(milliseconds: 120),
                      duration: const Duration(milliseconds: 500),
                      child: const Text(
                        'مكالمة صوتية واردة...',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      duration: const Duration(milliseconds: 500),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CallChoiceButton(
                            label: 'رفض',
                            icon: Icons.call_end,
                            color: const Color(0xFFE53935),
                            onPressed: _onDecline,
                          ),
                          _CallChoiceButton(
                            label: 'رد',
                            icon: Icons.call,
                            color: const Color(0xFF25D366),
                            onPressed: _onAccept,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingAvatar extends StatelessWidget {
  final AnimationController controller;
  final String initial;

  const _PulsingAvatar({
    required this.controller,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulseRing(controller: controller, delay: 0),
          _PulseRing(controller: controller, delay: 0.35),
          _PulseRing(controller: controller, delay: 0.7),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _PulseRing({
    required this.controller,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value + delay) % 1.0;
        final scale = 0.85 + (t * 0.55);
        final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.45;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: opacity),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CallChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CallChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.45),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
