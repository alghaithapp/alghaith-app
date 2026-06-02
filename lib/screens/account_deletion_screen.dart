import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDeletionScreen extends StatelessWidget {
  static const String deletionRequestUrl =
      'https://www.alghaithst.com/account-deletion.html';

  const AccountDeletionScreen({super.key});

  Future<void> _openDeletionForm(BuildContext context) async {
    final uri = Uri.parse(deletionRequestUrl);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح صفحة طلب حذف الحساب. تحقق من الاتصال وحاول مجدداً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'حذف الحساب',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.trash_fill,
                      color: CupertinoColors.systemRed,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'طلب حذف الحساب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'إذا رغبت في حذف حسابك نهائياً، يمكنك تقديم الطلب عبر النموذج الرسمي على موقع الغيث.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      height: 1.6,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.15),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قبل المتابعة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• سيتم مراجعة طلبك من فريق الدعم.\n'
                    '• قد يستغرق التنفيذ عدة أيام عمل.\n'
                    '• تأكد من إدخال نفس رقم الهاتف المسجل في التطبيق.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.7,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: CupertinoColors.systemRed,
                borderRadius: BorderRadius.circular(18),
                onPressed: () => _openDeletionForm(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.arrow_up_right_square, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'فتح نموذج طلب حذف الحساب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              deletionRequestUrl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
