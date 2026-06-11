import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_profile_fields.dart';
import '../../services/image_storage_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/location_picker_screen.dart';
import '../../widgets/merchant/merchant_image_upload_slot.dart';
import '../../widgets/merchant/merchant_working_hours_picker.dart';

class MerchantStoreSettingsScreen extends StatefulWidget {
  const MerchantStoreSettingsScreen({super.key});

  @override
  State<MerchantStoreSettingsScreen> createState() =>
      _MerchantStoreSettingsScreenState();
}

class _MerchantStoreSettingsScreenState
    extends State<MerchantStoreSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _addressController;
  String _openTime = '';
  String _closeTime = '';
  late final TextEditingController _deliveryAreasController;
  late final TextEditingController _deliveryFeeController;
  bool _isOpen = true;
  String? _coverImageBase64;
  String? _logoImageBase64;
  String? _profileImageBase64;
  final List<String> _workSampleImagesBase64 = [];
  String? _selectedProfessionalCategoryId;
  String? _selectedRestaurantCategory;
  double? _storeLatitude;
  double? _storeLongitude;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();
    _addressController = TextEditingController();
    _deliveryAreasController = TextEditingController();
    _deliveryFeeController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    _nameController.text = provider.merchantStoreName;
    _descController.text = provider.merchantDescription;
    _phoneController.text = provider.merchantPhone;
    _whatsappController.text =
        (provider.merchantStore?['whatsapp'] as String?)?.trim() ?? '';
    _addressController.text = provider.merchantAddress;
    _openTime = provider.merchantOpenTime;
    _closeTime = provider.merchantCloseTime;
    _deliveryAreasController.text = provider.merchantDeliveryAreas;
    _deliveryFeeController.text = provider.merchantDeliveryFee.toString();
    _isOpen = provider.isMerchantStoreOpen;
    _coverImageBase64 ??=
        ImageStorageService.merchantUploadedImageRef(provider.merchantCoverImage);
    _logoImageBase64 ??=
        ImageStorageService.merchantUploadedImageRef(provider.merchantLogoImage);
    _profileImageBase64 ??=
        ImageStorageService.merchantUploadedImageRef(
          provider.merchantProfileImageBase64,
        );
    _selectedProfessionalCategoryId ??= provider.merchantProfessionalCategoryId;
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
  }

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
    _deliveryAreasController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantActiveLabels;
    final serviceIds = provider.merchantServiceIds;
    final availableToAdd = DummyData.categories
        .where((category) => !serviceIds.contains(category.id))
        .toList();
    final hideFee = provider.merchantActiveServiceId == 'professionals' ||
        provider.merchantActiveServiceId == 'restaurant';
    final isProfessional = provider.merchantActiveServiceId == 'professionals';
    final requiresStoreLocation =
        serviceIds.contains('restaurant') || serviceIds.contains('product');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          labels.storeSettingsTitleAr,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الخدمات',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك إضافة خدمة جديدة لاحقًا من هنا، ثم التبديل بين خدماتك في أي وقت.',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: serviceIds.map((serviceId) {
                    final service = DummyData.categories.firstWhere(
                      (category) => category.id == serviceId,
                      orElse: () => DummyData.categories.first,
                    );
                    final selected = serviceId == provider.merchantActiveServiceId;
                    return ChoiceChip(
                      label: Text(
                        service.titleAr,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      selected: selected,
                      onSelected: (_) => provider.setMerchantActiveService(serviceId),
                      selectedColor: AppColors.accent,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
                if (availableToAdd.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'إضافة خدمة جديدة:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableToAdd.map((category) {
                      return ActionChip(
                        avatar: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        label: Text(
                          category.titleAr,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        onPressed: () async {
                          await provider.addMerchantService(category.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إضافة خدمة ${category.titleAr} إلى حسابك.',
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          MerchantImagePreviewBanner(
            title: labels.coverLabelAr,
            imageRef: _coverImageBase64,
          ),
          const SizedBox(height: 12),
          MerchantImagePreviewBanner(
            title: labels.logoLabelAr,
            imageRef: _logoImageBase64,
          ),
          const SizedBox(height: 12),
          MerchantImageUploadSlot(
            title: labels.coverLabelAr,
            subtitle: 'اختر صورة الغلاف الرئيسية للمطعم أو المتجر',
            imageRef: _coverImageBase64,
            icon: Icons.storefront_rounded,
            style: MerchantImageUploadStyle.row,
            onTap: _pickCoverImage,
          ),
          const SizedBox(height: 12),
          MerchantImageUploadSlot(
            title: labels.logoLabelAr,
            subtitle: 'اختر الشعار الظاهر في الواجهة',
            imageRef: _logoImageBase64,
            icon: Icons.badge_rounded,
            style: MerchantImageUploadStyle.row,
            onTap: _pickLogoImage,
          ),
          if (provider.merchantActiveServiceId == 'restaurant') ...[
            const SizedBox(height: 16),
            const _SectionTitle(title: 'تخصص المطعم'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CategoryChoiceButton(
                      label: 'مشويات',
                      selected: _selectedRestaurantCategory == 'مشويات',
                      onTap: () => setState(() => _selectedRestaurantCategory = 'مشويات'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CategoryChoiceButton(
                      label: 'وجبات سريعة',
                      selected: _selectedRestaurantCategory == 'وجبات سريعة',
                      onTap: () => setState(() => _selectedRestaurantCategory = 'وجبات سريعة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _SectionTitle(title: 'معلومات أساسية'),
          const SizedBox(height: 10),
          _Field(
              label: labels.storeNameLabelAr,
              controller: _nameController),
          _Field(
              label:
                  labels.descriptionLabelAr,
              controller: _descController,
              maxLines: 3),
          _Field(
            label: 'رقم الهاتف',
            controller: _phoneController,
            hintText: 'يجب أن يكون رقم واتساب فعّال',
            keyboardType: TextInputType.phone,
          ),
          _Field(
            label: 'رقم واتساب',
            controller: _whatsappController,
            hintText: 'اختياري — اتركه فارغاً لاستخدام نفس رقم الهاتف',
            keyboardType: TextInputType.phone,
          ),
          _Field(
              label: 'العنوان',
              controller: _addressController),
          _buildStoreLocationCard(),
          const SizedBox(height: 6),
          _SectionTitle(
            title: isProfessional
                ? 'صور وصاحب المهنة'
                : 'الصور والهوية',
          ),
          const SizedBox(height: 10),
          if (isProfessional) ...[
            MerchantImageUploadSlot(
              title: 'الصورة الشخصية',
              subtitle: 'تظهر هذه الصورة في حساب التاجر وملف صاحب المهنة',
              imageRef: _profileImageBase64,
              icon: Icons.person_rounded,
              style: MerchantImageUploadStyle.row,
              onTap: _pickProfileImage,
            ),
            const SizedBox(height: 12),
            _SampleImagesRow(
              title: 'صور نماذج الأعمال',
              subtitle: 'اختياري، ويمكنك إضافة أكثر من صورة',
              imagesBase64: _workSampleImagesBase64,
              onAddTap: _pickWorkSamples,
              onRemoveTap: (index) {
                setState(() => _workSampleImagesBase64.removeAt(index));
              },
            ),
          ],
          if (isProfessional) ...[
            const SizedBox(height: 12),
            _SectionTitle(
              title: 'تخصص المهنة',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: DummyData.professionalsSubCategories.any((category) =>
                      category.id == _selectedProfessionalCategoryId)
                  ? _selectedProfessionalCategoryId
                  : null,
              items: DummyData.professionalsSubCategories.map((profession) {
                return DropdownMenuItem<String>(
                  value: profession.id,
                  child: Text(
                    profession.titleAr,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedProfessionalCategoryId = value);
              },
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
          const SizedBox(height: 12),
          MerchantWorkingHoursPicker(
            openTime: _openTime,
            closeTime: _closeTime,
            onOpenTimeChanged: (value) => setState(() => _openTime = value),
            onCloseTimeChanged: (value) => setState(() => _closeTime = value),
          ),
          const SizedBox(height: 12),
          _Field(
              label: labels.deliveryAreasLabelAr,
              controller: _deliveryAreasController,
              maxLines: 2),
          if (!hideFee)
            _Field(
                label: labels.deliveryFeeLabelAr,
                controller: _deliveryFeeController,
                keyboardType: TextInputType.number)
          else
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'لا توجد رسوم مباشرة في هذا القسم.',
                style: const TextStyle(fontFamily: 'Cairo', height: 1.4),
              ),
            ),
          SwitchListTile(
            value: _isOpen,
            onChanged: (value) => setState(() => _isOpen = value),
            title: Text(
              'حالة ${labels.storeLabelAr}',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _isOpen ? 'مفتوح' : 'مغلق',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              if (requiresStoreLocation &&
                  (_storeLatitude == null || _storeLongitude == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('حدد موقع المتجر على الخريطة أولاً'),
                  ),
                );
                return;
              }
              if (_openTime.trim().isEmpty || _closeTime.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى تحديد وقت الافتتاح ووقت الإغلاق'),
                  ),
                );
                return;
              }
              provider.updateMerchantStore({
                'name': _nameController.text.trim(),
                'description': _descController.text.trim(),
                'phone': _phoneController.text.trim(),
                'whatsapp': _resolveWhatsAppNumber(),
                'address': _addressController.text.trim(),
                'latitude': _storeLatitude,
                'longitude': _storeLongitude,
                'openTime': _openTime,
                'closeTime': _closeTime,
                'deliveryAreas': _deliveryAreasController.text.trim(),
                'deliveryFee': hideFee
                    ? 0
                    : int.tryParse(_deliveryFeeController.text.trim()) ??
                        provider.merchantDeliveryFee,
                'isOpen': _isOpen,
                'coverImageBase64': _coverImageBase64,
                'logoImageBase64': _logoImageBase64,
                'restaurantCategory': _selectedRestaurantCategory,
                'profileImageBase64': provider.merchantActiveServiceId ==
                        'restaurant'
                    ? _logoImageBase64
                    : _profileImageBase64,
                'workSampleImagesBase64':
                    provider.merchantActiveServiceId == 'restaurant'
                        ? const []
                        : List<String>.from(_workSampleImagesBase64),
                'professionalCategoryId': _selectedProfessionalCategoryId,
                'professionalInfo': isProfessional
                    ? {
                        'name': _nameController.text.trim(),
                        'address': _addressController.text.trim(),
                        'latitude': _storeLatitude,
                        'longitude': _storeLongitude,
                        'phone': _phoneController.text.trim(),
                        'whatsapp': _resolveWhatsAppNumber(),
                        'openTime': _openTime,
                        'closeTime': _closeTime,
                        'profileImageBase64': _profileImageBase64,
                        'workSampleImagesBase64':
                            List<String>.from(_workSampleImagesBase64),
                        'professionId': _selectedProfessionalCategoryId,
                        'professionNameAr':
                            _selectedProfessionalCategoryId == null
                                ? null
                                : DummyData.professionalsSubCategories
                                    .firstWhere(
                                      (item) =>
                                          item.id ==
                                          _selectedProfessionalCategoryId,
                                    )
                                    .titleAr,
                        'professionNameEn':
                            _selectedProfessionalCategoryId == null
                                ? null
                                : DummyData.professionalsSubCategories
                                    .firstWhere(
                                      (item) =>
                                          item.id ==
                                          _selectedProfessionalCategoryId,
                                    )
                                    .titleEn,
                      }
                    : const {},
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حفظ التغييرات بنجاح'),
                ),
              );
            },
            child: Text(
              'حفظ التغييرات',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildStoreLocationCard() {
    final hasLocation = _storeLatitude != null && _storeLongitude != null;
    final locationLabel = MerchantProfileFields.locationSummary(
      address: _addressController.text.trim(),
      latitude: _storeLatitude,
      longitude: _storeLongitude,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'موقع المتجر على الخريطة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            locationLabel.isNotEmpty
                ? locationLabel
                : 'حدد الموقع على الخريطة وأدخل العنوان النصي في حقل «العنوان» أعلاه.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.black87,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _pickStoreLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.location_on_rounded),
            label: Text(
              hasLocation ? 'تعديل الموقع' : 'تحديد الموقع',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    
    final url = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (url != null) {
      setState(() {
        _profileImageBase64 = url;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    
    final url = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (url != null) {
      setState(() {
        _coverImageBase64 = url;
      });
    }
  }

  Future<void> _pickLogoImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    
    final url = await context.read<AppProvider>().uploadImage(File(picked.path));
    if (url != null) {
      setState(() {
        _logoImageBase64 = url;
      });
    }
  }

  Future<void> _pickWorkSamples() async {
    final picked = await AppHelpers.pickMultiImage(context);
    if (picked.isEmpty) return;
    
    final provider = context.read<AppProvider>();
    final urls = <String>[];
    
    for (final image in picked) {
      final url = await provider.uploadImage(File(image.path));
      if (url != null) urls.add(url);
    }
    
    if (urls.isNotEmpty) {
      setState(() {
        _workSampleImagesBase64.addAll(urls);
      });
    }
  }
}

class _CategoryChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChoiceButton({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.grey.shade200,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w900,
        fontSize: 17,
      ),
    );
  }
}

class _SampleImagesRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> imagesBase64;
  final VoidCallback onAddTap;
  final void Function(int index) onRemoveTap;

  const _SampleImagesRow({
    required this.title,
    required this.subtitle,
    required this.imagesBase64,
    required this.onAddTap,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.grey,
            fontSize: 12,
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
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AppImage(
                      imageData: image,
                      width: 110,
                      height: 110,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => onRemoveTap(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  final String? hintText;

  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.hintText,
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
