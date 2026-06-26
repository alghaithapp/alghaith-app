import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

import '../../../../widgets/app_image.dart';
import 'status_badge.dart';

/// A card widget that displays merchant information and actions.
class MerchantCard extends StatelessWidget {
  final Map merchant;
  final bool isBusy;
  final String? busyAction;
  final void Function(String action) onAction;
  final VoidCallback? onTap;

  const MerchantCard({
    super.key,
    required this.merchant,
    required this.isBusy,
    this.busyAction,
    required this.onAction,
    this.onTap,
  });

  String _str(String key, [String fallback = '']) =>
      (merchant[key]?.toString() ?? fallback);

  int _int(String key) => (merchant[key] as num?)?.toInt() ?? 0;

  bool _bool(String key) => merchant[key] == true;

  String _serviceLabel(String id) {
    switch (id) {
      case 'restaurant':
        return 'مطعم';
      case 'product':
        return 'متجر';
      case 'real_estate':
        return 'عقار';
      case 'professionals':
        return 'مهني';
      default:
        return id;
    }
  }

  String _formatMoney(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _bool('isApproved');
    final isFrozen = _bool('isFrozen');
    final isBazaar = _bool('isBazaarMember');
    final storeName = _str('storeName', 'بدون اسم');
    final fullName = _str('fullName', '');
    final phone = _str('phone');
    final serviceId = _str('primaryServiceId');
    final isProfessional = _bool('isProfessional') || serviceId == 'professionals';
    final rejectionMsg = _str('rejectionMessageAr');
    final totalProducts = _int('totalProducts');
    final availableProducts = _int('availableProducts');
    final totalOrders = _int('totalOrders');
    final completedOrders = _int('completedOrders');
    final totalRevenue = _int('totalRevenue');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.accent.withValues(alpha: 0.08),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isFrozen
                ? Colors.red.shade100
                : isApproved
                    ? Colors.green.shade100
                    : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isFrozen ? 0.06 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
            if (onTap != null)
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar + Info + Status badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarPreview(
                    imageBase64:
                        merchant['profileImageBase64'] ?? merchant['logoImageBase64']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(storeName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          if (isProfessional)
                            MiniLabel(label: 'مهني', color: Colors.teal),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (fullName.isNotEmpty)
                        Text(fullName,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
                      Text('$phone · ${_serviceLabel(serviceId)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: isApproved
                          ? 'مفعّل'
                          : (merchant['approvalStatus'] == 'rejected'
                              ? 'مرفوض'
                              : 'معلق'),
                      color: isApproved
                          ? Colors.green
                          : (merchant['approvalStatus'] == 'rejected'
                              ? Colors.red
                              : Colors.orange),
                    ),
                    if (isFrozen) ...[
                      const SizedBox(height: 4),
                      StatusBadge(label: 'مجمّد', color: Colors.red),
                    ],
                    if (isBazaar) ...[
                      const SizedBox(height: 4),
                      StatusBadge(label: 'بازار', color: Colors.teal),
                    ],
                  ],
                ),
              ],
            ),

            // Stats row
            if (totalProducts > 0 || totalOrders > 0 || totalRevenue > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                ),
                child: Row(
                  children: [
                    StatItem(
                        label: 'المنتجات',
                        value: '$totalProducts',
                        hint: availableProducts != totalProducts
                            ? '$availableProducts متاح'
                            : null),
                    const StatDivider(),
                    StatItem(label: 'الطلبات', value: '$totalOrders'),
                    const StatDivider(),
                    StatItem(label: 'المكتمل', value: '$completedOrders'),
                    const StatDivider(),
                    StatItem(
                      label: 'الأرباح',
                      value: '${_formatMoney(totalRevenue)} د.ع',
                      isCompact: true,
                    ),
                  ],
                ),
              ),
            ],

            // Rejection reason
            if (merchant['approvalStatus'] == 'rejected' &&
                rejectionMsg.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rejectionMsg,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons row
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isApproved) ...[
                  Expanded(
                      child: _QuickActionBtn(
                    label: 'موافقة',
                    icon: Icons.check,
                    color: Colors.green,
                    onTap: () => onAction('approve'),
                    isLoading: isBusy && busyAction == 'approval',
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _QuickActionBtn(
                    label: 'رفض',
                    icon: Icons.close,
                    color: Colors.red,
                    onTap: () => onAction('reject'),
                  )),
                ] else ...[
                  Expanded(
                      child: _QuickActionBtn(
                    label: isFrozen ? 'فك تجميد' : 'تجميد',
                    icon: isFrozen ? Icons.lock_open : Icons.lock_person,
                    color: Colors.red,
                    onTap: () => onAction('freeze'),
                    isLoading: isBusy && busyAction == 'freeze',
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _QuickActionBtn(
                    label: isBazaar ? 'إزالة بازار' : 'تفعيل بازار',
                    icon: Icons.storefront,
                    color: Colors.teal,
                    onTap: () => onAction('bazaar'),
                    active: isBazaar,
                    isLoading: isBusy && busyAction == 'bazaar',
                  )),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// A small stat item used inside the MerchantCard stats row.
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final bool isCompact;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: isCompact ? 11 : 13,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// A thin vertical divider used between [StatItem] widgets.
class StatDivider extends StatelessWidget {
  const StatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFE0E0E0),
    );
  }
}

/// A small coloured label badge (e.g. "مهني").
class MiniLabel extends StatelessWidget {
  final String label;
  final Color color;

  const MiniLabel({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo')),
    );
  }
}

/// Internal avatar preview widget using [AppImage].
class _AvatarPreview extends StatelessWidget {
  final String? imageBase64;
  const _AvatarPreview({this.imageBase64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AppImage(imageData: imageBase64),
      ),
    );
  }
}

/// Internal quick action button (approve/reject/freeze/bazaar toggle).
class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  final bool isLoading;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.active = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const CupertinoActivityIndicator(radius: 8)
            else
              Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}
