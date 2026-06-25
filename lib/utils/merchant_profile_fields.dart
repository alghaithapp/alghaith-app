import 'package:flutter/material.dart';

/// حقول عرض بيانات المتجر (عنوان نصي، أوقات عمل) بشكل موحّد.
class MerchantProfileFields {
  MerchantProfileFields._();

  static final RegExp _coordinatesPattern = RegExp(
    r'^-?\d+(\.\d+)?\s*[,،]\s*-?\d+(\.\d+)?$',
  );

  static bool looksLikeCoordinates(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    return _coordinatesPattern.hasMatch(trimmed);
  }

  static String addressFromMap(Map<String, dynamic>? map) {
    if (map == null) return '';
    for (final key in ['address', 'merchant_address']) {
      final raw = map[key]?.toString().trim() ?? '';
      if (raw.isNotEmpty && !looksLikeCoordinates(raw)) {
        return raw;
      }
    }
    return '';
  }

  static String name(Map<String, dynamic>? map) {
    final resolved = storeNameOrEmpty(map);
    return resolved.isNotEmpty ? resolved : 'المحل';
  }

  /// اسم المتجر الفعلي أو سلسلة فارغة (للتحقق من اكتمال الملف).
  static String storeNameOrEmpty(Map<String, dynamic>? map) {
    if (map == null) return '';
    for (final key in [
      'name',
      'store_name',
      'storeName',
      'merchant_store_name',
      'merchantStoreName',
    ]) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String timeFromMap(
    Map<String, dynamic>? map, {
    required bool isOpen,
  }) {
    if (map == null) return '';
    final keys = isOpen
        ? ['open_time', 'openTime', 'merchant_open_time']
        : ['close_time', 'closeTime', 'merchant_close_time'];
    for (final key in keys) {
      final formatted = formatTimeDisplay(map[key]);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  static String workingHoursLabel(Map<String, dynamic>? map) {
    final open = formatArabic12h(timeFromMap(map, isOpen: true));
    final close = formatArabic12h(timeFromMap(map, isOpen: false));
    if (open.isEmpty && close.isEmpty) return 'غير محدد';
    if (open.isEmpty) return 'حتى $close';
    if (close.isEmpty) return 'من $open';
    return '$open — $close';
  }

  static TimeOfDay? toTimeOfDay(dynamic value) {
    final normalized = formatTimeDisplay(value);
    if (normalized.isEmpty) return null;
    final parts = normalized.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  static String storageFromTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// عرض 12 ساعة مع ص/م للواجهة العربية.
  static String formatArabic12h(dynamic value) {
    final normalized = formatTimeDisplay(value);
    if (normalized.isEmpty) return '';
    final tod = toTimeOfDay(normalized);
    if (tod == null) return normalized;
    final hour24 = tod.hour;
    final period = hour24 < 12 ? 'ص' : 'م';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  static String formatTimeDisplay(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';

    final hourOnly = int.tryParse(raw);
    if (hourOnly != null && hourOnly >= 0 && hourOnly <= 23) {
      return '${hourOnly.toString().padLeft(2, '0')}:00';
    }

    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }

    return raw;
  }

  static String? normalizeTimeForPersistence(dynamic value) {
    final formatted = formatTimeDisplay(value);
    return formatted.isEmpty ? null : formatted;
  }

  static String locationSummary({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    if (address.trim().isNotEmpty) return address.trim();
    if (latitude != null && longitude != null) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }
    return '';
  }

  static bool _boolFromDynamic(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return fallback;
    if (['true', '1', 'yes', 'y', 'on'].contains(normalized)) return true;
    if (['false', '0', 'no', 'n', 'off'].contains(normalized)) return false;
    return fallback;
  }

  /// قراءة منطقية آمنة من قيمة قد تأتي bool أو String أو رقم من السيرفر.
  static bool boolValue(dynamic value, {bool fallback = false}) =>
      _boolFromDynamic(value, fallback: fallback);

  /// قراءة عدد صحيح آمنة من قيمة قد تأتي int أو double أو String.
  static int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    final parsed = num.tryParse(value?.toString().trim() ?? '');
    return parsed?.toInt() ?? fallback;
  }

  static Map<String, dynamic> _contactVisibilityMap(Map<String, dynamic>? map) {
    if (map == null) return const {};
    final info = map['professional_info'] ?? map['professionalInfo'];
    if (info is! Map) return const {};
    final raw = info['contact_visibility'] ?? info['contactVisibility'];
    if (raw is! Map) return const {};
    return Map<String, dynamic>.from(raw);
  }

  static bool showPhoneToCustomers(Map<String, dynamic>? map) {
    final visibility = _contactVisibilityMap(map);
    final explicit = map?['show_phone_to_customers'] ?? map?['showPhoneToCustomers'];
    final nested =
        visibility['show_phone_to_customers'] ?? visibility['showPhoneToCustomers'];
    return _boolFromDynamic(explicit ?? nested, fallback: true);
  }

  static bool showWhatsAppToCustomers(Map<String, dynamic>? map) {
    final visibility = _contactVisibilityMap(map);
    final explicit =
        map?['show_whatsapp_to_customers'] ?? map?['showWhatsAppToCustomers'];
    final nested = visibility['show_whatsapp_to_customers'] ??
        visibility['showWhatsAppToCustomers'];
    return _boolFromDynamic(explicit ?? nested, fallback: true);
  }

  static String customerVisiblePhone(Map<String, dynamic>? map) {
    if (!showPhoneToCustomers(map)) return '';
    if (map == null) return '';
    for (final key in ['customer_phone', 'customerPhone', 'phone']) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String customerVisibleWhatsApp(Map<String, dynamic>? map) {
    if (!showWhatsAppToCustomers(map)) return '';
    if (map == null) return '';
    for (final key in ['customer_whatsapp', 'customerWhatsApp', 'whatsapp']) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final phone = map['phone']?.toString().trim() ?? '';
    return phone;
  }

  /// رقم التاجر للمراسلة/الاتصال داخل التطبيق — دائماً متاح بغض النظر عن إعدادات الإظهار.
  static String merchantInternalContactPhone(Map<String, dynamic>? map) {
    if (map == null) return '';
    for (final key in ['phone', 'customer_phone', 'customerPhone']) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// الوقت الحالي بتوقيت بغداد (UTC+3).
  static DateTime nowInBaghdad() {
    return DateTime.now().toUtc().add(const Duration(hours: 3));
  }

  /// هل الوقت الحالي ضمن ساعات الدوام المحددة؟
  static bool isWithinWorkingHours(
    Map<String, dynamic>? map, {
    DateTime? now,
  }) {
    final open = toTimeOfDay(timeFromMap(map, isOpen: true));
    final close = toTimeOfDay(timeFromMap(map, isOpen: false));
    if (open == null || close == null) return true;

    final current = now ?? nowInBaghdad();
    final nowMinutes = current.hour * 60 + current.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (openMinutes == closeMinutes) return true;
    if (closeMinutes > openMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    }
    return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
  }

  /// هل يقبل التاجر/المطعم اتصالات الزبائن الآن؟
  static bool isAcceptingCustomerCalls(
    Map<String, dynamic>? map, {
    DateTime? now,
  }) {
    if (map != null &&
        !boolValue(map['isOpen'] ?? map['is_open'], fallback: true)) {
      return false;
    }
    return isWithinWorkingHours(map, now: now);
  }

  /// رسالة عربية عند تعذّر الاتصال — أو null إذا مسموح.
  static String? callsUnavailableMessageAr(
    Map<String, dynamic>? map, {
    DateTime? now,
  }) {
    if (map != null &&
        !boolValue(map['isOpen'] ?? map['is_open'], fallback: true)) {
      return 'المتجر مغلق حالياً — الاتصال غير متاح.';
    }
    if (!isWithinWorkingHours(map, now: now)) {
      final hours = workingHoursLabel(map);
      if (hours == 'غير محدد') {
        return 'انتهى وقت الدوام. الاتصال متاح خلال ساعات العمل فقط.';
      }
      return 'انتهى وقت الدوام ($hours). الاتصال متاح خلال ساعات العمل فقط.';
    }
    return null;
  }

  /// مصدر واحد غير متكرر لحالة الاعتماد — يمنع التكرار اللانهائي
  /// (StackOverflow) الذي كان يحدث عند تبادل isApproved/approvalStatus.
  static String approvalStatus(Map<String, dynamic>? store) {
    if (store == null) return 'pending';

    final status = store['approvalStatus']?.toString().trim() ??
        store['approval_status']?.toString().trim() ??
        '';
    if (status == 'approved') return 'approved';
    if (status == 'rejected') return 'rejected';
    if (status == 'pending') return 'pending';

    if (store['isApproved'] == true || store['is_approved'] == true) {
      return 'approved';
    }
    if (store['isApproved'] == false || store['is_approved'] == false) {
      return 'pending';
    }

    final category = store['category']?.toString().trim() ??
        store['primary_service_id']?.toString().trim() ??
        store['primaryServiceId']?.toString().trim() ??
        '';
    final serviceIds = store['serviceIds'] ?? store['service_ids'];
    final hasProfessionalsService = category == 'professionals' ||
        (serviceIds is List &&
            serviceIds.map((item) => item.toString()).contains('professionals'));
    final professionalInfo = store['professionalInfo'] ?? store['professional_info'];
    final hasProfessionalInfo = professionalInfo is Map &&
        (professionalInfo['name']?.toString().trim().isNotEmpty == true ||
            professionalInfo['professionId']?.toString().trim().isNotEmpty ==
                true ||
            store['professionalCategoryId']?.toString().trim().isNotEmpty ==
                true);
    if (hasProfessionalsService || hasProfessionalInfo) {
      return 'pending';
    }

    // احتياط للبيانات القديمة: متجر باسم فعلي يُعتبر معتمداً.
    final name = store['name']?.toString().trim() ??
        store['store_name']?.toString().trim() ??
        '';
    return name.isNotEmpty ? 'approved' : 'pending';
  }

  static bool isApproved(Map<String, dynamic>? store) =>
      approvalStatus(store) == 'approved';

  static bool isRejected(Map<String, dynamic>? store) =>
      approvalStatus(store) == 'rejected';

  static String rejectionMessage(Map<String, dynamic>? store) =>
      store?['rejectionMessageAr']?.toString().trim() ??
      store?['rejection_message_ar']?.toString().trim() ??
      '';

  static Map<String, bool> serviceEnabledMap(Map<String, dynamic>? map) {
    if (map == null) return const {};
    final raw = map['serviceEnabled'] ??
        map['service_enabled'] ??
        (map['store_data'] is Map
            ? (map['store_data'] as Map)['serviceEnabled'] ??
                (map['store_data'] as Map)['service_enabled']
            : null);
    if (raw is! Map) return const {};
    final result = <String, bool>{};
    raw.forEach((key, value) {
      final id = key.toString().trim();
      if (id.isEmpty) return;
      if (value is bool) {
        result[id] = value;
        return;
      }
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized.isEmpty) return;
      result[id] = ['true', '1', 'yes', 'on'].contains(normalized);
    });
    return result;
  }

  static Map<String, bool> serviceEnabledMapForIds(
    Iterable<String> serviceIds,
    Map<String, dynamic>? map,
  ) {
    final stored = serviceEnabledMap(map);
    return {
      for (final id in serviceIds)
        if (id.trim().isNotEmpty) id.trim(): stored[id.trim()] ?? true,
    };
  }

  static bool isServiceEnabled(
    Map<String, dynamic>? map,
    String serviceId, {
    bool fallback = true,
  }) {
    final id = serviceId.trim();
    if (id.isEmpty) return fallback;
    final stored = serviceEnabledMap(map);
    if (!stored.containsKey(id)) return fallback;
    return stored[id] ?? fallback;
  }

  static Map<String, dynamic> serviceEnabledPayload(Map<String, bool> map) {
    return map.map((key, value) => MapEntry(key, value));
  }
}
