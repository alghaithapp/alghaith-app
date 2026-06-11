import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/phone_utils.dart';
import '../../core/utils/western_digits_input_formatter.dart';
import '../../providers/app_provider.dart';
import '../../utils/courier_profile_fields.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/merchant/merchant_image_upload_slot.dart';

class DeliverySetupScreen extends StatefulWidget {
  const DeliverySetupScreen({super.key});

  @override
  State<DeliverySetupScreen> createState() => _DeliverySetupScreenState();
}

class _DeliverySetupScreenState extends State<DeliverySetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _homeAddressController;
  String? _profileImageRef;
  String? _vehicleImageRef;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    final profile = provider.courierProfile ?? {};
    _nameController =
        TextEditingController(text: CourierProfileFields.name(profile));
    _phoneController = TextEditingController(
      text: CourierProfileFields.phone(profile).isNotEmpty
          ? CourierProfileFields.phone(profile)
          : (provider.authPhone ?? '').trim(),
    );
    _homeAddressController = TextEditingController(
      text: CourierProfileFields.homeAddress(profile),
    );
    _profileImageRef = CourierProfileFields.profileImage(profile).isNotEmpty
        ? CourierProfileFields.profileImage(profile)
        : null;
    _vehicleImageRef = CourierProfileFields.vehicleImage(profile).isNotEmpty
        ? CourierProfileFields.vehicleImage(profile)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickVehicleImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage('تعذر رفع صورة الدراجة، حاول مرة أخرى');
        return;
      }
      setState(() => _vehicleImageRef = url.trim());
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final url =
          await context.read<AppProvider>().uploadImage(File(picked.path));
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  Future<void> _save(AppProvider provider, {required bool isEditing}) async {
    final name = _nameController.text.trim();
    final phone = PhoneUtils.digitsOnly(_phoneController.text);
    final homeAddress = _homeAddressController.text.trim();
    final profileImage = _profileImageRef?.trim() ?? '';
    final vehicleImage = _vehicleImageRef?.trim() ?? '';

    if (!CourierProfileFields.isTripleName(name)) {
      _showMessage('أدخل الاسم الثلاثي (الاسم الأول + الأب + العائلة)');
      return;
    }
    if (phone.length < 10) {
      _showMessage('أدخل رقم هاتف صحيح مفعّل على واتساب');
      return;
    }
    if (homeAddress.isEmpty) {
      _showMessage('أدخل عنوان السكن');
      return;
    }
    if (profileImage.isEmpty) {
      _showMessage('أضف صورتك الشخصية');
      return;
    }
    if (vehicleImage.isEmpty) {
      _showMessage('أضف صورة للدراجة');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await provider.setCourierProfile({
        'name': name,
        'phone': phone,
        'homeAddress': homeAddress,
        'profileImage': profileImage,
        'vehicleImage': vehicleImage,
        'available': provider.courierProfile?['available'] as bool? ?? true,
      });
      if (!mounted) return;
      if (isEditing) {
        Navigator.of(context).pop();
        _showMessage('تم حفظ التعديلات');
      } else {
        _showMessage(
          'تم إرسال طلبك. سيتم تفعيل حسابك بعد موافقة الإدارة.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isEditing = provider.hasCourierProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            provider.setUserRole('customer');
          },
        ),
        title: Text(
          isEditing ? 'تعديل ملف المندوب' : 'تسجيل مندوب توصيل',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            child: const Row(
              children: [
                Icon(Icons.motorcycle, color: Colors.white, size: 34),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات مندوب التوصيل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الاسم الثلاثي، الهاتف، عنوان السكن، وصورة الدراجة والصورة الشخصية مطلوبة للتفعيل.',
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
          _Field(
            label: 'الاسم الثلاثي',
            hintText: 'مثال: محمد علي حسين',
            controller: _nameController,
          ),
          _Field(
            label: 'رقم الهاتف (واتساب)',
            hintText: 'يجب أن يكون رقم واتساب فعّال',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: const [WesternDigitsInputFormatter(maxLength: 11)],
          ),
          _Field(
            label: 'عنوان السكن',
            hintText: 'المدينة — الحي — أقرب نقطة دالة',
            controller: _homeAddressController,
            maxLines: 2,
          ),
          const SizedBox(height: 4),
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
                  title: 'صورة الدراجة',
                  subtitle: 'صورة الدراجة المستخدمة',
                  imageRef: _vehicleImageRef,
                  icon: Icons.motorcycle_rounded,
                  onTap: _isUploadingImage ? () {} : _pickVehicleImage,
                ),
              ),
            ],
          ),
          if (_isUploadingImage) ...[
            const SizedBox(height: 8),
            const Center(child: CupertinoActivityIndicator()),
          ],
          if ((_profileImageRef != null && _profileImageRef!.isNotEmpty) ||
              (_vehicleImageRef != null && _vehicleImageRef!.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (_profileImageRef != null && _profileImageRef!.isNotEmpty)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(
                        imageData: _profileImageRef,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (_profileImageRef != null &&
                    _profileImageRef!.isNotEmpty &&
                    _vehicleImageRef != null &&
                    _vehicleImageRef!.isNotEmpty)
                  const SizedBox(width: 10),
                if (_vehicleImageRef != null && _vehicleImageRef!.isNotEmpty)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(
                        imageData: _vehicleImageRef,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (!isEditing) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving || _isUploadingImage
                    ? null
                    : () => provider.setUserRole('customer'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'رجوع بدون إكمال',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF145B66),
                  side: const BorderSide(color: Color(0xFF145B66)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFF007A7A),
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(vertical: 15),
              onPressed: _isSaving || _isUploadingImage
                  ? null
                  : () => _save(provider, isEditing: isEditing),
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(
                      isEditing ? 'حفظ التعديلات' : 'حفظ وتفعيل حساب المندوب',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
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
  final List<TextInputFormatter> inputFormatters;

  const _Field({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
