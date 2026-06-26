import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/app_bottom_nav_style.dart';
import '../../../../providers/app_provider.dart';
import '../../../../widgets/safe_bottom_bar.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_favorite_place.dart';
import '../../models/taxi_saved_place_use.dart';
import '../../models/taxi_request.dart';
import '../../utils/taxi_rating_navigation.dart';
import 'taxi_customer_account_screen.dart';
import 'taxi_customer_tabs.dart';
import 'taxi_request_screen.dart';

/// واجهة خدمة التكسي للزبون — شريط سفلي بدل القائمة الجانبية.
class TaxiCustomerShell extends StatefulWidget {
  const TaxiCustomerShell({super.key});

  @override
  State<TaxiCustomerShell> createState() => _TaxiCustomerShellState();
}

class _TaxiCustomerShellState extends State<TaxiCustomerShell> {
  static const double _bottomNavHeight = 64;

  /// 0 = شاشة طلب الرحلة (الخريطة)، 1–4 = التبويبات السفلية.
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final provider = context.read<TaxiProvider>();
    final phone = context.read<AppProvider>().authPhone;
    provider.startPolling(phone: phone);
    await provider.loadActiveRequest();
    await provider.loadHistory();
    await provider.loadFavoritePlaces();
    await provider.checkPendingRating();
  }

  @override
  void dispose() {
    context.read<TaxiProvider>().stopPolling();
    super.dispose();
  }

  void _openMapTab() {
    setState(() => _currentIndex = 0);
    context.read<TaxiProvider>().loadActiveRequest();
  }

  void _useSavedPlaceForTrip(TaxiFavoritePlace place, TaxiSavedPlaceField field) {
    context.read<TaxiProvider>().setPendingSavedPlace(place, field);
    _openMapTab();
  }

  void _replayTripFromHistory(TaxiRequest request) {
    final provider = context.read<TaxiProvider>();
    final active = provider.currentRequest;
    if (active != null && !active.isCompleted && !active.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لديك طلب نشط حالياً. أكمله أو ألغِه قبل إعادة طلب رحلة سابقة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    if (!request.canReplayTrip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن إعادة هذه الرحلة — بيانات المسار غير متوفرة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    provider.setPendingTripReplay(request);
    _openMapTab();
  }

  void _openBottomTab(int tabIndex) {
    setState(() => _currentIndex = tabIndex + 1);
    context.read<TaxiProvider>().loadActiveRequest();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _TaxiRatingPrompt(
        child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            TaxiRequestScreen(
              onOpenCurrentOrderTab: () => _openBottomTab(0),
              bottomNavInset: _bottomNavHeight,
            ),
            _TaxiTabPage(
              title: 'طلبي الحالي',
              onBackToMap: _openMapTab,
              child: const TaxiCurrentRequestTab(),
            ),
            _TaxiTabPage(
              title: 'سجل الطلبات',
              onBackToMap: _openMapTab,
              child: TaxiHistoryTab(onReplayTrip: _replayTripFromHistory),
            ),
            _TaxiTabPage(
              title: 'تواصل معنا',
              onBackToMap: _openMapTab,
              child: const TaxiSupportTab(),
            ),
            _TaxiTabPage(
              title: 'حسابي',
              onBackToMap: _openMapTab,
              child: TaxiCustomerAccountScreen(
                onUseSavedPlace: _useSavedPlaceForTrip,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeBottomBar(
          color: Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          child: SizedBox(
            height: _bottomNavHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, CupertinoIcons.car_detailed, 'طلبي الحالي'),
                  _buildNavItem(1, CupertinoIcons.time, 'سجل الطلبات'),
                  _buildNavItem(2, CupertinoIcons.headphones, 'تواصل معنا'),
                  _buildNavItem(3, CupertinoIcons.person_fill, 'حسابي'),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int tabIndex, IconData icon, String label) {
    final shellIndex = tabIndex + 1;
    final isActive = _currentIndex == shellIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _openBottomTab(tabIndex),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? AppBottomNavStyle.activeColor
                  : CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxiTabPage extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onBackToMap;

  const _TaxiTabPage({
    required this.title,
    required this.child,
    required this.onBackToMap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBackToMap,
          icon: const Icon(Icons.map_outlined, color: AppColors.primary),
          tooltip: 'طلب رحلة',
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: child,
    );
  }
}

class _TaxiRatingPrompt extends StatefulWidget {
  final Widget child;

  const _TaxiRatingPrompt({required this.child});

  @override
  State<_TaxiRatingPrompt> createState() => _TaxiRatingPromptState();
}

class _TaxiRatingPromptState extends State<_TaxiRatingPrompt> {
  String? _lastPromptedId;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxiProvider>(
      builder: (context, provider, child) {
        final pending = provider.tripAwaitingRating;
        if (pending != null && pending.id != _lastPromptedId) {
          _lastPromptedId = pending.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            TaxiRatingNavigation.openIfNeeded(context, pending).then((_) {
              if (mounted) {
                setState(() => _lastPromptedId = null);
              }
            });
          });
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
