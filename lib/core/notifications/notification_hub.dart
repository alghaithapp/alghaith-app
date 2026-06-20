import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../widgets/customer_order_notifications.dart';

typedef NotifyCallback = String Function({
  required String title,
  required String body,
  required String audience,
  String? orderNumber,
  NotificationCategory category,
  NotificationPriority priority,
  String? eventKey,
});

class RoleBannerData {
  final String title;
  final String body;
  final String? orderNumber;
  final ColorHint colorHint;

  const RoleBannerData({
    required this.title,
    required this.body,
    this.orderNumber,
    this.colorHint = ColorHint.info,
  });
}

enum ColorHint { success, warning, error, info, promo }

class NotificationHub {
  NotificationHub(this._notify);

  final NotifyCallback _notify;

  String displayOrderNumber(ActiveOrder order) {
    final raw = order.orderNumber.trim();
    if (raw.isNotEmpty && raw.length <= 14) return raw;
    final idSeed = order.id.split('-').first;
    final seed = int.tryParse(idSeed);
    if (seed == null) return raw.isNotEmpty ? raw : order.id;
    return '#${(seed % 1000000).toString().padLeft(6, '0')}';
  }

  void onCustomerOrdersRefreshed(
    Map<String, ActiveOrder> previousById,
    List<ActiveOrder> loaded,
  ) {
    if (previousById.isEmpty) return;
    for (final order in loaded) {
      final previous = previousById[order.id];
      if (previous == null) continue;
      final snap = CustomerOrderSnapshot(
        statusKey: previous.statusKey,
        deliveryStatusKey: previous.deliveryStatusKey,
      );
      final banner = detectCustomerOrderBanner(order: order, previous: snap);
      if (banner != null) {
        _notify(
          title: banner.title,
          body: banner.body,
          audience: 'customer',
          orderNumber: order.orderNumber,
          category: NotificationCategory.order,
          priority: NotificationPriority.urgent,
          eventKey: 'customer:${order.id}:${banner.type.name}',
        );
        continue;
      }
      if (previous.statusKey != order.statusKey) {
        _notify(
          title: 'تحديث الطلب ${displayOrderNumber(order)}',
          body: 'الحالة: ${order.statusAr}',
          audience: 'customer',
          orderNumber: order.orderNumber,
          category: NotificationCategory.order,
          priority: NotificationPriority.normal,
          eventKey: 'customer:${order.id}:status:${order.statusKey}',
        );
      } else if (previous.deliveryStatusKey != order.deliveryStatusKey) {
        _notify(
          title: 'توصيل الطلب ${displayOrderNumber(order)}',
          body: order.deliveryStatusAr ?? order.deliveryStatusKey ?? '-',
          audience: 'customer',
          orderNumber: order.orderNumber,
          category: NotificationCategory.delivery,
          priority: NotificationPriority.normal,
          eventKey: 'customer:${order.id}:delivery:${order.deliveryStatusKey}',
        );
      }
    }
  }

  void onCheckoutSuccess(List<ActiveOrder> orders) {
    for (final order in orders) {
      _notify(
        title: 'تم إرسال طلبك ${displayOrderNumber(order)}',
        body: order.merchantStoreName?.trim().isNotEmpty == true
            ? 'بانتظار موافقة ${order.merchantStoreName}'
            : 'بانتظار موافقة التاجر',
        audience: 'customer',
        orderNumber: order.orderNumber,
        category: NotificationCategory.order,
        priority: NotificationPriority.urgent,
        eventKey: 'customer:${order.id}:placed',
      );
    }
  }

  void onCustomerCodReminder(ActiveOrder order) {
    if (!order.requiresDelivery || order.codConfirmed) return;
    _notify(
      title: 'تأكيد الدفع نقداً ${displayOrderNumber(order)}',
      body: 'جهّز المبلغ عند استلام الطلب من المندوب',
      audience: 'customer',
      orderNumber: order.orderNumber,
      category: NotificationCategory.order,
      priority: NotificationPriority.normal,
      eventKey: 'customer:${order.id}:cod_reminder',
    );
  }

