import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/helpers.dart';
import '../widgets/app_image.dart';

/// شاشة مطبعة جنة عدن — تعرض الخدمات وزر واتساب للتواصل المباشر.
class EdenPrintingScreen extends StatelessWidget {
  const EdenPrintingScreen({super.key});

  static const String _whatsappNumber = '9647725053888';

  static const List<_PrintingService> _services = [
    _PrintingService(
      icon: '📄',
      title: 'مطبوعات عامة',
      description: 'طباعة الكتب، الدفاتر، النشرات، البروشورات، الكتالوجات، والمطبوعات التجارية.',
    ),
    _PrintingService(
      icon: '🪟',
      title: 'فلكس',
      description: 'طباعة وتصميم الفلكس الإعلاني بجميع المقاسات للواجهات والمحلات التجارية.',
    ),
    _PrintingService(
      icon: '⚙️',
      title: 'CNC',
      description: 'حفر وقص بالكمبيوتر على الخشب، الأكريليك، المعادن، والبلاستيك بدقة عالية.',
    ),
    _PrintingService(
      icon: '📋',
      title: 'دفاتر وصولات',
      description: 'طباعة دفاتر الوصولات، السندات، والفواتير بجودة عالية وبأسعار مناسبة.',
    ),
    _PrintingService(
      icon: '🃏',
      title: 'طباعة كارتات',
      description: 'طباعة الكروت البلاستيكية والورقية، كروت الزيارات، التعريف، والدعوات.',
    ),
    _PrintingService(
      icon: '🎨',
      title: 'تصميم جرافيك',
      description: 'تصميم الشعارات، الهويات البصرية، الإعلانات، ومواد التسويق المطبوعة.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFFF8F5),
        middle: const Text(
          'مطبعة جنة عدن',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // صورة القسم
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppImage(
                  imageData: 'assets/images/cat_eden_printing.png',
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              // عنوان المطبعة مع زر واتساب صغير بالأعلى
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // صف العنوان وزر واتساب
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مطبعة جنة عدن',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2A1A17),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'كل ما تحتاجه من خدمات الطباعة في مكان واحد',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Color(0xFF6B5C55),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // زر واتساب صغير
                        GestureDetector(
                          onTap: () {
                            AppHelpers.launchWhatsApp(
                              _whatsappNumber,
                              'السلام عليكم، أريد الاستفسار عن خدمات الطباعة في مطبعة جنة عدن',
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.chat_bubble_2_fill,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // معلومات المطبعة
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.clock,
                          size: 16,
                          color: Color(0xFF9E8B82),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            '8 صباحاً → 8 مساءاً',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Color(0xFF9E8B82),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.location,
                          size: 16,
                          color: Color(0xFF9E8B82),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'الصويرة - فلكة كسار - مجاور البريد',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Color(0xFF9E8B82),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.phone,
                          size: 16,
                          color: Color(0xFF9E8B82),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '0772 505 3888',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E8B82),
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            AppHelpers.launchWhatsApp(
                              _whatsappNumber,
                              'السلام عليكم، أريد الاستفسار عن خدمات الطباعة في مطبعة جنة عدن',
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.chat_bubble_2_fill,
                                size: 14,
                                color: Color(0xFF25D366),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'واتساب',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // قسم الخدمات
              const Padding(
                padding: EdgeInsets.only(right: 4, bottom: 12),
                child: Text(
                  'الخدمات المقدمة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2A1A17),
                  ),
                ),
              ),

              // قائمة الخدمات
              ..._services.map((service) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE8E0DA),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          service.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2A1A17),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.description,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Color(0xFF8A7A72),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),

              const SizedBox(height: 24),

              // زر واتساب كبير أسفل الشاشة
              SizedBox(
                height: 56,
                child: CupertinoButton(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(16),
                  pressedOpacity: 0.85,
                  onPressed: () {
                    AppHelpers.launchWhatsApp(
                      _whatsappNumber,
                      'السلام عليكم، أريد الاستفسار عن خدمات الطباعة في مطبعة جنة عدن',
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chat_bubble_2_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'تواصل معنا عبر واتساب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintingService {
  final String icon;
  final String title;
  final String description;

  const _PrintingService({
    required this.icon,
    required this.title,
    required this.description,
  });
}
