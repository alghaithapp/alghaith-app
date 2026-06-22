import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/account_ui.dart';
import '../../providers/app_provider.dart';
import '../../utils/courier_profile_fields.dart';
import '../../utils/account_role_switch.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/account/account_page_header.dart';
import '../../screens/notifications_screen.dart';
import 'delivery_earnings_screen.dart';
import '../shared/operator_setup_screen.dart';
import 'delivery_shared_widgets.dart';

class DeliveryAccountScreen extends StatelessWidget {
  const DeliveryAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final profile = appProvider.courierProfile ?? const {};
    final isAvailable = appProvider.isCourierAvailable;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            AccountPageHeader(
              notificationCount: appProvider.unreadNotificationCount,
              title: 'حساب المندوب',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AccountUi.cardDecoration(radius: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CourierProfileFields.profileImage(profile)
                                    .isNotEmpty
                                ? AppImage(
                                    imageData:
                                        CourierProfileFields.profileImage(profile),
                                    fit: BoxFit.cover,
                                  )
                                : Icon(Icons.motorcycle,
                                    size: 38, color: Colors.orange.shade700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appProvider.deliveryCourierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'توصيل طلبات المطاعم والتسوق',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DeliveryEditProfileButton(
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const OperatorSetupScreen(role: 'delivery'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Availability toggle
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: isAvailable,
                          onChanged: (val) async {
                            try {
                              await appProvider.setCourierAvailability(val);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'حدث خطأ: ${e.toString()}',
                                      style: const TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.green,
                          inactiveTrackColor: Colors.red.shade100,
                          tileColor: Colors.white,
                          title: Text(
                            'حالة التوفر',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            isAvailable
                                ? 'متاح لاستلام الطلبات الآن'
                                : 'غير متاح لاستلام طلبات جديدة',
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DeliverySectionTitle(title: 'النشاط والإحصائيات'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DeliveryStatCard(
                          label: 'الجديدة',
                          value: '${appProvider.deliveryIncomingOrders.length}',
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DeliveryStatCard(
                          label: 'نشطة',
                          value: '${appProvider.deliveryActiveOrders.length}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DeliveryStatCard(
                          label: 'المكتملة',
                          value:
                              '${appProvider.deliveryCompletedOrders.length}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DeliveryNavigationCard(
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF007A7A),
                    title: 'شاشة الأرباح',
                    subtitle: 'عرض تفاصيل الأرباح اليومية والأسبوعية',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const DeliveryEarningsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  DeliveryNavigationCard(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFFE040FB),
                    title: 'تبديل الحساب (الدور)',
                    subtitle: 'الانتقال إلى واجهة الزبون أو التاجر أو المندوب',
                    onTap: () => showRoleSwitcher(context, appProvider),
                  ),
                  const SizedBox(height: 24),
                  DeliverySectionTitle(title: 'بيانات السكن والوثائق'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        DeliveryInfoTile(
                          label: 'عنوان السكن',
                          value: CourierProfileFields.homeAddress(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.homeAddress(profile)
                              : '—',
                        ),
                        DeliveryInfoTile(
                          label: 'اسم المختار',
                          value: CourierProfileFields.mukhtarName(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.mukhtarName(profile)
                              : '—',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DeliverySectionTitle(title: 'صور الوثائق والدراجة'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (CourierProfileFields.vehicleImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.vehicleImage(profile),
                              'الدراجة'),
                        if (CourierProfileFields.residenceCardImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.residenceCardImage(profile),
                              'بطاقة السكن'),
                        if (CourierProfileFields.idFrontImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.idFrontImage(profile),
                              'الموحدة (1)'),
                        if (CourierProfileFields.idBackImage(profile)
                            .isNotEmpty)
                          _docPreview(CourierProfileFields.idBackImage(profile),
                              'الموحدة (2)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  DeliveryLogoutCard(onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          'تأكيد الخروج',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                        content: const Text(
                          'هل تريد تسجيل الخروج من حساب المندوب؟',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              appProvider.resetAll();
                            },
                            child: const Text(
                              'تسجيل الخروج',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docPreview(String ref, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppImage(
              imageData: ref,
              width: 100,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class DeliveryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DeliveryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: AccountUi.cardDecoration(radius: 20),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryEditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const DeliveryEditProfileButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: AccountUi.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.pencil, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryNavigationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const DeliveryNavigationCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: AccountUi.cardDecoration(radius: 22),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryLogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const DeliveryLogoutCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.power,
                  color: CupertinoColors.systemRed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const DeliveryInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: CupertinoColors.systemGrey6.withValues(alpha: 0.9),
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
