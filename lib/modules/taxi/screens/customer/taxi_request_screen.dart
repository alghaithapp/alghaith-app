import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';

import 'package:flutter/cupertino.dart';
import '../../models/taxi_request.dart';
import '../../models/taxi_favorite_place.dart';
import '../../models/taxi_saved_place_use.dart';
import '../../providers/taxi_provider.dart';
import '../../utils/taxi_distance_calculator.dart';
import '../../utils/taxi_fare_calculator.dart';
import 'taxi_waiting_screen.dart';
import 'taxi_live_tracking_screen.dart';
import '../../../../core/data/iraq_neighborhoods.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../../../utils/guest_gate.dart';
import '../../services/taxi_places_service.dart';
import '../../widgets/taxi_map_widget.dart';
import '../../widgets/taxi_type_image.dart';
import '../../widgets/taxi_favorite_places_row.dart';
import '../../widgets/taxi_saved_place_role_sheet.dart';
import '../../widgets/taxi_party_contact_buttons.dart';
import '../../widgets/taxi_customer_trip_actions.dart';
import '../../utils/taxi_labels.dart';

/// شاشة طلب التكسي (مستوى الزبون)
class TaxiRequestScreen extends StatefulWidget {
  const TaxiRequestScreen({
    super.key,
    this.onOpenCurrentOrderTab,
    this.bottomNavInset = 0,
  });

  final VoidCallback? onOpenCurrentOrderTab;
  final double bottomNavInset;

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _dropoffFocus = FocusNode();
  gmaps.GoogleMapController? _mapController;
  bool _clearedForActiveTrip = false;

  double _distanceKm = 0.0;
  int _fareTuktuk = 0;
  int _fareWazz = 0;
  int _fareEconomic = 0;
  TaxiType _selectedTaxiType = TaxiType.tuktuk;
  bool _showCarSelection = false;
  bool _isRoundTrip = false;
  int _waitingMinutes = 15;
  static const List<int> _waitingOptions = [5, 10, 15, 30, 60];
  bool _isSearching = false;
  bool _isGettingLocation = false;
  List<TaxiPlaceSuggestion> _suggestions = [];
  bool _isPickupField = false;
  Timer? _searchDebounce;

  /// إحداثيات موقع الانطلاق والوصول
  LatLng? _pickupCoord;
  LatLng? _dropoffCoord;

  /// نقاط المسار بين الانطلاق والوصول
  List<LatLng>? _routePoints;

  /// مدة الرحلة بالثواني من Directions (أو تقدير من المسافة)
  int? _routeDurationSeconds;

  /// عند النقر على الخريطة — true يعني تعيين موقع الانطلاق، false يعني تعيين الوصول
  bool _isSettingPickupByTap = true;

  final List<_TripStopDraft> _stops = [];
  int? _editingStopIndex;

  List<TaxiDrivingRoute> _routeAlternatives = [];
  int _selectedRouteIndex = 0;

  bool get _hasBothLocations =>
      _pickupController.text.trim().isNotEmpty &&
      _dropoffController.text.trim().isNotEmpty;

  int get _tripDurationSeconds {
    final routeDuration = _routeDurationSeconds;
    if (routeDuration != null && routeDuration > 0) return routeDuration;
    if (_distanceKm > 0) {
      return TaxiDistanceCalculator.estimateDrivingDurationSeconds(_distanceKm);
    }
    return 60;
  }

  String get _tripEtaLabel =>
      'وقت الوصول: ${TaxiDistanceCalculator.formatDrivingDurationAr(_tripDurationSeconds)}';

