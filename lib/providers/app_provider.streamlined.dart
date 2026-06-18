import 'dart:async';
import 'package:flutter/material.dart';
import '../core/notifications/push_notification_inbox.dart';

import 'mixins/core_mixin.dart';
import 'mixins/auth_mixin.dart';
import 'mixins/customer_mixin.dart';
import 'mixins/merchant_mixin.dart';
import 'mixins/driver_mixin.dart';
import 'mixins/delivery_mixin.dart';
import 'mixins/admin_mixin.dart';
import 'mixins/persistence_mixin.dart';

/// مزوّد الحالة الرئيسي — يجمع كل الوظائف من mixins متخصصة.
///
/// AppProvider هو ChangeNotifier واحد يتكون من عدة mixins
/// كل mixin مسؤول عن مجال محدد (المصادقة، الزبون، التاجر،
/// السائق، المندوب، الإدارة، الحفظ المحلي).
///
class AppProvider extends ChangeNotifier with
    AppCoreMixin,
    PersistenceMixin,
    AuthMixin,
    CustomerMixin,
    MerchantMixin,
    DriverMixin,
    DeliveryMixin,
    AdminMixin {
  AppProvider() {
    PushNotificationInbox.onCourierStatusPush = handleCourierStatusPush;
    PushNotificationInbox.onTaxiStatusPush = handleTaxiStatusPush;

    // فوراً نجهّز الواجهة — لا ننتظر SharedPreferences
    _isHydrating = false;
    _isReady = true;
    _isGuestMode = true;
    _userRole = 'customer';
    notifyListeners();

    // تحميل الجلسة والبيانات في الخلفية — لا يمنع ظهور الواجهة أبداً
    _bootWatchdog = Timer(const Duration(seconds: 15), _forceBootReady);
    _loadSettings();
  }
}