  void onDeliveryDelay(ActiveOrder order) {
    _notify(
      title: 'تأخر متوقع ${displayOrderNumber(order)}',
      body: 'التوصيل يستغرق وقتاً أطول من المتوقع',
      audience: 'customer',
      orderNumber: order.orderNumber,
      category: NotificationCategory.delivery,
      priority: NotificationPriority.urgent,
      eventKey: 'customer:${order.id}:delay',
    );
  }

  void onAbandonedCart(int itemCount) {
    _notify(
      title: 'سلتك بانتظارك',
      body: 'لديك $itemCount منتج${itemCount == 1 ? '' : 'ات'} — أكمل الطلب',
      audience: 'customer',
      category: NotificationCategory.promo,
      priority: NotificationPriority.marketing,
      eventKey: 'customer:cart_abandoned',
    );
  }

  void onPromoApplied(String code, int discountIqd) {
    _notify(
      title: 'تم تطبيق العرض',
      body: discountIqd > 0
          ? 'كود $code — خصم $discountIqd د.ع'
          : 'كود $code مفعّل على سلتك',
      audience: 'customer',
      category: NotificationCategory.promo,
      priority: NotificationPriority.marketing,
      eventKey: 'customer:promo:$code',
    );
  }

  void onMerchantOrdersRefreshed(
    Map<String, ActiveOrder> previousById,
    List<ActiveOrder> loaded,
  ) {
    for (final order in loaded) {
      final previous = previousById[order.id];
      final no = displayOrderNumber(order);
      if (previous == null) {
        if (order.statusKey == 'pending') {
          _notify(
            title: 'طلب جديد $no',
            body: 'يوجد طلب جديد بانتظار المراجعة.',
            audience: 'merchant',
            orderNumber: order.orderNumber,
            category: NotificationCategory.order,
            priority: NotificationPriority.urgent,
            eventKey: 'merchant:${order.id}:new',
          );
        }
        continue;
      }
      if (previous.statusKey == order.statusKey) continue;
      switch (order.statusKey) {
        case 'cancel_requested':
          _notify(
            title: 'طلب إلغاء $no',
            body: 'الزبون طلب إلغاء الطلب وبانتظار قرارك.',
            audience: 'merchant',
            orderNumber: order.orderNumber,
            category: NotificationCategory.order,
            priority: NotificationPriority.urgent,
            eventKey: 'merchant:${order.id}:cancel_requested',
          );
        case 'cancelled':
          if (previous.statusKey == 'adjustment_pending' &&
              (order.noteAr.contains('رفض الزبون الطلب المعدّل') ||
                  order.noteEn.contains('Customer rejected adjusted order'))) {
            _notify(
              title: 'رفض الزبون التعديل $no',
              body: 'ألغى الزبون الطلب بعد التعديل',
              audience: 'merchant',
              orderNumber: order.orderNumber,
              category: NotificationCategory.order,
              priority: NotificationPriority.urgent,
              eventKey: 'merchant:${order.id}:adjustment_rejected',
            );
            break;
          }
          _notify(
            title: 'إلغاء الطلب $no',
            body: order.noteAr.trim().isNotEmpty
                ? order.noteAr
                : 'تم إلغاء الطلب.',
            audience: 'merchant',
            orderNumber: order.orderNumber,
            category: NotificationCategory.order,
            priority: NotificationPriority.normal,
            eventKey: 'merchant:${order.id}:cancelled',
          );
        case 'completed':
          _notify(
            title: 'طلب مكتمل $no',
            body: 'تم إنجاز الطلب بنجاح',
            audience: 'merchant',
            orderNumber: order.orderNumber,
            category: NotificationCategory.order,
            priority: NotificationPriority.normal,
            eventKey: 'merchant:${order.id}:completed',
          );
        case 'adjustment_pending':
          _notify(
            title: 'بانتظار موافقة الزبون $no',
            body: 'أُرسل الطلب المعدّل للزبون',
            audience: 'merchant',
            orderNumber: order.orderNumber,
            category: NotificationCategory.order,
            priority: NotificationPriority.normal,
            eventKey: 'merchant:${order.id}:adjustment_pending',
          );
        case 'accepted':
          if (previous.statusKey == 'adjustment_pending') {
            _notify(
              title: 'وافق الزبون على التعديل $no',
              body: 'يمكنك البدء بتجهيز الطلب',
              audience: 'merchant',
              orderNumber: order.orderNumber,
              category: NotificationCategory.order,
              priority: NotificationPriority.urgent,
              eventKey: 'merchant:${order.id}:adjustment_accepted',
            );
          }
        default:
          break;
      }
    }
  }

