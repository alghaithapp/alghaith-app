import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _confirmed = false;
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      await context.read<AppProvider>().deleteAccountPermanently();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف حسابك نهائياً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف الحساب: $error',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _confirmDeletion() async {
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          'تأكيد حذف الحساب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'سيتم حذف حسابك وبياناتك المرتبطة به نهائياً ولا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _deleteAccount();
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
                    'حذف الحساب نهائياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكنك حذف حسابك مباشرة من التطبيق دون الحاجة للتواصل عبر البريد أو الرسائل.',
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
                    'ماذا سيُحذف؟',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• بيانات الحساب وملفك الشخصي\n'
                    '• العناوين والمفضلة والإعدادات\n'
                    '• بيانات النشاط التجاري إن وُجدت\n'
                    '• سجل الطلبات المرتبط بحسابك',
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CupertinoSwitch(
                    value: _confirmed,
                    activeTrackColor: CupertinoColors.systemRed,
                    onChanged: _isDeleting
                        ? null
                        : (value) => setState(() => _confirmed = value),
                  ),
                  const Expanded(
                    child: Text(
                      'أفهم أن الحذف نهائي ولا يمكن استعادة البيانات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.5,
                      ),
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
                onPressed: !_confirmed || _isDeleting ? null : _confirmDeletion,
                child: _isDeleting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        'حذف حسابي الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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
