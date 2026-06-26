import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/app_models.dart';
import '../../../utils/extensions.dart';
import '../../../widgets/app_image.dart';

// ── Constants ──────────────────────────────────────────────────

const Color cartBrandRed = Color(0xFFF5A01D);
const LinearGradient cartBrandRedGradient = LinearGradient(
  colors: [cartBrandRed, Color(0xFFFF3D00)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ── Geo Point Helper ───────────────────────────────────────────

class CartGeoPoint {
  final double latitude;
  final double longitude;
  const CartGeoPoint(this.latitude, this.longitude);
}

// ── Cart Item Card ─────────────────────────────────────────────

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool isFavorite;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onFavorite;

  const CartItemCard({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onIncrement,
    required this.onDecrement,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final description = (item.descriptionAr?.trim().isNotEmpty == true)
        ? item.descriptionAr!.trim()
        : (item.optionAr?.trim().isNotEmpty == true
            ? item.optionAr!.trim()
            : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(28),
                ),
                child: SizedBox(
                  width: 118,
                  height: 118,
                  child: AppImage(imageData: item.image),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? cartBrandRed : Colors.grey.shade500,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameAr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${item.price.toPrice()} د.ع',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      color: cartBrandRed,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CartQtyBtn(
                  icon: Icons.add_rounded,
                  onTap: onIncrement,
                  isPrimary: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Text(
                      '${item.count}',
                      key: ValueKey<int>(item.count),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                CartQtyBtn(
                  icon: item.count > 1
                      ? Icons.remove_rounded
                      : Icons.delete_outline_rounded,
                  onTap: onDecrement,
                  isPrimary: false,
                  isDestructive: item.count <= 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quantity Button ────────────────────────────────────────────

class CartQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const CartQtyBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? cartBrandRed
        : isDestructive
            ? const Color(0xFFFFF1F2)
            : Colors.white;
    final iconColor = isPrimary
        ? Colors.white
        : isDestructive
            ? cartBrandRed
            : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: isPrimary
              ? null
              : Border.all(
                  color: isDestructive
                      ? cartBrandRed.withValues(alpha: 0.25)
                      : Colors.grey.shade200,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: cartBrandRed.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ── Delivery Option Card ───────────────────────────────────────

class CartDeliveryOptionCard extends StatelessWidget {
  final String title;
  final String? time;
  final bool selected;
  final VoidCallback onTap;

  const CartDeliveryOptionCard({
    super.key,
    required this.title,
    this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? cartBrandRed : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.04 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? cartBrandRed : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: selected ? cartBrandRed : Colors.transparent,
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: selected ? cartBrandRed : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (time != null && time!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                time!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: selected
                      ? cartBrandRed.withValues(alpha: 0.75)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Summary Row ────────────────────────────────────────────────

class CartSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLarge;
  final Color? valueColor;

  const CartSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isLarge = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: isLarge ? FontWeight.w900 : FontWeight.w700,
            fontSize: isLarge ? 18 : 14,
            color: isLarge ? Colors.black : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: isLarge ? 22 : 16,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ── Circle Icon Button ─────────────────────────────────────────

class CartCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CartCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

// ── Small Button ───────────────────────────────────────────────

class CartSmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool border;
  final bool isLoading;
  final VoidCallback onTap;

  const CartSmallButton({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    this.border = false,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: border ? Border.all(color: Colors.grey.shade300) : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: textColor),
              ),
      ),
    );
  }
}

// ── Pill Button ────────────────────────────────────────────────

class CartPillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool isLoading;
  final VoidCallback onTap;

  const CartPillButton({
    super.key,
    required this.label,
    required this.filled,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? cartBrandRed : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : cartBrandRed,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: filled ? Colors.white : Colors.black87,
                ),
              ),
      ),
    );
  }
}

// ── Mini Map Preview ───────────────────────────────────────────

class CartMiniMapPreview extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isCalculating;

  const CartMiniMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.isCalculating,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = latitude != null && longitude != null;

    return ColoredBox(
      color: const Color(0xFFECEFF3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCoords)
            CartStaticMapTile(latitude: latitude!, longitude: longitude!)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFECEFF3), Color(0xFFDDE3EA)],
                ),
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cartBrandRed.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: cartBrandRed,
                size: 28,
              ),
            ),
          ),
          if (isCalculating)
            Container(
              color: Colors.white.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: const CupertinoActivityIndicator(),
            ),
          if (distanceKm != null)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '${distanceKm!.toStringAsFixed(1)} كم',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Static Map Tile ────────────────────────────────────────────

class CartStaticMapTile extends StatelessWidget {
  final double latitude;
  final double longitude;

  const CartStaticMapTile({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  String get _url {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    const apiKey = 'AIzaSyBX720zCrccLT6ZKrc_o7r9tr0TAHDsy8c';
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=14'
        '&size=400x200'
        '&scale=2'
        '&markers=color:red%7C$lat,$lng'
        '&key=$apiKey';
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFECEFF3), Color(0xFFDDE3EA)],
          ),
        ),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFECEFF3),
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(),
        );
      },
    );
  }
}
