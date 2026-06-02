import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/helpers.dart';
import '../widgets/whatsapp_icon.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final darkMode = appProvider.darkMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الإعدادات',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSwitchItem(
              title: 'التنبيهات',
              value: _notifications,
              onChanged: (val) => setState(() => _notifications = val),
              icon: CupertinoIcons.bell_fill,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildSwitchItem(
              title: 'الوضع الليلي',
              value: darkMode,
              onChanged: (val) => appProvider.setDarkMode(val),
              icon: CupertinoIcons.moon_fill,
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              title: 'سياسة الخصوصية',
              subtitle: 'تعرّف على كيفية تعاملنا مع البيانات داخل التطبيق.',
              icon: CupertinoIcons.doc_text_fill,
              color: Colors.grey,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => StaticInfoScreen(
                      title: 'سياسة الخصوصية',
                      icon: CupertinoIcons.doc_text_fill,
                      color: Colors.grey,
                      paragraphs: const [
                        'نجمع فقط البيانات اللازمة لتشغيل الخدمات الأساسية مثل الطلبات والعناوين والتفضيلات.',
                        'لا نشارك بياناتك الشخصية مع أي طرف ثالث إلا عند الحاجة لتقديم الخدمة أو بوجود طلب قانوني.',
                        'ستتمكن من مراجعة إعداداتك أو طلب حذف الحساب في التحديثات القادمة داخل التطبيق.',
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              title: 'عن التطبيق',
              subtitle: 'معلومات سريعة عن الغيث وما يقدمه.',
              icon: CupertinoIcons.info_circle_fill,
              color: Colors.teal,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => StaticInfoScreen(
                      title: 'عن التطبيق',
                      icon: CupertinoIcons.info_circle_fill,
                      color: Colors.teal,
                      paragraphs: const [
                        'تطبيق الغيث منصة خدمات وتسوق محلية تجمع الطعام والسيارات والمتاجر والعقارات في مكان واحد.',
                        'هذه النسخة تركز على التدفق الحقيقي للتطبيق وتخفي الأجزاء غير الجاهزة حتى تكتمل.',
                        'الهدف هو تقديم تجربة بسيطة وواضحة وسريعة للمستخدم والتاجر داخل العراق.',
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSupportCard(isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          CupertinoSwitch(
            value: value,
            activeTrackColor: Colors.orange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.4,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_left,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الدعم والمساعدة',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          _SupportButton(
            label: 'اتصل بنا عبر واتساب',
            color: Colors.green,
            iconWidget: const WhatsAppIcon(size: 38),
            onTap: () => AppHelpers.launchWhatsApp(
              AppHelpers.supportWhatsAppNumber,
              'مرحبًا، أحتاج مساعدة في تطبيق الغيث',
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final String label;
  final Color color;
  final Widget? iconWidget;
  final VoidCallback onTap;

  const _SupportButton({
    required this.label,
    required this.color,
    this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            iconWidget ?? Icon(CupertinoIcons.chat_bubble_2_fill, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_left,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class StaticInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> paragraphs;

  const StaticInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.paragraphs,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...paragraphs.map(
              (paragraph) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  paragraph,
                  style: const TextStyle(
                    height: 1.6,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
