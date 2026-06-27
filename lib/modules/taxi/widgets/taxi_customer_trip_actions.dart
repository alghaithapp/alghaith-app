import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxi_request.dart';
import '../providers/taxi_provider.dart';

/// أزرار إلغاء / إنهاء الرحلة للزبون — تظهر حسب حالة الطلب.
class TaxiCustomerTripActions extends StatefulWidget {
  final TaxiRequest request;
  final VoidCallback? onTripEnded;

  const TaxiCustomerTripActions({
    super.key,
    required this.request,
    this.onTripEnded,
  });

  @override
  State<TaxiCustomerTripActions> createState() =>
      _TaxiCustomerTripActionsState();
}

class _TaxiCustomerTripActionsState extends State<TaxiCustomerTripActions> {
  bool _busy = false;

  Future<void> _onCancel() async {
    final request = widget.request;
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'إلغاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'هل تريد إلغاء الرحلة؟',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('رجوع', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'نعم، إلغاء',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<TaxiProvider>();
    final ok = await provider.cancelRequest(request.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إلغاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      widget.onTripEnded?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'تعذر إلغاء الطلب',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onComplete() async {
    final request = widget.request;
    if (!request.canCustomerCompleteTrip || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'إنهاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'هل وصلت إلى وجهتك وتريد إنهاء الرحلة؟\n'
            'استخدم هذا الخيار إذا نسي الكابتن إكمال الطلب.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع', style: TextStyle(fontFamily: 'Cairo')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'نعم، أنهيت الرحلة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<TaxiProvider>();
    final ok = await provider.completeTrip(request.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنهاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      widget.onTripEnded?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'تعذر إنهاء الرحلة',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final showCancel = request.canCustomerCancel;
    final showComplete = request.canCustomerCompleteTrip;

    if (!showCancel && !showComplete) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showComplete) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _onComplete,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text(
                'أنهيت الرحلة — إكمال الطلب',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (showCancel) const SizedBox(height: 10),
        ],
        if (showCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _onCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text(
                'إلغاء الرحلة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
