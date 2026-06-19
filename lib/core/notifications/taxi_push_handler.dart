import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

/// معالج إشعارات طلبات التكسي — يعرض نافذة منبثقة داخل التطبيق عند ورود طلب جديد
/// مع زرّي: قبول / رفض.
class TaxiPushHandler {
  TaxiPushHandler._();

  /// البيانات المستخرجة من الإشعار الوارد
  static final _handledKeys = <String>{};

  /// معالجة إشعار تكسي وارد أثناء تشغيل التطبيق (Foreground)
  static void handleForegroundPush(
    BuildContext context, {
    required String requestId,
    required String title,
    required String body,
    String? eventKey,
  }) {
    // منع التكرار — نافذة واحدة لكل طلب
    final dedupKey = 'foreground:$requestId';
    if (_handledKeys.contains(dedupKey)) return;
    _handledKeys.add(dedupKey);

    // إزالة المفتاح بعد 30 ثانية للسماح بإعادة الظهور
    Timer(const Duration(seconds: 30), () {
      _handledKeys.remove(dedupKey);
    });

    // إظهار النافذة المنبثقة
    _showTaxiRequestDialog(context, requestId: requestId, body: body);
  }

  /// إظهار نافذة طلب التكسي داخل التطبيق بقبول / رفض
  static void _showTaxiRequestDialog(
    BuildContext context, {
    required String requestId,
    required String body,
  }) {
    // استخدام addPostFrameCallback لضمان وجود BuildContext صالح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _TaxiRequestNotificationDialog(
            requestId: requestId,
            body: body,
          );
        },
      );
    });
  }
}

/// نافذة الطلب المنبثقة بداخلها تفاصيل الرحلة وزرّي قبول / رفض
class _TaxiRequestNotificationDialog extends StatefulWidget {
  final String requestId;
  final String body;

  const _TaxiRequestNotificationDialog({
    required this.requestId,
    required this.body,
  });

  @override
  State<_TaxiRequestNotificationDialog> createState() =>
      _TaxiRequestNotificationDialogState();
}

class _TaxiRequestNotificationDialogState
    extends State<_TaxiRequestNotificationDialog> {
  bool _isBusy = false;
  String? _resultMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الرأس: أيقونة 🚕 + عنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('🚕', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'طلب تكسي جديد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // جسم الإشعار — تفاصيل الرحلة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // رسالة النتيجة بعد الإجراء
          if (_resultMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _resultMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _resultMessage!.contains('✅')
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),

          // الأزرار
          Row(
            children: [
              // زر الرفض
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _reject(context),
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 20),
                    label: const Text('رفض', style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // زر القبول
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : () => _accept(context),
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('قبول', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    setState(() {
      _isBusy = true;
      _resultMessage = null;
    });

    try {
      final provider = context.read<AppProvider>();
      await provider.acceptTaxiRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _resultMessage = '✅ تم قبول الطلب بنجاح';
      });
      // إغلاق النافذة بعد ثانية
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultMessage = '❌ تعذر قبول الطلب: ${e.toString().replaceAll('Error: ', '')}';
        _isBusy = false;
      });
    }
  }

  Future<void> _reject(BuildContext context) async {
    setState(() {
      _isBusy = true;
      _resultMessage = null;
    });

    try {
      final provider = context.read<AppProvider>();
      await provider.rejectTaxiRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _resultMessage = '⏭️ تم رفض الطلب';
      });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultMessage = '❌ تعذر رفض الطلب';
        _isBusy = false;
      });
    }
  }
}