  void onMerchantOrderStatusChanged(
    ActiveOrder order,
    String previousStatus,
    String newStatusKey,
  ) {
    final no = displayOrderNumber(order);
    if (newStatusKey == 'adjustment_pending' &&
        previousStatus != 'adjustment_pending') {
      _notify(
        title: 'أُرسل التعديل للزبون $no',
        body: 'بانتظار موافقة الزبون على الطلب المعدّل',
        audience: 'merchant',
        orderNumber: order.orderNumber,
        category: NotificationCategory.order,
        priority: NotificationPriority.urgent,
        eventKey: 'merchant:${order.id}:adjustment_sent',
      );
    } else if (newStatusKey == 'accepted' && previousStatus != 'accepted') {
      _notify(
        title: 'قبلت الطلب $no',
        body: 'تم إرسال القبول للزبون',
        audience: 'merchant',
        orderNumber: order.orderNumber,
        category: NotificationCategory.order,
        priority: NotificationPriority.normal,
        eventKey: 'merchant:${order.id}:local_accept',
      );
    } else if (newStatusKey == 'completed') {
      _notify(
        title: 'أكملت الطلب $no',
        body: 'الطلب مُغلق في سجلك',
        audience: 'merchant',
        orderNumber: order.orderNumber,
        category: NotificationCategory.order,
        priority: NotificationPriority.normal,
        eventKey: 'merchant:${order.id}:local_done',
      );
    }
  }

  void onOrderAdjustmentProposed(ActiveOrder order) {
    final no = displayOrderNumber(order);
    _notify(
      title: 'أُرسل التعديل للزبون $no',
      body: 'بانتظار موافقة الزبون على الطلب المعدّل',
      audience: 'merchant',
      orderNumber: order.orderNumber,
      category: NotificationCategory.order,
      priority: NotificationPriority.urgent,
      eventKey: 'merchant:${order.id}:adjustment_proposed_local',
    );
  }

  void onOrderAdjustmentAccepted(ActiveOrder order) {
    final no = displayOrderNumber(order);
    _notify(
      title: 'وافقت على الطلب المعدّل $no',
      body: 'بدأ التاجر بتجهيز طلبك',
      audience: 'customer',
      orderNumber: order.orderNumber,
      category: NotificationCategory.order,
      priority: NotificationPriority.urgent,
      eventKey: 'customer:${order.id}:adjustment_accepted_local',
    );
  }

  void onOrderAdjustmentRejected(ActiveOrder order) {
    final no = displayOrderNumber(order);
    _notify(
      title: 'ألغيت الطلب المعدّل $no',
      body: 'لم توافق على التعديل المقترح من التاجر',
      audience: 'customer',
      orderNumber: order.orderNumber,
      category: NotificationCategory.order,
      priority: NotificationPriority.normal,
      eventKey: 'customer:${order.id}:adjustment_rejected_local',
    );
  }

