import 'dart:io'; // إضافة مكتبة الملفات
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../core/catalog/marketplace_catalog.dart';
import '../../utils/dummy_data.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import 'merchant_store_sections_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final bool isRestaurant;
  final String? serviceId;
  final ListItem? item;
  final String? initialSubCategoryId;

  const ProductFormScreen({
    super.key,
    required this.isRestaurant,
    this.serviceId,
    this.item,
    this.initialSubCategoryId,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _imageBase64;
  String? _imageLabel;
  bool _isAvailable = true;
  String? _selectedServiceId;
  String? _selectedSubCategoryId;
  String? _selectedSectionId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController.text = item?.nameAr ?? '';
    _priceController.text = item?.price.toString() ?? '';
    _descController.text = item?.descriptionAr ?? '';
    _imageBase64 = item?.imageBase64;
    _imageLabel = item == null ? null : 'selected';
    _isAvailable = item?.isAvailable ?? true;
    _selectedServiceId = widget.serviceId;
    _selectedSubCategoryId =
        item?.subCategory ?? widget.initialSubCategoryId;
    _selectedSectionId = item?.sectionId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final availableServiceIds = appProvider.merchantServiceIds.isNotEmpty
        ? appProvider.merchantServiceIds
        : const ['restaurant'];
    final serviceId = availableServiceIds.contains(_selectedServiceId ??
            widget.serviceId ??
            appProvider.merchantActiveServiceId)
        ? (_selectedServiceId ??
            widget.serviceId ??
            appProvider.merchantActiveServiceId)
        : availableServiceIds.first;
    final showServicePicker = appProvider.merchantHasMultipleServices;
    final labels = merchantServiceLabels(serviceId);
    final showShoppingSubCategoryPicker = serviceId == 'product';
    final showCarsSubCategoryPicker = serviceId == 'cars';
    final showRestaurantSectionPicker = serviceId == 'restaurant';
    final showSubCategoryPicker =
        showShoppingSubCategoryPicker || showCarsSubCategoryPicker;
    final showStoreSectionPicker =
        showShoppingSubCategoryPicker || showRestaurantSectionPicker;
    final shoppingSubCategories = showShoppingSubCategoryPicker
        ? DummyData.shoppingSubCategories
        : const <ServiceCategory>[];
    final carsSubCategories = showCarsSubCategoryPicker
        ? MarketplaceCatalog.carsPublishSubCategories
            .map(
              (sub) => ServiceCategory(
                id: sub.id,
                titleAr: sub.titleAr,
                titleEn: sub.titleEn,
                image: sub.image,
              ),
            )
            .toList()
        : const <ServiceCategory>[];
    final subCategoryOptions = showShoppingSubCategoryPicker
        ? shoppingSubCategories
        : carsSubCategories;
    final storeSections = showStoreSectionPicker
        ? appProvider.merchantProductSections
        : const [];
    final storeSectionLabel = showRestaurantSectionPicker
        ? 'قسم داخل مطعمك'
        : 'قسم داخل متجرك';
    final isEdit = widget.item != null;
    final title = isEdit
        ? labels.editItemAr
        : labels.addItemAr;

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
                        'اختر الخدمة المستهدفة',
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
                              category.titleAr,
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
                        showShoppingSubCategoryPicker
                            ? 'اختر قسم التسوق'
                            : 'اختر نوع خدمة السيارات',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: subCategoryOptions.any((element) =>
                                element.id == _selectedSubCategoryId)
                            ? _selectedSubCategoryId
                            : null,
                        items: subCategoryOptions.map((subCategory) {
                          return DropdownMenuItem<String>(
                            value: subCategory.id,
                            child: Text(
                              subCategory.titleAr,
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
                            return showShoppingSubCategoryPicker
                                ? 'اختر قسمًا فرعيًا للمنتج'
                                : 'اختر نوع الخدمة (4 راكب، حمل، باص، …)';
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
                    if (showStoreSectionPicker) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              storeSectionLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MerchantStoreSectionsScreen(),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text(
                              'إدارة الأقسام',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (storeSections.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            showRestaurantSectionPicker
                                ? 'أنشئ قسماً واحداً على الأقل (بيتزا، شاورما، غربي…) ثم اختره للصنف.'
                                : 'أنشئ قسماً واحداً على الأقل (مكسرات، حلويات…) ثم اختره للمنتج.',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: storeSections
                                  .any((s) => s.id == _selectedSectionId)
                              ? _selectedSectionId
                              : null,
                          items: storeSections
                              .map(
                                (section) => DropdownMenuItem<String>(
                                  value: section.id,
                                  child: Text(
                                    section.nameAr,
                                    style:
                                        const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedSectionId = value);
                          },
                          validator: (value) {
                            if (storeSections.isNotEmpty &&
                                (value == null || value.isEmpty)) {
                              return 'اختر قسم المتجر للمنتج';
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
                      'أضف صورة لـ ${labels.itemSingularAr} لتظهر بشكل احترافي',
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
                                      'رفع صورة',
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
                        'تم اختيار الصورة بنجاح',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'اسم ${labels.itemSingularAr}',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'السعر',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'أدخل سعراً صحيحاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'وصف ${labels.itemSingularAr}',
                      controller: _descController,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل الوصف';
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
                        'حالة التوفر',
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _isAvailable
                            ? 'متوفر'
                            : 'غير متوفر',
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
                            _saveItem(context, appProvider, serviceId),
                        child: Text(
                          isEdit
                              ? 'حفظ التعديل'
                              : labels.addItemAr,
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

  Future<void> _showSuccessDialog(BuildContext context, String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تم بنجاح',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // إغلاق الدايلوج
              Navigator.pop(context); // إغلاق الشاشة
            },
            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await AppHelpers.pickImage(context);
    if (picked == null) return;

    // رفع صورة المنتج للسحابة فوراً
    final provider = context.read<AppProvider>();
    final url = await provider.uploadImage(File(picked.path));

    if (url != null) {
      setState(() {
        _imageBase64 = url; // تخزين الرابط (URL) في المتغير المخصص للصور
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

  Future<void> _saveItem(
    BuildContext context,
    AppProvider provider,
    String serviceId,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!provider.canPublishForService(serviceId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد موقع المتجر على الخريطة قبل نشر المنتج.'),
        ),
      );
      return;
    }
    if ((serviceId == 'product' || serviceId == 'restaurant') &&
        provider.merchantProductSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serviceId == 'restaurant'
                ? 'أنشئ قسماً داخل مطعمك أولاً من «إدارة الأقسام».'
                : 'أنشئ قسماً داخل متجرك أولاً من «إدارة الأقسام».',
          ),
        ),
      );
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
      subCategory: (serviceId == 'product' || serviceId == 'cars')
          ? (_selectedSubCategoryId ?? widget.item?.subCategory)
          : widget.item?.subCategory,
      sectionId: (serviceId == 'product' || serviceId == 'restaurant')
          ? _selectedSectionId
          : widget.item?.sectionId,
      categoryLabelAr: (serviceId == 'product' || serviceId == 'restaurant') &&
              _selectedSectionId != null &&
              _selectedSectionId!.isNotEmpty
          ? (provider.merchantProductSectionName(_selectedSectionId) ??
              labels.productsTitleAr)
          : labels.productsTitleAr,
      categoryLabelEn: labels.productsTitleEn,
      image: (_imageBase64 != null && _imageBase64!.startsWith('http'))
          ? _imageBase64!
          : widget.item?.image ??
              (serviceId == 'restaurant'
                  ? 'assets/images/cat_restaurant.png'
                  : serviceId == 'cars'
                      ? 'assets/images/cat_cars.png'
                      : serviceId == 'real_estate'
                          ? 'assets/images/re_house.png'
                          : 'assets/images/cat_shopping.png'),
      imageBase64: _imageBase64,
      prepMinutes: widget.item?.prepMinutes,
      isAvailable: _isAvailable,
      avgPriceLabelAr: 'السعر',
      avgPriceLabelEn: 'Price',
      actionLabelAr: labels.actionLabelAr,
      actionLabelEn: labels.actionLabelEn,
    );

    try {
      if (isEdit) {
        provider.updateProduct(item);
      } else {
        await provider.addProduct(item);
      }
      if (!context.mounted) return;

      if (!isEdit && serviceId == 'used') {
        _showSuccessDialog(context, 'تم استلام طلب النشر. سيظهر الإعلان للزبائن بعد مراجعة الإدارة والموافقة عليه.');
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!context.mounted) return;
      final raw = error.toString();
      final message = raw.contains('Missing authorization token') ||
              raw.contains('Invalid authorization token') ||
              raw.contains('401')
          ? 'انتهت جلسة الدخول. سجل الخروج ثم ادخل مرة أخرى.'
          : raw.contains('يرجى تحديد موقع المتجر على الخريطة')
              ? 'حدد موقع المتجر على الخريطة أولاً، ثم أعد نشر المنتج.'
          : raw.contains('Network error')
              ? 'فشل الاتصال بالإنترنت أو بالخادم. حاول مرة أخرى.'
              : 'تعذر حفظ المنتج في السحابة. تحقق من الاتصال وحاول مرة أخرى.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }
}
