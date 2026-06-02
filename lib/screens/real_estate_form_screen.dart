import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/dummy_data.dart';
import '../widgets/app_image.dart';

class RealEstateFormScreen extends StatefulWidget {
  final String mode;
  final ListItem? item;

  const RealEstateFormScreen({
    super.key,
    required this.mode,
    this.item,
  });

  @override
  State<RealEstateFormScreen> createState() => _RealEstateFormScreenState();
}

class _RealEstateFormScreenState extends State<RealEstateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _floorsController = TextEditingController();

  String? _imageBase64;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController.text = item?.nameAr ?? '';
    _priceController.text = item?.price.toString() ?? '';
    _areaController.text = item?.areaSquareMeter?.toString() ?? '';
    _addressController.text = item?.address ?? '';
    _descController.text = item?.descriptionAr ?? '';
    _bedroomsController.text = item?.bedrooms?.toString() ?? '';
    _floorsController.text = item?.floorCount?.toString() ?? '';
    _imageBase64 = item?.imageBase64;
    _selectedSubCategoryId =
        item?.subCategory ?? (widget.mode == 'sell' ? 'house' : 'land');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _bedroomsController.dispose();
    _floorsController.dispose();
    super.dispose();
  }

  bool get _isHouseLike =>
      _selectedSubCategoryId != null &&
      _selectedSubCategoryId != 'land' &&
      _selectedSubCategoryId != 'shops';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'تعديل العقار'
              : (widget.mode == 'sell'
                  ? 'عرض عقار للبيع'
                  : 'عرض عقار للإيجار'),
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
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
                    label: 'عنوان الإعلان',
                    controller: _titleController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
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
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل سعرًا صحيحًا';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'العنوان',
                    controller: _addressController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل العنوان';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    label: 'المساحة (م²)',
                    controller: _areaController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل المساحة';
                      }
                      return null;
                    },
                  ),
                  if (_isHouseLike)
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'عدد الغرف',
                            controller: _bedroomsController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'أدخل عدد الغرف';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'عدد الطوابق',
                            controller: _floorsController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'أدخل عدد الطوابق';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  _buildField(
                    label: 'الوصف',
                    controller: _descController,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل الوصف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE6E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AppImage(
                          imageData: _imageBase64 != null && _imageBase64!.isNotEmpty
                              ? _imageBase64
                              : _imageForSubCategory(selectedSubCategory.id),
                        ),
                      ),
                    ),
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
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                final price = int.parse(_priceController.text.trim());
                final area = int.parse(_areaController.text.trim());
                final title = _titleController.text.trim();
                final description = _descController.text.trim();
                final address = _addressController.text.trim();
                final bedrooms = _bedroomsController.text.trim().isEmpty
                    ? null
                    : int.tryParse(_bedroomsController.text.trim());
                final floors = _floorsController.text.trim().isEmpty
                    ? null
                    : int.tryParse(_floorsController.text.trim());

                final item = ListItem(
                  id: widget.item?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
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
                  imageBase64: _imageBase64,
                  avgPriceLabelAr: 'السعر',
                  avgPriceLabelEn: 'Price',
                  actionLabelAr: 'تواصل',
                  actionLabelEn: 'Contact',
                  address: address,
                  bedrooms: bedrooms,
                  floorCount: floors,
                  areaSquareMeter: area,
                  listingMode: widget.mode,
                  isAvailable: true,
                );

                if (isEdit) {
                  provider.updateProduct(item);
                } else {
                  provider.addProduct(item);
                }
                Navigator.pop(context);
              },
              child: Text(
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
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBase64 = base64Encode(bytes);
    });
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
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
            maxLines: maxLines,
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
