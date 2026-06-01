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
      TextEditingController(text: 'جاهز لاستلام الطلبات القريبة');

  String _driverType = 'taxi';

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
    final isAr = provider.lang == 'ar';
    final title = isAr ? 'تسجيل حساب السائق' : 'Driver Account Setup';
    final subtitle = _driverType == 'taxi'
        ? (isAr ? 'سائق تكسي فقط' : 'Taxi service only')
        : _driverType == 'delivery'
            ? (isAr ? 'مندوب توصيل فقط' : 'Delivery service only')
            : (isAr ? 'الخدمتان معًا' : 'Both services');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          title,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr
                            ? 'أنت على وشك إنشاء حساب سائق للخدمات'
                            : 'You are setting up a service driver account',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'اختر الخدمات التي تريد استقبالها ثم أدخل بياناتك الأساسية.'
                            : 'Choose the services you want to receive and enter your details.',
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
          _TypeSelector(
            isAr: isAr,
            selectedType: _driverType,
            onChanged: (value) => setState(() => _driverType = value),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          _Field(
            label: isAr ? 'الاسم الكامل' : 'Full name',
            controller: _nameController,
          ),
          _Field(
            label: isAr ? 'رقم الهاتف' : 'Phone number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            label: isAr ? 'نوع السيارة' : 'Vehicle type',
            controller: _vehicleController,
          ),
          _Field(
            label: isAr ? 'رقم اللوحة' : 'Plate number',
            controller: _plateController,
          ),
          _Field(
            label: isAr ? 'المنطقة' : 'Working area',
            controller: _areaController,
          ),
          _Field(
            label: isAr ? 'ملاحظات' : 'Notes',
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
                provider.setDriverType(_driverType);
                await provider.setDriverProfile({
                  'type': _driverType,
                  'services': {
                    'taxi': _driverType == 'taxi' || _driverType == 'both',
                    'delivery':
                        _driverType == 'delivery' || _driverType == 'both',
                  },
                  'name': _nameController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'vehicle': _vehicleController.text.trim(),
                  'plate': _plateController.text.trim(),
                  'area': _areaController.text.trim(),
                  'notes': _notesController.text.trim(),
                });
                provider.setUserRole('driver');
              },
              child: Text(
                isAr ? 'حفظ وتفعيل الحساب' : 'Save and activate',
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
}

class _TypeSelector extends StatelessWidget {
  final bool isAr;
  final String selectedType;
  final ValueChanged<String> onChanged;

  const _TypeSelector({
    required this.isAr,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                isSelected: selectedType == 'taxi',
                title: isAr ? 'سائق تكسي فقط' : 'Taxi only',
                subtitle: isAr ? 'استقبال طلبات التكسي' : 'Taxi requests only',
                icon: Icons.local_taxi_rounded,
                color: Colors.orange,
                onTap: () => onChanged('taxi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeCard(
                isSelected: selectedType == 'delivery',
                title: isAr ? 'مندوب توصيل فقط' : 'Delivery only',
                subtitle: isAr ? 'استقبال طلبات المطاعم' : 'Restaurant orders only',
                icon: Icons.delivery_dining_rounded,
                color: Colors.blue,
                onTap: () => onChanged('delivery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TypeCard(
          isSelected: selectedType == 'both',
          title: isAr ? 'الخدمتان معًا' : 'Both services',
          subtitle: isAr
              ? 'التكسي وطلبات التوصيل معًا'
              : 'Taxi and delivery requests together',
          icon: Icons.sync_alt_rounded,
          color: Colors.green,
          onTap: () => onChanged('both'),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final bool isSelected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.35,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
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
