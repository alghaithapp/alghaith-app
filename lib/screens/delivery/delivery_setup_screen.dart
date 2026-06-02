import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

class DeliverySetupScreen extends StatefulWidget {
  const DeliverySetupScreen({super.key});

  @override
  State<DeliverySetupScreen> createState() => _DeliverySetupScreenState();
}

class _DeliverySetupScreenState extends State<DeliverySetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _areaController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final profile =
        Provider.of<AppProvider>(context, listen: false).courierProfile ?? {};
    _nameController =
        TextEditingController(text: '${profile['name'] ?? ''}'.trim());
    _phoneController = TextEditingController(
      text: '${profile['phone'] ?? Provider.of<AppProvider>(context, listen: false).authPhone ?? ''}'
          .trim(),
    );
    _vehicleController =
        TextEditingController(text: '${profile['vehicle'] ?? 'دراجة نارية'}'.trim());
    _areaController =
        TextEditingController(text: '${profile['area'] ?? ''}'.trim());
    _notesController =
        TextEditingController(text: '${profile['notes'] ?? ''}'.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isEditing = provider.hasCourierProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل ملف المندوب' : 'تسجيل مندوب توصيل',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D4D), Color(0xFF007A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.motorcycle,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مندوب توصيل — المطاعم وتسوق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل بياناتك لاستلام وتوصيل طلبات الزبائن من المطاعم والمحلات.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Field(
            label: 'الاسم الكامل',
            controller: _nameController,
          ),
          _Field(
            label: 'رقم الهاتف',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            label: 'نوع الدراجة',
            controller: _vehicleController,
          ),
          _Field(
            label: 'منطقة العمل',
            controller: _areaController,
          ),
          _Field(
            label: 'ملاحظات',
            controller: _notesController,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: const Color(0xFF007A7A),
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(vertical: 15),
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال الاسم'),
                    ),
                  );
                  return;
                }
                await provider.setCourierProfile({
                  'name': name,
                  'phone': _phoneController.text.trim(),
                  'vehicle': _vehicleController.text.trim(),
                  'area': _areaController.text.trim(),
                  'notes': _notesController.text.trim(),
                  'available': profileAvailable(provider),
                });
                if (!context.mounted) return;
                if (isEditing) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                isEditing ? 'حفظ التعديلات' : 'حفظ وتفعيل حساب المندوب',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool profileAvailable(AppProvider provider) {
    return provider.courierProfile?['available'] as bool? ?? true;
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
