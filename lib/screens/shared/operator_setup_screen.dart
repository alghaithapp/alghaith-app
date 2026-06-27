import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../modules/taxi/models/taxi_request.dart';
import '../../modules/taxi/widgets/taxi_type_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/utils/western_digits_input_formatter.dart';
import '../../providers/app_provider.dart';
import '../../utils/courier_profile_fields.dart';
import '../../utils/driver_profile_fields.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../modules/merchant/widgets/merchant_image_upload_slot.dart';

class OperatorSetupScreen extends StatefulWidget {
  final String role;
  const OperatorSetupScreen({super.key, required this.role});

  @override
  State<OperatorSetupScreen> createState() => _OperatorSetupScreenState();
}

class _OperatorSetupScreenState extends State<OperatorSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _homeAddressController;
  late final TextEditingController _mukhtarNameController;
  late final TextEditingController _plateController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _areaController;
  String? _profileImageRef;
  String? _vehicleImageRef;
  String? _idFrontImageRef;
  String? _idBackImageRef;
  String? _residenceCardImageRef;
  String? _vehicleRegFrontImageRef;
  String? _vehicleRegBackImageRef;
  String _selectedTaxiType = '';
  bool _isUploadingImage = false;
  bool _isSaving = false;

  bool get _isDriver => widget.role == 'driver';

  bool get _isCarTaxi => _selectedTaxiType == 'economic';

  String get _vehicleImageTitle {
    switch (_selectedTaxiType) {
      case 'tuktuk':
        return 'صورة التكتك';
      case 'wazz':
        return 'صورة الواز';
      default:
        return 'صورة السيارة';
    }
  }

  String get _vehicleImageSubtitle {
    switch (_selectedTaxiType) {
      case 'tuktuk':
        return 'صورة واضحة للتكتك';
      case 'wazz':
        return 'صورة واضحة للدراجة';
      default:
        return 'صورة واضحة للمركبة';
    }
  }

  IconData get _vehicleImageIcon {
    switch (_selectedTaxiType) {
      case 'tuktuk':
        return Icons.electric_rickshaw_rounded;
      case 'wazz':
        return Icons.two_wheeler_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_isDriver) {
      final profile = provider.driverProfile;
      _nameController = TextEditingController(
        text: DriverProfileFields.name(profile),
      );
      _phoneController = TextEditingController(
        text: DriverProfileFields.phone(profile).isNotEmpty
            ? DriverProfileFields.phone(profile)
            : (provider.authPhone ?? '').trim(),
      );
      _homeAddressController = TextEditingController(
        text: DriverProfileFields.homeAddress(profile),
      );
      _mukhtarNameController = TextEditingController(
        text: DriverProfileFields.mukhtarName(profile),
      );
      _plateController = TextEditingController(
        text: DriverProfileFields.plate(profile),
      );
      _vehicleController = TextEditingController(
        text: DriverProfileFields.vehicle(profile),
      );
      _areaController = TextEditingController(
        text: DriverProfileFields.area(profile),
      );
      _profileImageRef = DriverProfileFields.profileImage(profile).isNotEmpty
          ? DriverProfileFields.profileImage(profile)
          : null;
      _vehicleImageRef = DriverProfileFields.carImage(profile).isNotEmpty
          ? DriverProfileFields.carImage(profile)
          : null;
      _idFrontImageRef = DriverProfileFields.idFrontImage(profile).isNotEmpty
          ? DriverProfileFields.idFrontImage(profile)
          : null;
      _idBackImageRef = DriverProfileFields.idBackImage(profile).isNotEmpty
          ? DriverProfileFields.idBackImage(profile)
          : null;
      _residenceCardImageRef =
          DriverProfileFields.residenceCardImage(profile).isNotEmpty
              ? DriverProfileFields.residenceCardImage(profile)
              : null;
      _vehicleRegFrontImageRef =
          DriverProfileFields.vehicleRegFrontImage(profile).isNotEmpty
              ? DriverProfileFields.vehicleRegFrontImage(profile)
              : null;
      _vehicleRegBackImageRef =
          DriverProfileFields.vehicleRegBackImage(profile).isNotEmpty
              ? DriverProfileFields.vehicleRegBackImage(profile)
              : null;
      _selectedTaxiType = profile?['taxiType']?.toString().trim() ?? '';
    } else {
      final profile = provider.courierProfile ?? {};
      _nameController = TextEditingController(
        text: CourierProfileFields.name(profile),
      );
      _phoneController = TextEditingController(
        text: CourierProfileFields.phone(profile).isNotEmpty
            ? CourierProfileFields.phone(profile)
            : (provider.authPhone ?? '').trim(),
      );
      _homeAddressController = TextEditingController(
        text: CourierProfileFields.homeAddress(profile),
      );
      _mukhtarNameController = TextEditingController(
        text: CourierProfileFields.mukhtarName(profile),
      );
      _plateController = TextEditingController();
      _vehicleController = TextEditingController();
      _areaController = TextEditingController();
      _profileImageRef = CourierProfileFields.profileImage(profile).isNotEmpty
          ? CourierProfileFields.profileImage(profile)
          : null;
      _vehicleImageRef = CourierProfileFields.vehicleImage(profile).isNotEmpty
          ? CourierProfileFields.vehicleImage(profile)
          : null;
      _idFrontImageRef = CourierProfileFields.idFrontImage(profile).isNotEmpty
          ? CourierProfileFields.idFrontImage(profile)
          : null;
      _idBackImageRef = CourierProfileFields.idBackImage(profile).isNotEmpty
          ? CourierProfileFields.idBackImage(profile)
          : null;
      _residenceCardImageRef =
          CourierProfileFields.residenceCardImage(profile).isNotEmpty
              ? CourierProfileFields.residenceCardImage(profile)
              : null;
      _vehicleRegFrontImageRef = null;
      _vehicleRegBackImageRef = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    _mukhtarNameController.dispose();
    _plateController.dispose();
    _vehicleController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required String errorMessage,
    required void Function(String url) onUrl,
  }) async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<AppProvider>().uploadImage(File(picked.path));
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        _showMessage(errorMessage);
        return;
      }
      onUrl(url.trim());
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickProfileImage() => _pickImage(
        errorMessage: 'تعذر رفع الصورة الشخصية، حاول مرة أخرى',
        onUrl: (url) => _profileImageRef = url,
      );

  Future<void> _pickVehicleImage() => _pickImage(
        errorMessage: _isDriver
            ? 'تعذر رفع صورة السيارة، حاول مرة أخرى'
            : 'تعذر رفع صورة الدراجة، حاول مرة أخرى',
        onUrl: (url) => _vehicleImageRef = url,
      );

  Future<void> _pickIdFrontImage() => _pickImage(
        errorMessage: 'تعذر رفع صورة البطاقة الموحدة (الوجه)، حاول مرة أخرى',
        onUrl: (url) => _idFrontImageRef = url,
      );

  Future<void> _pickIdBackImage() => _pickImage(
        errorMessage: 'تعذر رفع صورة البطاقة الموحدة (الظهر)، حاول مرة أخرى',
        onUrl: (url) => _idBackImageRef = url,
      );

  Future<void> _pickResidenceCardImage() => _pickImage(
        errorMessage: 'تعذر رفع صورة بطاقة السكن، حاول مرة أخرى',
        onUrl: (url) => _residenceCardImageRef = url,
      );

  Future<void> _pickVehicleRegFrontImage() => _pickImage(
        errorMessage: 'تعذر رفع صورة سنوية السيارة (الوجه)، حاول مرة أخرى',
        onUrl: (url) => _vehicleRegFrontImageRef = url,
      );

  Future<void> _pickVehicleRegBackImage() => _pickImage(
        errorMessage: 'تعذر رفع صورة سنوية السيارة (الظهر)، حاول مرة أخرى',
        onUrl: (url) => _vehicleRegBackImageRef = url,
      );

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
    final mukhtarName = _mukhtarNameController.text.trim();
    final plate = _plateController.text.trim();
    final vehicle = _vehicleController.text.trim();
    final area = _areaController.text.trim();
    final profileImage = _profileImageRef?.trim() ?? '';
    final vehicleImage = _vehicleImageRef?.trim() ?? '';
    final idFrontImage = _idFrontImageRef?.trim() ?? '';
    final idBackImage = _idBackImageRef?.trim() ?? '';
    final residenceCardImage = _residenceCardImageRef?.trim() ?? '';
    final vehicleRegFrontImage = _vehicleRegFrontImageRef?.trim() ?? '';
    final vehicleRegBackImage = _vehicleRegBackImageRef?.trim() ?? '';

    if (_isDriver) {
      if (name.isEmpty) {
        _showMessage('أدخل الاسم الرباعي');
        return;
      }
    } else {
      if (!CourierProfileFields.isTripleName(name)) {
        _showMessage('أدخل الاسم الثلاثي (الاسم الأول + الأب + العائلة)');
        return;
      }
    }
    if (phone.length < 10) {
      _showMessage(
        _isDriver ? 'أدخل رقم هاتف صحيح' : 'أدخل رقم هاتف صحيح مفعّل على واتساب',
      );
      return;
    }
    if (homeAddress.isEmpty) {
      _showMessage(_isDriver ? 'أدخل عنوانك الحالي' : 'أدخل عنوان السكن');
      return;
    }
    if (mukhtarName.isEmpty) {
      _showMessage('أدخل اسم المختار');
      return;
    }
    if (_isDriver) {
      if (_selectedTaxiType != 'tuktuk' &&
          _selectedTaxiType != 'wazz' &&
          _selectedTaxiType != 'economic') {
        _showMessage('اختر نوع الخدمة: تكتك، واز، أو تكسي اقتصادي');
        return;
      }
      if (plate.isEmpty) {
        _showMessage(_isCarTaxi
            ? 'أدخل رقم لوحة السيارة'
            : 'أدخل رقم لوحة المركبة');
        return;
      }
      if (vehicle.isEmpty) {
        _showMessage(_isCarTaxi
            ? 'أدخل نوع السيارة'
            : 'أدخل نوع المركبة');
        return;
      }
      if (area.isEmpty) {
        _showMessage('أدخل منطقة العمل');
        return;
      }
    }
    if (profileImage.isEmpty) {
      _showMessage('أضف صورتك الشخصية');
      return;
    }
    if (vehicleImage.isEmpty) {
      _showMessage(_isDriver ? 'أضف $_vehicleImageTitle' : 'أضف صورة للدراجة');
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
    if (_isDriver && _isCarTaxi) {
      if (vehicleRegFrontImage.isEmpty) {
        _showMessage('أضف صورة سنوية السيارة (الوجه الأمامي)');
        return;
      }
      if (vehicleRegBackImage.isEmpty) {
        _showMessage('أضف صورة سنوية السيارة (الوجه الخلفي)');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (_isDriver) {
        provider.setDriverType('taxi');
        final existingServices = provider.driverProfile?['services'];
        await provider.setDriverProfile({
          'type': 'taxi',
          'services': existingServices ?? {'taxi': true, 'delivery': false},
          'name': name,
          'phone': phone,
          'homeAddress': homeAddress,
          'mukhtarName': mukhtarName,
          'plate': plate,
          'plateNumber': plate,
          'vehicle': vehicle,
          'vehicleModel': vehicle,
          'taxiType': _selectedTaxiType,
          'area': area,
          'profileImage': profileImage,
          'carImage': vehicleImage,
          'idFrontImage': idFrontImage,
          'idBackImage': idBackImage,
          'residenceCardImage': residenceCardImage,
          'vehicleRegFrontImage': vehicleRegFrontImage,
          'vehicleRegBackImage': vehicleRegBackImage,
        });
      } else {
        await provider.setCourierProfile({
          'name': name,
          'phone': phone,
          'homeAddress': homeAddress,
          'mukhtarName': mukhtarName,
          'profileImage': profileImage,
          'vehicleImage': vehicleImage,
          'residenceCardImage': residenceCardImage,
          'idFrontImage': idFrontImage,
          'idBackImage': idBackImage,
          'available': provider.courierProfile?['available'] as bool? ?? false,
        });
      }
      if (!mounted) return;
      if (isEditing && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        _showMessage('تم حفظ التعديلات');
      } else {
        _showMessage('تم إرسال طلبك. سيتم تفعيل حسابك بعد موافقة الإدارة.');
      }
    } catch (e) {
      if (!mounted) return;
      if (_isDriver) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e', style: const TextStyle(fontFamily: 'Cairo')),
          ),
        );
      } else {
        _showMessage('حدث خطأ أثناء الحفظ: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _previewThumb(String ref, String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
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
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = _isDriver ? provider.driverProfile : null;
    final hasProfile = _isDriver
        ? (profile != null && profile.isNotEmpty)
        : provider.hasCourierRegistration;
    final isEditing = hasProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
          isEditing
              ? (_isDriver ? 'تعديل ملف السائق' : 'تعديل ملف المندوب')
              : (_isDriver ? 'تسجيل سائق تكسي' : 'تسجيل مندوب توصيل'),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(isEditing),
          const SizedBox(height: 16),
          if (_isDriver) ...[
            const _SectionTitle(text: 'البيانات الشخصية'),
            const SizedBox(height: 8),
          ],
          _Field(
            label: _isDriver ? 'الاسم الرباعي' : 'الاسم الثلاثي',
            hintText: _isDriver
                ? 'الاسم الأول — اسم الأب — اسم الجد — العائلة'
                : 'مثال: محمد علي حسين',
            controller: _nameController,
          ),
          _Field(
            label: 'رقم الهاتف (واتساب)',
            hintText:
                _isDriver ? 'رقم مفعّل على واتساب' : 'يجب أن يكون رقم واتساب فعّال',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: _isDriver
                ? const []
                : const [WesternDigitsInputFormatter(maxLength: 11)],
          ),
          _Field(
            label: _isDriver ? 'العنوان الحالي' : 'عنوان السكن',
            hintText: _isDriver
                ? 'المدينة — الحي — الشارع'
                : 'المدينة — الحي — أقرب نقطة دالة',
            controller: _homeAddressController,
            maxLines: 2,
          ),
          _Field(
            label: 'اسم المختار',
            hintText: _isDriver
                ? 'أدخل اسم مختار منطقتك'
                : 'أدخل اسم مختار المنطقة',
            controller: _mukhtarNameController,
          ),
          if (_isDriver) ...[
            const SizedBox(height: 20),
            const _SectionTitle(text: 'نوع الخدمة'),
            const SizedBox(height: 8),
            _TaxiTypePicker(
              selected: _selectedTaxiType,
              onChanged: (value) => setState(() => _selectedTaxiType = value),
            ),
            const SizedBox(height: 20),
            const _SectionTitle(text: 'بيانات المركبة'),
            const SizedBox(height: 8),
            _Field(
              label: _isCarTaxi ? 'نوع السيارة' : 'نوع المركبة',
              hintText: _selectedTaxiType == 'tuktuk'
                  ? 'مثال: تكتك — ركشة'
                  : _selectedTaxiType == 'wazz'
                      ? 'مثال: دراجة نارية — هوندا'
                      : 'مثال: سيارة صالون — تاكسي',
              controller: _vehicleController,
            ),
            _Field(
              label: _isCarTaxi ? 'رقم لوحة السيارة' : 'رقم لوحة المركبة',
              hintText: 'مثال: 12345 بغداد',
              controller: _plateController,
            ),
            _Field(
              label: 'منطقة العمل',
              hintText: 'المدينة أو المنطقة التي ستعمل بها',
              controller: _areaController,
            ),
          ],
          if (_isDriver) ...[
            const SizedBox(height: 20),
            const _SectionTitle(text: 'الصور الثبوتية'),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 4),
          ],
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
                  title: _isDriver ? _vehicleImageTitle : 'صورة الدراجة',
                  subtitle: _isDriver
                      ? _vehicleImageSubtitle
                      : 'صورة الدراجة المستخدمة',
                  imageRef: _vehicleImageRef,
                  icon: _isDriver
                      ? _vehicleImageIcon
                      : Icons.motorcycle_rounded,
                  onTap: _isUploadingImage ? () {} : _pickVehicleImage,
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
                  title: _isDriver ? 'البطاقة الموحدة (الوجه)' : 'الموحدة (الوجه)',
                  subtitle: 'الوجه الأمامي',
                  imageRef: _idFrontImageRef,
                  icon: Icons.badge_rounded,
                  onTap: _isUploadingImage ? () {} : _pickIdFrontImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MerchantImageUploadSlot(
                  title: _isDriver ? 'البطاقة الموحدة (الظهر)' : 'الموحدة (الظهر)',
                  subtitle: 'الوجه الخلفي',
                  imageRef: _idBackImageRef,
                  icon: Icons.badge_rounded,
                  onTap: _isUploadingImage ? () {} : _pickIdBackImage,
                ),
              ),
            ],
          ),
          if (_isDriver && _isCarTaxi) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: MerchantImageUploadSlot(
                    title: 'سنوية السيارة (الوجه)',
                    subtitle: 'الوجه الأمامي لإجازة السنوية',
                    imageRef: _vehicleRegFrontImageRef,
                    icon: Icons.description_rounded,
                    onTap: _isUploadingImage ? () {} : _pickVehicleRegFrontImage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MerchantImageUploadSlot(
                    title: 'سنوية السيارة (الظهر)',
                    subtitle: 'الوجه الخلفي لإجازة السنوية',
                    imageRef: _vehicleRegBackImageRef,
                    icon: Icons.description_rounded,
                    onTap: _isUploadingImage ? () {} : _pickVehicleRegBackImage,
                  ),
                ),
              ],
            ),
          ],
          if (_isUploadingImage) ...[
            const SizedBox(height: 8),
            const Center(child: CupertinoActivityIndicator()),
          ],
          if (_hasPreviews) ...[
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
                children: _previewThumbs,
              ),
            ),
          ],
          if (!isEditing && !_isDriver) ...[
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
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: _isSaving || _isUploadingImage
                  ? null
                  : () => _save(provider, isEditing: isEditing),
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(
                      isEditing
                          ? 'حفظ التعديلات'
                          : (_isDriver
                              ? 'إرسال طلب التفعيل'
                              : 'حفظ وتفعيل حساب المندوب'),
                      style: const TextStyle(
                        color: Colors.white,
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

  bool get _hasPreviews {
    if (_isDriver) {
      return (_profileImageRef != null && _profileImageRef!.isNotEmpty) ||
          (_vehicleImageRef != null && _vehicleImageRef!.isNotEmpty) ||
          (_residenceCardImageRef != null &&
              _residenceCardImageRef!.isNotEmpty) ||
          (_idFrontImageRef != null && _idFrontImageRef!.isNotEmpty) ||
          (_idBackImageRef != null && _idBackImageRef!.isNotEmpty) ||
          (_vehicleRegFrontImageRef != null &&
              _vehicleRegFrontImageRef!.isNotEmpty) ||
          (_vehicleRegBackImageRef != null &&
              _vehicleRegBackImageRef!.isNotEmpty);
    }
    return (_profileImageRef != null && _profileImageRef!.isNotEmpty) ||
        (_vehicleImageRef != null && _vehicleImageRef!.isNotEmpty) ||
        (_residenceCardImageRef != null &&
            _residenceCardImageRef!.isNotEmpty) ||
        (_idFrontImageRef != null && _idFrontImageRef!.isNotEmpty) ||
        (_idBackImageRef != null && _idBackImageRef!.isNotEmpty);
  }

  List<Widget> get _previewThumbs {
    final thumbs = <Widget>[];
    if (_profileImageRef != null) {
      thumbs.add(_previewThumb(_profileImageRef!, 'شخصية'));
    }
    if (_vehicleImageRef != null) {
      thumbs.add(_previewThumb(_vehicleImageRef!, _isDriver ? 'سيارة' : 'دراجة'));
    }
    if (_residenceCardImageRef != null) {
      thumbs.add(_previewThumb(_residenceCardImageRef!, 'سكن'));
    }
    if (_idFrontImageRef != null) {
      thumbs.add(
        _previewThumb(_idFrontImageRef!, _isDriver ? 'موحدة-وجه' : 'موحدة-1'),
      );
    }
    if (_idBackImageRef != null) {
      thumbs.add(
        _previewThumb(_idBackImageRef!, _isDriver ? 'موحدة-ظهر' : 'موحدة-2'),
      );
    }
    if (_isDriver) {
      if (_vehicleRegFrontImageRef != null) {
        thumbs.add(_previewThumb(_vehicleRegFrontImageRef!, 'سنوية-وجه'));
      }
      if (_vehicleRegBackImageRef != null) {
        thumbs.add(_previewThumb(_vehicleRegBackImageRef!, 'سنوية-ظهر'));
      }
    }
    return thumbs;
  }

  Widget _buildHeroCard(bool isEditing) {
    return Container(
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
            child: Icon(
              _isDriver ? Icons.local_taxi_rounded : Icons.motorcycle,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDriver ? 'حساب سائق تكسي' : 'بيانات مندوب التوصيل',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditing
                      ? 'أكمل البيانات والمستندات الناقصة لتفعيل حسابك.'
                      : (_isDriver
                          ? 'اختر نوع الخدمة (تكتك، واز، أو تكسي)، ثم أكمل بياناتك والمستندات.'
                          : 'الاسم الثلاثي، الهاتف، عنوان السكن، اسم المختار، والصور الثبوتية مطلوبة للتفعيل.'),
                  style: const TextStyle(
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
    );
  }
}

class _TaxiTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TaxiTypePicker({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (id: 'tuktuk', type: TaxiType.tuktuk),
      (id: 'wazz', type: TaxiType.wazz),
      (id: 'economic', type: TaxiType.economic),
    ];

    return Column(
      children: [
        for (final option in options) ...[
          _TaxiTypeOptionCard(
            type: option.type,
            isSelected: selected == option.id,
            onTap: () => onChanged(option.id),
          ),
          if (option.id != 'economic') const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TaxiTypeOptionCard extends StatelessWidget {
  final TaxiType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaxiTypeOptionCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              TaxiTypeImage(
                type: type,
                width: 52,
                height: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.labelAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      type.subtitleAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
            ],
          ),
        ),
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
