import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../providers/app_provider.dart';
import '../../../models/app_notification.dart';
import '../../../services/image_storage_service.dart';
import '../../../widgets/app_image.dart';
import '../merchant_notifications_screen.dart';
import '../merchant_profile_screen.dart';

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
            child: _ProfilePillButton(
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
            child: _SectionHeader(
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

  DecorationImage? _coverDecoration() {
    final cover = coverImage.trim();
    if (cover.isEmpty) return null;
    if (ImageStorageService.isRemoteUrl(cover)) {
      return DecorationImage(
        image: NetworkImage(cover),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.55),
          BlendMode.darken,
        ),
      );
    }
    if (cover.startsWith('iVBOR') || cover.startsWith('/9j/')) {
      try {
        return DecorationImage(
          image: MemoryImage(base64Decode(cover)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.darken,
          ),
        );
      } catch (error) {
        debugPrint('MERCHANT_COVER_DECODE_ERROR: $error');
        return null;
      }
    }
    return null;
  }

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
        image: _coverDecoration(),
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
              _StoreAvatar(imageData: profileImage),
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
                    _StoreStatusSwitch(
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
                child: _HeroMiniStat(
                  label: itemLabel,
                  value: '$productsCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMiniStat(
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

class _StoreAvatar extends StatelessWidget {
  final String? imageData;

  const _StoreAvatar({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _brand.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: AppImage(
          imageData: imageData,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _StoreStatusSwitch extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final bool isProfessional;

  const _StoreStatusSwitch({
    required this.isOpen,
    required this.onToggle,
    this.isProfessional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isOpen ? Colors.green : Colors.red).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isOpen ? Colors.greenAccent : Colors.redAccent)
                  .withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOpen ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isProfessional
                    ? (isOpen ? 'متاح للعمل' : 'غير متاح للعمل')
                    : (isOpen ? 'مفتوح الآن' : 'مغلق'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfilePillButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfilePillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_rounded, color: _brand, size: 20),
              SizedBox(width: 8),
              Text(
                'عرض الملف الكامل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _brand, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: _brand,
                fontSize: 13,
              ),
            ),
          ),
      ],
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
