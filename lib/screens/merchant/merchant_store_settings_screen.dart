import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/location_picker_screen.dart';

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
  late final TextEditingController _openController;
  late final TextEditingController _closeController;
  late final TextEditingController _deliveryAreasController;
  late final TextEditingController _deliveryFeeController;
  bool _isOpen = true;
  String? _coverImageBase64;
  String? _logoImageBase64;
  String? _profileImageBase64;
  final List<String> _workSampleImagesBase64 = [];
  String? _selectedProfessionalCategoryId;
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
    _openController = TextEditingController();
    _closeController = TextEditingController();
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
    _whatsappController.text = provider.merchantWhatsApp;
    _addressController.text = provider.merchantAddress;
    _openController.text = provider.merchantOpenTime;
    _closeController.text = provider.merchantCloseTime;
    _deliveryAreasController.text = provider.merchantDeliveryAreas;
    _deliveryFeeController.text = provider.merchantDeliveryFee.toString();
    _isOpen = provider.isMerchantStoreOpen;
    _coverImageBase64 ??= _extractBase64(provider.merchantCoverImage);
    _logoImageBase64 ??= _extractBase64(provider.merchantLogoImage);
    _profileImageBase64 ??= provider.merchantProfileImageBase64;
    _selectedProfessionalCategoryId ??= provider.merchantProfessionalCategoryId;
    _storeLatitude ??= provider.merchantLatitude;
    _storeLongitude ??= provider.merchantLongitude;
    if (_workSampleImagesBase64.isEmpty) {
      _workSampleImagesBase64.addAll(provider.merchantWorkSampleImagesBase64);
    }
  }

  String? _extractBase64(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('iVBOR') ||
        trimmed.startsWith('/9j/') ||
        trimmed.length > 80) {
      return trimmed;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _openController.dispose();
    _closeController.dispose();
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
                      selectedColor: Colors.deepOrange,
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
                          color: Colors.deepOrange,
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
          _ImagePreview(
            title: labels.coverLabelAr,
            image: _coverImageBase64 ?? provider.merchantCoverImage,
          ),
          const SizedBox(height: 12),
          _ImagePreview(
            title: labels.logoLabelAr,
            image: _logoImageBase64 ?? provider.merchantLogoImage,
          ),
          const SizedBox(height: 12),
          _ImagePickerCard(
            title: labels.coverLabelAr,
            subtitle: 'اختر صورة الغلاف الرئيسية للمطعم أو المتجر',
            imageBase64: _coverImageBase64,
            onTap: _pickCoverImage,
          ),
          const SizedBox(height: 12),
          _ImagePickerCard(
            title: labels.logoLabelAr,
            subtitle: 'اختر الشعار الظاهر في الواجهة',
            imageBase64: _logoImageBase64,
            onTap: _pickLogoImage,
          ),
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
              controller: _phoneController),
          _Field(
              label: 'واتساب',
              controller: _whatsappController),
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
            _ImagePickerCard(
              title: 'الصورة الشخصية',
              subtitle: 'تظهر هذه الصورة في حساب التاجر وملف صاحب المهنة',
              imageBase64: _profileImageBase64,
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
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'يفتح',
                  controller: _openController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'يغلق',
                  controller: _closeController,
                ),
              ),
            ],
          ),
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
                color: Colors.orange.withValues(alpha: 0.08),
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
              backgroundColor: Colors.deepOrange,
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
              provider.updateMerchantStore({
                'name': _nameController.text.trim(),
                'description': _descController.text.trim(),
                'phone': _phoneController.text.trim(),
                'whatsapp': _whatsappController.text.trim(),
                'address': _addressController.text.trim(),
                'latitude': _storeLatitude,
                'longitude': _storeLongitude,
                'openTime': _openController.text.trim(),
                'closeTime': _closeController.text.trim(),
                'deliveryAreas': _deliveryAreasController.text.trim(),
                'deliveryFee': hideFee
                    ? 0
                    : int.tryParse(_deliveryFeeController.text.trim()) ??
                        provider.merchantDeliveryFee,
                'isOpen': _isOpen,
                'coverImageBase64': _coverImageBase64,
                'logoImageBase64': _logoImageBase64,
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
                        'whatsapp': _whatsappController.text.trim(),
                        'openTime': _openController.text.trim(),
                        'closeTime': _closeController.text.trim(),
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
            hasLocation
                ? '${_storeLatitude!.toStringAsFixed(5)}, ${_storeLongitude!.toStringAsFixed(5)}'
                : 'حدد الموقع بدقة ليتم احتساب رسوم التوصيل من المطعم إلى الزبون بمسار حقيقي.',
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
              backgroundColor: Colors.deepOrange,
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

class _ImagePreview extends StatelessWidget {
  final String title;
  final String image;

  const _ImagePreview({
    required this.title,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    if (image.trim().isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withValues(alpha: 0.18),
              Colors.deepOrange.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    final isBase64 = image.startsWith('iVBOR') ||
        image.startsWith('/9j/') ||
        image.length > 80 && !image.startsWith('assets/');

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: AppImage(
        imageData: image,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageBase64;
  final VoidCallback onTap;

  const _ImagePickerCard({
    required this.title,
    required this.subtitle,
    required this.imageBase64,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 84,
                height: 84,
                color: const Color(0xFFF7F8FC),
                child: imageBase64 != null && imageBase64!.isNotEmpty
                    ? AppImage(imageData: imageBase64)
                    : const Icon(Icons.add_a_photo_rounded,
                        color: Colors.deepOrange, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
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
                            color: Colors.deepOrange, size: 30),
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

  const _Field({
    required this.label,
    required this.controller,
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
