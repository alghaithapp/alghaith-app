import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';

enum CustomerBannerType {
  accepted,
  rejected,
  timeout,
  onWay,
  delivered,
  preparing,
  courierAccepted,
  pickedUp,
  cancelApproved,
  cancelRejected,
  adjustmentProposed,
  adjustmentAccepted,
  adjustmentRejected,
}

class CustomerBannerData {
  final CustomerBannerType type;
  final String title;
  final String body;
  final String orderNumber;

  const CustomerBannerData({
    required this.type,
    required this.title,
    required this.body,
    required this.orderNumber,
  });
}

class CustomerOrderSnapshot {
  final String statusKey;
  final String? deliveryStatusKey;

  const CustomerOrderSnapshot({
    required this.statusKey,
    this.deliveryStatusKey,
  });
}

/// يكتشف تغيّرات الطلب ويُرجع بيانات البانر المناسبة.
CustomerBannerData? detectCustomerOrderBanner({
  required ActiveOrder order,
  required CustomerOrderSnapshot? previous,
}) {
  if (previous == null) return null;

  final prevStatus = previous.statusKey;
  final status = order.statusKey;
  final prevDelivery = previous.deliveryStatusKey;
  final delivery = order.deliveryStatusKey;
  final orderNo = order.orderNumber;

  if (prevStatus != status) {
    if (status == 'adjustment_pending' && prevStatus == 'pending') {
      return CustomerBannerData(
        type: CustomerBannerType.adjustmentProposed,
        title: 'تعديل على طلبك $orderNo',
        body: order.merchantStoreName?.trim().isNotEmpty == true
            ? '${order.merchantStoreName} عدّل الطلب — راجع ووافق أو ألغِ'
            : 'التاجر عدّل الطلب — راجع التفاصيل ووافق أو ألغِ',
        orderNumber: orderNo,
      );
    }

    if (status == 'accepted' && prevStatus == 'adjustment_pending') {
      return CustomerBannerData(
        type: CustomerBannerType.adjustmentAccepted,
        title: 'تم قبول الطلب المعدّل $orderNo',
        body: 'وافقت على التعديل وبدأ التجهيز',
        orderNumber: orderNo,
      );
    }

    if (status == 'accepted') {
      return CustomerBannerData(
        type: CustomerBannerType.accepted,
        title: 'تم قبول طلبك $orderNo',
        body: order.merchantStoreName?.trim().isNotEmpty == true
            ? '${order.merchantStoreName} قبل طلبك'
            : 'التاجر قبل طلبك وبدأ التجهيز',
        orderNumber: orderNo,
      );
    }

    if (status == 'preparing') {
      return CustomerBannerData(
        type: CustomerBannerType.preparing,
        title: 'طلبك قيد التحضير $orderNo',
        body: 'المتجر يجهّز طلبك الآن',
        orderNumber: orderNo,
      );
    }

    if (status == 'delivering') {
      return CustomerBannerData(
        type: CustomerBannerType.onWay,
        title: 'طلبك في طريق التوصيل $orderNo',
        body: 'تم تجهيز الطلب وسيصل إليك قريباً',
        orderNumber: orderNo,
      );
    }

    if (status == 'completed') {
      return CustomerBannerData(
        type: CustomerBannerType.delivered,
        title: 'تم تسليم طلبك $orderNo',
        body: 'نأمل أن تكون تجربتك ممتعة',
        orderNumber: orderNo,
      );
    }

    if (status == 'cancelled') {
      if (prevStatus == 'cancel_requested' ||
          order.noteAr.contains('موافقة التاجر') ||
          order.noteEn.contains('Merchant approved cancellation')) {
        return CustomerBannerData(
          type: CustomerBannerType.cancelApproved,
          title: 'تم إلغاء طلبك $orderNo',
          body: 'وافق التاجر على طلب الإلغاء',
          orderNumber: orderNo,
        );
      }

      if (prevStatus == 'pending' &&
          (order.noteAr.contains('مهلة') || order.noteEn.contains('timeout'))) {
        return CustomerBannerData(
          type: CustomerBannerType.timeout,
          title: 'انتهت مهلة الطلب $orderNo',
          body: 'لم يرد التاجر خلال 20 دقيقة وأُلغي الطلب',
          orderNumber: orderNo,
        );
      }

      if (order.noteAr.contains('سبب الرفض') ||
          order.noteEn.contains('Rejected reason') ||
          order.statusEn == 'Rejected') {
        return CustomerBannerData(
          type: CustomerBannerType.rejected,
          title: 'تم رفض طلبك $orderNo',
          body: order.noteAr.trim().isNotEmpty
              ? order.noteAr
              : 'التاجر رفض الطلب',
          orderNumber: orderNo,
        );
      }

      if (prevStatus == 'adjustment_pending' &&
          (order.noteAr.contains('رفض الزبون الطلب المعدّل') ||
              order.noteEn.contains('Customer rejected adjusted order'))) {
        return CustomerBannerData(
          type: CustomerBannerType.adjustmentRejected,
          title: 'ألغيت الطلب المعدّل $orderNo',
          body: 'لم توافق على التعديل المقترح',
          orderNumber: orderNo,
        );
      }
    }

    if (prevStatus == 'cancel_requested' &&
        (status == 'accepted' ||
            status == 'pending' ||
            status == 'preparing' ||
            status == 'delivering')) {
      return CustomerBannerData(
        type: CustomerBannerType.cancelRejected,
        title: 'رفض التاجر إلغاء الطلب $orderNo',
        body: 'سيستمر تنفيذ طلبك كما هو',
        orderNumber: orderNo,
      );
    }
  }

  if (prevDelivery != delivery && delivery != null && delivery.isNotEmpty) {
    switch (delivery) {
      case 'accepted':
        return CustomerBannerData(
          type: CustomerBannerType.courierAccepted,
          title: 'المندوب قبل طلبك $orderNo',
          body: order.assignedCourierName?.trim().isNotEmpty == true
              ? 'المندوب: ${order.assignedCourierName}'
              : 'المندوب في الطريق للمتجر',
          orderNumber: orderNo,
        );
      case 'picked_up':
        return CustomerBannerData(
          type: CustomerBannerType.pickedUp,
          title: 'تم استلام طلبك $orderNo',
          body: 'المندوب استلم الطلب من المتجر',
          orderNumber: orderNo,
        );
      case 'on_way':
        return CustomerBannerData(
          type: CustomerBannerType.onWay,
          title: 'المندوب في الطريق إليك $orderNo',
          body: order.estimatedArrivalMinutes != null
              ? 'الوصول المتوقع: ~${order.estimatedArrivalMinutes} دقيقة'
              : 'استعد لاستلام طلبك',
          orderNumber: orderNo,
        );
      case 'delivered':
      case 'completed':
        return CustomerBannerData(
          type: CustomerBannerType.delivered,
          title: 'تم تسليم طلبك $orderNo',
          body: 'تم التسليم — شكراً لاستخدامك الغيث',
          orderNumber: orderNo,
        );
    }
  }

  return null;
}

