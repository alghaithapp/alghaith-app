import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

class DriverSetupScreen extends StatefulWidget {
  const DriverSetupScreen({super.key});

  @override
  State<DriverSetupScreen> createState() => _DriverSetupScreenState();
}

class _DriverSetupScreenState extends State<DriverSetupScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'السائق التجريبي');
  final TextEditingController _phoneController =
      TextEditingController(text: '07700000000');
  final TextEditingController _vehicleController =
      TextEditingController(text: 'تويوتا كامري');
  final TextEditingController _plateController =
      TextEditingController(text: '12345 بغداد');
  final TextEditingController _areaController =
      TextEditingController(text: 'بغداد - المنصور');
  final TextEditingController _notesController =
      TextEditingController(text: 'جاهز لاستلام طلبات التكسي القريبة');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'تسجيل سائق تكسي',
          style:
              TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFF2C2C2C)],
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
                    color: Colors.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.local_taxi_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حساب سائق تكسي — نقل الزبائن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'هذا الحساب لطلبات التكسي فقط. لتوصيل طلبات المطاعم والتسوق استخدم حساب مندوب التوصيل.',
                        style: TextStyle(
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
            label: 'نوع السيارة',
            controller: _vehicleController,
          ),
          _Field(
            label: 'رقم اللوحة',
            controller: _plateController,
          ),
          _Field(
            label: 'المنطقة',
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
              color: Colors.deepOrange,
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(vertical: 15),
              onPressed: () async {
                provider.setDriverType('taxi');
                await provider.setDriverProfile({
                  'type': 'taxi',
                  'services': {'taxi': true, 'delivery': false},
                  'name': _nameController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'vehicle': _vehicleController.text.trim(),
                  'plate': _plateController.text.trim(),
                  'area': _areaController.text.trim(),
                  'notes': _notesController.text.trim(),
                });
                provider.setUserRole('driver');
              },
              child: const Text(
                'إرسال طلب التفعيل',
                style: TextStyle(
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