  void onMerchantStoreOpenChanged(bool isOpen) {
    _notify(
      title: isOpen ? 'المتجر مفتوح' : 'المتجر مغلق',
      body: isOpen
          ? 'الزبائن يمكنهم الطلب الآن'
          : 'لن تصل طلبات جديدة حتى تعيد الفتح',
      audience: 'merchant',
      category: NotificationCategory.account,
      priority: NotificationPriority.normal,
      eventKey: 'merchant:store_open:$isOpen',
    );
  }

  void onMerchantCatalogSynced() {
    _notify(
      title: 'تمت المزامنة',
      body: 'منتجاتك ومتجرك محدّثان على السحابة',
      audience: 'merchant',
      category: NotificationCategory.system,
      priority: NotificationPriority.normal,
      eventKey: 'merchant:catalog_sync_ok',
    );
  }

  void onMerchantCatalogSyncFailed(String message) {
    final body = message.length > 120 ? '${message.substring(0, 120)}…' : message;
    _notify(
      title: 'فشلت المزامنة',
      body: body,
      audience: 'merchant',
      category: NotificationCategory.system,
      priority: NotificationPriority.urgent,
      eventKey: 'merchant:catalog_sync_fail',
    );
  }

  void onNewMerchantReview(String reviewerName, int rating) {
    _notify(
      title: 'تقييم جديد',
      body: '$reviewerName — $rating نجوم',
      audience: 'merchant',
      category: NotificationCategory.review,
      priority: NotificationPriority.normal,
      eventKey: 'merchant:review:${reviewerName.hashCode}:$rating',
    );
  }

  void onMerchantReviewReplied(String reviewId) {
    _notify(
      title: 'تم الرد على التقييم',
      body: 'ردك ظاهر للزبائن',
      audience: 'merchant',
      category: NotificationCategory.review,
      priority: NotificationPriority.normal,
      eventKey: 'merchant:review_reply:$reviewId',
    );
  }

  void onProductUnavailable(String productName) {
    _notify(
      title: 'منتج غير متاح',
      body: productName,
      audience: 'merchant',
      category: NotificationCategory.system,
      priority: NotificationPriority.normal,
      eventKey: 'merchant:product_unavail:${productName.hashCode}',
    );
  }

  void onOfferExpiringSoon(String offerTitle, int daysLeft) {
    _notify(
      title: 'عرض ينتهي قريباً',
      body: daysLeft <= 0
          ? '$offerTitle انتهى اليوم'
          : '$offerTitle — متبقي $daysLeft يوم',
      audience: 'merchant',
      category: NotificationCategory.promo,
      priority: NotificationPriority.marketing,
      eventKey: 'merchant:offer_expiry:${offerTitle.hashCode}',
    );
  }

