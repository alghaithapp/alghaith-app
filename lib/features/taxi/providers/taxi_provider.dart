import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/taxi_request.dart';
import '../models/driver_model.dart';
import '../services/taxi_api_service.dart';

/// مزود حالة التكسي (Provider) — يدير الطلبات، السائقين القريبين، والـ Polling
class TaxiProvider extends ChangeNotifier {
  List<TaxiRequest> _requests = [];
  TaxiRequest? _currentRequest;
  List<DriverModel> _nearbyDrivers = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;

  // ── Getters ──

  List<TaxiRequest> get requests => List.unmodifiable(_requests);

  TaxiRequest? get currentRequest => _currentRequest;

  List<TaxiRequest> get activeRequests =>
      _requests.where((r) => !r.isCompleted && !r.isCancelled).toList();

  List<TaxiRequest> get completedRequests =>
      _requests.where((r) => r.isCompleted).toList();

  List<TaxiRequest> get completedTrips => completedRequests;

  int get todayEarnings =>
      _requests.where((r) => r.isCompleted && r.completedAt != null && _isSameDay(r.completedAt!)).fold(0, (sum, r) => sum + r.fare);

  int get weeklyEarnings =>
      _requests.where((r) => r.isCompleted && r.completedAt != null && _isSameWeek(r.completedAt!)).fold(0, (sum, r) => sum + r.fare);

  int get monthlyEarnings =>
      _requests.where((r) => r.isCompleted && r.completedAt != null && _isSameMonth(r.completedAt!)).fold(0, (sum, r) => sum + r.fare);

  int get totalEarnings =>
      _requests.where((r) => r.isCompleted).fold(0, (sum, r) => sum + r.fare);

  List<TaxiRequest> get pendingRequests =>
      _requests.where((r) => r.isPending).toList();

  List<DriverModel> get nearbyDrivers => List.unmodifiable(_nearbyDrivers);

  bool get isLoading => _isLoading;

  String? get error => _error;
  
  bool get isOnline => true; // TODO: ربط مع حالة السائق
  
  int get todayTrips => completedRequests.length;

  // ── Toggle حالة الاتصال ──

  void toggleOnline() {
    // TODO: ربط مع الخدمة الفعلية (تغيير حالة السائق في Supabase)
    notifyListeners();
  }

  // ── إنشاء طلب ──

  Future<TaxiRequest?> createTaxiRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double distanceKm,
    required String taxiType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = await TaxiApiService.createRequest(
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        distanceKm: distanceKm,
        taxiType: taxiType,
      );
      _currentRequest = request;
      _requests.insert(0, request);
      return request;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── قبول الطلب ──

  Future<bool> acceptRequest(
    String requestId, {
    String? driverName,
    String? vehicleModel,
    String? plateNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await TaxiApiService.acceptRequest(
        requestId,
        driverName: driverName,
        vehicleModel: vehicleModel,
        plateNumber: plateNumber,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── رفض الطلب ──

  Future<void> rejectRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await TaxiApiService.rejectRequest(requestId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── تحديث الحالة ──

  Future<bool> updateStatus(
    String requestId,
    String statusKey,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await TaxiApiService.updateStatus(requestId, statusKey);
      if (_currentRequest != null && _currentRequest!.id == requestId) {
        _currentRequest = _currentRequest!.copyWith(statusKey: statusKey);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── إلغاء الطلب ──

  Future<bool> cancelRequest(
    String requestId,
    String reason,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await TaxiApiService.cancelRequest(requestId, reason);
      if (_currentRequest != null && _currentRequest!.id == requestId) {
        _currentRequest = _currentRequest!.copyWith(
          statusKey: 'cancelled',
          cancellationReason: reason,
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── تحميل الطلب النشط للزبون ──

  Future<void> loadActiveRequest() async {
    try {
      final request = await TaxiApiService.getActiveRequest();
      _currentRequest = request;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── تحميل الطلب النشط للسائق ──

  Future<void> loadDriverActiveRequest() async {
    try {
      final request = await TaxiApiService.getDriverActiveRequest();
      _currentRequest = request;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── تحميل تاريخ الطلبات للزبون ──

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = await TaxiApiService.getHistory();
      _requests = history;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── تحميل تاريخ الطلبات للسائق ──

  Future<void> loadDriverHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = await TaxiApiService.getDriverHistory();
      _requests = history;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── جلب السائقين القريبين ──

  Future<void> fetchNearbyDrivers(
    double lat,
    double lng,
    String taxiType,
  ) async {
    try {
      final drivers = await TaxiApiService.getNearbyDrivers(lat, lng, taxiType);
      _nearbyDrivers = drivers;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Polling للطلبات النشطة ──

  void startPolling({bool isDriver = false}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (isDriver) {
        await loadDriverActiveRequest();
      } else {
        await loadActiveRequest();
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _requests = [];
    _currentRequest = null;
    _nearbyDrivers = [];
    _error = null;
    notifyListeners();
  }

  static bool _isSameDay(DateTime a) {
    final now = DateTime.now();
    return a.year == now.year && a.month == now.month && a.day == now.day;
  }

  static bool _isSameWeek(DateTime a) {
    final now = DateTime.now();
    final diff = now.difference(a).inDays;
    return diff >= 0 && diff <= 7 && a.isBefore(now.add(const Duration(days: 1)));
  }

  static bool _isSameMonth(DateTime a) {
    final now = DateTime.now();
    return a.year == now.year && a.month == now.month;
  }
}
