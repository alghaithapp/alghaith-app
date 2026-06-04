import 'package:flutter/material.dart';

import '../../services/image_storage_service.dart';
import '../app_image.dart';

/// حقل رفع صورة للتاجر — فارغ بدون صور التطبيق الافتراضية.
class MerchantImageUploadSlot extends StatelessWidget {
  const MerchantImageUploadSlot({
    super.key,
    required this.title,
    required this.imageRef,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.add_photo_alternate_outlined,
    this.style = MerchantImageUploadStyle.card,
  });

  final String title;
  final String? subtitle;
  final String? imageRef;
  final IconData icon;
  final VoidCallback onTap;
  final MerchantImageUploadStyle style;

  bool get _hasUploadedImage =>
      ImageStorageService.isMerchantUploadedImage(imageRef);

  @override
  Widget build(BuildContext context) {
    if (style == MerchantImageUploadStyle.row) {
      return _buildRow(context);
    }
    return _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _hasUploadedImage
                ? const Color(0xFFF5A01D).withValues(alpha: 0.25)
                : Colors.grey.shade300,
            width: _hasUploadedImage ? 1.5 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _hasUploadedImage
                    ? AppImage(imageData: imageRef)
                    : _EmptyImagePlaceholder(
                        icon: icon,
                        hint: 'لم تُرفع صورة بعد',
                        actionHint: 'اضغط لرفع الصورة',
                      ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: _hasUploadedImage ? 0.45 : 0.55,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 84,
                height: 84,
                child: _hasUploadedImage
                    ? AppImage(imageData: imageRef)
                    : _EmptyImagePlaceholder(
                        icon: icon,
                        compact: true,
                        hint: 'فارغ',
                        actionHint: 'رفع',
                      ),
              ),
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
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.grey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

enum MerchantImageUploadStyle { card, row }

class MerchantImagePreviewBanner extends StatelessWidget {
  const MerchantImagePreviewBanner({
    super.key,
    required this.title,
    required this.imageRef,
  });

  final String title;
  final String? imageRef;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        ImageStorageService.isMerchantUploadedImage(imageRef);

    if (!hasImage) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'لم تُرفع صورة بعد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: AppImage(
        imageData: imageRef,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _EmptyImagePlaceholder extends StatelessWidget {
  const _EmptyImagePlaceholder({
    required this.icon,
    required this.hint,
    required this.actionHint,
    this.compact = false,
  });

  final IconData icon;
  final String hint;
  final String actionHint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F8FC),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: Colors.grey.shade400,
          radius: compact ? 16 : 22,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? 28 : 48,
                  color: Colors.grey.shade400,
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  actionHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: compact ? 11 : 12,
                    color: Colors.grey.shade500,
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      Radius.circular(radius - 4),
    );
    const dash = 6.0;
    const gap = 5.0;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
