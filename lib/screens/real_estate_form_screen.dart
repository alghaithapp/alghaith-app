import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/dummy_data.dart';
import '../widgets/app_image.dart';
import '../widgets/merchant/merchant_image_upload_slot.dart';

class RealEstateFormScreen extends StatefulWidget {
  final String mode;
  final ListItem? item;
  final String? initialSubCategoryId;

  const RealEstateFormScreen({
    super.key,
    required this.mode,
    this.item,
    this.initialSubCategoryId,
  });

  @override
  State<RealEstateFormScreen> createState() => _RealEstateFormScreenState();
}

class _RealEstateFormScreenState extends State<RealEstateFormScreen> {
  static const int _maxGalleryImages = 4;

  final _formKey = GlobalKey<FormState>();
  final _neighborhoodController = TextEditingController();
  final _facadeController = TextEditingController();
  final _floorsController = TextEditingController();
  final _areaController = TextEditingController();
  final _priceController = TextEditingController();

  final List<String?> _galleryImages = List<String?>.filled(_maxGalleryImages, null);
  String? _selectedSubCategoryId;
  String? _imageValidationError;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _neighborhoodController.text =
        item?.neighborhood?.trim().isNotEmpty == true
            ? item!.neighborhood!.trim()
            : (item?.address?.trim() ?? '');
    _facadeController.text = item?.facade ?? '';
    _floorsController.text = item?.floorCount?.toString() ?? '';
    _areaController.text = item?.areaSquareMeter?.toString() ?? '';
    _priceController.text = item?.price.toString() ?? '';
    _selectedSubCategoryId = item?.subCategory ??
        widget.initialSubCategoryId ??
        'house';

