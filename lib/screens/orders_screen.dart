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
      if (!context.mounted) return;
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
    // Taxi request status removed (old taxi service)
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('طلباتي', style: TextStyle(fontWeight: FontWeight.bold)),
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
            // Taxi request banner removed (old taxi service)
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
                  Text("طلب $displayIndex",
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
                  if (order.statusKey == 'adjustment_pending') ...[
                    const SizedBox(height: 2),
                    const Text(
                      'التاجر عدّل الطلب — راجع التفاصيل أدناه',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
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
          if (order.statusKey == 'cancelled' &&
              order.noteAr.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          if (order.statusKey == 'adjustment_pending') ...[
            const SizedBox(height: 10),
            ...order.lineItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      item.isAvailable ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: item.isAvailable ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.nameAr} (${item.quantity} × ${item.price.toLocaleString()} د.ع)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                          decoration: item.isAvailable
                              ? null
                              : TextDecoration.lineThrough,
                          color:
                              item.isAvailable ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if ((order.originalPrice ?? 0) > 0 &&
                order.originalPrice != order.price) ...[
              const SizedBox(height: 4),
              Text(
                'السعر السابق: ${order.originalPrice!.toLocaleString()} د.ع',
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey,
                  decoration: TextDecoration.lineThrough,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
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
                  if (order.statusKey == 'adjustment_pending') ...[
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                      minimumSize: const Size(0, 35),
                      onPressed: () => _confirmAdjustmentResponse(order, true),
                      child: const Text(
                        'موافقة على التعديل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      minimumSize: const Size(0, 35),
                      onPressed: () => _confirmAdjustmentResponse(order, false),
                      child: const Text(
                        'رفض التعديل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
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
          if ((order.merchantPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        AppHelpers.makePhoneCall(order.merchantPhone!),
                    icon: const Icon(CupertinoIcons.phone_fill, size: 16),
                    label: const Text('اتصال بالتاجر',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => AppHelpers.launchWhatsApp(
                        order.merchantPhone!,
                        'مرحباً، بخصوص طلبي (رقم ${order.id.length >= 5 ? order.id.substring(0, 5) : order.id}) من متجركم.'),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('واتساب',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  bool _isPendingApproval(ActiveOrder order) =>
      order.statusKey == 'pending' || order.statusKey == 'adjustment_pending';

  Future<void> _confirmAdjustmentResponse(
    ActiveOrder order,
    bool approve,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(approve ? 'موافقة على التعديل' : 'رفض التعديل'),
        content: Text(
          approve
              ? 'سيتم قبول الطلب بمبلغ ${order.price.toLocaleString()} د.ع وبدء التجهيز.'
              : 'سيتم إلغاء الطلب بالكامل ولن يُنفَّذ.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !approve,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'موافقة' : 'رفض التعديل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context
        .read<AppProvider>()
        .respondToOrderAdjustment(order.id, approve: approve);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (approve ? 'تم قبول الطلب المعدّل.' : 'تم إلغاء الطلب.')
              : 'تعذر تنفيذ العملية. حاول مجدداً.',
        ),
      ),
    );
  }

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
    final pastOrders = appProvider.orders
        .where((o) =>
            o.statusKey == 'completed' ||
            o.statusKey == 'rejected' ||
            o.statusKey == 'cancelled')
        .toList();

    if (pastOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.archivebox,
                size: 60, color: CupertinoColors.systemGrey4),
            const SizedBox(height: 12),
            const Text("لا يوجد سجل طلبات بعد",
                style: TextStyle(
                    color: CupertinoColors.systemGrey, fontFamily: 'Cairo')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pastOrders.length,
      itemBuilder: (context, index) {
        final order = pastOrders[index];
        return _buildHistoryItem(order);
      },
    );
  }

  Widget _buildHistoryItem(ActiveOrder order) {
    final appProvider = context.read<AppProvider>();
    final isRejected =
        order.statusKey == 'rejected' || order.statusKey == 'cancelled';
    final isCompleted = order.statusKey == 'completed';

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
                  Text(appProvider.displayOrderNumber(order),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(order.dateAr,
                      style: const TextStyle(
                          color: CupertinoColors.systemGrey, fontSize: 11)),
                ],
              ),
              Text("${order.price.toPrice()} د.ع",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isRejected
                          ? Colors.red
                          : CupertinoColors.systemGreen)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppBottomNavStyle.primaryActionButton(
                  onPressed: () {
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
                  radius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text(
                    'إعادة الطلب',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              if (isCompleted && !order.isRated) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => _showRatingDialog(order),
                    child: const Text(
                      'قيم التاجر',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
              if (order.isRated) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'تم التقييم ✓',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(ActiveOrder order) {
    int selectedStars = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title:
              const Text('تقييم المتجر', style: TextStyle(fontFamily: 'Cairo')),
          content: Column(
            children: [
              const SizedBox(height: 12),
              Text(order.merchantStoreName ?? 'المتجر',
                  style: const TextStyle(fontFamily: 'Cairo')),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedStars = index + 1),
                    child: Icon(
                      index < selectedStars
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: index < selectedStars
                          ? Colors.amber
                          : Colors.grey.shade400,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: commentController,
                placeholder: 'اكتب رأيك هنا (اختياري)',
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        await context.read<AppProvider>().submitMerchantReview(
                              orderId: order.id,
                              stars: selectedStars,
                              comment: commentController.text.trim(),
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('شكراً لتقييمك!')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ: $e')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const CupertinoActivityIndicator()
                  : const Text('إرسال', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}

// Taxi request status banner removed (old taxi service)

class _PendingApprovalCountdown extends StatefulWidget {
  final ActiveOrder order;

  const _PendingApprovalCountdown({required this.order});

  @override
  State<_PendingApprovalCountdown> createState() =>
      _PendingApprovalCountdownState();
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
    final label = context
        .read<AppProvider>()
        .pendingApprovalRemainingLabelAr(widget.order);
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

// Taxi notice details removed (old taxi service)
