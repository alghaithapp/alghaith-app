import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

/// A pill-shaped chip for displaying service type selection.
class DrvTypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DrvTypePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

/// A card for controlling which services (taxi/delivery) are enabled.
class DrvServiceCard extends StatelessWidget {
  final bool taxiEnabled;
  final bool deliveryEnabled;
  final ValueChanged<bool> onTaxiChanged;
  final ValueChanged<bool> onDeliveryChanged;

  const DrvServiceCard({
    super.key,
    required this.taxiEnabled,
    required this.deliveryEnabled,
    required this.onTaxiChanged,
    required this.onDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bothEnabled = taxiEnabled && deliveryEnabled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الخدمات المفعلة',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك تشغيل التكسي أو التوصيل أو الاثنين معًا',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              height: 1.35,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          DrvToggleRow(
            label: 'سائق تكسي',
            subtitle: 'يظهر له طلبات التكسي',
            icon: Icons.local_taxi_rounded,
            active: taxiEnabled,
            color: AppColors.accent,
            onChanged: onTaxiChanged,
          ),
          const SizedBox(height: 10),
          DrvToggleRow(
            label: 'مندوب توصيل',
            subtitle: 'يظهر له طلبات المطاعم',
            icon: Icons.delivery_dining_rounded,
            active: deliveryEnabled,
            color: Colors.blue,
            onChanged: onDeliveryChanged,
          ),
          if (bothEnabled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'الخدمتان مفعّلتان معًا، وستظهر الطلبات جميعها داخل الحساب.',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A toggle row for enabling/disabling a specific service.
class DrvToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Color color;
  final ValueChanged<bool> onChanged;

  const DrvToggleRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A card showing a delivery order for a driver.
class DrvDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const DrvDeliveryCard({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.bag_fill,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب مطعم #${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'جديد',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.itemsNameAr,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.price.toPrice()} د.ع',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Row(
                children: [
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () async {
                      try {
                        await provider.rejectDeliveryOrder(order.id);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    },
                    child: Text('رفض',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () async {
                      try {
                        await provider.acceptDeliveryOrder(order.id);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    },
                    child: Text('موافقة',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A card showing an active delivery order being worked on.
class DrvActiveDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const DrvActiveDeliveryCard({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final delivered = order.deliveryStatusKey == 'delivered';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'طلب #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            order.deliveryStatusAr ?? 'قيد التوصيل',
            style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.deliveryStatusKey == 'accepted')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () async {
                    try {
                      await provider.markDeliveryPickedUp(order.id);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                  child: Text('استلام الطلب',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (order.deliveryStatusKey == 'picked_up')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () async {
                    try {
                      await provider.markDeliveryCompleted(order.id);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                  child: Text('تم التسليم',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (delivered)
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

/// A top card widget displaying driver info with a gradient background.
class DrvTopCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const DrvTopCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.96),
            const Color(0xFF111111)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A statistics box showing a label and a colored value.
class DrvStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DrvStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip showing the current service mode with a colored indicator.
class DrvServiceChip extends StatelessWidget {
  final String label;
  final Color color;

  const DrvServiceChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// A section header with a colored accent bar.
class DrvSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? color;

  const DrvSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF1A1A1A);
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An empty state placeholder with an icon, title, and subtitle.
class DrvEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const DrvEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded,
              size: 54, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// A tile showing a label-value pair.
class DrvInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const DrvInfoTile({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable action button with colored background.
class DrvActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const DrvActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}
