import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import '../../widgets/app_logo.dart';
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

  bool _isSaving = false;
  final List<String> _selectedServiceIds = []; // تبدأ فارغة ليقوم التاجر بالاختيار أولاً
  String? _coverImageBase64;
  String? _logoImageBase64;
  String? _profileImageBase64;
  final List<String> _workSampleImagesBase64 = [];
  String? _selectedProfessionalCategoryId;
  String? _selectedRestaurantCategory;
  String? _selectedServiceSubCategory; // للخدمات: جمال، سيارات، عقارات، سياحة
  double? _storeLatitude;
  double? _storeLongitude;

  String get _primaryServiceId =>
      _selectedServiceIds.isEmpty ? 'product' : _selectedServiceIds.first;

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

  bool get _awaitingProfessionPick =>
      _isProfessionalSetup &&
      (_selectedProfessionalCategoryId == null ||
          _selectedProfessionalCategoryId!.isEmpty);

  bool get _isRestaurantSetup => _primaryServiceId == 'restaurant';

  /// خدمات الجمال تُعرض كملف خدمة (صورة + هاتف + واتساب + ساعات) لا كمتجر منتجات
  bool get _isBeautySetup => _primaryServiceId == 'beauty';

  bool get _hasServiceSubCategories =>
      const {'beauty', 'cars', 'real_estate', 'tourism'}.contains(_primaryServiceId);

  List<String> get _serviceSubCategories {
    switch (_primaryServiceId) {
      case 'beauty':
        return ['صالون رجالي', 'صالون نسائي', 'عيادة تجميل', 'صيدلية'];
      case 'cars':
        return ['بيع وشراء', 'تأجير', 'قطع غيار', 'صيانة'];
      case 'real_estate':
        return ['بيع', 'إيجار', 'مكتب عقاري'];
      case 'tourism':
        return ['رحلات', 'فنادق', 'تأشيرات'];
      default:
        return [];
    }
  }

  String get _serviceSubCategoryLabel {
    switch (_primaryServiceId) {
      case 'beauty': return 'تخصص النشاط';
      case 'cars': return 'نوع النشاط';
      case 'real_estate': return 'نوع الخدمة العقارية';
      case 'tourism': return 'نوع الخدمة السياحية';
      default: return 'التخصص';
    }
  }

  bool _isLocationRequiredFor(String serviceId) {
    return const {
      'restaurant',
      'product',
      'beauty',
      'professionals',
      'real_estate',
      'offers'
    }.contains(serviceId);
  }

  bool get _requiresStoreLocation => _isLocationRequiredFor(_primaryServiceId);

  String _locationTitleFor(String serviceId) {
    switch (serviceId) {
      case 'bazar_ghaith':
        return 'لوكيشن متجرك في بازار الغيث';
      case 'restaurant':
        return 'لوكيشن المطعم على الخريطة';
      case 'product':
        return 'لوكيشن المتجر على الخريطة';
      case 'offers':
      case 'professionals':
      case 'tourism':
        return 'موقعك الحالي على الخريطة';
      default:
        return 'تحديد موقعك على الخريطة';
    }
  }

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
      // استعادة الأقسام من حساب مُسجَّل مسبقاً أو من إعداد موجود
      if (_selectedServiceIds.isEmpty) {
        final existingServices = provider.merchantServiceIds;
        if (existingServices.isNotEmpty) {
          _selectedServiceIds.addAll(existingServices);
        } else if (provider.hasCompletedMerchantProfile) {
          final category = provider.merchantStore?['category']?.toString();
          if (category != null && category.isNotEmpty) {
            _selectedServiceIds.add(category);
          }
        }
      }
      _selectedProfessionalCategoryId ??=
          provider.merchantProfessionalCategoryId;
      _selectedRestaurantCategory ??=
          provider.merchantStore?['restaurantCategory']?.toString();
      _selectedServiceSubCategory ??=
          provider.merchantStore?['serviceSubCategory']?.toString();
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
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _handleBack(AppProvider appProvider) {
    if (_awaitingProfessionPick) {
      setState(() {
        _selectedServiceIds.clear();
        _selectedProfessionalCategoryId = null;
      });
      return;
    }
    if (_isProfessionalSetup && _selectedProfessionalCategoryId != null) {
      setState(() => _selectedProfessionalCategoryId = null);
      return;
    }
    if (_selectedServiceIds.isNotEmpty) {
      setState(() {
        _selectedServiceIds.clear();
        _selectedProfessionalCategoryId = null;
      });
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    appProvider.setUserRole('customer');
  }

  String _navigationTitle(MerchantServiceLabels labels) {
    if (_selectedServiceIds.isEmpty) return 'إنشاء حساب تجاري';
    if (_awaitingProfessionPick) return 'اختر تخصصك المهني';
    if (_isProfessionalSetup) return 'إعداد ملف المهنة';
    return labels.accountTitleAr;
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
          onPressed: () => _handleBack(appProvider),
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
          _navigationTitle(labels),
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: _selectedServiceIds.isEmpty
            ? _buildInitialActivitySelection()
            : _awaitingProfessionPick
                ? _buildProfessionPicker()
                : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF004D4D), Color(0xFF007A7A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007A7A).withValues(alpha: 0.18),
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
                            _sectionTitle('تخصصك المهني'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF007A7A)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AppImage(
                                      imageData: DummyData
                                          .professionalsSubCategories
                                          .firstWhere(
                                            (item) =>
                                                item.id ==
                                                _selectedProfessionalCategoryId,
                                            orElse: () => DummyData
                                                .professionalsSubCategories
                                                .first,
                                          )
                                          .image,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedProfessionalCategoryNameAr ??
                                          'تخصص غير محدد',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minSize: 0,
                                    onPressed: () => setState(
                                      () => _selectedProfessionalCategoryId =
                                          null,
                                    ),
                                    child: const Text(
                                      'تغيير',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (_isProfessionalSetup) ...[
                            _sectionTitle('العنوان والموقع'),
                            const SizedBox(height: 6),
                            const Text(
                              'أدخل عنوانك وحدده على الخريطة — مطلوب لظهور ملفك للزبائن.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                height: 1.5,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              'العنوان (مطلوب)',
                              _addressController,
                              maxLines: 2,
                              hintText:
                                  'مثال: بغداد، الكرادة، شارع ...',
                            ),
                            const SizedBox(height: 12),
                            _buildLocationCard(required: true),
                          ] else ...[
                            _buildField('العنوان', _addressController),
                            const SizedBox(height: 12),
                            _buildLocationCard(),
                          ],
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
                                      selected: _selectedRestaurantCategory ==
                                          'مشويات',
                                      onTap: () => setState(
                                        () => _selectedRestaurantCategory =
                                            'مشويات',
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
                            if (_hasServiceSubCategories) ...[
                              const SizedBox(height: 20),
                              _sectionTitle(_serviceSubCategoryLabel),
                              const SizedBox(height: 6),
                              Text(
                                'حدد نوع نشاطك ليظهر في القسم المناسب للزبائن.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _serviceSubCategories.map((sub) => _ChoiceChip(
                                  label: sub,
                                  selected: _selectedServiceSubCategory == sub,
                                  onTap: () => setState(
                                    () => _selectedServiceSubCategory = sub,
                                  ),
                                )).toList(),
                              ),
                            ],
                          ] else if (_isBeautySetup) ...[
                            MerchantImageUploadSlot(
                              title: 'صورة غلاف الصالون/العيادة',
                              imageRef: _coverImageBase64,
                              icon: Icons.storefront_rounded,
                              onTap: _pickCoverImage,
                            ),
                            const SizedBox(height: 12),
                            MerchantImageUploadSlot(
                              title: 'شعار أو صورة بارزة',
                              imageRef: _logoImageBase64,
                              icon: Icons.badge_rounded,
                              onTap: _pickLogoImage,
                            ),
                            const SizedBox(height: 12),
                            _SampleImagesRow(
                              title: 'صور من داخل المكان',
                              imagesBase64: _workSampleImagesBase64,
                              onAddTap: _pickWorkSamples,
                            ),
                          ] else if (_isProfessionalSetup) ...[
                            MerchantImageUploadSlot(
                              title: 'الصورة الشخصية (مطلوبة)',
                              imageRef: _profileImageBase64,
                              icon: Icons.person_rounded,
                              onTap: _pickProfileImage,
                            ),
                            const SizedBox(height: 12),
                            _SampleImagesRow(
                              title: 'صور نماذج الأعمال',
                              imagesBase64: _workSampleImagesBase64,
                              onAddTap: _pickWorkSamples,
                            ),
                          ],
                          if (!_isProfessionalSetup && !_isBeautySetup) ...[
                              const SizedBox(height: 20),
                              _sectionTitle('الخدمات المشمولة'),
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
                              children: MarketplaceCatalog
                                  .merchantAvailableCategories
                                  .map((cat) {
                                final selected =
                                    _selectedServiceIds.contains(cat.id);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    if (selected) {
                                      if (_selectedServiceIds.length == 1) {
                                        return;
                                      }
                                      _selectedServiceIds.remove(cat.id);
                                    } else {
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
                                      color: selected
                                          ? const Color(0xFF007A7A)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFF007A7A)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      cat.titleAr,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.black87,
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
                          ],
                          const SizedBox(height: 20),
                          _sectionTitle(hideFee
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
                                color: const Color(0xFF007A7A)
                                    .withValues(alpha: 0.08),
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
                              color: const Color(0xFF007A7A),
                              borderRadius: BorderRadius.circular(18),
                              onPressed: _isSaving ? null : () async {
                                setState(() => _isSaving = true);

                                void failWith(String msg) {
                                  setState(() => _isSaving = false);
                                  _showMessage(msg);
                                }

                                final name = _nameController.text.trim();
                                if (name.isEmpty) {
                                  return failWith('يرجى إدخال الاسم أولاً');
                                }

                                if (_showsStoreBrandingImages) {
                                  if (!ImageStorageService
                                          .isMerchantUploadedImage(
                                              _coverImageBase64) ||
                                      !ImageStorageService
                                          .isMerchantUploadedImage(
                                              _logoImageBase64)) {
                                    return failWith(
                                      'يرجى رفع ${brandLabels.coverLabelAr} و${brandLabels.logoLabelAr}',
                                    );
                                  }
                                }
                                if (_isRestaurantSetup) {
                                  if (_selectedRestaurantCategory == null) {
                                    return failWith(
                                        'يرجى اختيار تصنيف المطعم (مشويات أو وجبات سريعة)');
                                  }
                                }
                                if (_hasServiceSubCategories &&
                                    (_selectedServiceSubCategory == null ||
                                        _selectedServiceSubCategory!.isEmpty)) {
                                  return failWith(
                                      'يرجى اختيار $_serviceSubCategoryLabel');
                                }

                                if (_isProfessionalSetup) {
                                  final address =
                                      _addressController.text.trim();
                                  final phone = _phoneController.text.trim();
                                  final openTime = _openTime.trim();
                                  final closeTime = _closeTime.trim();
                                  final professionId =
                                      _selectedProfessionalCategoryId;
                                  if (professionId == null ||
                                      professionId.isEmpty) {
                                    return failWith('يرجى اختيار تخصص المهنة');
                                  }
                                  if (address.isEmpty) {
                                    return failWith('يرجى إدخال عنوانك');
                                  }
                                  if (_storeLatitude == null ||
                                      _storeLongitude == null) {
                                    return failWith(
                                        'يرجى تحديد موقعك على الخريطة');
                                  }
                                  if (phone.isEmpty) {
                                    return failWith('يرجى إدخال رقم الهاتف');
                                  }
                                  if (openTime.isEmpty || closeTime.isEmpty) {
                                    return failWith(
                                        'يرجى تحديد وقت الافتتاح ووقت الإغلاق');
                                  }
                                  if (!ImageStorageService
                                      .isMerchantUploadedImage(
                                          _profileImageBase64)) {
                                    return failWith('يرجى رفع صورتك الشخصية');
                                  }
                                }
                                if (!_isProfessionalSetup &&
                                    _requiresStoreLocation &&
                                    (_storeLatitude == null ||
                                        _storeLongitude == null)) {
                                  return failWith(
                                      'حدد ${_locationTitleFor(_primaryServiceId)} أولاً');
                                }
                                if (_openTime.trim().isEmpty ||
                                    _closeTime.trim().isEmpty) {
                                  return failWith(
                                      'يرجى تحديد وقت الافتتاح ووقت الإغلاق');
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
                                    'restaurantCategory':
                                        _selectedRestaurantCategory,
                                    'serviceSubCategory':
                                        _selectedServiceSubCategory,
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
                                        : int.tryParse(_deliveryFeeController
                                                .text
                                                .trim()) ??
                                            0,
                                    'isOpen': true,
                                    'rating': 0,
                                    if (!_isRestaurantSetup)
                                      'workSampleImagesBase64':
                                          List<String>.from(
                                              _workSampleImagesBase64),
                                    'professionalInfo': _isProfessionalSetup
                                        ? {
                                            'name': _nameController.text.trim(),
                                            'address': _addressController.text
                                                .trim(),
                                            'latitude': _storeLatitude,
                                            'longitude': _storeLongitude,
                                            'phone':
                                                _phoneController.text.trim(),
                                            'whatsapp':
                                                _resolveWhatsAppNumber(),
                                            'openTime': _openTime.trim(),
                                            'closeTime': _closeTime.trim(),
                                            'profileImageBase64':
                                                _profileImageBase64,
                                            'workSampleImagesBase64':
                                                List<String>.from(
                                                    _workSampleImagesBase64),
                                            'professionId':
                                                _selectedProfessionalCategoryId,
                                            'professionNameAr':
                                                _selectedProfessionalCategoryNameAr,
                                            'professionNameEn':
                                                _selectedProfessionalCategoryId ==
                                                        null
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
                                  if (!context.mounted) return;
                                  _showMessage(
                                    appProvider.isMerchantApproved
                                        ? (_isProfessionalSetup
                                            ? 'تم حفظ بياناتك بنجاح.'
                                            : 'تم حفظ بيانات المتجر بنجاح.')
                                        : (_isProfessionalSetup
                                            ? 'تم إرسال طلبك. سيظهر ملفك في قسم المهنيين بعد موافقة الإدارة.'
                                            : 'تم إرسال طلبك. سيتم تفعيل حسابك بعد موافقة الإدارة.'),
                                  );
                                } catch (error) {
                                  _showMessage(
                                      'تعذر حفظ بيانات التاجر: $error');
                                } finally {
                                  if (mounted) setState(() => _isSaving = false);
                                }
                              },
                              child: _isSaving
                                  ? const CupertinoActivityIndicator(color: Colors.white)
                                  : Text(
                                      'إرسال طلب ${labels.storeLabelAr}',
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
          title: 'تحديد موقع التاجر',
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

  Widget _buildProfessionPicker() {
    final professions = DummyData.professionalsSubCategories;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ما هي مهنتك؟',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'اختر التخصص المناسب لك. بعد موافقة الإدارة سيظهر ملفك للزبائن مع إمكانية التواصل عبر واتساب والهاتف.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final profession = professions[index];
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedProfessionalCategoryId = profession.id,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: AppImage(
                        imageData: profession.image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
              childCount: professions.length,
            ),
          ),
        ),
      ],
    );
  }

  void _selectService(String serviceId) {
    setState(() {
      _selectedServiceIds
        ..clear()
        ..add(serviceId);
      if (serviceId == 'professionals') {
        _selectedProfessionalCategoryId = null;
      }
    });
  }

  Widget _buildInitialActivitySelection() {
    // الخيارات الرئيسية الثلاث — بطاقات كبيرة بارزة
    final mainOptions = [
      _BusinessTypeOption(
        id: 'product',
        icon: Icons.shopping_bag_rounded,
        titleAr: 'متجر',
        subtitleAr: 'بيع منتجات ومستلزمات',
        color: const Color(0xFF007A7A),
      ),
      _BusinessTypeOption(
        id: 'restaurant',
        icon: Icons.restaurant_rounded,
        titleAr: 'مطعم',
        subtitleAr: 'قائمة طعام وطلبات توصيل',
        color: const Color(0xFFF5A01D),
      ),
      _BusinessTypeOption(
        id: 'professionals',
        icon: Icons.engineering_rounded,
        titleAr: 'مهني',
        subtitleAr: 'طبيب، محامٍ، مهندس وغيرهم',
        color: const Color(0xFF5C6BC0),
      ),
    ];

    // الخيارات الأخرى — قائمة مدمجة أصغر
    final otherOptions = [
      _BusinessTypeOption(id: 'beauty', icon: Icons.spa_rounded, titleAr: 'الصحة والجمال', color: const Color(0xFFE91E8C)),
      _BusinessTypeOption(id: 'cars', icon: Icons.directions_car_rounded, titleAr: 'معرض سيارات', color: const Color(0xFF1565C0)),
      _BusinessTypeOption(id: 'real_estate', icon: Icons.home_work_rounded, titleAr: 'العقارات', color: const Color(0xFF43A047)),
      _BusinessTypeOption(id: 'tourism', icon: Icons.travel_explore_rounded, titleAr: 'السياحة والسفر', color: const Color(0xFF00897B)),
      _BusinessTypeOption(id: 'used', icon: Icons.recycling_rounded, titleAr: 'المستعمل', color: const Color(0xFF6D4C41)),
      _BusinessTypeOption(id: 'offers', icon: Icons.local_offer_rounded, titleAr: 'العروض والخصومات', color: const Color(0xFFE53935)),
      _BusinessTypeOption(id: 'bazar_ghaith', icon: Icons.auto_awesome_rounded, titleAr: 'بازار الغيث', color: const Color(0xFFF5A01D), requiresApproval: true),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الصفحة
          Center(
            child: Column(
              children: [
                const AppLogo(size: 64),
                const SizedBox(height: 16),
                const Text(
                  'ما نوع نشاطك التجاري؟',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر نوع نشاطك وسنهيئ لك الإعداد المناسب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontFamily: 'Cairo',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // البطاقات الرئيسية الثلاث
          Row(
            children: mainOptions.map((opt) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _selectService(opt.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: opt.color.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: opt.color.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: opt.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt.icon, color: opt.color, size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          opt.titleAr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            color: opt.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.subtitleAr ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Cairo',
                            color: Colors.grey.shade500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 28),

          // قسم "خدمات أخرى"
          Text(
            'خدمات أخرى',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 10),
          ...otherOptions.map((opt) => GestureDetector(
            onTap: () => _selectService(opt.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: opt.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(opt.icon, color: opt.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.titleAr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (opt.requiresApproval)
                          Text(
                            'يتطلب موافقة الإدارة',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Cairo',
                              color: Colors.orange.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_left, color: Colors.grey.shade300, size: 16),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ── دالة وهمية لإرضاء المترجم — تم استبدالها بـ _buildInitialActivitySelection الجديدة ──
  Widget _buildInitialActivitySelectionOld_unused() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: 0,
            itemBuilder: (context, index) {
              final cat = MarketplaceCatalog.categories[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedServiceIds
                      ..clear()
                      ..add(cat.id);
                    if (cat.id == 'professionals') {
                      _selectedProfessionalCategoryId = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007A7A).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _categoryIcon(cat.id),
                              color: const Color(0xFF007A7A),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              cat.titleAr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_left,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ],
                      ),
                      if (cat.id == 'bazar_ghaith') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFF5A01D), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: يلزم حصولك على موافقة الإدارة لتتمكن من النشر في قسم بازار ومطاعم الغيث.',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF5A01D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  IconData _categoryIcon(String id) {
    switch (id) {
      case 'bazar_ghaith':
        return Icons.auto_awesome_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'product':
        return Icons.shopping_bag_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'professionals':
        return Icons.engineering_rounded;
      case 'real_estate':
        return Icons.home_work_rounded;
      case 'offers':
        return Icons.local_offer_rounded;
      case 'tourism':
        return Icons.travel_explore_rounded;
      case 'cars':
        return Icons.directions_car_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildLocationCard({bool required = false}) {
    final hasLocation = _storeLatitude != null && _storeLongitude != null;
    final baseTitle = _locationTitleFor(_primaryServiceId);
    final title = required ? '$baseTitle (مطلوب)' : baseTitle;
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
          Text(
            title,
            style: const TextStyle(
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
                : 'يرجى تحديد الموقع على الخريطة وكتابة العنوان النصي.',
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
            color: const Color(0xFFF5A01D),
            borderRadius: BorderRadius.circular(12),
            onPressed: _pickStoreLocation,
            child: Text(
              hasLocation ? 'تعديل الموقع' : 'تحديد الموقع على الخريطة',
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
          color: selected ? const Color(0xFFF5A01D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFF5A01D) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(0xFFF5A01D).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
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
                            color: const Color(0xFFF5A01D), size: 30),
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

class _BusinessTypeOption {
  final String id;
  final IconData icon;
  final String titleAr;
  final String? subtitleAr;
  final Color color;
  final bool requiresApproval;

  const _BusinessTypeOption({
    required this.id,
    required this.icon,
    required this.titleAr,
    this.subtitleAr,
    required this.color,
    this.requiresApproval = false,
  });
}
