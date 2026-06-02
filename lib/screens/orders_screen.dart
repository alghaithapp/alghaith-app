import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ui/app_bottom_nav_style.dart';
import '../providers/app_provider.dart';
import '../models/app_models.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';
import '../widgets/order_tracking_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedSegment = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshCustomerOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final orders = appProvider.orders;
    final currentOrders = orders
        .where((order) =>
            order.statusKey != 'completed' &&
            order.statusKey != 'rejected' &&
            order.statusKey != 'cancelled')
        .toList();
    final latestTaxiRequest =
        appProvider.taxiRequests.isNotEmpty ? appProvider.taxiRequests.first : null;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('طلباتي',
            style: TextStyle(fontWeight: FontWeight.bold)),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedSegment,
                  onValueChanged: (value) =>
                      setState(() => _selectedSegment = value!),
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text("الطلبات الحالية",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text("الطلبات السابقة",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  },
                ),
              ),
            ),
            if (latestTaxiRequest != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _TaxiRequestStatusBanner(
                  request: latestTaxiRequest,
                ),
              ),
            Expanded(
              child: _selectedSegment == 0
                  ? currentOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: currentOrders.length,
                          itemBuilder: (context, index) {
                            final order = currentOrders[index];
                            return _buildOrderCard(
                              order,
                              displayIndex: index + 1,
                            );
                          },
                        )
                  : _buildPreviousOrders(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.doc_text,
              size: 80, color: CupertinoColors.systemGrey4),
          const SizedBox(height: 16),
          const Text("لا توجد طلبات حالية",
              style: TextStyle(color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    ActiveOrder order, {
    required int displayIndex,
  }) {
    final appProvider = context.read<AppProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "طلب $displayIndex",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(order.dateAr,
                      style: const TextStyle(
                          color: CupertinoColors.systemGrey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    appProvider.orderElapsedLabelAr(order),
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey2,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (order.statusKey == 'pending') ...[
                    const SizedBox(height: 2),
                    _PendingApprovalCountdown(order: order),
                  ],
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(order.statusAr,
                    style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (order.deliveryStatusKey != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.deliveryStatusAr ?? '',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          if ((order.assignedCourierName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'المندوب: ${order.assignedCourierName}',
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
          if (order.statusKey == 'cancelled' && order.noteAr.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.noteAr,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
          if (order.statusKey == 'pending' &&
              order.merchantReadAt != null &&
              order.merchantReadAt!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'تمت قراءة الطلب من التاجر',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
          if (order.codConfirmed) ...[
            const SizedBox(height: 6),
            const Text(
              '✓ تم الدفع نقداً',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFF2F2F7)),
          ),
          Row(
            children: [
              if (order.image != null)
                AppImage(
                  imageData: order.image,
                  width: 50,
                  height: 50,
                  borderRadius: BorderRadius.circular(12),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.itemsNameAr,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1),
                    Text("${order.itemsCount} عناصر",
                        style: const TextStyle(
                            color: CupertinoColors.systemGrey, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text("${order.price.toLocaleString()} د.ع",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (_canRequestCancel(order))
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      minimumSize: const Size(0, 35),
                      onPressed: () => _confirmCancelRequest(order),
                      child: Text(
                        _isPendingApproval(order) ? 'إلغاء فوري' : 'طلب إلغاء',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  if (order.statusKey == 'cancel_requested')
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'بانتظار موافقة التاجر',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                    minimumSize: const Size(0, 35),
                    onPressed: () => _showTrackingSheet(context, order),
                    child: const Text("تتبع الطلب",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canRequestCancel(ActiveOrder order) {
    return order.statusKey != 'completed' &&
        order.statusKey != 'cancelled' &&
        order.statusKey != 'rejected' &&
        order.statusKey != 'cancel_requested';
  }

  bool _isPendingApproval(ActiveOrder order) => order.statusKey == 'pending';

  Future<void> _confirmCancelRequest(ActiveOrder order) async {
    final isPendingApproval = _isPendingApproval(order);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(isPendingApproval ? 'إلغاء الطلب' : 'طلب إلغاء الطلب'),
        content: Text(
          isPendingApproval
              ? 'الطلب ما زال بانتظار موافقة التاجر، وسيتم إلغاؤه فورًا بدون انتظار موافقة.'
              : 'سيتم إرسال طلب الإلغاء إلى التاجر للموافقة عليه.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isPendingApproval ? 'تأكيد الإلغاء' : 'إرسال الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok =
        context.read<AppProvider>().requestCustomerOrderCancellation(order.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (isPendingApproval
                  ? 'تم إلغاء الطلب مباشرة.'
                  : 'تم إرسال طلب الإلغاء إلى التاجر.')
              : 'لا يمكن إرسال طلب إلغاء لهذه الحالة.',
        ),
      ),
    );
  }

  void _showTrackingSheet(BuildContext context, ActiveOrder order) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => OrderTrackingSheet(order: order),
    );
  }

  Widget _buildPreviousOrders() {
    final appProvider = Provider.of<AppProvider>(context);
    final pastOrders = appProvider.orders.where((o) => 
      o.statusKey == 'completed' ||
      o.statusKey == 'rejected' ||
      o.statusKey == 'cancelled'
    ).toList();

    if (pastOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.archivebox, size: 60, color: CupertinoColors.systemGrey4),
            const SizedBox(height: 12),
            const Text("لا يوجد سجل طلبات بعد",
                style: TextStyle(color: CupertinoColors.systemGrey, fontFamily: 'Cairo')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pastOrders.length,
      itemBuilder: (context, index) {
        final order = pastOrders[index];
        return _buildHistoryItem(
          appProvider.displayOrderNumber(order),
          order.dateAr,
          order.price.toPrice(),
          order.statusKey == 'rejected' || order.statusKey == 'cancelled',
          onReorder: () {
            final ok = appProvider.reorderFromPreviousOrder(order);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'تمت إضافة نفس الطلب إلى السلة.'
                      : 'تعذر إعادة الطلب الآن (تحقق من المتجر أو وجود طلب نشط).',
                ),
              ),
            );
            if (ok) {
              setState(() => _selectedSegment = 0);
            }
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(
    String id,
    String date,
    String price,
    bool isRejected, {
    required VoidCallback onReorder,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(date,
                      style: const TextStyle(
                          color: CupertinoColors.systemGrey, fontSize: 11)),
                ],
              ),
              Text("$price د.ع",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isRejected ? Colors.red : CupertinoColors.systemGreen)),
            ],
          ),
          const SizedBox(height: 10),
          AppBottomNavStyle.primaryActionButton(
            onPressed: onReorder,
            radius: 10,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              'إعادة نفس الطلب',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiRequestStatusBanner extends StatelessWidget {
  final TaxiRequest request;

  const _TaxiRequestStatusBanner({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final details = _taxiNotice(request.statusKey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: details.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: details.colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(details.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.35,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              request.statusAr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TaxiNotice _taxiNotice(String statusKey) {
    switch (statusKey) {
      case 'accepted':
        return _TaxiNotice(
          title: 'تم قبول الطلب',
          subtitle: 'السائق بدأ تجهيز نفسه للانطلاق',
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          icon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      case 'on_way':
        return _TaxiNotice(
          title: 'السائق في الطريق',
          subtitle: 'الرحلة تتقدم نحو موقعك',
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          icon: CupertinoIcons.car_fill,
        );
      case 'arrived':
        return _TaxiNotice(
          title: 'وصل للموقع',
          subtitle: 'السائق ينتظر عند نقطة الانطلاق',
          colors: [Colors.purple.shade700, Colors.purple.shade400],
          icon: CupertinoIcons.location_solid,
        );
      case 'picked_up':
        return _TaxiNotice(
          title: 'استلام الزبون',
          subtitle: 'تم بدء الرحلة مع السائق',
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        );
      case 'completed':
        return _TaxiNotice(
          title: 'تم الوصول',
          subtitle: 'انتهت الرحلة بنجاح',
          colors: [Colors.green.shade700, Colors.green.shade400],
          icon: CupertinoIcons.check_mark_circled_solid,
        );
      case 'rejected':
        return _TaxiNotice(
          title: 'تم رفض الطلب',
          subtitle: 'يمكنك إرسال طلب جديد الآن',
          colors: [Colors.red.shade700, Colors.red.shade400],
          icon: CupertinoIcons.xmark_circle_fill,
        );
      default:
        return _TaxiNotice(
          title: 'بانتظار السائق',
          subtitle: 'سيظهر طلبك عند أول سائق متاح',
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          icon: CupertinoIcons.time,
        );
    }
  }
}

class _PendingApprovalCountdown extends StatefulWidget {
  final ActiveOrder order;

  const _PendingApprovalCountdown({required this.order});

  @override
  State<_PendingApprovalCountdown> createState() => _PendingApprovalCountdownState();
}

class _PendingApprovalCountdownState extends State<_PendingApprovalCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        context.read<AppProvider>().pendingApprovalRemainingLabelAr(widget.order);
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 11,
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TaxiNotice {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;

  const _TaxiNotice({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });
}
