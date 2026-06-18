import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/merchant/merchant_image_upload_slot.dart';

class DriverSetupScreen extends StatefulWidget {
  const DriverSetupScreen({super.key});

  @override
  State<DriverSetupScreen> createState() => _DriverSetupScreenState();
}

class _DriverSetupScreenState extends State<DriverSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();
  final TextEditingController _mukhtarNameController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  String? _profileImageRef;
  String? _carImageRef;
  String? _idFrontImageRef;
  String? _idBackImageRef;
  String? _residenceCardImageRef;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    _mukhtarNameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع الصورة الشخصية، حاول مرة أخرى');
        return;
      }
      setState(() => _profileImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickCarImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع صورة السيارة، حاول مرة أخرى');
        return;
      }
      setState(() => _carImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickIdFrontImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع صورة البطاقة الموحدة (الوجه)، حاول مرة أخرى');
        return;
      }
      setState(() => _idFrontImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickIdBackImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع صورة البطاقة الموحدة (الظهر)، حاول مرة أخرى');
        return;
      }
      setState(() => _idBackImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickResidenceCardImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع صورة بطاقة السكن، حاول مرة أخرى');
        return;
      }
      setState(() => _residenceCardImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  Future<void> _save(AppProvider provider) async {
    final name = _nameController.text.trim();
    final phone = PhoneUtils.digitsOnly(_phoneController.text);
    final homeAddress = _homeAddressController.text.trim();
    final mukhtarName = _mukhtarNameController.text.trim();
    final plate = _plateController.text.trim();
    final profileImage = _profileImageRef?.trim() ?? '';
    final carImage = _carImageRef?.trim() ?? '';
    final idFrontImage = _idFrontImageRef?.trim() ?? '';
    final idBackImage = _idBackImageRef?.trim() ?? '';
    final residenceCardImage = _residenceCardImageRef?.trim() ?? '';

    if (name.isEmpty) {
      _showMessage('أدخل الاسم الرباعي');
      return;
    }
    if (phone.length < 10) {
      _showMessage('أدخل رقم هاتف صحيح');
      return;
    }
    if (homeAddress.isEmpty) {
      _showMessage('أدخل عنوانك الحالي');
      return;
    }
    if (mukhtarName.isEmpty) {
      _showMessage('أدخل اسم المختار');
      return;
    }
    if (plate.isEmpty) {
      _showMessage('أدخل رقم لوحة السيارة');
      return;
    }
    if (profileImage.isEmpty) {
      _showMessage('أضف صورتك الشخصية');
      return;
    }
    if (carImage.isEmpty) {
      _showMessage('أضف صورة للسيارة');
      return;
    }
    if (idFrontImage.isEmpty) {
      _showMessage('أضف صورة البطاقة الموحدة (الوجه)');
      return;
    }
    if (idBackImage.isEmpty) {
      _showMessage('أضف صورة البطاقة الموحدة (الظهر)');
      return;
    }
    if (residenceCardImage.isEmpty) {
      _showMessage('أضف صورة بطاقة السكن');
      return;
    }

    setState(() => _isSaving = true);
    try {
      provider.setDriverType('taxi');
      await provider.setDriverProfile({
        'type': 'taxi',
        'services': {'taxi': true, 'delivery': true},
        'name': name,
        'phone': phone,
        'homeAddress': homeAddress,
        'mukhtarName': mukhtarName,
        'plate': plate,
        'profileImage': profileImage,
        'carImage': carImage,
        'idFrontImage': idFrontImage,
        'idBackImage': idBackImage,
        'residenceCardImage': residenceCardImage,
      });
      if (!mounted) return;
      _showMessage('تم إرسال طلبك. سيتم تفعيل حسابك بعد موافقة الإدارة.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _previewThumb(String ref, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(
              imageData: ref,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'تسجيل سائق تكسي',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D4D), Color(0xFF007A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.local_taxi_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حساب سائق تكسي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الاسم الرباعي، العنوان، رقم اللوحة، والمستندات الثبوتية مطلوبة للتفعيل.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // الحقول الأساسية
          const _SectionTitle(text: 'البيانات الشخصية'),
          const SizedBox(height: 8),
          _Field(
            label: 'الاسم الرباعي',
            hintText: 'الاسم الأول — اسم الأب — اسم الجد — العائلة',
            controller: _nameController,
          ),
          _Field(
            label: 'رقم الهاتف (واتساب)',
            hintText: 'رقم مفعّل على واتساب',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            label: 'العنوان الحالي',
            hintText: 'المدينة — الحي — الشارع',
            controller: _homeAddressController,
            maxLines: 2,
          ),
          _Field(
            label: 'اسم المختار',
            hintText: 'أدخل اسم مختار منطقتك',
            controller: _mukhtarNameController,
          ),
          const SizedBox(height: 20),

          // معلومات المركبة
          const _SectionTitle(text: 'بيانات المركبة'),
          const SizedBox(height: 8),
          _Field(
            label: 'رقم لوحة السيارة',
            hintText: 'مثال: 12345 بغداد',
            controller: _plateController,
          ),
          const SizedBox(height: 20),

          // الصور
          const _SectionTitle(text: 'الصور الثبوتية'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MerchantImageUploadSlot(
                  title: 'الصورة الشخصية',
                  subtitle: 'صورة واضحة للوجه',
                  imageRef: _profileImageRef,
                  icon: CupertinoIcons.person_crop_circle_fill,
                  onTap: _isUploadingImage ? () {} : _pickProfileImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MerchantImageUploadSlot(
                  title: 'صورة السيارة',
                  subtitle: 'صورة واضحة للمركبة',
                  imageRef: _carImageRef,
                  icon: Icons.directions_car_rounded,
                  onTap: _isUploadingImage ? () {} : _pickCarImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MerchantImageUploadSlot(
            title: 'بطاقة السكن',
            subtitle: 'صورة واضحة لبطاقة السكن',
            imageRef: _residenceCardImageRef,
            icon: Icons.home_work_rounded,
            onTap: _isUploadingImage ? () {} : _pickResidenceCardImage,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MerchantImageUploadSlot(
                  title: 'البطاقة الموحدة (الوجه)',
                  subtitle: 'الوجه الأمامي',
                  imageRef: _idFrontImageRef,
                  icon: Icons.badge_rounded,
                  onTap: _isUploadingImage ? () {} : _pickIdFrontImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MerchantImageUploadSlot(
                  title: 'البطاقة الموحدة (الظهر)',
                  subtitle: 'الوجه الخلفي',
                  imageRef: _idBackImageRef,
                  icon: Icons.badge_rounded,
                  onTap: _isUploadingImage ? () {} : _pickIdBackImage,
                ),
              ),
            ],
          ),

          if (_isUploadingImage) ...[
            const SizedBox(height: 8),
            const Center(child: CupertinoActivityIndicator()),
          ],

          // معاينة
          if ((_profileImageRef != null && _profileImageRef!.isNotEmpty) ||
              (_carImageRef != null && _carImageRef!.isNotEmpty) ||
              (_residenceCardImageRef != null &&
                  _residenceCardImageRef!.isNotEmpty) ||
              (_idFrontImageRef != null && _idFrontImageRef!.isNotEmpty) ||
              (_idBackImageRef != null && _idBackImageRef!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            const Text(
              'معاينة الصور المرفوعة:',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_profileImageRef != null)
                    _previewThumb(_profileImageRef!, 'شخصية'),
                  if (_carImageRef != null)
                    _previewThumb(_carImageRef!, 'سيارة'),
                  if (_residenceCardImageRef != null)
                    _previewThumb(_residenceCardImageRef!, 'سكن'),
                  if (_idFrontImageRef != null)
                    _previewThumb(_idFrontImageRef!, 'موحدة-وجه'),
                  if (_idBackImageRef != null)
                    _previewThumb(_idBackImageRef!, 'موحدة-ظهر'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed:
                  _isSaving || _isUploadingImage ? null : () => _save(context.read<AppProvider>()),
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text(
                      'إرسال طلب التفعيل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: AppColors.primary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
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
