import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notifications/notification_hub.dart';
import '../providers/app_provider.dart';
import '../widgets/in_app_notification_banner.dart';

/// استطلاع دوري + بانرات للمندوب أو السائق.
class RoleNotificationPoller extends StatefulWidget {
  const RoleNotificationPoller({
    super.key,
    required this.child,
    required this.role,
    required this.onRefresh,
    required this.pollBanners,
    this.interval = const Duration(seconds: 20),
  });

  final Widget child;
  final String role;
  final Future<void> Function(AppProvider provider) onRefresh;
  final List<RoleBannerData> Function(AppProvider provider) pollBanners;
  final Duration interval;

  @override
  State<RoleNotificationPoller> createState() => _RoleNotificationPollerState();
}

class _RoleNotificationPollerState extends State<RoleNotificationPoller> {
  Timer? _timer;
  final List<RoleBannerData> _pending = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _poll();
    });
    _timer = Timer.periodic(widget.interval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await widget.onRefresh(provider);
    if (!mounted) return;
    if (provider.inAppAlertsEnabled) {
      _pending.addAll(widget.pollBanners(provider));
      await _showNextBanner();
    } else {
      _pending.clear();
    }
  }

  Future<void> _showNextBanner() async {
    if (!mounted || _pending.isEmpty) return;
    if (!context.read<AppProvider>().inAppAlertsEnabled) {
      _pending.clear();
      return;
    }
    final data = _pending.removeAt(0);
    final tapped = await showInAppNotificationBanner(
      context: context,
      title: data.title,
      body: data.body,
      accentColor: _accentFor(data.colorHint),
      icon: Icons.notifications_active_rounded,
    );
    if (!mounted) return;
    if (tapped && data.orderNumber != null) {
      context.read<AppProvider>().markNotificationsReadForOrder(
            data.orderNumber!,
            widget.role,
          );
    }
    if (_pending.isNotEmpty && mounted) {
      await _showNextBanner();
    }
  }

  Color _accentFor(ColorHint hint) {
    switch (hint) {
      case ColorHint.success:
        return const Color(0xFF2E7D32);
      case ColorHint.warning:
        return const Color(0xFFF57C00);
      case ColorHint.error:
        return const Color(0xFFC62828);
      case ColorHint.promo:
        return const Color(0xFF6A1B9A);
      case ColorHint.info:
        return const Color(0xFF007A7A);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
