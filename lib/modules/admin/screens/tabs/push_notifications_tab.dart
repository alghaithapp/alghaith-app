import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/api_client.dart';

class PushNotificationsTab extends StatefulWidget {
  const PushNotificationsTab({super.key});

  @override
  State<PushNotificationsTab> createState() => _PushNotificationsTabState();
}

class _PushNotificationsTabState extends State<PushNotificationsTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _audience = 'all';
  bool _storeUpdate = false;
  bool _isSending = false;
  Map<String, dynamic>? _result;
  String? _error;

  final List<Map<String, String>> _audiences = [
    {'key': 'all', 'label': 'الجميع'},
    {'key': 'customers', 'label': 'الزبائن'},
    {'key': 'merchants', 'label': 'التجار'},
    {'key': 'drivers', 'label': 'السائقين'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال العنوان والنص', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await ApiClient.instance.post(
        '/db/admin/push/send',
        body: {
          'title': title,
          'body': body,
          'audience': _audience,
          'storeUpdate': _storeUpdate,
        },
      );
      setState(() {
        _result = result is Map ? Map<String, dynamic>.from(result) : null;
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إرسال إشعار يدوي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اكتب العنوان والنص واختر الجمهور المستهدف',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // الجمهور
          const Text(
            'الجمهور المستهدف',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _audiences.map((a) {
              final isSelected = _audience == a['key'];
              return ChoiceChip(
                label: Text(
                  a['label']!,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                ),
                selected: isSelected,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                onSelected: (_) => setState(() => _audience = a['key']!),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // العنوان
          const Text(
            'العنوان',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'مثال: تحديث جديد في التطبيق',
              hintStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),

          // النص
          const Text(
            'النص',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bodyController,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'مثال: تم إضافة ميزة جديدة يمكنك تجربتها الآن',
              hintStyle: const TextStyle(fontFamily: 'Cairo'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 24),

          // تحديث التطبيق
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _storeUpdate,
                  onChanged: (v) => setState(() => _storeUpdate = v ?? false),
                  activeColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'تحديث التطبيق',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'عند الضغط على الإشعار يذهب المستخدم إلى المتجر (Google Play / App Store)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // زر الإرسال
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال الإشعار',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),

          // النتيجة
          if (_result != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ تم الإرسال',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تم الإرسال إلى ${_result!['sent']} جهاز',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                  if ((_result!['failed'] ?? 0) > 0)
                    Text(
                      'فشل: ${_result!['failed']} جهاز',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
                    ),
                  if ((_result!['platforms'] as List?)?.isNotEmpty == true)
                    Text(
                      'المنصات: ${(_result!['platforms'] as List).join(', ')}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '❌ $_error',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
