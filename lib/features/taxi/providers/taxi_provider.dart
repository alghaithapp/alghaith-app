import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, RealtimeChannel;

import '../../../services/supabase_service.dart';
import '../models/taxi_request.dart';
import '../models/driver_model.dart';
import '../services/taxi_api_service.dart';

/// مزود حالة التكسي (Provider) — يدير الطلبات، السائقين القريبين، والـ Polling
class TaxiProvider extends ChangeNotifier {
  List<TaxiRequest> _requests = [];
  TaxiRequest? _currentRequest;
  TaxiRequest? _tripAwaitingRating;
  final Set<String> _dismissedRatingIds = {};
  List<DriverModel> _nearbyDrivers = [];
  List<TaxiRequest> _incomingRequests = [];
  bool _isLoading = false;
  bool _isOnline = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _incomingPoolTimer;
  RealtimeChannel? _activeRequestChannel;
  RealtimeChannel? _incomingRequestChannel;
  double? _incomingPollLat;
  double? _incomingPollLng;
  String? _incomingPollTaxiType;

  // ── Getters ──

  List<TaxiRequest> get requests => List.unmodifiable(_requests);

  TaxiRequest? get currentRequest => _currentRequest;

  TaxiRequest? get tripAwaitingRating => _tripAwaitingRating;

  List<TaxiRequest> get incomingRequests => List.unmodifiable(_incomingRequests);

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

  bool get isOnline => _isOnline;

  String? get error => _error;

  int get todayTrips => completedRequests.length;

  // ── Toggle حالة الاتصال ──

