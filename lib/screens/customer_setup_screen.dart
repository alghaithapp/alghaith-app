import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
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
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBase64 = base64Encode(bytes);
    });
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
      try {
        await provider.updateCustomerProfile(
          name: name,
          phone: phone,
          address: _addressController.text.trim(),
          avatarBase64: _avatarBase64,
        );
      } catch (error) {
        debugPrint('Customer profile update skipped: $error');
      }
      await provider.setUserRole('customer');
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<AppProvider>().lang == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isAr ? 'إكمال ملف الزبون' : 'Complete customer profile',
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color:
                              const Color(0xFFE53935).withValues(alpha: 0.35),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child:
                            _avatarBase64 != null && _avatarBase64!.isNotEmpty
                                ? Image.memory(
                                    base64Decode(_avatarBase64!),
                                    fit: BoxFit.cover,
                                  )
                                : const AppLogo(size: 72, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isAr ? 'الصورة الشخصية' : 'Profile photo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Field(
                    label: isAr ? 'الاسم الكامل' : 'Full name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: isAr ? 'رقم الهاتف' : 'Phone number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: isAr ? 'العنوان' : 'Address',
                    controller: _addressController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A5A), Color(0xFFE53935)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          height: 54,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isAr ? 'حفظ ومتابعة' : 'Save and continue',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isAr
                        ? 'لن يظهر الحساب الكامل إلا بعد إدخال بياناتك الشخصية.'
                        : 'Your account will be ready after completing your personal details.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB5B5B5),
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

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD7D7D7),
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          padding: const EdgeInsets.all(14),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3B3B3B)),
          ),
        ),
      ],
    );
  }
}
