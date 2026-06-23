import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';

class MerchantProfileScreen extends StatelessWidget {
  const MerchantProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantActiveLabels;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final showWorkSamples =
        provider.merchantActiveServiceId != 'restaurant' && workSamples.isNotEmpty;
    final profileImageBase64 = provider.merchantProfileImageBase64;
    final services = provider.merchantServiceIds;
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : 'ملف التاجر';

    String showOrDash(String value) =>
        value.trim().isNotEmpty ? value.trim() : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'ملف ${labels.storeLabelAr}',
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
                colors: [Color(0xFF111111), Color(0xFF2E2E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: AppImage(
                    imageData: profileImageBase64,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.merchantDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            title: 'بيانات التواصل',
            children: [
              _InfoRow(
                label: 'الهاتف',
                value: showOrDash(provider.merchantPhone),
              ),
              _InfoRow(
                label: 'WhatsApp',
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
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'الخدمات',
            children: [
              if (services.isEmpty)
                Text(
                  'لا توجد خدمات مفعلة بعد.',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Cairo',
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: services.map((serviceId) {
                    final serviceLabels = merchantServiceLabels(serviceId);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        serviceLabels.storeLabelAr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
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
              title: 'نماذج الأعمال',
              trailing: const SizedBox.shrink(),
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workSamples.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
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
          _SectionCard(
            title: 'ملاحظات',
            children: [
              Text(
                'يمكنك تعديل هذا الملف من شاشة تعديل بيانات التاجر، وستنعكس التغييرات هنا مباشرة.',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  height: 1.5,
                ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
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

  const _InfoRow({required this.label, required this.value});

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
                fontSize: 12,
                fontFamily: 'Cairo',
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
