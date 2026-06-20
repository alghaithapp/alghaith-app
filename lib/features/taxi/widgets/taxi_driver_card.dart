import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../../../core/theme/app_colors.dart';

/// بطاقة معلومات السائق — تصميم مستوحى من `_3/code.html`
///
/// تعرض صورة السائق، الاسم، التقييم، وسام "سائق مميز"،
/// معلومات السيارة (الموديل، اللون، اللوحة)، وأزرار اتصال ورسالة.
class TaxiDriverCard extends StatelessWidget {
  final DriverModel driver;
  final String? driverImageUrl;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const TaxiDriverCard({
    super.key,
    required this.driver,
    this.driverImageUrl,
    this.onCall,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── صف معلومات السائق ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // الصورة + التقييم
              _DriverAvatar(
                imageUrl: driverImageUrl,
                name: driver.name,
                rating: driver.rating,
              ),
              const SizedBox(width: 16),
              // الاسم + الوسام
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'سائق مميز',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── بطاقة معلومات السيارة ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // الموديل واللون
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.vehicleModel,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _parseColor(driver.color),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            driver.color,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // رقم اللوحة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        driver.plateNumber,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Container(
                        height: 1,
                        width: 40,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                      Text(
                        'العراق',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── أزرار اتصال ورسالة ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCall,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call, color: AppColors.accentDark, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'اتصال',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onMessage,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble, color: Colors.black87, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'رسالة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// تحويل اسم لون عربي إلى قيمة [Color] للعرض
  Color _parseColor(String colorName) {
    switch (colorName.trim()) {
      case 'أبيض':
      case 'ابيض':
        return Colors.white;
      case 'أسود':
      case 'اسود':
        return Colors.black;
      case 'أحمر':
      case 'احمر':
        return Colors.red;
      case 'أزرق':
      case 'ازرق':
        return Colors.blue;
      case 'أخضر':
      case 'اخضر':
        return Colors.green;
      case 'أصفر':
      case 'اصفر':
        return Colors.yellow;
      case 'رمادي':
        return Colors.grey;
      case 'فضي':
        return const Color(0xFFC0C0C0);
      case 'بني':
        return Colors.brown;
      case 'برتقالي':
        return Colors.orange;
      case 'بيج':
        return const Color(0xFFF5F5DC);
      case 'سلفر':
        return const Color(0xFFC0C0C0);
      default:
        return Colors.grey.shade400;
    }
  }
}

/// صورة السائق الدائرية مع شارة التقييم
class _DriverAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double rating;

  const _DriverAvatar({
    this.imageUrl,
    required this.name,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // الصورة
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return _defaultAvatar();
                    },
                  )
                : _defaultAvatar(),
          ),
        ),
        // شارة التقييم
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 12, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}