  Future<void> toggleOnline() async {
    _isOnline = !_isOnline;
    notifyListeners();
    try {
      await TaxiApiService.setDriverOnlineStatus(_isOnline);
    } catch (e) {
      _isOnline = !_isOnline;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setOnline(bool value) async {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
    try {
      await TaxiApiService.setDriverOnlineStatus(value);
    } catch (e) {
      _isOnline = !value;
      _error = e.toString();
      notifyListeners();
    }
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
    List<TaxiWaypoint> waypoints = const [],
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
        waypoints: waypoints,
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
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      _error = 'معرّف الطلب غير صالح';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final accepted = await TaxiApiService.acceptRequest(
        trimmedId,
        driverName: driverName,
        vehicleModel: vehicleModel,
        plateNumber: plateNumber,
      );
      _currentRequest = accepted;
      _incomingRequests.removeWhere((r) => r.id == trimmedId);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── رفض الطلب ──

  Future<bool> rejectRequest(String requestId) async {
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      _error = 'معرّف الطلب غير صالح';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await TaxiApiService.rejectRequest(trimmedId);
      _incomingRequests.removeWhere((r) => r.id == trimmedId);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '');
      return false;
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

  Future<bool> cancelRequest(String requestId, {String? reason}) async {
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      _error = 'معرّف الطلب غير صالح';
      notifyListeners();
      return false;
    }

    final current = _currentRequest;
    if (current != null &&
        current.id == trimmedId &&
        current.hasAssignedDriver &&
        !current.isPickedUp &&
        !current.isCancelRequested) {
      return requestTripCancellation(trimmedId, reason: reason);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await TaxiApiService.cancelRequest(trimmedId, reason: reason);
      if (updated == null || updated.isCancelled) {
        _currentRequest = null;
      } else {
        _currentRequest = updated;
      }
      if (updated?.isCancelled == true) {
        _requests.removeWhere((r) => r.id == trimmedId);
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestTripCancellation(String requestId, {String? reason}) async {
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      _error = 'معرّف الطلب غير صالح';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await TaxiApiService.requestTripCancellation(
        trimmedId,
        reason: reason,
      );
      if (updated != null) {
        _currentRequest = updated;
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDriverTripLocation({
    required String requestId,
    required double lat,
    required double lng,
  }) async {
    try {
      final updated = await TaxiApiService.updateDriverTripLocation(
        requestId: requestId,
        lat: lat,
        lng: lng,
      );
      if (updated != null && _currentRequest?.id == requestId) {
        _currentRequest = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── تحميل الطلب النشط للزبون ──

  Future<void> loadActiveRequest() async {
    try {
      final previous = _currentRequest;
      final request = await TaxiApiService.getActiveRequest();
      if (request != null) {
        _currentRequest = request;
      } else {
        _currentRequest = null;
        final wasInProgress = previous != null &&
            !previous.isCompleted &&
            !previous.isCancelled &&
            (previous.hasAssignedDriver || previous.isPending);
        if (wasInProgress) {
          await _refreshPendingRating();
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> checkPendingRating() => _refreshPendingRating();

  Future<void> _refreshPendingRating() async {
    try {
      final pending = await TaxiApiService.getPendingRatingRequest();
      if (pending != null &&
          pending.driverRating <= 0 &&
          !_dismissedRatingIds.contains(pending.id)) {
        _tripAwaitingRating = pending;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> rateTrip({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    _error = null;
    try {
      final updated = await TaxiApiService.rateTrip(
        requestId: requestId,
        rating: rating,
        comment: comment,
      );
      _tripAwaitingRating = null;
      _dismissedRatingIds.remove(updated.id);
      _currentRequest = null;
      final index = _requests.indexWhere((r) => r.id == updated.id);
      if (index >= 0) {
        _requests[index] = updated;
      } else {
        _requests.insert(0, updated);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearTripAwaitingRating({String? requestId}) {
    final id = (requestId ?? _tripAwaitingRating?.id)?.trim();
    if (id != null && id.isNotEmpty) {
      _dismissedRatingIds.add(id);
    }
    if (_tripAwaitingRating == null) return;
    _tripAwaitingRating = null;
    notifyListeners();
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
      _requests = _dedupeTaxiRequestsList(history);
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

  void startPolling({bool isDriver = false, String? phone}) {
    stopPolling();
    // Realtime هو المصدر الأساسي؛ الاستطلاع الاحتياطي كل 30 ثانية فقط.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (isDriver) {
        await loadDriverActiveRequest();
      } else {
        await loadActiveRequest();
      }
    });
    if (isDriver) {
      loadDriverActiveRequest();
    } else {
      loadActiveRequest();
    }
    _startRealtime(isDriver: isDriver, phone: phone);
  }

  void updateIncomingPollLocation({double? lat, double? lng}) {
    if (lat != null) _incomingPollLat = lat;
    if (lng != null) _incomingPollLng = lng;
  }

  List<TaxiRequest> _dedupeTaxiRequestsList(List<TaxiRequest> requests) {
    final byId = <String, TaxiRequest>{};
    for (final request in requests) {
      final id = request.id.trim();
      if (id.isEmpty) continue;
      byId[id] = request;
    }
    return byId.values.toList();
  }

  /// جلب الطلبات الواردة للسائق من الخادم (حسب الموقع والنوع)
  Future<void> fetchIncomingRequests() async {
    try {
      final requests = await TaxiApiService.getIncomingRequests(
        lat: _incomingPollLat,
        lng: _incomingPollLng,
        taxiType: _incomingPollTaxiType,
      );
      _incomingRequests = _dedupeTaxiRequestsList(requests);
      notifyListeners();
    } catch (_) {}
  }

  void startIncomingPolling({
    String? phone,
    double? lat,
    double? lng,
    String? taxiType,
  }) {
    _incomingPollLat = lat;
    _incomingPollLng = lng;
    _incomingPollTaxiType = taxiType ?? 'economic';
    _incomingPoolTimer?.cancel();
    fetchIncomingRequests();
    _incomingPoolTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await fetchIncomingRequests();
    });
    _startIncomingRealtime(phone: phone);
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _incomingPoolTimer?.cancel();
    _incomingPoolTimer = null;
    _incomingRequests = [];
    _stopRealtime();
  }

  // ── Supabase Realtime ──

  void _startRealtime({bool isDriver = false, String? phone}) {
    _activeRequestChannel?.unsubscribe();
    _activeRequestChannel = null;
    if (phone == null || phone.isEmpty) return;
    final table = 'taxi_requests';
    final column = isDriver ? 'driver_phone' : 'phone';
    _activeRequestChannel = SupabaseService.realtime.subscribeToTable(
      table: table,
      filterColumn: column,
      filterValue: phone,
      onData: (_) {
        if (isDriver) {
          loadDriverActiveRequest();
        } else {
          loadActiveRequest();
        }
      },
    );
  }

  void _startIncomingRealtime({String? phone}) {
    _incomingRequestChannel?.unsubscribe();
    _incomingRequestChannel = null;

    _incomingRequestChannel =
        SupabaseService.realtime.subscribeToTable(
      table: 'taxi_requests',
      filterColumn: 'status_key',
      filterValue: 'pending',
      event: PostgresChangeEvent.all,
      onData: (_) {
        fetchIncomingRequests();
      },
    );
  }

  void _stopRealtime() {
    _activeRequestChannel?.unsubscribe();
    _activeRequestChannel = null;
    _incomingRequestChannel?.unsubscribe();
    _incomingRequestChannel = null;
  }

  @override
  void dispose() {
    stopPolling();
    _stopRealtime();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _requests = [];
    _currentRequest = null;
    _tripAwaitingRating = null;
    _nearbyDrivers = [];
    _isOnline = false;
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