  @override
  void initState() {
    super.initState();
    _pickupController.addListener(() => _onTextChanged(true));
    _dropoffController.addListener(() => _onTextChanged(false));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapActiveRequest());
  }

  Future<void> _bootstrapActiveRequest() async {
    if (!mounted) return;
    final taxi = context.read<TaxiProvider>();
    taxi.addListener(_onTaxiProviderChanged);
    final phone = context.read<AppProvider>().authPhone;
    if (phone != null && phone.isNotEmpty) {
      taxi.startPolling(phone: phone);
    }
    await taxi.loadActiveRequest();
    if (!mounted) return;
    _applyActiveRequestState(taxi.currentRequest);
    if (!mounted) return;
    await _applyPendingSavedPlaceIfAny();
    if (!mounted) return;
    await _applyPendingTripReplayIfAny();
    if (!mounted) return;
    await _autoSetPickupFromCurrentLocation(taxi.currentRequest);
  }

  Future<void> _applyPendingTripReplayIfAny() async {
    final trip = context.read<TaxiProvider>().takePendingTripReplay();
    if (trip == null) return;
    await _applyTripReplay(trip);
  }

  Future<void> _applyTripReplay(TaxiRequest request) async {
    if (!request.canReplayTrip) return;

    for (final stop in _stops) {
      stop.dispose();
    }
    _stops.clear();

    _pickupController.text = request.pickupAddress;
    _dropoffController.text = request.dropoffAddress;
    _pickupCoord = LatLng(request.pickupLat, request.pickupLng);
    _dropoffCoord = LatLng(request.dropoffLat, request.dropoffLng);
    _selectedTaxiType = request.taxiType;

    for (final wp in request.waypoints) {
      if (wp.address.trim().isEmpty || wp.lat.abs() <= 0.001 || wp.lng.abs() <= 0.001) {
        continue;
      }
      final draft = _TripStopDraft();
      draft.controller.text = wp.address;
      draft.coord = LatLng(wp.lat, wp.lng);
      _stops.add(draft);
    }

    _isPickupField = false;
    _isSettingPickupByTap = false;
    _showCarSelection = true;
    _suggestions = [];
    _editingStopIndex = null;
    FocusScope.of(context).unfocus();

    if (_stops.isEmpty) {
      await _fetchRoute(_pickupCoord!, _dropoffCoord!);
    } else {
      await _refreshRouteWithStops();
    }

    if (mounted) setState(() {});
  }

  Future<void> _applyPendingSavedPlaceIfAny() async {
    final pending = context.read<TaxiProvider>().takePendingSavedPlace();
    if (pending == null) return;
    await _applySavedPlace(pending.place, pending.field);
  }

  Future<void> _promptAndApplySavedPlace(TaxiFavoritePlace place) async {
    final field = await showTaxiSavedPlaceRoleSheet(context, place: place);
    if (field == null || !mounted) return;
    await _applySavedPlace(place, field);
  }

  Future<void> _applySavedPlace(
    TaxiFavoritePlace place,
    TaxiSavedPlaceField field,
  ) async {
    _showCarSelection = false;
    _suggestions = [];
    _editingStopIndex = null;
    FocusScope.of(context).unfocus();

    if (field == TaxiSavedPlaceField.dropoff) {
      _dropoffController.text = place.address;
      _dropoffCoord = place.coord;
      _isPickupField = true;
      _isSettingPickupByTap = true;
      final pickup = _pickupCoord;
      if (pickup != null) {
        await _fetchRoute(pickup, place.coord);
      }
    } else {
      _pickupController.text = place.address;
      _pickupCoord = place.coord;
      _isPickupField = false;
      _isSettingPickupByTap = false;
      final dropoff = _dropoffCoord;
      if (dropoff != null) {
        await _fetchRoute(place.coord, dropoff);
      } else {
        _dropoffFocus.requestFocus();
      }
    }

    if (mounted) setState(() {});
  }

  /// عند فتح الخدمة: طلب إذن الموقع وتعيين الموقع الحالي كنقطة انطلاق.
  Future<void> _autoSetPickupFromCurrentLocation(TaxiRequest? request) async {
    if (_pickupCoord != null || _dropoffCoord != null) return;
    if (request != null &&
        !request.isCompleted &&
        !request.isCancelled &&
        (request.hasAssignedDriver || request.isPending)) {
      return;
    }
    await _getCurrentLocation(focusDropoffOnSuccess: _dropoffCoord == null);
  }

  void _onTaxiProviderChanged() {
    if (!mounted) return;
    _applyActiveRequestState(context.read<TaxiProvider>().currentRequest);
    if (context.read<TaxiProvider>().pendingSavedPlace != null) {
      unawaited(_applyPendingSavedPlaceIfAny());
    }
    if (context.read<TaxiProvider>().pendingTripReplay != null) {
      unawaited(_applyPendingTripReplayIfAny());
    }
  }

  void _applyActiveRequestState(TaxiRequest? request) {
    if (request == null || request.isCompleted || request.isCancelled) {
      _clearedForActiveTrip = false;
      return;
    }
    if ((request.hasAssignedDriver || request.isPending) &&
        !_clearedForActiveTrip) {
      _clearLocationForm();
      _clearedForActiveTrip = true;
    }
  }

  void _clearLocationForm() {
    _pickupController.clear();
    _dropoffController.clear();
    if (!mounted) return;
    setState(() {
      _pickupCoord = null;
      _dropoffCoord = null;
      _routePoints = null;
      _routeDurationSeconds = null;
      _showCarSelection = false;
      _suggestions = [];
      _distanceKm = 0;
      _fareTuktuk = 0;
      _fareWazz = 0;
      _fareEconomic = 0;
    });
  }

  void _onTextChanged(bool isPickup) {
    final controller = isPickup ? _pickupController : _dropoffController;
    final query = controller.text.trim();
    _isPickupField = isPickup;
    _searchDebounce?.cancel();

    if (_pickupController.text.trim().isNotEmpty &&
        _dropoffController.text.trim().isNotEmpty) {
      FocusScope.of(context).unfocus();
    }

    if (query.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPlaceSuggestions(query);
    });
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    final bias = _pickupCoord ??
        const LatLng(IraqNeighborhoods.centerLat, IraqNeighborhoods.centerLng);
    final googleResults =
        await TaxiPlacesService.autocomplete(query, bias: bias);
    final localResults = IraqNeighborhoods.search(query, maxResults: 6);

    final merged = <TaxiPlaceSuggestion>[];
    final seen = <String>{};

    for (final local in localResults) {
      final key = local.place.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      merged.add(
        TaxiPlaceSuggestion(
          displayName: local.place.name,
          latLng: local.place.latlng,
        ),
      );
    }

    for (final item in googleResults) {
      final key = item.displayName.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      merged.add(item);
    }

    if (!mounted) return;
    setState(() {
      _suggestions = merged.take(12).toList();
      _isSearching = false;
    });
  }

  Future<void> _selectSuggestion(TaxiPlaceSuggestion suggestion) async {
    final stopIndex = _editingStopIndex;
    final controller = stopIndex != null
        ? _stops[stopIndex].controller
        : (_isPickupField ? _pickupController : _dropoffController);

    LatLng? coord = suggestion.latLng;
    var address = suggestion.displayName;

    if (coord == null &&
        suggestion.googlePlaceId != null &&
        suggestion.googlePlaceId!.isNotEmpty) {
      final details =
          await TaxiPlacesService.placeDetails(suggestion.googlePlaceId!);
      if (details != null) {
        coord = details.latLng;
        address = details.displayName;
      }
    }

    if (!mounted) return;

    if (stopIndex != null) {
      setState(() {
        controller.text = address;
        _stops[stopIndex].coord = coord;
        _suggestions = [];
        _showCarSelection = false;
        _editingStopIndex = null;
      });
      await _refreshRouteWithStops();
      FocusScope.of(context).unfocus();
      return;
    }

    if (_isPickupField) {
      setState(() {
        controller.text = address;
        _suggestions = [];
        _showCarSelection = false;
        _pickupCoord = coord;
        _dropoffCoord = null;
        _routePoints = null;
        _routeDurationSeconds = null;
      });
      if (coord != null) {
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(coord.latitude, coord.longitude),
            15.0,
          ),
        );
      }
    } else {
      setState(() {
        controller.text = address;
        _suggestions = [];
        _showCarSelection = false;
        _dropoffCoord = coord;
      });
      final pickup = _pickupCoord;
      if (pickup != null && coord != null) {
        await _fetchRoute(pickup, coord);
      }
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _refreshRouteWithStops() async {
    final pickup = _pickupCoord;
    final dropoff = _dropoffCoord;
    if (pickup == null || dropoff == null) return;

    final hasStops = _stops.any((s) => s.coord != null);

    if (!hasStops) {
      await _fetchRoute(pickup, dropoff);
      return;
    }

    // حساب المسافة الكلية عبر نقاط التوقف (خط مستقيم)
    final chain = <LatLng>[pickup];
    for (final stop in _stops) {
      final coord = stop.coord;
      if (coord != null) chain.add(coord);
    }
    chain.add(dropoff);

    double totalKm = 0;
    for (var i = 0; i < chain.length - 1; i++) {
      totalKm += TaxiDistanceCalculator.calculateDistance(
        chain[i].latitude, chain[i].longitude,
        chain[i + 1].latitude, chain[i + 1].longitude,
      );
    }

    // جلب المسار من أول نقطة إلى آخر نقطة (Google/Mapbox يتجاهل نقاط التوقف)
    await _fetchRoute(pickup, dropoff);
    if (!mounted) return;
    if (totalKm > _distanceKm) {
      setState(() {
        _distanceKm = totalKm;
        _updateFares();
      });
    }
  }

  void _addStopField() {
    if (_stops.length >= 3) return;
    setState(() {
      _stops.add(_TripStopDraft());
      _editingStopIndex = _stops.length - 1;
      _isPickupField = false;
    });
  }

  void _removeStopField(int index) {
    if (index < 0 || index >= _stops.length) return;
    setState(() {
      _stops[index].dispose();
      _stops.removeAt(index);
      if (_editingStopIndex == index) _editingStopIndex = null;
    });
    unawaited(_refreshRouteWithStops());
  }

  List<TaxiWaypoint> _buildWaypoints() {
    return _stops
        .where((s) =>
            s.controller.text.trim().isNotEmpty &&
            s.coord != null &&
            s.coord!.latitude != 0)
        .map(
          (s) => TaxiWaypoint(
            address: s.controller.text.trim(),
            lat: s.coord!.latitude,
            lng: s.coord!.longitude,
          ),
        )
        .toList();
  }

  /// جلب المسار — مع البدائل لعرضها للمستخدم لاختيار الأنسب.
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final alternatives = await TaxiPlacesService.fetchDrivingRouteAlternatives(from, to);
    if (!mounted) return;
    final primary = alternatives.isNotEmpty ? alternatives[0] : const TaxiDrivingRoute();
    final altList = alternatives.length > 1 ? [alternatives[1]] : <TaxiDrivingRoute>[];

    setState(() {
      _routePoints = primary.points.length >= 2 ? primary.points : null;
      _routeDurationSeconds = primary.durationSeconds;
      _routeAlternatives = altList;
      _selectedRouteIndex = 0;
      final routeDistanceKm = primary.distanceKm;
      if (routeDistanceKm != null && routeDistanceKm > 0) {
        _distanceKm = routeDistanceKm;
        _updateFares();
      }
    });
    if (primary.points.length >= 2) {
      await _fitMapToLocations();
    }
  }

  void _selectRouteAlternative(int index) {
    final routes = [if (_routePoints != null) TaxiDrivingRoute(points: _routePoints!, durationSeconds: _routeDurationSeconds, distanceMeters: _distanceKm * 1000), ..._routeAlternatives];
    if (index < 0 || index >= routes.length) return;
    final selected = routes[index];
    setState(() {
      _selectedRouteIndex = index;
      _routePoints = selected.points.length >= 2 ? selected.points : _routePoints;
      _routeDurationSeconds = selected.durationSeconds ?? _routeDurationSeconds;
      final routeDistanceKm = selected.distanceKm;
      if (routeDistanceKm != null && routeDistanceKm > 0) {
        _distanceKm = routeDistanceKm;
        _updateFares();
      }
    });
  }

  void _updateFares() {
    _fareTuktuk = TaxiFareCalculator.fareForTypeWithRoundTrip(_distanceKm, TaxiType.tuktuk, _isRoundTrip);
    _fareWazz = TaxiFareCalculator.fareForTypeWithRoundTrip(_distanceKm, TaxiType.wazz, _isRoundTrip);
    _fareEconomic = TaxiFareCalculator.fareForTypeWithRoundTrip(_distanceKm, TaxiType.economic, _isRoundTrip);
  }

  Future<void> _fitMapToLocations() async {
    if (_mapController == null) return;
    final points = <gmaps.LatLng>[];
    if (_pickupCoord != null) {
      points.add(
        gmaps.LatLng(_pickupCoord!.latitude, _pickupCoord!.longitude),
      );
    }
    if (_dropoffCoord != null) {
      points.add(
        gmaps.LatLng(_dropoffCoord!.latitude, _dropoffCoord!.longitude),
      );
    }
    if (_routePoints != null) {
      for (final p in _routePoints!) {
        points.add(gmaps.LatLng(p.latitude, p.longitude));
      }
    }
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
    try {
      await _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 72),
      );
    } catch (_) {}
  }

  void _calculateFares() {
    _fareTuktuk = TaxiFareCalculator.fareForTypeWithRoundTrip(
        _distanceKm, TaxiType.tuktuk, _isRoundTrip);
    _fareWazz = TaxiFareCalculator.fareForTypeWithRoundTrip(
        _distanceKm, TaxiType.wazz, _isRoundTrip);
    _fareEconomic = TaxiFareCalculator.fareForTypeWithRoundTrip(
        _distanceKm, TaxiType.economic, _isRoundTrip);
    setState(() {});
  }

  Future<void> _onRequestTrip() async {
    if (_pickupController.text.trim().isEmpty) {
      _showSnackBar('يرجى تحديد نقطة الانطلاق أولاً.');
      return;
    }
    if (_dropoffController.text.trim().isEmpty) {
      _showSnackBar('يرجى تحديد الوجهة أولاً.');
      return;
    }
    final pickup = _pickupCoord;
    final dropoff = _dropoffCoord;
    if (pickup != null && dropoff != null && (_routePoints == null || _routePoints!.length < 2)) {
      await _fetchRoute(pickup, dropoff);
    }
    if (!mounted) return;
    _calculateFares();
    setState(() => _showCarSelection = true);
  }

  void _onDismissCarSelection() {
    setState(() => _showCarSelection = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  Future<void> _onConfirmRequest() async {
    if (!GuestGate.requireAccount(context, message: 'سجّل دخولك لطلب التكسي.')) {
      return;
    }

    final pickup = _pickupCoord ?? const LatLng(32.9256, 44.7766);
    final dropoff = _dropoffCoord ?? const LatLng(32.9300, 44.7800);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaxiWaitingScreen(
          createParams: TaxiTripCreateParams(
            pickupAddress: _pickupController.text,
            dropoffAddress: _dropoffController.text,
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            dropoffLat: dropoff.latitude,
            dropoffLng: dropoff.longitude,
            distanceKm: _distanceKm,
            taxiType: _selectedTaxiType.toApiName,
            waypoints: _buildWaypoints(),
            isRoundTrip: _isRoundTrip,
            waitingMinutes: _isRoundTrip ? _waitingMinutes : null,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    context.read<TaxiProvider>().removeListener(_onTaxiProviderChanged);
    for (final stop in _stops) {
      stop.dispose();
    }
    _pickupController.dispose();
    _dropoffController.dispose();
    _dropoffFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRequest = context.watch<TaxiProvider>().currentRequest;
    final hasActiveTrip = activeRequest != null &&
        !activeRequest.isCompleted &&
        !activeRequest.isCancelled;

    final hideLocationFields = hasActiveTrip &&
        (activeRequest.hasAssignedDriver || activeRequest.isPending);
    final showPendingBanner = hasActiveTrip && activeRequest.isPending;
    final showAcceptedBanner = hasActiveTrip && activeRequest.hasAssignedDriver;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('طلب تكسي'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: const _TaxiBackButton(),
          actions: [
            GestureDetector(
              onTap: _isGettingLocation ? null : () => _getCurrentLocation(),
              child: Container(
                margin: const EdgeInsets.all(8),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isGettingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // ── خلفية الخريطة (مع الإحداثيات والمسار) ──
            TaxiMapWidget(
              onMapCreated: (controller) => _mapController = controller,
              pickupLocation: hideLocationFields ? null : _pickupCoord,
              dropoffLocation: hideLocationFields ? null : _dropoffCoord,
              routePoints: hideLocationFields ? null : _routePoints,
              showCrosshair: !hideLocationFields && _pickupCoord == null,
              onMapTap: hideLocationFields ? null : _onMapTapped,
              onPickupDragEnd: hideLocationFields ? null : _onPickupDragEnd,
              onDropoffDragEnd: hideLocationFields ? null : _onDropoffDragEnd,
            ),

            if (showAcceptedBanner)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: _ActiveTripBanner(
                  request: activeRequest,
                  onTrack: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TaxiLiveTrackingScreen(),
                      ),
                    );
                  },
                  onOpenOrders: widget.onOpenCurrentOrderTab,
                ),
              ),

            if (showPendingBanner && !hideLocationFields)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: _PendingTripBanner(
                  onOpenWaiting: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TaxiWaitingScreen(),
                      ),
                    );
                  },
                ),
              ),

            // ── حقول البحث العائمة ──
            if (!hideLocationFields)
            Positioned(
              top: 16, left: 20, right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // حقل "من أين؟"
                  _buildSearchField(
                    controller: _pickupController,
                    hint: 'من أين؟',
                    icon: Icons.my_location,
                    iconColor: AppColors.primary,
                    onTap: () {
                      _editingStopIndex = null;
                      _isPickupField = true;
                    },
                  ),
                  const SizedBox(height: 8),
                  // حقل "إلى أين؟"
                  _buildSearchField(
                    controller: _dropoffController,
                    hint: 'إلى أين؟',
                    icon: Icons.search,
                    iconColor: AppColors.primary,
                    focusNode: _dropoffFocus,
                    onTap: () {
                      _editingStopIndex = null;
                      _isPickupField = false;
                    },
                  ),
                  const SizedBox(height: 8),
                  TaxiFavoritePlacesRow(
                    onSelected: (place) => _promptAndApplySavedPlace(place),
                  ),
                  // ── نقاط التوقف الوسيطة ──
                  if (_stops.isNotEmpty || _stops.length < 3)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _stops.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Cairo'))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSearchField(
                                    controller: _stops[i].controller,
                                    hint: 'نقطة توقف ${i + 1}',
                                    icon: Icons.add_location_alt_outlined,
                                    iconColor: AppColors.accent,
                                    onTap: () {
                                      _editingStopIndex = i;
                                      _isPickupField = false;
                                    },
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeStopField(i),
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_stops.length < 3)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _addStopField,
                                icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
                                label: Text(
                                  'إضافة توقف',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // الاقتراحات
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (_, i) {
                          final item = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              item.googlePlaceId != null
                                  ? Icons.place_outlined
                                  : Icons.location_city_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              item.displayName,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: item.subtitle != null &&
                                    item.subtitle!.isNotEmpty
                                ? Text(
                                    item.subtitle!,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            onTap: () => _selectSuggestion(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // ── زر "اطلب رحلة" (يظهر بعد تحديد الوجهة) ──
            if (!hideLocationFields && _hasBothLocations && !_showCarSelection)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + widget.bottomNavInset),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onRequestTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'اطلب رحلة 🌍',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Bottom Sheet: اختيار السيارة (بعد الضغط على "اطلب رحلة") ──
            if (!hideLocationFields && _showCarSelection)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 30,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── شريط تدرج علوي ──
                          Container(
                            height: 4,
                            width: 60,
                            margin: const EdgeInsets.only(top: 10, bottom: 14),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradientLinear,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // ── العنوان مع زر الخروج ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.local_taxi, color: AppColors.primary, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'اختر نوع السيارة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _onDismissCarSelection,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F2F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // ── صف المسافة ووقت الوصول ──
                          Row(
                            children: [
                              if (_distanceKm > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.straighten, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_distanceKm.toStringAsFixed(1)} كم',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      _tripEtaLabel,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _FareOptionCard(
                            type: TaxiType.tuktuk,
                            price: '$_fareTuktuk د.ع',
                            isSelected: _selectedTaxiType == TaxiType.tuktuk,
                            onTap: () => setState(
                              () => _selectedTaxiType = TaxiType.tuktuk,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _FareOptionCard(
                            type: TaxiType.wazz,
                            price: '$_fareWazz د.ع',
                            isSelected: _selectedTaxiType == TaxiType.wazz,
                            onTap: () => setState(
                              () => _selectedTaxiType = TaxiType.wazz,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _FareOptionCard(
                            type: TaxiType.economic,
                            price: '$_fareEconomic د.ع',
                            isSelected: _selectedTaxiType == TaxiType.economic,
                            onTap: () => setState(
                              () => _selectedTaxiType = TaxiType.economic,
                            ),
                          ),
                          // ── Toggle: ذهاب فقط / ذهاب وعودة ──
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isRoundTrip = false;
                                      _calculateFares();
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isRoundTrip ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(11),
                                        boxShadow: !_isRoundTrip
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.arrow_forward, size: 16, color: !_isRoundTrip ? AppColors.primary : Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('ذهاب فقط',
                                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700,
                                              color: !_isRoundTrip ? AppColors.primary : Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isRoundTrip = true;
                                      _calculateFares();
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isRoundTrip ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(11),
                                        boxShadow: _isRoundTrip
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.replay, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text('ذهاب وعودة',
                                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700,
                                              color: _isRoundTrip ? AppColors.primary : Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Waiting time selector (only for round trip) ──
                          if (_isRoundTrip) ...[
                            SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                itemCount: _waitingOptions.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final min = _waitingOptions[index];
                                  final selected = _waitingMinutes == min;
                                  return GestureDetector(
                                    onTap: () => setState(() => _waitingMinutes = min),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: selected ? AppColors.primary : const Color(0xFFF2F2F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$min دقيقة',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── Route alternatives ──
                          if (_routeAlternatives.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _selectRouteAlternative(0),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedRouteIndex == 0 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                          boxShadow: _selectedRouteIndex == 0
                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                                              : null,
                                        ),
                                        child: Column(
                                          children: [
                                            Text('المسار الأول', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
                                              color: _selectedRouteIndex == 0 ? AppColors.primary : Colors.grey)),
                                            Text('${_distanceKm.toStringAsFixed(1)} كم', style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                                              color: _selectedRouteIndex == 0 ? AppColors.primary : Colors.grey.shade500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _selectRouteAlternative(1),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedRouteIndex == 1 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(9),
                                          boxShadow: _selectedRouteIndex == 1
                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                                              : null,
                                        ),
                                        child: Column(
                                          children: [
                                            Text('المسار الثاني', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
                                              color: _selectedRouteIndex == 1 ? AppColors.accent : Colors.grey)),
                                            if (_routeAlternatives.isNotEmpty)...[const SizedBox(height: 2)],
                                            Text('${(_routeAlternatives.length > 0 ? (_routeAlternatives[0].distanceKm ?? _distanceKm) : _distanceKm).toStringAsFixed(1)} كم',
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: _selectedRouteIndex == 1 ? AppColors.accent : Colors.grey.shade500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          const SizedBox(height: 8),

                          // ── زر "تأكيد وطلب" بتدرج احترافي ──
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: AppColors.accentGradientLinear,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _onConfirmRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'تأكيد وطلب',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  /// الضغط لفترة طويلة على علامة الانطلاق → تفعيل وضع إعادة التحديد
  void _onPickupDragEnd(LatLng latlng) {
    setState(() => _isSettingPickupByTap = true);
  }

  /// الضغط لفترة طويلة على علامة الوصول → تفعيل وضع إعادة التحديد
  void _onDropoffDragEnd(LatLng latlng) {
    setState(() => _isSettingPickupByTap = false);
  }

  /// عند النقر على الخريطة — يحول الإحداثيات إلى عنوان عبر Mapbox Reverse Geocoding
  void _onMapTapped(LatLng latlng) async {
    if (_isSettingPickupByTap) {
      // تعيين موقع الانطلاق
      final address = await _reverseGeocode(latlng);
      setState(() {
        _pickupController.text = address;
        _pickupCoord = latlng;
        _dropoffCoord = null;
        _routePoints = null;
        _routeDurationSeconds = null;
        _distanceKm = 0;
      });
      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(latlng.latitude, latlng.longitude),
          15.0,
        ),
      );
      // تحويل إلى حقل الوصول
      setState(() => _isSettingPickupByTap = false);
    } else {
      // تعيين موقع الوصول
      final address = await _reverseGeocode(latlng);
      setState(() {
        _dropoffController.text = address;
        _dropoffCoord = latlng;
      });
      // حساب المسار
      if (_pickupCoord != null) {
        _fetchRoute(_pickupCoord!, latlng);
      }
      setState(() => _isSettingPickupByTap = true);
    }
  }

  /// الحصول على موقع الهاتف الحالي وتعيينه كنقطة انطلاق
  Future<void> _getCurrentLocation({bool focusDropoffOnSuccess = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل خدمات الموقع')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض الإذن، لا يمكن الحصول على الموقع')),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إذن الموقع مرفوض نهائياً. الرجاء تفعيله من الإعدادات')),
        );
      }
      return;
    }

    setState(() => _isGettingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      final latlng = LatLng(position.latitude, position.longitude);
      final address = await _reverseGeocode(latlng);
      if (mounted) {
        setState(() {
          _pickupController.text = address;
          _pickupCoord = latlng;
          _dropoffCoord = null;
          _routePoints = null;
          _routeDurationSeconds = null;
          _distanceKm = 0;
          _isSettingPickupByTap = false;
        });
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(latlng.latitude, latlng.longitude),
            15.0,
          ),
        );
        if (focusDropoffOnSuccess) {
          _dropoffFocus.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد موقعك. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  /// تحويل الإحداثيات إلى عنوان نصي (Google Geocoding).
  Future<String> _reverseGeocode(LatLng latlng) =>
      TaxiPlacesService.reverseGeocode(latlng);

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    FocusNode? focusNode,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: const TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textSecondary,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: controller.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                controller.clear();
                                FocusScope.of(context).unfocus();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripStopDraft {
  final TextEditingController controller = TextEditingController();
  LatLng? coord;

  void dispose() => controller.dispose();
}

class _ActiveTripBanner extends StatelessWidget {
  final TaxiRequest request;
  final VoidCallback onTrack;
  final VoidCallback? onOpenOrders;

  const _ActiveTripBanner({
    required this.request,
    required this.onTrack,
    this.onOpenOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.isPickedUp
                      ? 'رحلتك جارية الآن'
                      : '${TaxiLabels.theCaptain} قبل طلبك',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (request.hasAssignedDriver) ...[
            TaxiCustomerContactSection(
              requestId: request.id,
              driverName: request.driverName ?? TaxiLabels.theCaptain,
              driverPhone: request.driverPhone,
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.map_rounded, color: Colors.white),
              label: const Text(
                'تتبع ${TaxiLabels.theCaptain}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (request.canCustomerCancel || request.canCustomerCompleteTrip) ...[
            const SizedBox(height: 10),
            TaxiCustomerTripActions(request: request),
          ],
          if (onOpenOrders != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onOpenOrders,
              child: const Text(
                'فتح طلبي الحالي',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingTripBanner extends StatelessWidget {
  final VoidCallback onOpenWaiting;

  const _PendingTripBanner({required this.onOpenWaiting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top, color: AppColors.accent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لديك طلب قيد البحث عن ${TaxiLabels.captain}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onOpenWaiting,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'عرض شاشة الانتظار',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر رجوع — بدون خلفية
class _TaxiBackButton extends StatelessWidget {
  const _TaxiBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 28,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _FareOptionCard extends StatelessWidget {
  final TaxiType type;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  const _FareOptionCard({
    required this.type,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCFC4C5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            TaxiTypeImage(type: type, width: 64, height: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.labelAr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
