import 'dart:io'; // إضافة مكتبة الملفات
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';

class ProductFormScreen extends StatefulWidget {
  final bool isRestaurant;
  final String? serviceId;
  final ListItem? item;

  const ProductFormScreen({
    super.key,
    required this.isRestaurant,
    this.serviceId,
    this.item,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _prepController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _imageBase64;
  String? _imageLabel;
  bool _isAvailable = true;
  String? _selectedServiceId;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController.text = item?.nameAr ?? '';
    _priceController.text = item?.price.toString() ?? '';
    _descController.text = item?.descriptionAr ?? '';
    _prepController.text = item?.prepMinutes?.toString() ?? '';
    _imageBase64 = item?.imageBase64;
    _imageLabel = item == null ? null : 'selected';
    _isAvailable = item?.isAvailable ?? true;
    _selectedServiceId = widget.serviceId;
    _selectedSubCategoryId = item?.subCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';
    final availableServiceIds = appProvider.merchantServiceIds;
    final serviceId = availableServiceIds.contains(_selectedServiceId ??
            widget.serviceId ??
            appProvider.merchantActiveServiceId)
        ? (_selectedServiceId ??
            widget.serviceId ??
            appProvider.merchantActiveServiceId)
        : availableServiceIds.first;
    final showServicePicker = appProvider.merchantHasMultipleServices;
    final labels = merchantServiceLabels(serviceId);
    final showSubCategoryPicker = serviceId == 'product';
    final shoppingSubCategories = showSubCategoryPicker
        ? DummyData.shoppingSubCategories
        : const <ServiceCategory>[];
    final isEdit = widget.item != null;
    final title = isEdit
        ? (isAr ? labels.editItemAr : labels.editItemEn)
        : (isAr ? labels.addItemAr : labels.addItemEn);

    final previewImage = _buildPreviewImage(serviceId);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          title,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showServicePicker) ...[
                      Text(
                        isAr
                            ? 'اختر الخدمة المستهدفة'
                            : 'Choose target service',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: serviceId,
                        items: availableServiceIds.map((id) {
                          final category = DummyData.categories.firstWhere(
                            (element) => element.id == id,
                            orElse: () => DummyData.categories.first,
                          );
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              isAr ? category.titleAr : category.titleEn,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedServiceId = value);
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
                      const SizedBox(height: 16),
                    ],
                    if (showSubCategoryPicker) ...[
                      Text(
                        isAr ? 'اختر قسم التسوق' : 'Choose shopping category',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: shoppingSubCategories.any((element) =>
                                element.id == _selectedSubCategoryId)
                            ? _selectedSubCategoryId
                            : null,
                        items: shoppingSubCategories.map((subCategory) {
                          return DropdownMenuItem<String>(
                            value: subCategory.id,
                            child: Text(
                              isAr ? subCategory.titleAr : subCategory.titleEn,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedSubCategoryId = value);
                        },
                        validator: (value) {
                          if (showSubCategoryPicker &&
                              (value == null || value.isEmpty)) {
                            return isAr
                                ? 'اختر قسمًا فرعيًا للمنتج'
                                : 'Please choose a shopping sub-category';
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
                      const SizedBox(height: 16),
                    ],
                    Text(
                      isAr
                          ? 'أضف صورة لـ ${labels.itemSingularAr} لتظهر بشكل احترافي'
                          : 'Add an image for the ${labels.itemSingularEn} to look professional',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE6E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              previewImage,
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.28),
                                    ],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isAr ? 'رفع صورة' : 'Upload Image',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_imageLabel != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        isAr
                            ? 'تم اختيار الصورة بنجاح'
                            : 'Image selected successfully',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildField(
                      label: isAr
                          ? 'اسم ${labels.itemSingularAr}'
                          : '${labels.itemSingularEn} name',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return isAr
                              ? 'هذا الحقل مطلوب'
                              : 'This field is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: isAr ? 'السعر' : 'Price',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return isAr
                              ? 'أدخل سعراً صحيحاً'
                              : 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: isAr
                          ? 'وصف ${labels.itemSingularAr}'
                          : '${labels.itemSingularEn} description',
                      controller: _descController,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return isAr ? 'أدخل الوصف' : 'Enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (serviceId == 'restaurant')
                      _buildField(
                        label: isAr ? 'مدة التحضير (دقائق)' : 'Prep time (min)',
                        controller: _prepController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return isAr
                                  ? 'أدخل رقماً صحيحاً'
                                  : 'Enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isAvailable,
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                      title: Text(
                        isAr ? 'حالة التوفر' : 'Availability',
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _isAvailable
                            ? (isAr ? 'متوفر' : 'Available')
                            : (isAr ? 'غير متوفر' : 'Unavailable'),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: () =>
                            _saveItem(context, appProvider, isAr, serviceId),
                        child: Text(
                          isEdit
                              ? (isAr ? 'حفظ التعديل' : 'Save Changes')
                              : (isAr ? labels.addItemAr : labels.addItemEn),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;
    
    // رفع الصورة فوراً لكلود فلير والحصول على الرابط
    final provider = context.read<AppProvider>();
    final url = await provider.uploadImage(File(picked.path));
    
    if (url != null) {
      setState(() {
        _imageBase64 = url; // سنخزن الرابط في نفس المتغير لسهولة التعامل
        _imageLabel = picked.name;
      });
    }
  }

  Widget _buildPreviewImage(String serviceId) {
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      return AppImage(imageData: _imageBase64);
    }

    final fallbackAsset = serviceId == 'restaurant'
        ? 'assets/images/cat_restaurant.png'
        : serviceId == 'cars'
            ? 'assets/images/cat_cars.png'
            : serviceId == 'real_estate'
                ? 'assets/images/re_house.png'
                : 'assets/images/cat_shopping.png';
    return AppImage(imageData: widget.item?.image ?? fallbackAsset);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontFamily: 'Cairo',
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
    );
  }

  void _saveItem(
    BuildContext context,
    AppProvider provider,
    bool isAr,
    String serviceId,
  ) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final isEdit = widget.item != null;
    final labels = merchantServiceLabels(serviceId);
    final price = int.parse(_priceController.text.trim());
    final name = _nameController.text.trim();
    final description = _descController.text.trim();
    final item = ListItem(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nameAr: name,
      nameEn: widget.item?.nameEn ?? name,
      descriptionAr: description,
      descriptionEn: widget.item?.descriptionEn ?? description,
      price: price,
      rating: widget.item?.rating ?? 4.8,
      category: serviceId,
      subCategory: serviceId == 'product'
          ? (_selectedSubCategoryId ?? widget.item?.subCategory)
          : widget.item?.subCategory,
      categoryLabelAr: labels.productsTitleAr,
      categoryLabelEn: labels.productsTitleEn,
      image: widget.item?.image ??
          (serviceId == 'restaurant'
              ? 'assets/images/cat_restaurant.png'
              : serviceId == 'cars'
                  ? 'assets/images/cat_cars.png'
                  : serviceId == 'real_estate'
                      ? 'assets/images/re_house.png'
                      : 'assets/images/cat_shopping.png'),
      imageBase64: _imageBase64,
      prepMinutes: serviceId == 'restaurant'
          ? int.tryParse(_prepController.text.trim())
          : null,
      isAvailable: _isAvailable,
      avgPriceLabelAr: 'السعر',
      avgPriceLabelEn: 'Price',
      actionLabelAr: labels.actionLabelAr,
      actionLabelEn: labels.actionLabelEn,
    );

    if (isEdit) {
      provider.updateProduct(item);
    } else {
      provider.addProduct(item);
    }

    Navigator.pop(context);
  }
}
