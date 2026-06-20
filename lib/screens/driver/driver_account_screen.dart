import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../utils/account_role_switch.dart';
import '../../screens/notifications_screen.dart';
import '../../widgets/app_image.dart';
import 'driver_shared_widgets.dart';

class DriverAccountScreen extends StatelessWidget {
  const DriverAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.driverProfile ?? const {};
    const typeLabel = 'سائق';
    final isAvailable = profile['available'] as bool? ?? true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading:
              const Icon(Icons.notifications_outlined, color: AppColors.accent),
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
          ),
          trailing: provider.unreadNotificationCount > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFF5A01D),
                  child: Text(
                    '${provider.unreadNotificationCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111111), Color(0xFF2E2E2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              DrvAvatar(
                avatarBase64: profile['avatarBase64'] as String?,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حساب السائق',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'توصيل الطلبات والمطاعم',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withValues(alpha: 0.16)
                            : Colors.red.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isAvailable ? 'متاح' : 'غير متاح',
                        style: TextStyle(
                          color: isAvailable
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DrvImageCard(
                title: 'الصورة الشخصية',
                imageBase64: profile['avatarBase64'] as String?,
                icon: Icons.person,
                onTap: () => _showEditProfileSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DrvImageCard(
                title: 'صورة السيارة',
                imageBase64: profile['carImageBase64'] as String?,
                icon: Icons.directions_car,
                onTap: () => _showEditProfileSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: isAvailable,
          onChanged: (value) => provider.setDriverAvailability(value),
          activeThumbColor: AppColors.accent,
          tileColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'التوفر',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            isAvailable
                ? 'تستقبل الطلبات الآن'
                : 'مؤقتًا لا تستقبل الطلبات',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        const SizedBox(height: 12),
        DrvInfoTile(label: 'الاسم', value: '${profile['name'] ?? '-'}'),
        DrvInfoTile(label: 'الهاتف', value: '${profile['phone'] ?? '-'}'),
        DrvInfoTile(label: 'نوع الحساب', value: typeLabel),
        DrvInfoTile(label: 'السيارة', value: '${profile['vehicle'] ?? '-'}'),
        DrvInfoTile(label: 'اللوحة', value: '${profile['plate'] ?? '-'}'),
        DrvInfoTile(label: 'المنطقة', value: '${profile['area'] ?? '-'}'),
        if ((profile['notes'] as String?)?.isNotEmpty ?? false)
          DrvInfoTile(
            label: 'ملاحظات',
            value: '${profile['notes']}',
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(18),
            onPressed: () => _showEditProfileSheet(context),
            child: const Text(
              'تعديل الحساب',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: const Color(0xFFE040FB),
            borderRadius: BorderRadius.circular(18),
            onPressed: () => showRoleSwitcher(context, provider),
            child: const Text(
              'تبديل الحساب (الدور)',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(18),
            onPressed: () => provider.resetAll(),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final profile = provider.driverProfile ?? const {};
    final nameController =
        TextEditingController(text: '${profile['name'] ?? ''}');
    final phoneController =
        TextEditingController(text: '${profile['phone'] ?? ''}');
    final vehicleController =
        TextEditingController(text: '${profile['vehicle'] ?? ''}');
    final plateController =
        TextEditingController(text: '${profile['plate'] ?? ''}');
    final areaController =
        TextEditingController(text: '${profile['area'] ?? ''}');
    final notesController =
        TextEditingController(text: '${profile['notes'] ?? ''}');
    String? avatarBase64 = profile['avatarBase64'] as String?;
    String? carImageBase64 = profile['carImageBase64'] as String?;
    bool isAvailable = profile['available'] as bool? ?? true;

    Future<String?> pickImage() async {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return base64Encode(bytes);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.7,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F4F6),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تعديل ملف السائق',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DrvImageCard(
                        title: 'الصورة الشخصية',
                        imageBase64: avatarBase64,
                        icon: Icons.person,
                        onTap: () async {
                          final picked = await pickImage();
                          if (picked != null) {
                            setSheetState(() => avatarBase64 = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DrvImageCard(
                        title: 'صورة السيارة',
                        imageBase64: carImageBase64,
                        icon: Icons.directions_car,
                        onTap: () async {
                          final picked = await pickImage();
                          if (picked != null) {
                            setSheetState(() => carImageBase64 = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isAvailable,
                        onChanged: (value) =>
                            setSheetState(() => isAvailable = value),
                        title: Text(
                          'متاح / غير متاح',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          isAvailable ? 'تستقبل الطلبات' : 'مؤقتًا غير متصل',
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      _editField('الاسم الكامل', nameController),
                      _editField('رقم الهاتف', phoneController),
                      _editField('نوع السيارة', vehicleController),
                      _editField('رقم اللوحة', plateController),
                      _editField('منطقة العمل', areaController),
                      _editField('ملاحظات', notesController, maxLines: 3),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(18),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          onPressed: () async {
                            await provider.setDriverProfile({
                              'type': 'taxi',
                              'services': {'taxi': true, 'delivery': false},
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'vehicle': vehicleController.text.trim(),
                              'plate': plateController.text.trim(),
                              'area': areaController.text.trim(),
                              'notes': notesController.text.trim(),
                              'available': isAvailable,
                              'avatarBase64': avatarBase64,
                              'carImageBase64': carImageBase64,
                            });
                            if (context.mounted) Navigator.pop(sheetContext);
                          },
                          child: Text(
                            'حفظ التعديلات',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    vehicleController.dispose();
    plateController.dispose();
    areaController.dispose();
    notesController.dispose();
  }

  Widget _editField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class DrvAvatar extends StatelessWidget {
  final String? avatarBase64;

  const DrvAvatar({required this.avatarBase64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipOval(
        child: AppImage(
          imageData: avatarBase64,
        ),
      ),
    );
  }
}

class DrvImageCard extends StatelessWidget {
  final String title;
  final String? imageBase64;
  final IconData icon;
  final VoidCallback onTap;

  const DrvImageCard({
    required this.title,
    required this.imageBase64,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AppImage(
                  imageData: imageBase64,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
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
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
