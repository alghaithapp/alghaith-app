import '../../../core/network/api_client.dart';
import '../models/taxi_request.dart';
import '../models/driver_model.dart';

/// خدمة API لطلبات التكسي — تتصل بـ /db/taxi/* عبر ApiClient
class TaxiApiService {
  static const String _basePath = '/db/taxi';

  /// إنشاء طلب تكسي جديد
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<TaxiRequest> createRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double distanceKm,
    required String taxiType,
    List<TaxiWaypoint> waypoints = const [],
  }) async {
    final result = await ApiClient.instance.post('$_basePath/create', body: {
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'distanceKm': distanceKm,
      'taxiType': taxiType,
      if (waypoints.isNotEmpty)
        'waypoints': waypoints.map((wp) => wp.toApiMap()).toList(),
    });
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// قبول الطلب من قبل السائق
  static Future<TaxiRequest> acceptRequest(
    String requestId, {
    String? driverName,
    String? vehicleModel,
    String? plateNumber,
  }) async {
    final result = await ApiClient.instance.post('$_basePath/accept', body: {
      'requestId': requestId,
      if (driverName != null && driverName.isNotEmpty) 'driverName': driverName,
      if (vehicleModel != null && vehicleModel.isNotEmpty) 'vehicleModel': vehicleModel,
      if (plateNumber != null && plateNumber.isNotEmpty) 'plateNumber': plateNumber,
    });
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result as Map));
  }

  /// رفض الطلب من قبل السائق
  static Future<void> rejectRequest(String requestId) async {
    await ApiClient.instance.post('$_basePath/reject', body: {
      'requestId': requestId,
    });
  }

  /// تحديث حالة الطلب (arrived, picked_up, completed)
  static Future<void> updateStatus(
    String requestId,
    String statusKey,
  ) async {
    await ApiClient.instance.post('$_basePath/status', body: {
      'requestId': requestId,
      'statusKey': statusKey,
    });
  }

  /// إلغاء الطلب المعلّق فوراً
  static Future<TaxiRequest?> cancelRequest(String requestId, {String? reason}) async {
    final result = await ApiClient.instance.post('$_basePath/cancel', body: {
      'requestId': requestId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result as Map));
  }

  /// طلب إلغاء بعد قبول السائق (بانتظار موافقته)
  static Future<TaxiRequest?> requestTripCancellation(
    String requestId, {
    String? reason,
  }) async {
    final result =
        await ApiClient.instance.post('$_basePath/request-cancellation', body: {
      'requestId': requestId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result as Map));
  }

  /// تحديث موقع السائق أثناء الرحلة النشطة
  static Future<TaxiRequest?> updateDriverTripLocation({
    required String requestId,
    required double lat,
    required double lng,
  }) async {
    final result = await ApiClient.instance.post('$_basePath/driver-location', body: {
      'requestId': requestId,
      'lat': lat,
      'lng': lng,
    });
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result as Map));
  }

  /// جلب الطلب النشط للزبون
  static Future<TaxiRequest?> getActiveRequest() async {
    final result = await ApiClient.instance.get('$_basePath/active');
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// جلب الطلب النشط للسائق
  static Future<TaxiRequest?> getDriverActiveRequest() async {
    final result = await ApiClient.instance.get('$_basePath/driver-active');
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// آخر رحلة مكتملة بانتظار التقييم
  static Future<TaxiRequest?> getPendingRatingRequest() async {
    final result = await ApiClient.instance.get('$_basePath/pending-rating');
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// تقييم السائق بعد الرحلة
  static Future<TaxiRequest> rateTrip({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    final result = await ApiClient.instance.post('$_basePath/rate', body: {
      'requestId': requestId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result as Map));
  }

  /// جلب تاريخ الطلبات للزبون
  static Future<List<TaxiRequest>> getHistory() async {
    final result = await ApiClient.instance.get('$_basePath/history');
    if (result == null) return [];
    final list = (result as List)
        .map((e) => TaxiRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  /// جلب تاريخ الطلبات للسائق
  static Future<List<TaxiRequest>> getDriverHistory() async {
    final result = await ApiClient.instance.get('$_basePath/driver-history');
    if (result == null) return [];
    final list = (result as List)
        .map((e) => TaxiRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  /// تحديث حالة اتصال السائق (متصل/غير متصل)
  static Future<void> setDriverOnlineStatus(bool isOnline) async {
    await ApiClient.instance.post('$_basePath/driver-status', body: {
      'isOnline': isOnline,
    });
  }

  /// جلب الطلبات الواردة للسائق
  static Future<List<TaxiRequest>> getIncomingRequests({
    double? lat,
    double? lng,
    String? taxiType,
  }) async {
    final query = <String, String>{};
    if (lat != null && lat != 0) query['lat'] = lat.toString();
    if (lng != null && lng != 0) query['lng'] = lng.toString();
    if (taxiType != null && taxiType.trim().isNotEmpty) {
      query['taxiType'] = taxiType.trim();
    }
    final result = await ApiClient.instance.get(
      '$_basePath/incoming-requests',
      queryParameters: query.isEmpty ? null : query,
    );
    if (result == null) return [];
    final list = (result as List)
        .map((e) => TaxiRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  /// جلب السائقين القريبين
  static Future<List<DriverModel>> getNearbyDrivers(
    double lat,
    double lng,
    String taxiType,
  ) async {
    final result = await ApiClient.instance.get(
      '$_basePath/nearby-drivers',
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'taxiType': taxiType,
      },
    );
    if (result == null) return [];
    final list = (result as List)
        .map((e) => DriverModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }
}
