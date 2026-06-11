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

  static bool isApproved(Map<String, dynamic>? store) {
    if (store == null) return false;
    if (store['isApproved'] == true || store['is_approved'] == true) return true;
    if (approvalStatus(store) == 'approved') return true;
    if (approvalStatus(store) == 'pending' || approvalStatus(store) == 'rejected') {
      return false;
    }
    if (store['isApproved'] == false || store['is_approved'] == false) {
      return false;
    }
    final name = store['name']?.toString().trim() ??
        store['store_name']?.toString().trim() ??
        '';
    return name.isNotEmpty;
  }

  static String approvalStatus(Map<String, dynamic>? store) {
    if (isApproved(store)) return 'approved';
    final status =
        store?['approvalStatus']?.toString().trim() ??
            store?['approval_status']?.toString().trim() ??
            '';
    if (status == 'rejected') return 'rejected';
    if (status == 'pending') return 'pending';
    if (store?['isApproved'] == false || store?['is_approved'] == false) {
      return 'pending';
    }
    return 'approved';
  }

  static bool isRejected(Map<String, dynamic>? store) =>
      approvalStatus(store) == 'rejected';

  static String rejectionMessage(Map<String, dynamic>? store) =>
      store?['rejectionMessageAr']?.toString().trim() ??
      store?['rejection_message_ar']?.toString().trim() ??
      '';
}
