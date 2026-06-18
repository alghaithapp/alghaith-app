import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui/account_ui.dart';
import '../core/theme/app_colors.dart';
import '../providers/app_provider.dart';
import '../utils/account_role_switch.dart';
import '../utils/app_update_checker.dart';
import '../utils/helpers.dart';
import '../widgets/account/account_page_header.dart';
import '../widgets/app_image.dart';
import 'account_deletion_screen.dart';
import 'account_full_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'addresses_screen.dart';
import 'app_settings_screen.dart';
import 'orders_screen.dart';
import 'payment_methods_screen.dart';

/// واجهة حساب الزبون — تصميم iOS حديث.
class CustomerAccountView extends StatelessWidget {
  const CustomerAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final notificationCount = provider.unreadNotificationCount;

    return Scaffold(
      backgroundColor: accountBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountPageHeader(notificationCount: notificationCount),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  children: [
                    _ProfileCard(provider: provider),
                    if (provider.hasAdminAccess) ...[
                      const SizedBox(height: 14),
                      _NavigationCard(
                        icon: CupertinoIcons.shield_fill,
                        iconColor: Colors.redAccent,
                        title: 'لوحة الإدارة (Super Admin)',
                        subtitle: 'إحصائيات المنصة، إدارة التجار، وصلاحيات البازار',
                        onTap: () async {
                          if (!provider.isAdmin) {
                            final ok = await provider.setUserRole('admin');
                            if (!context.mounted || !ok) return;
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const AdminDashboardScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    _NavigationCard(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFFE040FB),
                      title: 'تبديل الحساب (الدور)',
                      subtitle: 'الانتقال إلى واجهة التاجر أو المندوب أو الزبون',
                      onTap: () => showRoleSwitcher(context, provider),
                    ),
                    const SizedBox(height: 14),
                    _NavigationCard(
                      icon: Icons.badge_rounded,
                      iconColor: Colors.purple,
                      title: 'بيانات الحساب الكامل',
                      subtitle: 'عرض وتحديث جميع بيانات حسابك',
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const AccountFullScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsListCard(),
                    const SizedBox(height: 14),
                    _LogoutCard(onTap: () => provider.resetAll()),
                    const SizedBox(height: 12),
                    _DeleteAccountCard(
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const AccountDeletionScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppProvider provider;

  const _ProfileCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AccountUi.cardDecoration(radius: 22),
      child: Row(
        children: [
          _CustomerAvatar(avatarBase64: provider.customerAvatarBase64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.customerName.trim().isNotEmpty
                      ? provider.customerName
                      : 'مستخدم الغيث',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accountHeadline,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.phone_fill,
                      size: 13,
                      color: accountBodyGray.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        provider.customerPhone.trim().isNotEmpty
                            ? provider.customerPhone
                            : (provider.authPhone ?? '-'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: accountBodyGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _EditProfileButton(
            onTap: () => _showEditProfileDialog(context, provider),
          ),
        ],
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String? avatarBase64;

  const _CustomerAvatar({required this.avatarBase64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: AppImage(
          imageData: avatarBase64,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: AccountUi.brandGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accountBrandRed.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.pencil,
                color: Colors.white,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: AccountUi.cardDecoration(radius: 22),
          child: Row(
            children: [
              _IconSquare(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: accountHeadline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: accountBodyGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsListCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _SettingsItemData(
        icon: CupertinoIcons.doc_text_fill,
        color: AppColors.accent,
        title: 'سجل الطلبات',
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const OrdersScreen()),
        ),
      ),
      _SettingsItemData(
        icon: CupertinoIcons.arrow_2_circlepath,
        color: const Color(0xFFE84A3A),
        title: 'التحقق من تحديث التطبيق',
        onTap: () => AppUpdateChecker.checkAndPrompt(context),
      ),
      _SettingsItemData(
        icon: CupertinoIcons.settings,
        color: Colors.purple,
        title: 'الإعدادات',
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const AppSettingsScreen()),
        ),
      ),
      // تم إخفاء "عناويني" و "طرق الدفع" بناءً على طلب الإدارة
      _SettingsItemData(
        icon: Icons.headset_mic_rounded,
        color: Colors.green,
        title: 'خدمة دعم العملاء',
        onTap: () => AppHelpers.launchWhatsApp(
          AppHelpers.supportWhatsAppNumber,
          'مرحبا، أحتاج مساعدة في تطبيق الغيث',
        ),
        showDivider: false,
      ),
    ];

    return Container(
      decoration: AccountUi.cardDecoration(radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items.map((item) => _SettingsRow(item: item)).toList(),
      ),
    );
  }
}

class _SettingsItemData {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItemData item;

  const _SettingsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            border: item.showDivider
                ? Border(
                    bottom: BorderSide(
                      color: CupertinoColors.systemGrey6.withValues(alpha: 0.9),
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              _IconSquare(icon: item.icon, color: item.color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accountHeadline,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconSquare({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.power,
                  color: CupertinoColors.systemRed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: CupertinoColors.systemRed.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'حذف الحساب نهائياً',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showEditProfileDialog(
  BuildContext context,
  AppProvider provider,
) async {
  final nameController = TextEditingController(text: provider.customerName);
  final phoneController = TextEditingController(text: provider.customerPhone);
  String? selectedAvatarBase64 = provider.customerAvatarBase64;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          final Widget avatarPreview;
          if (selectedAvatarBase64 != null && selectedAvatarBase64!.isNotEmpty) {
            avatarPreview = AppImage(
              imageData: selectedAvatarBase64,
              width: 72,
              height: 72,
              borderRadius: BorderRadius.circular(36),
            );
          } else {
            avatarPreview = const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.accent,
              child: Icon(
                CupertinoIcons.person_fill,
                color: Colors.white,
                size: 38,
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'تعديل الملف الشخصي',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 2),
                        ),
                        child: avatarPreview,
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await AppHelpers.pickImage(context);
                          if (picked == null) return;

                          final imageRef =
                              await provider.uploadImage(File(picked.path));
                          if (!context.mounted) return;
                          if (imageRef != null) {
                            setStateDialog(() {
                              selectedAvatarBase64 = imageRef;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر رفع الصورة. تحقق من الاتصال وحاول مجدداً.',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _profileField(label: 'الاسم', controller: nameController),
                  const SizedBox(height: 12),
                  _profileField(
                    label: 'رقم الهاتف',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  try {
                    await provider.updateCustomerProfile(
                      name: nameController.text,
                      phone: phoneController.text,
                      avatarBase64: selectedAvatarBase64,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تعذر حفظ الصورة: $error',
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _profileField({
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}
