import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/supabase_service.dart';
import '../utils/guest_gate.dart';
import '../utils/helpers.dart';
import '../widgets/app_image.dart';

class ProfessionalsDirectoryScreen extends StatefulWidget {
  final ServiceCategory profession;

  const ProfessionalsDirectoryScreen({
    super.key,
    required this.profession,
  });

  @override
  State<ProfessionalsDirectoryScreen> createState() =>
      _ProfessionalsDirectoryScreenState();
}

class _ProfessionalsDirectoryScreenState
    extends State<ProfessionalsDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _futureProfiles;

  @override
  void initState() {
    super.initState();
    _futureProfiles = _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadProfiles() {
    return SupabaseService.loadProfessionalProfiles(
      professionId: widget.profession.id,
    );
  }

  String _profileName(Map<String, dynamic> profile) {
    final storeName = profile['store_name']?.toString().trim();
    final fullName = profile['full_name']?.toString().trim();
    final professionalInfo = profile['professional_info'];
    final infoName = professionalInfo is Map
        ? (professionalInfo['name']?.toString().trim() ?? '')
        : '';
    const fallback = 'مهني';
    return [storeName, infoName, fullName]
            .where((value) => value != null && value.trim().isNotEmpty)
            .map((value) => value!.trim())
            .firstOrNull ??
        fallback;
  }

  String _profileDescription(Map<String, dynamic> profile) {
    final description = profile['description']?.toString().trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    final professionalInfo = profile['professional_info'];
    if (professionalInfo is Map) {
      final info = professionalInfo['description']?.toString().trim();
      if (info != null && info.isNotEmpty) return info;
    }
    return 'متاح للتواصل مباشرة عبر واتساب';
  }

  List<String> _extractWorkSamples(Map<String, dynamic> profile) {
    final direct = profile['work_sample_images_base64'];
    if (direct is List) {
      return direct
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final info = profile['professional_info'];
    if (info is Map && info['workSampleImagesBase64'] is List) {
      return (info['workSampleImagesBase64'] as List)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _profileWhatsapp(Map<String, dynamic> profile) {
    final whatsapp = profile['whatsapp']?.toString().trim();
    if (whatsapp != null && whatsapp.isNotEmpty) return whatsapp;
    final info = profile['professional_info'];
    if (info is Map) {
      final value = info['whatsapp']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return AppHelpers.supportWhatsAppNumber;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.profession.titleAr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: 'الرجوع',
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ProfessionalDisclaimer(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'ابحث عن مهني',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureProfiles,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (snapshot.hasError) {
                    return const _EmptyState(
                      message: 'تعذر تحميل بيانات المهنيين',
                    );
                  }

                  final profiles = snapshot.data ?? const [];
                  final filtered = profiles.where((profile) {
                    final name = _profileName(profile).toLowerCase();
                    final desc = _profileDescription(profile).toLowerCase();
                    final phone =
                        profile['phone']?.toString().toLowerCase() ?? '';
                    final whatsapp = _profileWhatsapp(profile).toLowerCase();
                    if (query.isEmpty) return true;
                    return name.contains(query) ||
                        desc.contains(query) ||
                        phone.contains(query) ||
                        whatsapp.contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(
                      message: query.isEmpty
                          ? 'لا يوجد مهنيون مسجلون في هذا التخصص بعد'
                          : 'لا توجد نتائج مطابقة',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      return _ProfessionalCard(
                        name: _profileName(profile),
                        description: _profileDescription(profile),
                        phone: profile['phone']?.toString() ?? '',
                        whatsapp: _profileWhatsapp(profile),
                        address: profile['address']?.toString() ?? '',
                        openTime: profile['open_time']?.toString() ?? '',
                        closeTime: profile['close_time']?.toString() ?? '',
                        rating: (profile['rating'] as num?)?.toDouble() ?? 4.8,
                        profileImageBase64:
                            profile['profile_image_base64']?.toString(),
                        workSamples: _extractWorkSamples(profile),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalDisclaimer extends StatelessWidget {
  const _ProfessionalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'تنبيه: التطبيق وسيط فقط بينك وبين المهني. الاتفاق على السعر والتفاصيل وموعد التنفيذ يتم مباشرة عبر واتساب بين الطرفين. التطبيق لا يأخذ أي نسبة من العمل ولا يتحمل مسؤولية جودة الخدمة أو التنفيذ.',
              style: TextStyle(
                fontFamily: 'Cairo',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final String name;
  final String description;
  final String phone;
  final String whatsapp;
  final String address;
  final String openTime;
  final String closeTime;
  final double rating;
  final String? profileImageBase64;
  final List<String> workSamples;

  const _ProfessionalCard({
    required this.name,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.address,
    required this.openTime,
    required this.closeTime,
    required this.rating,
    required this.profileImageBase64,
    required this.workSamples,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF3F3F5),
                child: AppImage(
                  imageData: profileImageBase64,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (address.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'العنوان: $address',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ],
          if (openTime.trim().isNotEmpty || closeTime.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'الدوام: ${openTime.isEmpty ? '-' : openTime} - ${closeTime.isEmpty ? '-' : closeTime}',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ],
          if (workSamples.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workSamples.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppImage(
                      imageData: workSamples[index],
                      width: 82,
                      height: 82,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: whatsapp.trim().isEmpty
                      ? null
                      : () {
                          if (!GuestGate.requireAccount(
                            context,
                            message: 'سجّل دخولك للتواصل مع مزوّد الخدمة.',
                          )) {
                            return;
                          }
                          AppHelpers.launchWhatsApp(
                            whatsapp,
                            'مرحبًا، أريد الاستفسار عن الخدمة',
                          );
                        },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text(
                    'واتساب',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (phone.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك للتواصل مع مزوّد الخدمة.',
                    )) {
                      return;
                    }
                    AppHelpers.makePhoneCall(phone);
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text(
                    'اتصال',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.engineering_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