class CustomerOrderNotificationBanner extends StatefulWidget {
  final CustomerBannerData data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const CustomerOrderNotificationBanner({
    super.key,
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<CustomerOrderNotificationBanner> createState() =>
      _CustomerOrderNotificationBannerState();
}

class _CustomerOrderNotificationBannerState
    extends State<CustomerOrderNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _autoHide = Timer(const Duration(seconds: 3), _dismiss);
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  List<Color> get _gradientColors {
    switch (widget.data.type) {
      case CustomerBannerType.accepted:
      case CustomerBannerType.delivered:
        return [const Color(0xFF2E7D32), const Color(0xFF43A047)];
      case CustomerBannerType.rejected:
      case CustomerBannerType.cancelApproved:
        return [const Color(0xFFC62828), const Color(0xFFB71C1C)];
      case CustomerBannerType.timeout:
        return [const Color(0xFF455A64), const Color(0xFF263238)];
      case CustomerBannerType.onWay:
        return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
      case CustomerBannerType.preparing:
        return [const Color(0xFF6A1B9A), const Color(0xFF4A148C)];
      case CustomerBannerType.courierAccepted:
      case CustomerBannerType.pickedUp:
        return [const Color(0xFF00838F), const Color(0xFF006064)];
      case CustomerBannerType.cancelRejected:
        return [const Color(0xFFF57C00), const Color(0xFFE65100)];
      case CustomerBannerType.adjustmentProposed:
        return [const Color(0xFFEF6C00), const Color(0xFFE65100)];
      case CustomerBannerType.adjustmentAccepted:
        return [const Color(0xFF2E7D32), const Color(0xFF43A047)];
      case CustomerBannerType.adjustmentRejected:
        return [const Color(0xFFC62828), const Color(0xFFB71C1C)];
    }
  }

  Color get _shadowColor {
    switch (widget.data.type) {
      case CustomerBannerType.accepted:
      case CustomerBannerType.delivered:
        return Colors.green;
      case CustomerBannerType.rejected:
      case CustomerBannerType.cancelApproved:
        return Colors.red;
      case CustomerBannerType.timeout:
        return Colors.blueGrey;
      case CustomerBannerType.onWay:
        return Colors.blue;
      case CustomerBannerType.preparing:
        return Colors.purple;
      case CustomerBannerType.courierAccepted:
      case CustomerBannerType.pickedUp:
        return Colors.teal;
      case CustomerBannerType.cancelRejected:
        return Colors.orange;
      case CustomerBannerType.adjustmentProposed:
        return Colors.deepOrange;
      case CustomerBannerType.adjustmentAccepted:
        return Colors.green;
      case CustomerBannerType.adjustmentRejected:
        return Colors.red;
    }
  }

  IconData get _icon {
    switch (widget.data.type) {
      case CustomerBannerType.accepted:
        return Icons.check_circle_rounded;
      case CustomerBannerType.rejected:
        return Icons.block_rounded;
      case CustomerBannerType.timeout:
        return Icons.timer_off_rounded;
      case CustomerBannerType.onWay:
        return Icons.delivery_dining_rounded;
      case CustomerBannerType.delivered:
        return Icons.home_rounded;
      case CustomerBannerType.preparing:
        return Icons.restaurant_rounded;
      case CustomerBannerType.courierAccepted:
        return Icons.two_wheeler_rounded;
      case CustomerBannerType.pickedUp:
        return Icons.inventory_2_rounded;
      case CustomerBannerType.cancelApproved:
        return Icons.cancel_rounded;
      case CustomerBannerType.cancelRejected:
        return Icons.info_rounded;
      case CustomerBannerType.adjustmentProposed:
        return Icons.edit_note_rounded;
      case CustomerBannerType.adjustmentAccepted:
        return Icons.check_circle_rounded;
      case CustomerBannerType.adjustmentRejected:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _shadowColor.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.data.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