    final existingGallery = <String>[
      if (item?.galleryImagesBase64.isNotEmpty == true)
        ...item!.galleryImagesBase64,
      if ((item?.galleryImagesBase64.isEmpty ?? true) &&
          item?.imageBase64?.trim().isNotEmpty == true)
        item!.imageBase64!.trim(),
    ];
    for (var i = 0; i < _maxGalleryImages && i < existingGallery.length; i++) {
      _galleryImages[i] = existingGallery[i];
    }
  }

  @override
  void dispose() {
    _neighborhoodController.dispose();
    _facadeController.dispose();
    _floorsController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  List<String> get _uploadedGalleryImages => _galleryImages
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  String get _formTitle {
    if (widget.item != null) return 'تعديل إعلان العقار';
    return widget.mode == 'rent' ? 'إعلان عقار للإيجار' : 'إعلان عقار للبيع';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isEdit = widget.item != null;
    final subCategories = DummyData.realEstateSubCategories;
    final selectedSubCategory = subCategories.firstWhere(
      (element) => element.id == _selectedSubCategoryId,
      orElse: () => subCategories.first,
    );

    if (!provider.isMerchant) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        navigationBar: const CupertinoNavigationBar(
          middle: Text(
            'العقارات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.lock_fill,
                    size: 70,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'هذا القسم خاص بالتجار فقط',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يمكنك فقط تصفح العقارات كزبون، أما النشر فهو للتاجر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      height: 1.5,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'رجوع',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isPublishing,
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      appBar: AppBar(
        title: Text(
          _formTitle,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isPublishing) ...[
            const LinearProgressIndicator(minHeight: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.item != null ? 'جارٍ حفظ التعديل...' : 'جارٍ نشر العقار...',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'نوع العقار',
              child: DropdownButtonFormField<String>(
                value: subCategories
                        .any((item) => item.id == _selectedSubCategoryId)
                    ? _selectedSubCategoryId
                    : null,
                items: subCategories.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub.id,
                    child: Text(
                      sub.titleAr,
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSubCategoryId = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'اختر نوع العقار';
                  }
                  return null;
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
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'بيانات العقار',
              child: Column(
                children: [
                  _buildField(
                    label: 'الحي',
                    controller: _neighborhoodController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل اسم الحي';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'الواجهة',
                    controller: _facadeController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل الواجهة';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'النزال',
                    controller: _floorsController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل النزال';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'المساحة الكلية (م²)',
                    controller: _areaController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل المساحة الكلية';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'السعر (د.ع)',
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null) {
                        return 'أدخل سعرًا صحيحًا';
                      }
                      if (parsed < 250) {
                        return 'أقل سعر مسموح به هو 250 دينار';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'صور العقار',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'يمكنك رفع حتى 4 صور. يجب رفع صورة واحدة على الأقل.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (_imageValidationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _imageValidationError!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _maxGalleryImages,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      final imageRef = _galleryImages[index];
                      return MerchantImageUploadSlot(
                        title: 'صورة ${index + 1}',
                        imageRef: imageRef,
                        style: MerchantImageUploadStyle.card,
                        onTap: () => _pickImage(index),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _isPublishing
                  ? null
                  : () => _saveItem(context, provider, selectedSubCategory),
              child: _isPublishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                isEdit ? 'حفظ التعديل' : 'نشر العقار',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
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

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _galleryImages[index] = base64Encode(bytes);
      _imageValidationError = null;
    });
  }

  Future<void> _saveItem(
    BuildContext context,
    AppProvider provider,
    ServiceCategory selectedSubCategory,
  ) async {
    if (_isPublishing) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final gallery = _uploadedGalleryImages;
    if (gallery.isEmpty) {
      setState(() {
        _imageValidationError = 'يجب رفع صورة واحدة على الأقل للعقار';
      });
      return;
    }

    final neighborhood = _neighborhoodController.text.trim();
    final facade = _facadeController.text.trim();
    final floors = int.parse(_floorsController.text.trim());
    final area = int.parse(_areaController.text.trim());
    final price = int.parse(_priceController.text.trim());
    final title = '${selectedSubCategory.titleAr} — $neighborhood';
    final description = [
      'الحي: $neighborhood',
      'الواجهة: $facade',
      'النزال: $floors',
      'المساحة الكلية: $area م²',
      'نوع العقار: ${selectedSubCategory.titleAr}',
    ].join('\n');

    final item = ListItem(
      id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nameAr: title,
      nameEn: widget.item?.nameEn ?? title,
      descriptionAr: description,
      descriptionEn: widget.item?.descriptionEn ?? description,
      price: price,
      rating: widget.item?.rating ?? 4.8,
      category: 'real_estate',
      subCategory: _selectedSubCategoryId,
      categoryLabelAr: 'العقارات',
      categoryLabelEn: 'Real Estate',
      image: _imageForSubCategory(selectedSubCategory.id),
      imageBase64: gallery.first,
      galleryImagesBase64: gallery,
      avgPriceLabelAr: 'السعر',
      avgPriceLabelEn: 'Price',
      actionLabelAr: 'تواصل',
      actionLabelEn: 'Contact',
      address: neighborhood,
      neighborhood: neighborhood,
      facade: facade,
      floorCount: floors,
      areaSquareMeter: area,
      listingMode: widget.mode == 'rent' ? 'rent' : 'sell',
      isAvailable: true,
    );

    setState(() => _isPublishing = true);
    try {
      if (widget.item != null) {
        await provider.updateProduct(item);
      } else {
        await provider.addProduct(item);
      }
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر نشر العقار. حاول مرة أخرى.',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
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
      ),
    );
  }

  String _imageForSubCategory(String subCategoryId) {
    switch (subCategoryId) {
      case 'land':
        return 'assets/images/re_land.png';
      case 'shops':
        return 'assets/images/re_shops.png';
      case 'apartment':
        return 'assets/images/re_apartment.png';
      case 'building':
        return 'assets/images/re_building.png';
      case 'farm':
        return 'assets/images/re_farm.png';
      case 'house':
      default:
        return 'assets/images/re_house.png';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
