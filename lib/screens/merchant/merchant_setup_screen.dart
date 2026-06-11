import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/marketplace_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../services/image_storage_service.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_profile_fields.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import '../../widgets/location_picker_screen.dart';
import '../../widgets/merchant/merchant_image_upload_slot.dart';
import '../../widgets/merchant/merchant_working_hours_picker.dart';

class MerchantSetupScreen extends StatefulWidget {
  const MerchantSetupScreen({super.key});

  @override
  State<MerchantSetupScreen> createState() => _MerchantSetupScreenState();
}

class _MerchantSetupScreenState extends State<MerchantSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _openTime = '';
  String _closeTime = '';
  final TextEditingController _deliveryFeeController = TextEditingController();

  final List<String> _selectedServiceIds = ['restaurant'];
  String? _coverImageBase64;
  String? _logoImageBase64;
  String? _profileImageBase64;
  final List<String> _workSampleImagesBase64 = [];
  String? _selectedProfessionalCategoryId;
  String? _selectedRestaurantCategory;
  double? _storeLatitude;
  double? _storeLongitude;

  String get _primaryServiceId => _selectedServiceIds.first;

  String _resolveWhatsAppNumber() {
    final whatsapp = _whatsappController.text.trim();
    if (whatsapp.isNotEmpty) return whatsapp;
    return _phoneController.text.trim();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  bool get _isProfessionalSetup =>
      _selectedServiceIds.contains('professionals');

  bool get _isRestaurantSetup => _primaryServiceId == 'restaurant';
  bool get _requiresStoreLocation =>
      _selectedServiceIds.contains('restaurant') ||
      _selectedServiceIds.contains('product');

  bool get _showsStoreBrandingImages =>
      _selectedServiceIds.contains('restaurant') ||
      _selectedServiceIds.contains('product');

  String get _brandingServiceId {
    if (_selectedServiceIds.contains('restaurant')) return 'restaurant';
    if (_selectedServiceIds.contains('product')) return 'product';
    return _primaryServiceId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (_nameController.text.isEmpty)
        _nameController.text = provider.merchantStoreName;
      if (_descController.text.isEmpty)
        _descController.text = provider.merchantDescription;
      if (_phoneController.text.isEmpty)
        _phoneController.text = provider.merchantPhone;
      if (_whatsappController.text.isEmpty) {
        _whatsappController.text =
            (provider.merchantStore?['whatsapp'] as String?)?.trim() ?? '';
      }
      if (_addressController.text.isEmpty) {
        _addressController.text = provider.merchantAddress;
      }
      if (_openTime.isEmpty) {
        setState(() => _openTime = provider.merchantOpenTime);
      }
      if (_closeTime.isEmpty) {
        setState(() => _closeTime = provider.merchantCloseTime);
      }
      if (_deliveryFeeController.text.isEmpty &&
          provider.merchantDeliveryFee > 0) {
        _deliveryFeeController.text = provider.merchantDeliveryFee.toString();
      }
      _coverImageBase64 ??=
          ImageStorageService.merchantUploadedImageRef(provider.merchantCoverImage);
      _logoImageBase64 ??=
          ImageStorageService.merchantUploadedImageRef(provider.merchantLogoImage);
      _profileImageBase64 ??=
          ImageStorageService.merchantUploadedImageRef(
            provider.merchantProfileImageBase64,
          );
      _selectedProfessionalCategoryId ??=
          provider.merchantProfessionalCategoryId;
      _selectedRestaurantCategory ??=
          provider.merchantStore?['restaurantCategory']?.toString();
      _storeLatitude ??= provider.merchantLatitude;
      _storeLongitude ??= provider.merchantLongitude;
      if (_workSampleImagesBase64.isEmpty) {
        _workSampleImagesBase64.addAll(
          provider.merchantWorkSampleImagesBase64.where(
            ImageStorageService.isMerchantUploadedImage,
          ),
        );
      }
      setState(() {});
    });
  }

  String? get _selectedProfessionalCategoryNameAr {
    final id = _selectedProfessionalCategoryId;
    if (id == null || id.isEmpty) return null;
    final category = DummyData.professionalsSubCategories.firstWhere(
      (item) => item.id == id,
      orElse: () => DummyData.professionalsSubCategories.first,
    );
    return category.titleAr;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final labels = merchantServiceLabels(_primaryServiceId);
    final brandLabels = merchantServiceLabels(_brandingServiceId);
    final hideFee = _primaryServiceId == 'professionals' ||
        _primaryServiceId == 'restaurant';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }
            appProvider.setUserRole('customer');
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.back,
                color: CupertinoColors.activeBlue,
                size: 20,
              ),
              SizedBox(width: 4),
              Text(
                'رجوع',
                style: TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontFamily: 'Cairo',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        middle: Text(
          labels.accountTitleAr,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentDark,
                        AppColors.accent
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.storefront,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels.dashboardGreetingAr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              labels.dashboardIntroAr,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                                fontSize: 12,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('معلومات ${labels.storeLabelAr}'),
                    const SizedBox(height: 12),
                    _buildField(
                        _isProfessionalSetup
                            ? 'اسم صاحب المهنة'
                            : 'اسم ${labels.storeLabelAr}',
                        _nameController),
                    const SizedBox(height: 14),
                    _buildField(
                        _isProfessionalSetup
                            ? 'وصف المهنة'
                            : 'وصف ${labels.storeLabelAr}',
                        _descController,
                        maxLines: 3),
                    const SizedBox(height: 14),
                    _buildField(
                      'رقم الهاتف (يجب أن يكون رقم واتساب)',
                      _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      'رقم واتساب (اختياري)',
                      _whatsappController,
                      hintText:
                          'اتركه فارغاً لاستخدام نفس رقم الهاتف أعلاه',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    if (_isProfessionalSetup) ...[
                      _sectionTitle('تخصص المهنة'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: DummyData.professionalsSubCategories.any(
                                (category) =>
                                    category.id ==
                                    _selectedProfessionalCategoryId)
                            ? _selectedProfessionalCategoryId
                            : null,
                        items: DummyData.professionalsSubCategories
                            .map((profession) {
                          return DropdownMenuItem<String>(
                            value: profession.id,
                            child: Text(
                              profession.titleAr,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(
                              () => _selectedProfessionalCategoryId = value);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F8FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (_isProfessionalSetup &&
                              (value == null || value.isEmpty)) {
                            return 'اختر تخصص المهنة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildField(
                        'العنوان', _addressController),
                    const SizedBox(height: 12),
                    _buildLocationCard(),
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _showsStoreBrandingImages
                          ? 'صورة ${brandLabels.storeLabelAr} وشعاره'
                          : (_isProfessionalSetup
                              ? 'الصورة الشخصية والأعمال'
                              : 'الصور والهوية'),
                    ),
                    const SizedBox(height: 12),
                    if (_showsStoreBrandingImages) ...[
                      MerchantImageUploadSlot(
                        title: brandLabels.coverLabelAr,
                        imageRef: _coverImageBase64,
                        icon: Icons.storefront_rounded,
                        onTap: _pickCoverImage,
                      ),
                      const SizedBox(height: 12),
                      MerchantImageUploadSlot(
                        title: brandLabels.logoLabelAr,
                        imageRef: _logoImageBase64,
                        icon: Icons.badge_rounded,
                        onTap: _pickLogoImage,
                      ),
                      if (_isRestaurantSetup) ...[
                        const SizedBox(height: 20),
                        _sectionTitle('تصنيف المطعم'),
                        const SizedBox(height: 6),
                        const Text(
                          'حدد التخصص الأساسي لمطعمك ليظهر في الفلتر الصحيح للزبائن.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ChoiceChip(
                                label: 'مشويات',
                                selected:
                                    _selectedRestaurantCategory == 'مشويات',
                                onTap: () => setState(
                                  () => _selectedRestaurantCategory = 'مشويات',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ChoiceChip(
                                label: 'وجبات سريعة',
                                selected: _selectedRestaurantCategory ==
                                    'وجبات سريعة',
                                onTap: () => setState(
                                  () => _selectedRestaurantCategory =
                                      'وجبات سريعة',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else if (_isProfessionalSetup) ...[
                      MerchantImageUploadSlot(
                        title: 'الصورة الشخصية',
                        imageRef: _profileImageBase64,
                        icon: Icons.person_rounded,
                        onTap: _pickProfileImage,
                      ),
                      const SizedBox(height: 12),
                      _SampleImagesRow(
                        title:
                            'صور نماذج الأعمال',
                        imagesBase64: _workSampleImagesBase64,
                        onAddTap: _pickWorkSamples,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _sectionTitle(
                        'الخدمات المشمولة'),
                    const SizedBox(height: 6),
                    Text(
                      'يمكنك اختيار أكثر من خدمة من نفس الحساب، ثم التبديل بينها لاحقًا من داخل حسابك.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: MarketplaceCatalog.merchantAvailableCategories.map((cat) {
                        final selected = _selectedServiceIds.contains(cat.id);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) {
                              // إلغاء التحديد — لكن يجب الإبقاء على خدمة واحدة على الأقل
                              if (_selectedServiceIds.length == 1) return;
                              _selectedServiceIds.remove(cat.id);
                            } else {
                              // إضافة وجعلها الخدمة الأساسية
                              _selectedServiceIds.remove(cat.id);
                              _selectedServiceIds.insert(0, cat.id);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.accent : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              cat.titleAr,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط على أي خدمة لتجعلها الخدمة الأساسية أثناء تعبئة البيانات.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(
                        hideFee
                            ? 'أوقات وإعدادات ${labels.storeLabelAr}'
                            : 'أوقات ورسوم ${labels.storeLabelAr}'),
                    const SizedBox(height: 12),
                    MerchantWorkingHoursPicker(
                      openTime: _openTime,
                      closeTime: _closeTime,
                      onOpenTimeChanged: (value) =>
                          setState(() => _openTime = value),
                      onCloseTimeChanged: (value) =>
                          setState(() => _closeTime = value),
                    ),
                    const SizedBox(height: 14),
                    if (!hideFee) ...[
                      _buildField(
                        'رسوم ${labels.storeLabelAr}',
                        _deliveryFeeController,
                        keyboardType: TextInputType.number,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'لا توجد رسوم مباشرة على الزبون. التواصل والتفاهم يتم بين الطرفين فقط.',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ملاحظات',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'بعد الحفظ سيتم تفعيل الحساب وفتح لوحة التحكم ببياناتك أنت فقط.',
                            style: const TextStyle(
                              color: Colors.grey,
                              height: 1.45,
                              fontSize: 13,
                              fontFamily: 'Cairo',
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            _showMessage('يرجى إدخال الاسم أولاً');
                            return;
                          }

                          if (_showsStoreBrandingImages) {
                            if (!ImageStorageService
                                    .isMerchantUploadedImage(_coverImageBase64) ||
                                !ImageStorageService
                                    .isMerchantUploadedImage(_logoImageBase64)) {
                              _showMessage(
                                'يرجى رفع ${brandLabels.coverLabelAr} و${brandLabels.logoLabelAr}',
                              );
                              return;
                            }
                          }
                          if (_isRestaurantSetup) {
                            if (_selectedRestaurantCategory == null) {
                              _showMessage('يرجى اختيار تصنيف المطعم (مشويات أو وجبات سريعة)');
                              return;
                            }
                          }

                          if (_isProfessionalSetup) {
                            final address = _addressController.text.trim();
                            final phone = _phoneController.text.trim();
                            final openTime = _openTime.trim();
                            final closeTime = _closeTime.trim();
                            final professionId =
                                _selectedProfessionalCategoryId;
                            if (address.isEmpty ||
                                phone.isEmpty ||
                                openTime.isEmpty ||
                                closeTime.isEmpty ||
                                professionId == null ||
                                professionId.isEmpty) {
                              _showMessage('يرجى إكمال بيانات صاحب المهنة');
                              return;
                            }
                          }
                          if (_requiresStoreLocation &&
                              (_storeLatitude == null ||
                                  _storeLongitude == null)) {
                            _showMessage('حدد موقع ${labels.storeLabelAr} على الخريطة أولاً');
                            return;
                          }
                          if (_openTime.trim().isEmpty ||
                              _closeTime.trim().isEmpty) {
                            _showMessage(
                                'يرجى تحديد وقت الافتتاح ووقت الإغلاق');
                            return;
                          }

                          try {
                            await appProvider.setMerchantStore({
                            'name': name,
                            'description': _descController.text.trim(),
                            'category': _primaryServiceId,
                            'serviceIds':
                                List<String>.from(_selectedServiceIds),
                            'activeServiceId': _primaryServiceId,
                            'image': '',
                            'coverImageBase64': _coverImageBase64,
                            'logoImageBase64': _logoImageBase64,
                            'restaurantCategory': _selectedRestaurantCategory,
                            'profileImageBase64': _isRestaurantSetup
                                ? _logoImageBase64
                                : _profileImageBase64,
                            'phone': _phoneController.text.trim(),
                            'whatsapp': _resolveWhatsAppNumber(),
                            'address': _addressController.text.trim(),
                            'latitude': _storeLatitude,
                            'longitude': _storeLongitude,
                            'openTime': _openTime.trim(),
                            'closeTime': _closeTime.trim(),
                            'deliveryFee': hideFee
                                ? 0
                                : int.tryParse(
                                        _deliveryFeeController.text.trim()) ??
                                    0,
                            'isOpen': true,
                            'rating': 0,
                            if (!_isRestaurantSetup)
                              'workSampleImagesBase64':
                                  List<String>.from(_workSampleImagesBase64),
                            'professionalInfo': _isProfessionalSetup
                                ? {
                                    'name': _nameController.text.trim(),
                                    'address': _addressController.text.trim(),
                                    'latitude': _storeLatitude,
                                    'longitude': _storeLongitude,
                                    'phone': _phoneController.text.trim(),
                                    'whatsapp': _resolveWhatsAppNumber(),
                                    'openTime': _openTime.trim(),
                                    'closeTime': _closeTime.trim(),
                                    'profileImageBase64': _profileImageBase64,
                                    'workSampleImagesBase64': List<String>.from(
                                        _workSampleImagesBase64),
                                    'professionId':
                                        _selectedProfessionalCategoryId,
                                    'professionNameAr':
                                        _selectedProfessionalCategoryNameAr,
                                    'professionNameEn':
                                        _selectedProfessionalCategoryId == null
                                            ? null
                                            : DummyData
                                                .professionalsSubCategories
                                                .firstWhere(
                                                  (item) =>
                                                      item.id ==
                                                      _selectedProfessionalCategoryId,
                                                )
                                                .titleEn,
                                  }
                                : null,
                            'professionalCategoryId':
                                _selectedProfessionalCategoryId,
                          });
                          await appProvider.activateMerchantRole();
                          } catch (error) {
                            _showMessage('تعذر حفظ بيانات التاجر: $error');
                          }
                        },
                        child: Text(
                          'حفظ وتفعيل ${labels.storeLabelAr}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                          ),
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

  Future<void> _pickProfileImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    final base64 = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (base64 != null) {
      setState(() {
        _profileImageBase64 = base64;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    final base64 = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (base64 != null) {
      setState(() {
        _coverImageBase64 = base64;
      });
    }
  }

  Future<void> _pickLogoImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    final base64 = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (base64 != null) {
      setState(() {
        _logoImageBase64 = base64;
      });
    }
  }

  Future<void> _pickWorkSamples() async {
    final picked = await AppHelpers.pickMultiImage(context);
    if (picked.isEmpty) return;
    
    final provider = context.read<AppProvider>();
    final images = <String>[];
    for (final image in picked) {
      final base64 = await provider.uploadImage(File(image.path));
      if (base64 != null) images.add(base64);
    }
    
    if (images.isNotEmpty) {
      setState(() {
        _workSampleImagesBase64
          ..clear()
          ..addAll(images);
      });
    }
  }

  Future<void> _pickStoreLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      CupertinoPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'تحديد موقع المتجر',
          initialLatitude: _storeLatitude,
          initialLongitude: _storeLongitude,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _storeLatitude = picked.latitude;
      _storeLongitude = picked.longitude;
      _addressController.text = picked.address;
    });
  }

  Widget _buildLocationCard() {
    final hasLocation = _storeLatitude != null && _storeLongitude != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لوكيشن المطعم على الخريطة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            MerchantProfileFields.locationSummary(
              address: _addressController.text.trim(),
              latitude: _storeLatitude,
              longitude: _storeLongitude,
            ).isNotEmpty
                ? 'العنوان: ${MerchantProfileFields.locationSummary(address: _addressController.text.trim(), latitude: _storeLatitude, longitude: _storeLongitude)}'
                : 'يرجى تحديد موقع المتجر على الخريطة وكتابة العنوان النصي.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.black87,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            onPressed: _pickStoreLocation,
            child: Text(
              hasLocation ? 'تعديل موقع المتجر' : 'تحديد موقع المتجر',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
        ),
        if (hintText != null && hintText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            hintText,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontFamily: 'Cairo',
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _SampleImagesRow extends StatelessWidget {
  final String title;
  final List<String> imagesBase64;
  final VoidCallback onAddTap;

  const _SampleImagesRow({
    required this.title,
    required this.imagesBase64,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imagesBase64.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == imagesBase64.length) {
                return GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            color: AppColors.accent, size: 30),
                        SizedBox(height: 6),
                        Text(
                          'إضافة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final image = imagesBase64[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AppImage(
                  imageData: image,
                  width: 110,
                  height: 110,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
