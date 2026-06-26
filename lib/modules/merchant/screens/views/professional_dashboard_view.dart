import 'package:flutter/material.dart';

import '../../../../providers/app_provider.dart';
import '../../../../models/app_notification.dart';
import '../merchant_notifications_screen.dart';
import '../merchant_profile_screen.dart';
import '../widgets/shared_dashboard_widgets.dart';

const _brand = Color(0xFFF5A01D);

class ProfessionalDashboardView extends StatelessWidget {
  final AppProvider provider;
  final String storeName;
  final String description;
  final String address;
  final String ratingLabel;
  final List<AppNotificationItem> alerts;

  const ProfessionalDashboardView({
    super.key,
    required this.provider,
    required this.storeName,
    required this.description,
    required this.address,
    required this.ratingLabel,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    final labels = provider.merchantActiveLabels;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _ProfessionalHeroCard(
              storeName: storeName,
              description: description,
              address: address,
              isOpen: provider.isMerchantStoreOpen,
              onToggleOpen: provider.toggleMerchantOpenStatus,
              profileImage: provider.merchantProfileImageBase64,
              coverImage: provider.merchantCoverImage,
              productsCount: provider.merchantProductCount,
              ratingLabel: ratingLabel,
              itemLabel: labels.itemPluralAr,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: MerchantProfilePillButton(
              label: 'عرض الملف الكامل',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MerchantProfileScreen(),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: MerchantSectionHeader(
              title: 'التنبيهات المهمة',
              icon: Icons.notifications_rounded,
              actionLabel: 'عرض الكل',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MerchantNotificationsScreen(),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _AlertsCard(alerts: alerts),
          ),
        ),
      ],
    );
  }
}

class _ProfessionalHeroCard extends StatelessWidget {
  final String storeName;
  final String description;
  final String address;
  final bool isOpen;
  final VoidCallback onToggleOpen;
  final String? profileImage;
  final String coverImage;
  final int productsCount;
  final String ratingLabel;
  final String itemLabel;

  const _ProfessionalHeroCard({
    required this.storeName,
    required this.description,
    required this.address,
    required this.isOpen,
    required this.onToggleOpen,
    required this.profileImage,
    required this.coverImage,
    required this.productsCount,
    required this.ratingLabel,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0A0A), Color(0xFF1F1F1F), Color(0xFF2A1515)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        image: merchantCoverDecoration(coverImage),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MerchantStoreAvatar(imageData: profileImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.45,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              height: 1.4,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MerchantStoreStatusSwitch(
                      isOpen: isOpen,
                      onToggle: onToggleOpen,
                      isProfessional: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MerchantHeroMiniStat(
                  label: itemLabel,
                  value: '$productsCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MerchantHeroMiniStat(
                  label: 'التقييم',
                  value: ratingLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _AlertsCard extends StatelessWidget {
  final List<AppNotificationItem> alerts;

  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Colors.grey.shade300,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد تنبيهات جديدة حالياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: alerts.map((n) {
          final isLast = alerts.indexOf(n) == alerts.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  n.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1D2939),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    n.body,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF2F4F7),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
