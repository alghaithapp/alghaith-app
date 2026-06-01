import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
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

  String _profileName(Map<String, dynamic> profile, bool isAr) {
    final storeName = profile['store_name']?.toString().trim();
    final fullName = profile['full_name']?.toString().trim();
    final professionalInfo = profile['professional_info'];
    final infoName = professionalInfo is Map
        ? (professionalInfo['name']?.toString().trim() ?? '')
        : '';
    final fallback = isAr ? 'مهني' : 'Professional';
    return [storeName, infoName, fullName]
            .where((value) => value != null && value.trim().isNotEmpty)
            .map((value) => value!.trim())
            .firstOrNull ??
        fallback;
  }

  String _profileDescription(Map<String, dynamic> profile, bool isAr) {
    final description = profile['description']?.toString().trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    final professionalInfo = profile['professional_info'];
    if (professionalInfo is Map) {
      final info = professionalInfo['description']?.toString().trim();
      if (info != null && info.isNotEmpty) return info;
    }
    return isAr
        ? 'متاح للتواصل مباشرة عبر واتساب'
        : 'Available for direct WhatsApp contact';
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
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final query = _searchController.text.trim().toLowerCase();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? widget.profession.titleAr : widget.profession.titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: isAr ? 'الرجوع' : 'Back',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ProfessionalDisclaimer(isAr: isAr),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: isAr ? 'ابحث عن مهني' : 'Search professional',
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
                    return _EmptyState(
                      isAr: isAr,
                      message: isAr
                          ? 'تعذر تحميل بيانات المهنيين'
                          : 'Failed to load professionals',
                    );
                  }

                  final profiles = snapshot.data ?? const [];
                  final filtered = profiles.where((profile) {
                    final name = _profileName(profile, isAr).toLowerCase();
                    final desc =
                        _profileDescription(profile, isAr).toLowerCase();
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
                      isAr: isAr,
                      message: query.isEmpty
                          ? (isAr
                              ? 'لا يوجد مهنيون مسجلون في هذا التخصص بعد'
                              : 'No professionals registered for this category yet')
                          : (isAr
                              ? 'لا توجد نتائج مطابقة'
                              : 'No matching results'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      return _ProfessionalCard(
                        isAr: isAr,
                        name: _profileName(profile, isAr),
                        description: _profileDescription(profile, isAr),
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
  final bool isAr;

  const _ProfessionalDisclaimer({
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final text = isAr
        ? 'تنبيه: التطبيق وسيط فقط بينك وبين المهني. الاتفاق على السعر والتفاصيل وموعد التنفيذ يتم مباشرة عبر واتساب بين الطرفين. التطبيق لا يأخذ أي نسبة من العمل ولا يتحمل مسؤولية جودة الخدمة أو التنفيذ.'
        : 'Notice: the app is only a middleman between you and the professional. Price, details, and timing are agreed directly via WhatsApp. The app takes no commission and is not responsible for service quality or execution.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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
  final bool isAr;
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
    required this.isAr,
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
    final avatar = profileImageBase64 != null && profileImageBase64!.isNotEmpty
        ? MemoryImage(base64Decode(profileImageBase64!))
        : null;

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
              isAr ? 'العنوان: $address' : 'Address: $address',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ],
          if (openTime.trim().isNotEmpty || closeTime.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'الدوام: ${openTime.isEmpty ? '-' : openTime} - ${closeTime.isEmpty ? '-' : closeTime}'
                  : 'Hours: ${openTime.isEmpty ? '-' : openTime} - ${closeTime.isEmpty ? '-' : closeTime}',
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
                      : () => AppHelpers.launchWhatsApp(
                            whatsapp,
                            isAr
                                ? 'مرحبًا، أريد الاستفسار عن الخدمة'
                                : 'Hello, I would like to ask about the service',
                          ),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(
                    isAr ? 'واتساب' : 'WhatsApp',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (phone.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => AppHelpers.makePhoneCall(phone),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(
                    isAr ? 'اتصال' : 'Call',
                    style: const TextStyle(fontFamily: 'Cairo'),
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
  final bool isAr;
  final String message;

  const _EmptyState({
    required this.isAr,
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
