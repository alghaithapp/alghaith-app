import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../models/taxi_request.dart';
import '../models/driver_model.dart';

/// خدمة API لطلبات التكسي — تتصل بـ /db/taxi/* عبر ApiClient
class TaxiApiService {
  static String get _baseUrl => '${AppConfig.normalizedDatabaseUrl}/db/taxi';

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
  }) async {
    final result = await ApiClient.instance.post('$_baseUrl/create', body: {
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'distanceKm': distanceKm,
      'taxiType': taxiType,
    });
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// قبول الطلب من قبل السائق
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<void> acceptRequest(
    String requestId, {
    String? driverName,
    String? vehicleModel,
    String? plateNumber,
  }) async {
    await ApiClient.instance.post('$_baseUrl/accept', body: {
      'requestId': requestId,
      if (driverName != null) 'driverName': driverName,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (plateNumber != null) 'plateNumber': plateNumber,
    });
  }

  /// رفض الطلب من قبل السائق
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<void> rejectRequest(String requestId) async {
    await ApiClient.instance.post('$_baseUrl/reject', body: {
      'requestId': requestId,
    });
  }

  /// تحديث حالة الطلب (arrived, picked_up, completed)
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<void> updateStatus(
    String requestId,
    String statusKey,
  ) async {
    await ApiClient.instance.post('$_baseUrl/status', body: {
      'requestId': requestId,
      'statusKey': statusKey,
    });
  }

  /// إلغاء الطلب من قبل الزبون
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<void> cancelRequest(
    String requestId,
    String reason,
  ) async {
    await ApiClient.instance.post('$_baseUrl/cancel', body: {
      'requestId': requestId,
      'reason': reason,
    });
  }

  /// جلب الطلب النشط للزبون
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<TaxiRequest?> getActiveRequest() async {
    final result = await ApiClient.instance.get('$_baseUrl/active');
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// جلب الطلب النشط للسائق
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<TaxiRequest?> getDriverActiveRequest() async {
    final result = await ApiClient.instance.get('$_baseUrl/driver-active');
    if (result == null) return null;
    return TaxiRequest.fromMap(Map<String, dynamic>.from(result));
  }

  /// جلب تاريخ الطلبات للزبون
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<List<TaxiRequest>> getHistory() async {
    final result = await ApiClient.instance.get('$_baseUrl/history');
    if (result == null) return [];
    final list = (result as List)
        .map((e) => TaxiRequest.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  /// جلب تاريخ الطلبات للسائق
  /// (رقم الهاتف يجي من توكن الجلسة تلقائياً)
  static Future<List<TaxiRequest>> getDriverHistory() async {
    final result = await ApiClient.instance.get('$_baseUrl/driver-history');
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
      '$_baseUrl/nearby-drivers',
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
