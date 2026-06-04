import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/merchant_product_section.dart';
import '../../providers/app_provider.dart';

const _brand = Color(0xFFF5A01D);

/// إدارة أقسام منتجات متجر التسوق (يُنشئها التاجر).
class MerchantStoreSectionsScreen extends StatefulWidget {
  const MerchantStoreSectionsScreen({super.key});

  @override
  State<MerchantStoreSectionsScreen> createState() =>
      _MerchantStoreSectionsScreenState();
}

class _MerchantStoreSectionsScreenState
    extends State<MerchantStoreSectionsScreen> {
  final _nameController = TextEditingController();
  late List<MerchantProductSection> _sections;
  bool _saving = false;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _sections = List<MerchantProductSection>.from(
      context.read<AppProvider>().merchantProductSections,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _editingId = null;
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().setMerchantProductSections(_sections);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ أقسام المتجر',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر الحفظ: $error',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _submitSection() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل اسم القسم',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    if (_editingId != null) {
      final index = _sections.indexWhere((s) => s.id == _editingId);
      if (index != -1) {
        _sections[index] = _sections[index].copyWith(nameAr: name);
      }
    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _sections.add(
        MerchantProductSection(
          id: id,
          nameAr: name,
          sortOrder: _sections.length,
        ),
      );
    }
    setState(_resetForm);
  }

  Future<void> _deleteSection(MerchantProductSection section) async {
    final provider = context.read<AppProvider>();
    final count = provider.merchantProductsInSection(section.id);
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن حذف «${section.nameAr}» — مرتبط بـ $count منتج',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف القسم',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: Text(
          'حذف «${section.nameAr}»؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _brand),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _sections.removeWhere((s) => s.id == section.id);
      if (_editingId == section.id) _resetForm();
    });
  }

  void _startEdit(MerchantProductSection section) {
    setState(() {
      _editingId = section.id;
      _nameController.text = section.nameAr;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'أقسام المتجر',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'أنشئ أقساماً داخل متجرك (مثل: مكسرات، حلويات، عروض). '
                'عند دخول الزبون لمتجرك يرى المنتجات مرتبة حسب هذه الأقسام وليس كلها معاً.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  height: 1.5,
                  fontSize: 13,
                  color: Color(0xFF5D4037),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingId == null ? 'قسم جديد' : 'تعديل القسم',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'اكتب القسم الذي تريد عمله',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_editingId != null)
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text(
                            'إلغاء التعديل',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submitSection,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _editingId == null ? 'إضافة القسم' : 'حفظ التعديل',
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'أقسامك (${_sections.length})',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            if (_sections.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'لا توجد أقسام بعد. أضف قسماً واحداً على الأقل قبل ربط المنتجات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.grey.shade600,
                    height: 1.45,
                  ),
                ),
              )
            else
              ..._sections.map((section) {
                final count = provider.merchantProductsInSection(section.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: ListTile(
                    title: Text(
                      section.nameAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '$count منتج',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.pencil, size: 20),
                          onPressed: () => _startEdit(section),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteSection(section),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _saving ? null : _saveAll,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ الأقسام',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