  List<RoleBannerData> courierBannersFromDiff({
    required List<ActiveOrder> previousPool,
    required List<ActiveOrder> pool,
    required List<ActiveOrder> previousAssigned,
    required List<ActiveOrder> assigned,
  }) {
    final banners = <RoleBannerData>[];
    final prevPoolIds = {for (final o in previousPool) o.id};
    final prevAssigned = {for (final o in previousAssigned) o.id: o};

    for (final order in pool) {
      if (!prevPoolIds.contains(order.id)) {
        _notify(
          title: 'طلب توصيل جديد ${displayOrderNumber(order)}',
          body: order.merchantStoreName?.trim().isNotEmpty == true
              ? 'من ${order.merchantStoreName}'
              : 'متاح في قائمة الطلبات',
          audience: 'delivery',
          orderNumber: order.orderNumber,
          category: NotificationCategory.delivery,
          priority: NotificationPriority.urgent,
          eventKey: 'delivery:${order.id}:pool_new',
        );
        banners.add(RoleBannerData(
          title: 'طلب توصيل جديد!',
          body: displayOrderNumber(order),
          orderNumber: order.orderNumber,
          colorHint: ColorHint.success,
        ));
      }
    }

    for (final order in assigned) {
      final prev = prevAssigned[order.id];
      if (prev == null) {
        _notify(
          title: 'تم تعيينك ${displayOrderNumber(order)}',
          body: 'الطلب أصبح ضمن مهامك النشطة',
          audience: 'delivery',
          orderNumber: order.orderNumber,
          category: NotificationCategory.delivery,
          priority: NotificationPriority.urgent,
          eventKey: 'delivery:${order.id}:assigned',
        );
        banners.add(RoleBannerData(
          title: 'طلب مُعيَّن لك',
          body: displayOrderNumber(order),
          orderNumber: order.orderNumber,
          colorHint: ColorHint.info,
        ));
        continue;
      }
      if (prev.deliveryStatusKey != order.deliveryStatusKey) {
        _notify(
          title: 'تحديث توصيل ${displayOrderNumber(order)}',
          body: order.deliveryStatusAr ?? order.deliveryStatusKey ?? '',
          audience: 'delivery',
          orderNumber: order.orderNumber,
          category: NotificationCategory.delivery,
          priority: NotificationPriority.normal,
          eventKey: 'delivery:${order.id}:dstatus:${order.deliveryStatusKey}',
        );
      }
      if (prev.statusKey != order.statusKey && order.statusKey == 'cancelled') {
        _notify(
          title: 'إلغاء ${displayOrderNumber(order)}',
          body: order.noteAr.isNotEmpty ? order.noteAr : 'تم إلغاء الطلب',
          audience: 'delivery',
          orderNumber: order.orderNumber,
          category: NotificationCategory.delivery,
          priority: NotificationPriority.urgent,
          eventKey: 'delivery:${order.id}:cancelled',
        );
        banners.add(RoleBannerData(
          title: 'إلغاء طلب',
          body: displayOrderNumber(order),
          orderNumber: order.orderNumber,
          colorHint: ColorHint.warning,
        ));
      }
    }
    return banners;
  }

  void onCourierAcceptedOrder(String orderNumber) {
    _notify(
      title: 'قبلت طلب التوصيل',
      body: orderNumber,
      audience: 'delivery',
      orderNumber: orderNumber,
      category: NotificationCategory.delivery,
      priority: NotificationPriority.normal,
      eventKey: 'delivery:accept:$orderNumber',
    );
  }

  void onCourierRejectedOrder(String orderNumber) {
    _notify(
      title: 'رفضت طلب التوصيل',
      body: 'لن يظهر في قائمتك',
      audience: 'delivery',
      orderNumber: orderNumber,
      category: NotificationCategory.delivery,
      priority: NotificationPriority.normal,
      eventKey: 'delivery:reject:$orderNumber',
    );
  }

  void onLoginSuccess() {
    _notify(
      title: 'مرحباً بعودتك',
      body: 'تم تسجيل الدخول بنجاح',
      audience: 'customer',
      category: NotificationCategory.account,
      priority: NotificationPriority.normal,
      eventKey: 'account:login',
    );
  }

  void onAppBootWelcome(String? name) {
    _notify(
      title: name != null && name.isNotEmpty ? 'أهلاً بك يا $name' : 'أهلاً بك في الغيث',
      body: 'نتمنى لك تجربة تسوق ممتعة اليوم.',
      audience: 'customer',
      category: NotificationCategory.promo,
      priority: NotificationPriority.normal,
      eventKey: 'app:boot:welcome:${DateTime.now().day}',
    );
  }

  void onUnreadNotificationsPrompt(String role, int count) {
    final roleLabel = _roleLabelAr(role);
    _notify(
      title: 'لديك إشعارات غير مقروءة',
      body: 'يوجد $count إشعار${count > 1 ? 'ات' : ''} بانتظارك في وضع $roleLabel.',
      audience: role,
      category: NotificationCategory.system,
      priority: NotificationPriority.urgent,
      eventKey: 'prompt:unread:$role:${DateTime.now().hour}',
    );
  }

