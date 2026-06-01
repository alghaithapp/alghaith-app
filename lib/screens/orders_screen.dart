import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/app_models.dart';
import '../utils/extensions.dart';
import '../utils/translations.dart';
import '../widgets/app_image.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final lang = appProvider.lang;
    final isAr = lang == 'ar';
    final orders = appProvider.orders;
    final latestTaxiRequest =
        appProvider.taxiRequests.isNotEmpty ? appProvider.taxiRequests.first : null;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppTranslations.t('orders', lang),
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(isAr ? "الطلبات الحالية" : "Active",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(isAr ? "الطلبات السابقة" : "Previous",
                          style: const TextStyle(
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
                  isAr: isAr,
                ),
              ),
            Expanded(
              child: _selectedSegment == 0
                  ? orders.isEmpty
                      ? _buildEmptyState(isAr)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderCard(order, isAr, lang);
                          },
                        )
                  : _buildPreviousOrders(isAr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.doc_text,
              size: 80, color: CupertinoColors.systemGrey4),
          const SizedBox(height: 16),
          Text(isAr ? "لا توجد طلبات حالية" : "No active orders",
              style: const TextStyle(color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(ActiveOrder order, bool isAr, String lang) {
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
                      isAr
                          ? "طلب #${order.orderNumber}"
                          : "Order #${order.orderNumber}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(isAr ? order.dateAr : order.dateEn,
                      style: const TextStyle(
                          color: CupertinoColors.systemGrey, fontSize: 11)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(isAr ? order.statusAr : order.statusEn,
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
                  isAr
                      ? (order.deliveryStatusAr ?? '')
                      : (order.deliveryStatusEn ?? ''),
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    Text(isAr ? order.itemsNameAr : order.itemsNameEn,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1),
                    Text("${order.itemsCount} ${isAr ? 'عناصر' : 'items'}",
                        style: const TextStyle(
                            color: CupertinoColors.systemGrey, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${order.price.toLocaleString()} د.ع",
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
                minimumSize: const Size(0, 35),
                onPressed: () => _showTrackingSheet(context, order, isAr),
                child: Text(isAr ? "تتبع الطلب" : "Track",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTrackingSheet(BuildContext context, ActiveOrder order, bool isAr) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(isAr
            ? "تتبع الطلب #${order.orderNumber}"
            : "Tracking Order #${order.orderNumber}"),
        message: Column(
          children: [
            const SizedBox(height: 20),
            _buildTimelineStep(isAr ? "تم استلام الطلب" : "Order Received",
                isAr ? "تم التأكيد والدفع كاش" : "Confirmed & COD", true, true),
            _buildTimelineStep(isAr ? "قيد التحضير" : "Preparing",
                isAr ? "الطلب في المستودع" : "In Warehouse", true, true),
            _buildTimelineStep(isAr ? "قيد التوصيل" : "Out for Delivery",
                isAr ? "المندوب في الطريق" : "Courier on the way", true, false),
            _buildTimelineStep(isAr ? "تم التسليم" : "Delivered",
                isAr ? "استلم وادفع كاش" : "Received & Paid", false, false),
          ],
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? "إغلاق" : "Close"),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(
      String title, String subtitle, bool isDone, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Icon(
              isDone
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isDone ? Colors.orange : CupertinoColors.systemGrey4,
              size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDone
                          ? CupertinoColors.black
                          : CupertinoColors.systemGrey)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: CupertinoColors.systemGrey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPreviousOrders(bool isAr) {
    final appProvider = Provider.of<AppProvider>(context);
    // تصفية الطلبات لعرض المنتهية فقط (مكتملة أو مرفوضة) في السجل
    final pastOrders = appProvider.orders.where((o) => 
      o.statusKey == 'completed' || o.statusKey == 'rejected'
    ).toList();

    if (pastOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.archivebox, size: 60, color: CupertinoColors.systemGrey4),
            const SizedBox(height: 12),
            Text(isAr ? "لا يوجد سجل طلبات بعد" : "No order history yet",
                style: const TextStyle(color: CupertinoColors.systemGrey, fontFamily: 'Cairo')),
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
          order.orderNumber,
          isAr ? order.dateAr : order.dateEn,
          order.price.toPrice(),
          isAr,
          order.statusKey == 'rejected',
        );
      },
    );
  }

  Widget _buildHistoryItem(String id, String date, String price, bool isAr, bool isRejected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Row(
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
    );
  }
}

class _TaxiRequestStatusBanner extends StatelessWidget {
  final TaxiRequest request;
  final bool isAr;

  const _TaxiRequestStatusBanner({
    required this.request,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final details = _taxiNotice(request.statusKey, isAr);
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
              isAr ? request.statusAr : request.statusEn,
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

  _TaxiNotice _taxiNotice(String statusKey, bool isAr) {
    switch (statusKey) {
      case 'accepted':
        return _TaxiNotice(
          title: isAr ? 'تم قبول الطلب' : 'Request accepted',
          subtitle: isAr
              ? 'السائق بدأ تجهيز نفسه للانطلاق'
              : 'The driver is preparing to leave',
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          icon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      case 'on_way':
        return _TaxiNotice(
          title: isAr ? 'السائق في الطريق' : 'Driver on the way',
          subtitle: isAr
              ? 'الرحلة تتقدم نحو موقعك'
              : 'Your trip is moving toward your location',
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          icon: CupertinoIcons.car_fill,
        );
      case 'arrived':
        return _TaxiNotice(
          title: isAr ? 'وصل للموقع' : 'Arrived at pickup',
          subtitle: isAr
              ? 'السائق ينتظر عند نقطة الانطلاق'
              : 'The driver is waiting at pickup',
          colors: [Colors.purple.shade700, Colors.purple.shade400],
          icon: CupertinoIcons.location_solid,
        );
      case 'picked_up':
        return _TaxiNotice(
          title: isAr ? 'استلام الزبون' : 'Customer picked up',
          subtitle: isAr
              ? 'تم بدء الرحلة مع السائق'
              : 'The trip has started',
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        );
      case 'completed':
        return _TaxiNotice(
          title: isAr ? 'تم الوصول' : 'Trip completed',
          subtitle: isAr
              ? 'انتهت الرحلة بنجاح'
              : 'The trip completed successfully',
          colors: [Colors.green.shade700, Colors.green.shade400],
          icon: CupertinoIcons.check_mark_circled_solid,
        );
      case 'rejected':
        return _TaxiNotice(
          title: isAr ? 'تم رفض الطلب' : 'Request rejected',
          subtitle: isAr
              ? 'يمكنك إرسال طلب جديد الآن'
              : 'You can send a new request now',
          colors: [Colors.red.shade700, Colors.red.shade400],
          icon: CupertinoIcons.xmark_circle_fill,
        );
      default:
        return _TaxiNotice(
          title: isAr ? 'بانتظار السائق' : 'Waiting for driver',
          subtitle: isAr
              ? 'سيظهر طلبك عند أول سائق متاح'
              : 'Your request will appear for the next available driver',
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          icon: CupertinoIcons.time,
        );
    }
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
