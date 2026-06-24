import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/helpers.dart';
import '../utils/merchant_service_labels.dart';

import '../widgets/app_image.dart';
import '../widgets/account/account_server_loading_view.dart';

class AccountFullScreen extends StatelessWidget {
  const AccountFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final appUser = provider.appUserRecord ?? const <String, dynamic>{};
    final isMerchant = provider.isMerchant;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final services = provider.merchantServiceIds;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant';
    final lastSeen = appUser['last_seen_at']?.toString();
    String showOrDash(String value) =>
        value.trim().isNotEmpty ? value.trim() : '-';

    final isLoading = provider.isLoadingAccountFromServer;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'بيانات الحساب الكامل',
          style:
              TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: isLoading
          ? const Column(
              children: [
                SizedBox(height: 48),
                AccountServerLoadingView(),
              ],
            )
          : ListView(
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
                        'رقم الهاتف: ${provider.authPhone ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الدور الحالي: ${provider.userRole ?? '-'}',
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
            title: 'app_users',
            children: [
              _InfoRow(label: 'الاسم', value: provider.customerName),
              _InfoRow(
                  label: 'رقم الهاتف', value: provider.authPhone ?? '-'),
              _InfoRow(
                  label: 'الدور', value: provider.userRole ?? '-'),
              _InfoRow(
                label: 'آخر دخول',
                value: lastSeen ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'ملف الزبون',
            children: [
              _InfoRow(
                label: 'الاسم الظاهر',
                value: provider.customerName,
              ),
              _InfoRow(
                label: 'رقم الزبون',
                value: provider.customerPhone,
              ),
              _InfoRow(
                label: 'العنوان',
                value: provider.customerAddress.isNotEmpty
                    ? provider.customerAddress
                    : '-',
              ),
              _InfoRow(
                label: 'الصورة',
                value: provider.customerAvatarBase64 != null &&
                        provider.customerAvatarBase64!.isNotEmpty
                    ? 'موجودة'
                    : 'غير موجودة',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'ملف التاجر',
            children: [
              _InfoRow(
                label: 'اسم المتجر',
                value: showOrDash(provider.merchantStoreName),
              ),
              _InfoRow(
                label: 'واتساب',
                value: showOrDash(provider.merchantWhatsApp),
              ),
              _InfoRow(
                label: 'العنوان',
                value: showOrDash(provider.merchantAddress),
              ),
              _InfoRow(
                label: 'أوقات العمل',
                value:
                    '${showOrDash(provider.merchantOpenTime)} - ${showOrDash(provider.merchantCloseTime)}',
              ),
              const SizedBox(height: 8),
              if (services.isEmpty)
                const Text(
                  'لا توجد خدمات مفعلة بعد.',
                  style: TextStyle(fontFamily: 'Cairo'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services.map((serviceId) {
                    final labels = merchantServiceLabels(serviceId);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A01D),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF5A01D).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        labels.storeLabelAr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          if (showWorkSamples) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'صور الأعمال',
              children: [
                if (workSamples.isEmpty)
                  const Text(
                    'لا توجد صور أعمال.',
                    style: TextStyle(fontFamily: 'Cairo'),
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
              title: 'روابط سريعة',
              children: [
                const Text(
                  'يمكن للزبائن مراسلتك مباشرة داخل التطبيق من صفحة متجرك أو الطلبات.',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
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