  static String _roleLabelAr(String role) {
    switch (role) {
      case 'merchant':
        return 'التاجر';
      case 'customer':
        return 'الزبون';
      case 'delivery':
        return 'مندوب التوصيل';
      case 'driver':
        return 'سائق التكسي';
      case 'admin':
        return 'الإدارة';
      default:
        return role;
    }
  }

  void onRoleSwitched(String role, String roleLabelAr) {
    final audience = notificationAudienceForRole(role) ?? 'customer';
    _notify(
      title: 'تبديل الحساب',
      body: 'أنت الآن في وضع $roleLabelAr',
      audience: audience,
      category: NotificationCategory.account,
      priority: NotificationPriority.normal,
      eventKey: 'account:role:$role',
    );
  }

  void onProfileUpdated(String audience) {
    _notify(
      title: 'تم تحديث الملف',
      body: 'بيانات حسابك محفوظة',
      audience: audience,
      category: NotificationCategory.account,
      priority: NotificationPriority.normal,
      eventKey: 'account:profile_updated',
    );
  }

  void onMerchantProfileActivated() {
    _notify(
      title: 'تم تفعيل حساب التاجر',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن إدارة متجرك واستقبال الطلبات.',
      audience: 'merchant',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'merchant:account:approved',
    );
  }

  void onMerchantRejected(String message) {
    final body = message.trim().isNotEmpty
        ? message.trim()
        : 'يرجى تعديل بيانات متجرك وإعادة إرسال الطلب.';
    _notify(
      title: 'طلب التاجر يحتاج تعديلاً',
      body: body,
      audience: 'merchant',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'merchant:account:rejected',
    );
  }

  void onCourierApproved() {
    _notify(
      title: 'تم تفعيل حساب المندوب',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن استقبال طلبات التوصيل.',
      audience: 'delivery',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'courier:account:approved',
    );
  }

  void onCourierRejected(String message) {
    final body = message.trim().isNotEmpty
        ? message.trim()
        : 'يرجى تعديل بياناتك وإعادة إرسال الطلب.';
    _notify(
      title: 'طلب المندوب يحتاج تعديلاً',
      body: body,
      audience: 'delivery',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'courier:account:rejected',
    );
  }

  void onDriverApproved() {
    _notify(
      title: 'تم تفعيل حساب التكسي',
      body: 'وافقت الإدارة على طلبك. يمكنك الآن استقبال طلبات الركوب.',
      audience: 'driver',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'driver:account:approved',
    );
  }

  void onDriverRejected(String message) {
    final body = message.trim().isNotEmpty
        ? message.trim()
        : 'يرجى تعديل بياناتك وإعادة إرسال الطلب.';
    _notify(
      title: 'طلب التكسي يحتاج تعديلاً',
      body: body,
      audience: 'driver',
      category: NotificationCategory.account,
      priority: NotificationPriority.urgent,
      eventKey: 'driver:account:rejected',
    );
  }

  void onAdminReportsUpdated(
    Map<String, dynamic>? previous,
    Map<String, dynamic>? current,
  ) {
    if (current == null || current.isEmpty) return;
    if (previous != null && previous.toString() == current.toString()) return;
    final pending = current['pendingOrders'] ?? current['pending_count'];
    final merchants = current['merchantsCount'] ?? current['merchants'];
    final parts = <String>[
      if (pending != null) 'طلبات معلقة: $pending',
      if (merchants != null) 'تجار: $merchants',
    ];
    _notify(
      title: 'تقرير النظام',
      body: parts.isEmpty ? 'تم تحديث لوحة الإدارة' : parts.join(' · '),
      audience: 'admin',
      category: NotificationCategory.admin,
      priority: NotificationPriority.normal,
      eventKey: 'admin:reports:${DateTime.now().day}',
    );
  }
}
