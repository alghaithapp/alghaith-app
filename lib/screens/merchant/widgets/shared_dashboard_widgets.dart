import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_models.dart';
import '../../../models/app_notification.dart';
import '../../../services/image_storage_service.dart';
import '../../../utils/extensions.dart';
import '../../../widgets/app_image.dart';
import '../order_details_screen.dart';

const _brand = Color(0xFFF5A01D);

// ──────────────────────────────────────────────
// Cover image helpers (extracted from HeroCards)
// ──────────────────────────────────────────────

DecorationImage? merchantCoverDecoration(String coverImage) {
  final cover = ImageStorageService.normalizeImageRef(coverImage)?.trim();
  if (cover == null || cover.isEmpty) return null;
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
  final base64 = extractBase64Payload(cover);
  if (base64 != null) {
    try {
      return DecorationImage(
        image: MemoryImage(base64Decode(base64)),
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

String? extractBase64Payload(String value) {
  var payload = value.trim();
  if (payload.isEmpty) return null;
  if (payload.contains('base64,')) {
    payload = payload.split('base64,').last.trim();
  }
  if (payload.startsWith('data:image/')) {
    final commaIndex = payload.indexOf(',');
    if (commaIndex != -1) {
      payload = payload.substring(commaIndex + 1).trim();
    }
  }
  if (!ImageStorageService.isBase64Image(payload)) return null;
  return payload;
}

Widget buildMerchantCoverImage(String coverImage) {
  final cover = ImageStorageService.normalizeImageRef(coverImage)?.trim();
  if (cover == null || cover.isEmpty) return const SizedBox.shrink();
  if (ImageStorageService.isRemoteUrl(cover)) {
    return Image.network(
      cover,
      fit: BoxFit.cover,
      color: Colors.black.withValues(alpha: 0.55),
      colorBlendMode: BlendMode.darken,
    );
  }
  final base64 = extractBase64Payload(cover);
  if (base64 != null) {
    try {
      return Image.memory(
        base64Decode(base64),
        fit: BoxFit.cover,
        color: Colors.black.withValues(alpha: 0.55),
        colorBlendMode: BlendMode.darken,
      );
    } catch (error) {
      debugPrint('MERCHANT_COVER_DECODE_ERROR: $error');
      return const SizedBox.shrink();
    }
  }
  return const SizedBox.shrink();
}

// ──────────────────────────────────────────────
// MerchantStoreAvatar
// ──────────────────────────────────────────────

class MerchantStoreAvatar extends StatelessWidget {
  final String? imageData;

  const MerchantStoreAvatar({required this.imageData});

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

// ──────────────────────────────────────────────
// MerchantStoreStatusSwitch
// ──────────────────────────────────────────────

class MerchantStoreStatusSwitch extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final bool isProfessional;

  const MerchantStoreStatusSwitch({
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
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
      ),
    );
  }
}

// ──────────────────────────────────────────────
// MerchantHeroMiniStat
// ──────────────────────────────────────────────

class MerchantHeroMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const MerchantHeroMiniStat({
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

// ──────────────────────────────────────────────
// MerchantProfilePillButton
// ──────────────────────────────────────────────

class MerchantProfilePillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const MerchantProfilePillButton({
    required this.label,
    required this.onTap,
  });

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.badge_rounded, color: _brand, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
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

// ──────────────────────────────────────────────
// MerchantSectionHeader
// ──────────────────────────────────────────────

class MerchantSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MerchantSectionHeader({
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

// ──────────────────────────────────────────────
// MerchantStatCard
// ──────────────────────────────────────────────

class MerchantStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const MerchantStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Status badge helpers
// ──────────────────────────────────────────────

class MerchantStatusBadgeData {
  final String label;
  final Color color;

  const MerchantStatusBadgeData(this.label, this.color);
}

MerchantStatusBadgeData merchantOrderStatusBadge(ActiveOrder order) {
  if (order.statusAr.trim().isNotEmpty &&
      order.statusKey != 'pending' &&
      order.statusKey != 'accepted') {
    final color = switch (order.statusKey) {
      'completed' => Colors.green,
      'cancelled' || 'rejected' => Colors.red,
      _ => AppColors.accent,
    };
    return MerchantStatusBadgeData(order.statusAr, color);
  }
  return switch (order.statusKey) {
    'pending' => const MerchantStatusBadgeData('جديد', Colors.blue),
    'accepted' => const MerchantStatusBadgeData('قيد التحضير', AppColors.accent),
    'preparing' => const MerchantStatusBadgeData('قيد التحضير', AppColors.accent),
    'completed' => const MerchantStatusBadgeData('مكتمل', Colors.green),
    'cancelled' || 'rejected' => const MerchantStatusBadgeData('ملغي', Colors.red),
    _ => MerchantStatusBadgeData(order.statusAr, Colors.grey),
  };
}

// ──────────────────────────────────────────────
// MerchantOrdersEmptyCard
// ──────────────────────────────────────────────

class MerchantOrdersEmptyCard extends StatelessWidget {
  const MerchantOrdersEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 56,
            color: _brand.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// MerchantOrdersListCard / MerchantOrderRow
// ──────────────────────────────────────────────

class MerchantOrdersListCard extends StatelessWidget {
  final List<ActiveOrder> orders;
  final String Function(ActiveOrder) displayOrderNumber;

  const MerchantOrdersListCard({
    required this.orders,
    required this.displayOrderNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16,
              ),
            MerchantOrderRow(
              order: orders[i],
              orderNumber: displayOrderNumber(orders[i]),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: orders[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MerchantOrderRow extends StatelessWidget {
  final ActiveOrder order;
  final String orderNumber;
  final VoidCallback onTap;

  const MerchantOrderRow({
    required this.order,
    required this.orderNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = merchantOrderStatusBadge(order);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerNameAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${order.itemsCount} منتج · ${order.dateAr}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.price.toPrice()} د.ع',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      color: _brand,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badge.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// MerchantAlertsCard / MerchantAlertRow
// ──────────────────────────────────────────────

class MerchantAlertsCard extends StatelessWidget {
  final List<AppNotificationItem> alerts;

  const MerchantAlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          'لا توجد تنبيهات جديدة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16,
              ),
            MerchantAlertRow(
              title: alerts[i].title,
              body: alerts[i].body,
              index: i,
              unread: !alerts[i].read,
            ),
          ],
        ],
      ),
    );
  }
}

class MerchantAlertRow extends StatelessWidget {
  final String title;
  final String body;
  final int index;
  final bool unread;

  const MerchantAlertRow({
    required this.title,
    required this.body,
    required this.index,
    this.unread = false,
  });

  static const _iconColors = [
    AppColors.accent,
    Colors.green,
    Colors.purple,
  ];

  static const _icons = [
    Icons.shopping_bag_rounded,
    Icons.store_rounded,
    Icons.local_offer_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _iconColors[index % _iconColors.length];
    final icon = _icons[index % _icons.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MerchantPurchaseFlowUnavailable extends StatelessWidget {
  final String title;
  final String message;

  const MerchantPurchaseFlowUnavailable({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFFF2F2F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 52,
                  color: AppColors.primary.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xFF636366),
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
