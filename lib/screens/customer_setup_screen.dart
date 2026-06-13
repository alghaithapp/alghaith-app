import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/image_storage_service.dart';
import '../widgets/app_image.dart';
import '../widgets/app_logo.dart';

class CustomerSetupScreen extends StatefulWidget {
  const CustomerSetupScreen({super.key});

  @override
  State<CustomerSetupScreen> createState() => _CustomerSetupScreenState();
}

class _CustomerSetupScreenState extends State<CustomerSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _avatarBase64;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    if (_nameController.text.isEmpty && provider.customerName.isNotEmpty) {
      _nameController.text = provider.customerName;
    }
    if (_phoneController.text.isEmpty && provider.customerPhone.isNotEmpty) {
      _phoneController.text = provider.customerPhone;
    }
    if (_addressController.text.isEmpty &&
        provider.customerAddress.isNotEmpty) {
      _addressController.text = provider.customerAddress;
    }
    _avatarBase64 ??= provider.customerAvatarBase64;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    // استخدام دالة الرفع لضمان المعالجة الصحيحة
    final imageRef =
        await context.read<AppProvider>().uploadImage(File(picked.path));
    if (!mounted) return;
    if (imageRef != null) {
      setState(() {
        _avatarBase64 = imageRef;
      });
      return;
    }

    final localFallback =
        await ImageStorageService.encodeFileAsBase64(File(picked.path));
    if (!mounted) return;
    if (localFallback != null) {
      setState(() {
        _avatarBase64 = localFallback;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر رفع الصورة للسحابة. سيتم حفظ نسخة محلية مؤقتاً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تعذر رفع الصورة. حاول مرة أخرى.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل الاسم ورقم الهاتف')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<AppProvider>();

      await provider.setUserRole('customer');
      await provider.updateCustomerProfile(
        name: name,
        phone: phone,
        address: _addressController.text.trim(),
        avatarBase64: _avatarBase64,
      );

      // 3. إغلاق الصفحة والعودة للرئيسية
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (error) {
      debugPrint('Save error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandTeal = Color(0xFF007A7A);
    const brandOrange = Color(0xFFF5A01D);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: brandTeal),
        title: const Text(
          'إكمال ملف الزبون',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: brandTeal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: brandTeal.withValues(alpha: 0.15),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child:
                            _avatarBase64 != null && _avatarBase64!.isNotEmpty
                                ? AppImage(
                                    imageData: _avatarBase64,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    CupertinoIcons.person_alt_circle_fill,
                                    size: 72,
                                    color: Color(0xFFD1D1D6),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'الصورة الشخصية',
                    style: TextStyle(
                      color: brandTeal,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    label: 'الاسم الكامل',
                    controller: _nameController,
                    icon: CupertinoIcons.person_fill,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'رقم الهاتف',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    icon: CupertinoIcons.phone_fill,
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'العنوان السكني',
                    controller: _addressController,
                    maxLines: 2,
                    icon: CupertinoIcons.location_solid,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _saving ? null : _save,
                      child: Container(
                        alignment: Alignment.center,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [brandOrange, Color(0xFFE68A19)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: brandOrange.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _saving
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text(
                                'حفظ ومتابعة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لن يظهر الحساب الكامل إلا بعد إدخال بياناتك الشخصية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontFamily: 'Cairo',
                      height: 1.6,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final IconData icon;

  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    const brandTeal = Color(0xFF007A7A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF48484A),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefix: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(icon, color: brandTeal.withValues(alpha: 0.6), size: 20),
          ),
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
        ),
      ],
    );
  }
}
