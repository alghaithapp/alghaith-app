import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/image_storage_service.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import '../../widgets/location_picker_screen.dart';

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
  final TextEditingController _openTimeController = TextEditingController();
  final TextEditingController _closeTimeController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();

  final List<String> _selectedServiceIds = ['restaurant'];
  String? _coverImageBase64;
  String? _logoImageBase64;
  String? _profileImageBase64;
  final List<String> _workSampleImagesBase64 = [];
  String? _selectedProfessionalCategoryId;
  double? _storeLatitude;
  double? _storeLongitude;

  String get _primaryServiceId => _selectedServiceIds.first;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  bool get _isProfessionalSetup =>
      _selectedServiceIds.contains('professionals');

  bool get _isRestaurantSetup => _primaryServiceId == 'restaurant';
  bool get _requiresStoreLocation =>
      _selectedServiceIds.contains('restaurant') ||
      _selectedServiceIds.contains('product');

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
        _whatsappController.text = provider.merchantWhatsApp;
      }
      if (_addressController.text.isEmpty) {
        _addressController.text = provider.merchantAddress;
      }
      if (_openTimeController.text.isEmpty) {
        _openTimeController.text = provider.merchantOpenTime;
      }
      if (_closeTimeController.text.isEmpty) {
        _closeTimeController.text = provider.merchantCloseTime;
      }
      if (_deliveryFeeController.text.isEmpty &&
          provider.merchantDeliveryFee > 0) {
        _deliveryFeeController.text = provider.merchantDeliveryFee.toString();
      }
      _coverImageBase64 ??= _extractBase64(provider.merchantCoverImage);
      _logoImageBase64 ??= _extractBase64(provider.merchantLogoImage);
      _profileImageBase64 ??= provider.merchantProfileImageBase64;
      _selectedProfessionalCategoryId ??=
          provider.merchantProfessionalCategoryId;
      _storeLatitude ??= provider.merchantLatitude;
      _storeLongitude ??= provider.merchantLongitude;
      if (_workSampleImagesBase64.isEmpty) {
        _workSampleImagesBase64.addAll(provider.merchantWorkSampleImagesBase64);
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

  String? _extractBase64(String value) {
    return ImageStorageService.normalizeImageRef(value);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final labels = merchantServiceLabels(_primaryServiceId);
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
                        Colors.orange.shade700,
                        Colors.deepOrange.shade400
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.18),
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
                        'رقم الهاتف', _phoneController),
                    const SizedBox(height: 14),
                    if (_isProfessionalSetup) ...[
                      _buildField(
                        'رقم الواتساب',
                        _whatsappController,
                      ),
                      const SizedBox(height: 14),
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
                      _isRestaurantSetup
                          ? 'صورة المطعم وشعاره'
                          : (_isProfessionalSetup
                              ? 'الصورة الشخصية والأعمال'
                              : 'الصور والهوية'),
                    ),
                    const SizedBox(height: 12),
                    if (_isRestaurantSetup) ...[
                      _ImagePickCard(
                        title: 'صورة المطعم',
                        imageBase64: _coverImageBase64,
                        icon: Icons.storefront_rounded,
                        onTap: _pickCoverImage,
                      ),
                      const SizedBox(height: 12),
                      _ImagePickCard(
                        title: 'شعار المطعم',
                        imageBase64: _logoImageBase64,
                        icon: Icons.badge_rounded,
                        onTap: _pickLogoImage,
                      ),
                    ] else ...[
                      _ImagePickCard(
                        title: 'الصورة الشخصية',
                        imageBase64: _profileImageBase64,
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
                      children: DummyData.categories.map((cat) {
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
                              color: selected ? Colors.orange : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? Colors.orange
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
                    Row(
                      children: [
                        Expanded(
                            child: _buildField(
                                'يفتح', _openTimeController)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildField(
                                'يغلق', _closeTimeController)),
                      ],
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
                          color: Colors.orange.withValues(alpha: 0.08),
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            _showMessage('يرجى إدخال الاسم أولاً');
                            return;
                          }

                          if (_isRestaurantSetup) {
                            if (_coverImageBase64 == null ||
                                _coverImageBase64!.isEmpty ||
                                _logoImageBase64 == null ||
                                _logoImageBase64!.isEmpty) {
                              _showMessage('يرجى إضافة صورة المطعم وشعاره');
                              return;
                            }
                          }

                          if (_isProfessionalSetup) {
                            final address = _addressController.text.trim();
                            final phone = _phoneController.text.trim();
                            final whatsapp = _whatsappController.text.trim();
                            final openTime = _openTimeController.text.trim();
                            final closeTime = _closeTimeController.text.trim();
                            final professionId =
                                _selectedProfessionalCategoryId;
                            if (address.isEmpty ||
                                phone.isEmpty ||
                                whatsapp.isEmpty ||
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
                            'profileImageBase64': _isRestaurantSetup
                                ? _logoImageBase64
                                : _profileImageBase64,
                            'phone': _phoneController.text.trim(),
                            'whatsapp': _whatsappController.text.trim(),
                            'address': _addressController.text.trim(),
                            'latitude': _storeLatitude,
                            'longitude': _storeLongitude,
                            'openTime': _openTimeController.text.trim(),
                            'closeTime': _closeTimeController.text.trim(),
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
                                    'whatsapp': _whatsappController.text.trim(),
                                    'openTime': _openTimeController.text.trim(),
                                    'closeTime':
                                        _closeTimeController.text.trim(),
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
            hasLocation
                ? 'تم تحديد الموقع: ${_storeLatitude!.toStringAsFixed(5)}, ${_storeLongitude!.toStringAsFixed(5)}'
                : 'يرجى تحديد موقع المتجر بدقة ليتم حساب كلفة التوصيل بخط طريق حقيقي.',
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
            color: Colors.deepOrange,
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

class _ImagePickCard extends StatelessWidget {
  final String title;
  final String? imageBase64;
  final IconData icon;
  final VoidCallback onTap;

  const _ImagePickCard({
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
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: imageBase64 != null && imageBase64!.isNotEmpty
                    ? AppImage(imageData: imageBase64)
                    : Container(
                        color: const Color(0xFFF7F8FC),
                        child: Icon(icon, size: 56, color: Colors.orange),
                      ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
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
          ],
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
