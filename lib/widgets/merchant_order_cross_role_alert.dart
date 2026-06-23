import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/account_role_switch.dart';
import 'in_app_notification_banner.dart';

/// يراقب طلبات حساب التاجر حتى عندما يكون المستخدم في واجهة أخرى
/// (مثل واجهة الزبون)، ويعرض بانراً قابلاً للنقر ينقله لواجهة التاجر
/// عند وصول طلب جديد.
class MerchantOrderCrossRoleAlert extends StatefulWidget {
  const MerchantOrderCrossRoleAlert({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 10),
  });

  final Widget child;
  final Duration interval;

  @override
  State<MerchantOrderCrossRoleAlert> createState() =>
      _MerchantOrderCrossRoleAlertState();
}

class _MerchantOrderCrossRoleAlertState
    extends State<MerchantOrderCrossRoleAlert> {
  Timer? _timer;
  // معرّفات الطلبات المعلّقة التي رأيناها سابقاً (لاكتشاف الجديد فقط).
  Set<String> _knownPendingIds = {};
  bool _baselineReady = false;
  bool _showingBanner = false;
  bool _switching = false;

  bool _isEligible(AppProvider provider) {
    return provider.canUseMerchantAccount && provider.userRole != 'merchant';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _timer = Timer.periodic(widget.interval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted || _switching) return;
    final provider = context.read<AppProvider>();
    if (!_isEligible(provider)) {
      // أعد ضبط الأساس حتى لا ننبّه فجأة عند العودة لواجهة الزبون.
      _baselineReady = false;
      _knownPendingIds = {};
      return;
    }

    await provider.refreshMerchantIncomingOrders();
    if (!mounted) return;

    final pendingIds = provider.merchantIncomingOrders
        .where((order) => order.statusKey == 'pending')
        .map((order) => order.id)
        .toSet();

    if (!_baselineReady) {
      _knownPendingIds = pendingIds;
      _baselineReady = true;
      return;
    }

    final newIds = pendingIds.difference(_knownPendingIds);
    _knownPendingIds = pendingIds;

    if (newIds.isEmpty) return;
    if (!provider.inAppAlertsEnabled) return;

    await _showBanner(newIds.length);
  }

  Future<void> _showBanner(int newCount) async {
    if (_showingBanner || !mounted) return;
    _showingBanner = true;

    final body = newCount > 1
        ? 'وصلك $newCount طلبات جديدة على متجرك — اضغط للانتقال'
        : 'وصلك طلب جديد على متجرك — اضغط للانتقال';

    final tapped = await showInAppNotificationBanner(
      context: context,
      title: 'طلب جديد في حساب التاجر',
      body: body,
      accentColor: const Color(0xFFFF6B00),
      icon: Icons.storefront_rounded,
      autoHide: const Duration(seconds: 6),
    );

    _showingBanner = false;
    if (!mounted || !tapped) return;
    await _switchToMerchant();
  }

  Future<void> _switchToMerchant() async {
    if (_switching || !mounted) return;
    final provider = context.read<AppProvider>();
    if (!_isEligible(provider)) return;
    _switching = true;
    try {
      await switchAccountRoleWithLoading(
        context,
        provider,
        'merchant',
        loadingMessage: 'جارٍ فتح حساب التاجر...',
        errorMessage: 'تعذّر فتح حساب التاجر، حاول مرة أخرى',
      );
    } finally {
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
