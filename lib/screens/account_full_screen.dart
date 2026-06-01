import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/helpers.dart';
import '../utils/merchant_service_labels.dart';

import '../widgets/app_image.dart';

class AccountFullScreen extends StatelessWidget {
  const AccountFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final appUser = provider.appUserRecord ?? const <String, dynamic>{};
    final isMerchant = provider.isMerchant;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final services = provider.merchantServiceIds;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant';
    final lastSeen = appUser['last_seen_at']?.toString();
    String showOrDash(String value) =>
        value.trim().isNotEmpty ? value.trim() : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          isAr ? 'بيانات الحساب الكامل' : 'Full account data',
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
                colors: [Color(0xFF111111), Color(0xFF2A2A2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                _AvatarPreview(
                  imageBase64: provider.customerAvatarBase64,
                  fallbackIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'رقم الهاتف: ${provider.authPhone ?? '-'}'
                            : 'Phone: ${provider.authPhone ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'الدور الحالي: ${provider.userRole ?? '-'}'
                            : 'Current role: ${provider.userRole ?? '-'}',
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
          _SectionCard(
            title: isAr ? 'app_users' : 'app_users',
            children: [
              _InfoRow(
                  label: isAr ? 'الاسم' : 'Name', value: provider.customerName),
              _InfoRow(
                  label: isAr ? 'رقم الهاتف' : 'Phone',
                  value: provider.authPhone ?? '-'),
              _InfoRow(
                  label: isAr ? 'الدور' : 'Role',
                  value: provider.userRole ?? '-'),
              _InfoRow(
                label: isAr ? 'آخر دخول' : 'Last seen',
                value: lastSeen ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: isAr ? 'ملف الزبون' : 'Customer profile',
            children: [
              _InfoRow(
                label: isAr ? 'الاسم الظاهر' : 'Display name',
                value: provider.customerName,
              ),
              _InfoRow(
                label: isAr ? 'رقم الزبون' : 'Customer phone',
                value: provider.customerPhone,
              ),
              _InfoRow(
                label: isAr ? 'العنوان' : 'Address',
                value: provider.customerAddress.isNotEmpty
                    ? provider.customerAddress
                    : '-',
              ),
              _InfoRow(
                label: isAr ? 'الصورة' : 'Avatar',
                value: provider.customerAvatarBase64 != null &&
                        provider.customerAvatarBase64!.isNotEmpty
                    ? (isAr ? 'موجودة' : 'Available')
                    : (isAr ? 'غير موجودة' : 'Not set'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: isAr ? 'ملف التاجر' : 'Merchant profile',
            children: [
              _InfoRow(
                label: isAr ? 'اسم المتجر' : 'Store name',
                value: showOrDash(provider.merchantStoreName),
              ),
              _InfoRow(
                label: isAr ? 'واتساب' : 'WhatsApp',
                value: showOrDash(provider.merchantWhatsApp),
              ),
              _InfoRow(
                label: isAr ? 'العنوان' : 'Address',
                value: showOrDash(provider.merchantAddress),
              ),
              _InfoRow(
                label: isAr ? 'أوقات العمل' : 'Working hours',
                value:
                    '${showOrDash(provider.merchantOpenTime)} - ${showOrDash(provider.merchantCloseTime)}',
              ),
              const SizedBox(height: 8),
              if (services.isEmpty)
                Text(
                  isAr ? 'لا توجد خدمات مفعلة بعد.' : 'No services enabled yet.',
                  style: const TextStyle(fontFamily: 'Cairo'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services.map((serviceId) {
                    final labels = merchantServiceLabels(serviceId);
                    return Chip(
                      label: Text(
                        isAr ? labels.storeLabelAr : labels.storeLabelEn,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          if (showWorkSamples) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: isAr ? 'صور الأعمال' : 'Work samples',
              children: [
                if (workSamples.isEmpty)
                  Text(
                    isAr ? 'لا توجد صور أعمال.' : 'No work sample images.',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workSamples.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final image = workSamples[index];
                      return GestureDetector(
                        onTap: () => _openPreview(context, image),
                        child: AppImage(
                          imageData: image,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (isMerchant)
            _SectionCard(
              title: isAr ? 'روابط سريعة' : 'Quick actions',
              children: [
                ElevatedButton.icon(
                  onPressed: () => AppHelpers.launchWhatsApp(
                    provider.merchantWhatsApp,
                    isAr
                        ? 'مرحباً، هذا ملفي الكامل'
                        : 'Hello, this is my full profile.',
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label:
                      Text(isAr ? 'مشاركة عبر واتساب' : 'Share via WhatsApp'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, String imageSource) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InteractiveViewer(
              child: AppImage(
                imageData: imageSource,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String? imageBase64;
  final IconData fallbackIcon;

  const _AvatarPreview({
    required this.imageBase64,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
      ),
      child: AppImage(
        imageData: imageBase64,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
