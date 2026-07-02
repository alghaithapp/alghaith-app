import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/image_storage_service.dart';
import '../../../utils/helpers.dart';
import '../../../utils/merchant_profile_fields.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/internal_contact_buttons.dart';
import '../../../widgets/service_navigation_buttons.dart';
import '../../../widgets/whatsapp_icon.dart';

/// صفحة تفاصيل مزوّد خدمة تواصل (صيدلية، عيادة، صالون...) بدون سلة أو منتجات.
class ServiceProviderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String titleAr;

  const ServiceProviderDetailScreen({
    super.key,
    required this.profile,
    required this.titleAr,
  });

  String get _storeName => MerchantProfileFields.name(profile);

  String get _phone => MerchantProfileFields.customerVisiblePhone(profile);

  String get _whatsapp => MerchantProfileFields.customerVisibleWhatsApp(profile);

  String get _address => MerchantProfileFields.addressFromMap(profile);

  String get _hours => MerchantProfileFields.workingHoursLabel(profile);

  String get _specialty => MerchantProfileFields.specialty(profile);

  String get _doctorName => MerchantProfileFields.doctorName(profile);

  String get _clinicPhone {
    for (final key in ['clinic_phone', 'clinicPhone', 'doctor_phone', 'doctorPhone']) {
      final value = profile[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _openWhatsApp() async {
    final target = _whatsapp.isNotEmpty ? _whatsapp : _phone;
    if (target.isEmpty) return;
    await AppHelpers.launchWhatsApp(target, 'مرحباً $_storeName');
  }

  @override
  Widget build(BuildContext context) {
    final description = profile['description']?.toString().trim() ?? '';
    final isOpen = MerchantProfileFields.isAcceptingCustomerCalls(profile);
    final coverRef = ImageStorageService.merchantUploadedImageRef(
      profile['cover_image_url'] ?? profile['coverImageBase64'],
    );
    final logoRef = ImageStorageService.merchantUploadedImageRef(
      profile['logo_image_url'] ??
          profile['logoImageBase64'] ??
          profile['profile_image_url'] ??
          profile['profile_image_base64'],
    );

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: ServiceNavigationBar(title: titleAr),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SizedBox(
                      height: 160,
                      child: AppImage(
                        imageData: coverRef,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppImage(
                            imageData: logoRef,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _storeName,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                titleAr,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: isOpen ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOpen ? 'مفتوح الآن' : 'مغلق',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isOpen ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  _infoTile(Icons.location_on_outlined, 'العنوان', _address),
                  if (_specialty.isNotEmpty)
                    _infoTile(Icons.medical_information_outlined, 'التخصص', _specialty),
                  _infoTile(Icons.access_time, 'الدوام', _hours),
                  if (titleAr == 'صيدلية' && _doctorName.isNotEmpty)
                    _infoTile(Icons.medical_services_outlined, 'الصيدلاني', _doctorName),
                  if (titleAr == 'صيدلية' && _clinicPhone.isNotEmpty)
                    _infoTile(Icons.phone_outlined, 'هاتف الصيدلية', _clinicPhone),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InternalContactButtons.store(
                          merchantPhone: _phone.isNotEmpty
                              ? _phone
                              : MerchantProfileFields.merchantInternalContactPhone(profile),
                          storeName: _storeName,
                          merchantProfile: profile,
                          chatLabel: 'مراسلة داخل التطبيق',
                          callLabel: 'اتصال',
                        ),
                        if (_whatsapp.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openWhatsApp,
                              icon: const WhatsAppIcon(size: 20),
                              label: const Text(
                                'تواصل عبر واتساب',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Text(
                titleAr == 'صيدلية'
                    ? 'التطبيق وسيط للتواصل فقط. الاستفسار عن الأدوية والتوصيل يتم مباشرة مع الصيدلية عبر المراسلة أو واتساب.'
                    : 'التطبيق وسيط للتواصل فقط. يمكنك التواصل مع $titleAr مباشرة عبر المراسلة أو واتساب.',
                style: const TextStyle(fontFamily: 'Cairo', height: 1.5, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == 'غير محدد') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
