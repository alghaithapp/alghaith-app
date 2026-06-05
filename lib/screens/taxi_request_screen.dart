import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';

class TaxiRequestScreen extends StatefulWidget {
  /// عند الدخول من «طلب سيارة» — معرّف نوع المركبة (car_4seat، car_truck، …).
  final String? initialVehicleTypeId;

  const TaxiRequestScreen({super.key, this.initialVehicleTypeId});

  static const bool isComingSoon = true;

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  static const double _defaultDistanceKm = 0.0;
  static final Position _defaultMapCenter = Position(44.3661, 33.3152);
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  Timer? _distanceDebounce;
  double _estimatedDistanceKm = _defaultDistanceKm;
  bool _isCalculatingDistance = false;
  Position _mapCenter = _defaultMapCenter;
  int _mapRefreshSeed = 0;
  Position? _pickupPosition;
  Position? _dropoffPosition;
  List<Position> _routePolyline = const [];

  late String _selectedVehicleId;
  String _selectedPayment = 'cash';
  bool _showDrivers = false;
  bool _shareWithFamily = false;
  bool _scheduleRide = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = _mapInitialVehicle(widget.initialVehicleTypeId);
    if (TaxiRequestScreen.isComingSoon) return;
    _pickupController.addListener(_scheduleDistanceUpdate);
    _dropoffController.addListener(_scheduleDistanceUpdate);
    _scheduleDistanceUpdate();
  }

  @override
  void dispose() {
    _distanceDebounce?.cancel();
    _pickupController.removeListener(_scheduleDistanceUpdate);
    _dropoffController.removeListener(_scheduleDistanceUpdate);
    _pickupController.dispose();
    _dropoffController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _scheduleDistanceUpdate() {
    _distanceDebounce?.cancel();
    _distanceDebounce = Timer(
      const Duration(milliseconds: 600),
      _updateDistanceFromAddresses,
    );
  }

  Future<void> _updateDistanceFromAddresses() async {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      if (mounted) {
        setState(() {
          if (pickup.isEmpty) {
            _pickupPosition = null;
          }
          if (dropoff.isEmpty) {
            _dropoffPosition = null;
          }
          _routePolyline = const [];
          _mapRefreshSeed++;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isCalculatingDistance = true);
    }

    try {
      final from = await _resolveCoordinates('$pickup، العراق');
      final to = await _resolveCoordinates('$dropoff، العراق');
      if (from != null && to != null && mounted) {
        final pickupPos = Position(from.longitude, from.latitude);
        final dropoffPos = Position(to.longitude, to.latitude);
        final centerPos = Position(
          (pickupPos.lng + dropoffPos.lng) / 2,
          (pickupPos.lat + dropoffPos.lat) / 2,
        );
        final routePoints = await _fetchRoutePolyline(
          from: pickupPos,
          to: dropoffPos,
        );
        setState(() {
          _pickupPosition = pickupPos;
          _dropoffPosition = dropoffPos;
          _routePolyline = routePoints;
          _mapCenter = centerPos;
          _mapRefreshSeed++;
        });
      }

      final roadDistanceKm = await _fetchRoadDistanceKmFromBackend(
        pickupAddress: pickup,
        dropoffAddress: dropoff,
      );
      final fallbackDistanceKm = from == null || to == null
          ? null
          : _haversineDistanceKm(
              from.latitude,
              from.longitude,
              to.latitude,
              to.longitude,
            );
      final distanceKm = roadDistanceKm ?? fallbackDistanceKm;
      if (distanceKm == null) return;
      final normalizedDistance = distanceKm <= 0 ? 0.5 : distanceKm;

      if (!mounted) return;
      setState(() => _estimatedDistanceKm = normalizedDistance);
    } catch (_) {
      // نحتفظ بآخر قيمة صالحة بدل إيقاف التجربة على المستخدم.
    } finally {
      if (mounted) {
        setState(() => _isCalculatingDistance = false);
      }
    }
  }

  Future<double?> _fetchRoadDistanceKmFromBackend({
    required String pickupAddress,
    required String dropoffAddress,
  }) async {
    final baseUrl = AppConfig.normalizedDatabaseUrl;
    if (baseUrl.isEmpty) return null;

    try {
      final uri = Uri.parse('$baseUrl/maps/route-distance');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pickupAddress': pickupAddress,
              'dropoffAddress': dropoffAddress,
            }),
          )
          .timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) return null;
      final distanceKm = (payload['distanceKm'] as num?)?.toDouble();
      return distanceKm;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _calculateStraightDistanceKm({
    required String pickupAddress,
    required String dropoffAddress,
  }) async {
    final from = await _resolveCoordinates('$pickupAddress، العراق');
    final to = await _resolveCoordinates('$dropoffAddress، العراق');
    if (from == null || to == null) return null;
    return _haversineDistanceKm(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  Future<_GeoPoint?> _resolveCoordinates(String query) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'format': 'json',
        'limit': '1',
        'q': query,
      },
    );
    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'alghaith-app/1.0 taxi distance lookup'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map) return null;
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    return _GeoPoint(lat, lon);
  }

  double _haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double value) => value * math.pi / 180;

  Future<List<Position>> _fetchRoutePolyline({
    required Position from,
    required Position to,
  }) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return [from, to];
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?alternatives=false&overview=full&geometries=geojson&language=ar&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [from, to];
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['routes'] is! List) return [from, to];
      final routes = data['routes'] as List;
      if (routes.isEmpty || routes.first is! Map) return [from, to];
      final geometry = (routes.first as Map)['geometry'];
      if (geometry is! Map || geometry['coordinates'] is! List) {
        return [from, to];
      }
      final coordinates = geometry['coordinates'] as List;
      final points = coordinates
          .whereType<List>()
          .map((coord) {
            if (coord.length < 2) return null;
            final lng = (coord[0] as num?)?.toDouble();
            final lat = (coord[1] as num?)?.toDouble();
            if (lng == null || lat == null) return null;
            return Position(lng, lat);
          })
          .whereType<Position>()
          .toList();
      if (points.length < 2) return [from, to];
      return points;
    } catch (_) {
      return [from, to];
    }
  }

  Future<List<String>> _fetchAddressSuggestions(String query) async {
    final input = query.trim();
    if (input.length < 2) return const [];
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(input)}.json'
        '?language=ar&country=iq&limit=5&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['features'] is! List) return const [];
      final features = (data['features'] as List)
          .whereType<Map>()
          .map((item) => item['place_name']?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
      return features;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _resolveAddressFromCoordinates(double lat, double lng) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?language=ar&country=iq&limit=1&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is! Map || data['features'] is! List) return null;
      final features = data['features'] as List;
      if (features.isEmpty || features.first is! Map) return null;
      return (features.first['place_name']?.toString() ?? '').trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تفعيل خدمة الموقع في الهاتف.')),
      );
      return;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض إذن الموقع، لا يمكن تحديد موقعك.')),
      );
      return;
    }

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final address = await _resolveAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final label = (address == null || address.isEmpty)
          ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
          : address;
      if (!mounted) return;
      setState(() {
        _pickupController.text = label;
        _pickupController.selection = TextSelection.fromPosition(
          TextPosition(offset: _pickupController.text.length),
        );
        _pickupPosition = Position(position.longitude, position.latitude);
        _mapCenter = Position(position.longitude, position.latitude);
        _mapRefreshSeed++;
      });
      unawaited(_updateDistanceFromAddresses());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة موقعك الحالي حالياً.')),
      );
    }
  }

  String _estimatedArrivalLabel(double distanceKm) {
    if (distanceKm <= 0) return '--';
    final minMinutes = math.max(3, (distanceKm * 2.2).round());
    final maxMinutes = math.max(minMinutes + 2, (distanceKm * 3.4).round());
    return '$minMinutes-$maxMinutes';
  }

  Future<void> _handleCustomerCancel(
    BuildContext context,
    AppProvider provider,
    TaxiRequest request,
  ) async {
    final isPending = request.statusKey == 'pending' || request.statusKey == 'new';
    final isAccepted = request.statusKey == 'accepted';
    if (!isPending && !isAccepted) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(isPending ? 'إلغاء الطلب' : 'طلب إلغاء الرحلة'),
        content: Text(
          isPending
              ? 'سيتم إلغاء الطلب مباشرة لأنه لم يتم قبوله بعد.'
              : 'سيتم إرسال طلب إلغاء إلى السائق، ويلزم موافقته على الإلغاء.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final result = provider.cancelTaxiRequestByCustomer(request.id);
    if (!context.mounted) return;

    final message = result == 'cancelled'
        ? 'تم إلغاء الرحلة بنجاح.'
        : result == 'requested'
            ? 'تم إرسال طلب الإلغاء إلى السائق بانتظار موافقته.'
            : 'لا يمكن إلغاء الرحلة في حالتها الحالية.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int _roundTo250(int value) {
    if (value <= 0) return 250;
    return (value / 250).ceil() * 250;
  }

  static String _mapInitialVehicle(String? carRequestTypeId) {
    switch (carRequestTypeId) {
      case 'car_4seat':
        return 'economy_taxi';
      case 'car_truck':
        return 'truck';
      case 'car_bus':
        return 'bus';
      case 'car_starx11':
        return 'starx11';
      default:
        return 'economy_taxi';
    }
  }

  List<_VehicleOption> _vehicleOptions() {
    return [
      _VehicleOption(
        id: 'economy_taxi',
        name: 'تكسي اقتصادي',
        eta: '4 د',
        capacity: '4 مقاعد',
        emoji: '🚕',
        multiplier: 1.0,
      ),
      _VehicleOption(
        id: 'super_taxi',
        name: 'تكسي سوبر',
        eta: '3 د',
        capacity: '4 مقاعد',
        emoji: '🚘',
        multiplier: 1.30,
      ),
      _VehicleOption(
        id: 'truck',
        name: 'سيارة حمل',
        eta: '8 د',
        capacity: 'حمل',
        emoji: '🚚',
        multiplier: 1.85,
      ),
      _VehicleOption(
        id: 'bus',
        name: 'سيارة باص',
        eta: '10 د',
        capacity: 'باص',
        emoji: '🚌',
        multiplier: 2.1,
      ),
      _VehicleOption(
        id: 'starx11',
        name: 'ستاركس 11 نفر',
        eta: '6 د',
        capacity: '11 راكب',
        emoji: '🚐',
        multiplier: 1.75,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final baseFare = AppConfig.calculateTaxiFare(_estimatedDistanceKm);
    final vehicles = _vehicleOptions();
    final selectedVehicle = vehicles.firstWhere(
      (vehicle) => vehicle.id == _selectedVehicleId,
      orElse: () => vehicles.first,
    );
    final estimatedFare = _roundTo250((baseFare * selectedVehicle.multiplier).round());
    final latestTaxiRequest =
        appProvider.taxiRequests.isNotEmpty ? appProvider.taxiRequests.first : null;

    return _wrapComingSoon(
      Directionality(
        textDirection: TextDirection.rtl,
        child: CupertinoPageScaffold(
          backgroundColor: const Color(0xFF030B1A),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _TaxiMapBackdrop(
                    pickupAddress: _pickupController.text.trim(),
                    dropoffAddress: _dropoffController.text.trim(),
                    estimatedDistanceKm: _estimatedDistanceKm,
                    mapCenter: _mapCenter,
                    mapRefreshSeed: _mapRefreshSeed,
                    pickupPosition: _pickupPosition,
                    dropoffPosition: _dropoffPosition,
                    routePolyline: _routePolyline,
                  ),
                ),
              Positioned(
                top: 8,
                left: 14,
                right: 14,
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    _MapTopCircleButton(
                      icon: CupertinoIcons.bars,
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 116,
                right: 14,
                child: _MapTopCircleButton(
                  icon: CupertinoIcons.bell_fill,
                  onTap: () {},
                ),
              ),
              Positioned(
                top: 64,
                left: 14,
                right: 14,
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _GlassLocationCard(
                        title: 'نقطة الانطلاق',
                        value: _pickupController.text.trim().isEmpty
                            ? 'اضغط لإدخال الموقع'
                            : _pickupController.text.trim(),
                        glowColor: const Color(0xFF00C8FF),
                        icon: CupertinoIcons.circle_fill,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GlassLocationCard(
                        title: 'الوجهة',
                        value: _dropoffController.text.trim().isEmpty
                            ? 'أدخل الوجهة'
                            : _dropoffController.text.trim(),
                        glowColor: const Color(0xFFF5A01D),
                        icon: CupertinoIcons.location_solid,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                top: 190,
                child: Column(
                  children: [
                    _MapQuickActionButton(
                      icon: CupertinoIcons.location_fill,
                      label: 'موقعي',
                      onTap: _useCurrentLocation,
                    ),
                    const SizedBox(height: 10),
                    _MapQuickActionButton(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      label: 'SOS',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.50,
                minChildSize: 0.44,
                maxChildSize: 0.82,
                snap: true,
                snapSizes: const [0.50, 0.66, 0.82],
                builder: (context, controller) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD2D6E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PremiumSearchFields(
                          pickupController: _pickupController,
                          dropoffController: _dropoffController,
                          onQuerySuggestions: _fetchAddressSuggestions,
                          onPickupSuggestionSelected: (value) async {
                            final point = await _resolveCoordinates('$value، العراق');
                            if (point == null || !mounted) {
                              _scheduleDistanceUpdate();
                              return;
                            }
                            setState(() {
                              _pickupPosition = Position(point.longitude, point.latitude);
                              _mapCenter = Position(point.longitude, point.latitude);
                              _mapRefreshSeed++;
                            });
                            _scheduleDistanceUpdate();
                          },
                          onDropoffSuggestionSelected: (value) async {
                            final point = await _resolveCoordinates('$value، العراق');
                            if (point == null || !mounted) {
                              _scheduleDistanceUpdate();
                              return;
                            }
                            setState(() {
                              _dropoffPosition = Position(point.longitude, point.latitude);
                              _mapRefreshSeed++;
                            });
                            _scheduleDistanceUpdate();
                          },
                        ),
                        const SizedBox(height: 14),
                        _QuickActionsGrid(
                          actions: const ['المنزل', 'العمل', 'المفضلة', 'الرحلات السابقة', 'اختر على الخريطة'],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'اختر نوع المركبة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 146,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: vehicles.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final vehicle = vehicles[index];
                              final isSelected = vehicle.id == _selectedVehicleId;
                              final vehicleFare = _roundTo250((baseFare * vehicle.multiplier).round());
                              return _VehicleCard(
                                option: vehicle,
                                fare: vehicleFare,
                                selected: isSelected,
                                onTap: () => setState(() => _selectedVehicleId = vehicle.id),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TripInfoPanel(
                          isCalculatingDistance: _isCalculatingDistance,
                          distanceKm: _estimatedDistanceKm,
                          etaLabel: _estimatedArrivalLabel(_estimatedDistanceKm),
                          fareIqd: estimatedFare,
                        ),
                        const SizedBox(height: 14),
                        _ExtraOptionsPanel(
                          selectedPayment: _selectedPayment,
                          showDrivers: _showDrivers,
                          shareWithFamily: _shareWithFamily,
                          scheduleRide: _scheduleRide,
                          onPaymentSelected: (value) => setState(() => _selectedPayment = value),
                          onShowDriversChanged: (value) => setState(() => _showDrivers = value),
                          onShareWithFamilyChanged: (value) =>
                              setState(() => _shareWithFamily = value),
                          onScheduleRideChanged: (value) =>
                              setState(() => _scheduleRide = value),
                          noteController: _noteController,
                        ),
                        if (latestTaxiRequest != null) ...[
                          const SizedBox(height: 14),
                          _LiveStatusBanner(request: latestTaxiRequest),
                          const SizedBox(height: 10),
                          _TaxiStatusCard(request: latestTaxiRequest),
                          const SizedBox(height: 10),
                          _CustomerTaxiActionsCard(
                            request: latestTaxiRequest,
                            onCancelPressed: () => _handleCustomerCancel(
                              context,
                              appProvider,
                              latestTaxiRequest,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _PremiumRequestButton(
                          onPressed: () => _submitTaxiRequest(
                            context: context,
                            appProvider: appProvider,
                            selectedVehicle: selectedVehicle,
                            estimatedFare: estimatedFare,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _wrapComingSoon(Widget child) {
    if (!TaxiRequestScreen.isComingSoon) return child;

    return Stack(
      children: [
        IgnorePointer(child: child),
        const Positioned.fill(child: _TaxiComingSoonOverlay()),
      ],
    );
  }

  void _submitTaxiRequest({
    required BuildContext context,
    required AppProvider appProvider,
    required _VehicleOption selectedVehicle,
    required int estimatedFare,
  }) {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال نقطة الانطلاق والوجهة أولاً.'),
        ),
      );
      return;
    }

    appProvider.addTaxiRequest(
      TaxiRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        requestNumber:
            'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        requestedAtAr: 'اليوم، ${TimeOfDay.now().format(context)}',
        requestedAtEn: 'Today, ${TimeOfDay.now().format(context)}',
        customerNameAr: appProvider.customerName,
        customerNameEn: appProvider.customerName,
        customerPhone: appProvider.customerPhone,
        pickupAddressAr: pickup,
        pickupAddressEn: pickup,
        dropoffAddressAr: dropoff,
        dropoffAddressEn: dropoff,
        rideTypeId: selectedVehicle.id,
        rideTypeAr: selectedVehicle.name,
        rideTypeEn: selectedVehicle.name,
        fare: estimatedFare,
        statusKey: 'pending',
        statusAr: 'بانتظار السائق',
        statusEn: 'Waiting for driver',
        noteAr: _noteController.text.trim(),
        noteEn: _noteController.text.trim(),
        paymentMethodAr: _selectedPayment == 'cash'
            ? 'نقدًا'
            : _selectedPayment == 'wallet'
                ? 'محفظة'
                : 'بطاقة',
        paymentMethodEn: _selectedPayment == 'cash'
            ? 'Cash'
            : _selectedPayment == 'wallet'
                ? 'Wallet'
                : 'Card',
      ),
    );

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم إرسال الطلب'),
        content: const Text('تم استلام طلبك وجارٍ البحث عن أقرب سائق.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسنًا'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _GeoPoint {
  final double latitude;
  final double longitude;

  const _GeoPoint(this.latitude, this.longitude);
}

class _TaxiComingSoonOverlay extends StatelessWidget {
  const _TaxiComingSoonOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _MapTopCircleButton(
                  icon: CupertinoIcons.back,
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_taxi_rounded,
                        size: 38,
                        color: Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'قريباً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'خدمة طلب التكسي قيد التطوير\nستتوفر قريباً في تطبيق الغيث',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiMapBackdrop extends StatefulWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final double estimatedDistanceKm;
  final Position mapCenter;
  final int mapRefreshSeed;
  final Position? pickupPosition;
  final Position? dropoffPosition;
  final List<Position> routePolyline;

  const _TaxiMapBackdrop({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.estimatedDistanceKm,
    required this.mapCenter,
    required this.mapRefreshSeed,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.routePolyline,
  });

  @override
  State<_TaxiMapBackdrop> createState() => _TaxiMapBackdropState();
}

class _TaxiMapBackdropState extends State<_TaxiMapBackdrop> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;
  PolylineAnnotationManager? _polylineManager;
  bool get _hasMapboxToken => AppConfig.isMapboxConfigured;

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    try {
      _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
      _polylineManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      await _syncRouteAnnotations();
    } catch (_) {}
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    // محاولة تعريب طبقة basemap في Mapbox Standard.
    try {
      await _mapboxMap?.style
          .setStyleImportConfigProperty('basemap', 'language', 'ar');
    } catch (_) {
      // بعض الأنماط لا تدعم هذا الإعداد؛ نكمل بدون كسر الشاشة.
    }
    await _syncRouteAnnotations();
    await _setBestCamera();
  }

  @override
  void didUpdateWidget(covariant _TaxiMapBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.pickupPosition != widget.pickupPosition ||
        oldWidget.dropoffPosition != widget.dropoffPosition ||
        oldWidget.routePolyline != widget.routePolyline ||
        oldWidget.mapCenter != widget.mapCenter ||
        oldWidget.mapRefreshSeed != widget.mapRefreshSeed;
    if (changed) {
      unawaited(_syncRouteAnnotations());
      unawaited(_setBestCamera());
    }
  }

  Future<void> _setBestCamera() async {
    final map = _mapboxMap;
    if (map == null) return;
    final pickup = widget.pickupPosition;
    final dropoff = widget.dropoffPosition;
    if (pickup == null || dropoff == null) {
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: widget.mapCenter),
          zoom: 13.2,
          pitch: 55,
          bearing: 18,
        ),
      );
      return;
    }
    final latDiff = (pickup.lat - dropoff.lat).abs();
    final lngDiff = (pickup.lng - dropoff.lng).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    final zoom = maxDiff < 0.01
        ? 14.4
        : maxDiff < 0.03
            ? 13.7
            : maxDiff < 0.07
                ? 12.7
                : maxDiff < 0.15
                    ? 11.9
                    : 10.8;
    final center = Position(
      (pickup.lng + dropoff.lng) / 2,
      (pickup.lat + dropoff.lat) / 2,
    );
    await map.setCamera(
      CameraOptions(
        center: Point(coordinates: center),
        zoom: zoom,
        pitch: 52,
        bearing: 14,
      ),
    );
  }

  Future<void> _syncRouteAnnotations() async {
    final circles = _circleManager;
    final polyline = _polylineManager;
    if (circles == null || polyline == null) return;
    try {
      await circles.deleteAll();
      await polyline.deleteAll();

      final route = widget.routePolyline;
      if (route.length >= 2) {
        await polyline.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: route),
            lineColor: const Color(0x6600E5FF).value,
            lineWidth: 10,
            lineOpacity: 0.55,
          ),
        );
        await polyline.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: route),
            lineColor: const Color(0xFF00E5FF).value,
            lineWidth: 5.5,
            lineOpacity: 0.95,
          ),
        );
      }

      final pickup = widget.pickupPosition;
      if (pickup != null) {
        await circles.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: pickup),
            circleColor: const Color(0x5527C2FF).value,
            circleRadius: 15,
            circleStrokeColor: const Color(0x3327C2FF).value,
            circleStrokeWidth: 1.8,
          ),
        );
        await circles.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: pickup),
            circleColor: const Color(0xFF16B7FF).value,
            circleRadius: 7.5,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }

      final dropoff = widget.dropoffPosition;
      if (dropoff != null) {
        await circles.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: dropoff),
            circleColor: const Color(0x55E60012).value,
            circleRadius: 15,
            circleStrokeColor: const Color(0x33E60012).value,
            circleStrokeWidth: 1.8,
          ),
        );
        await circles.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: dropoff),
            circleColor: const Color(0xFFF5A01D).value,
            circleRadius: 7.5,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pickupAddress = widget.pickupAddress;
    final dropoffAddress = widget.dropoffAddress;
    final estimatedDistanceKm = widget.estimatedDistanceKm;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _hasMapboxToken
                ? MapWidget(
                    key: ValueKey('taxi-live-map-${widget.mapRefreshSeed}'),
                    styleUri: 'mapbox://styles/mapbox/navigation-night-v1',
                    cameraOptions: CameraOptions(
                      center: Point(coordinates: widget.mapCenter),
                      zoom: 13.2,
                      pitch: 55,
                      bearing: 16,
                    ),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedListener: _onStyleLoaded,
                  )
                : CustomPaint(painter: _MapPatternPainter()),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: _MovingVehiclesOverlay(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 200,
            child: _FloatingTag(
              title: pickupAddress.isEmpty ? 'حدد الانطلاق' : 'الانطلاق جاهز',
              color: const Color(0xFF16B7FF),
            ),
          ),
          Positioned(
            right: 16,
            top: 246,
            child: _FloatingTag(
              title: dropoffAddress.isEmpty
                  ? 'حدد الوجهة'
                  : '${estimatedDistanceKm.toStringAsFixed(1)} كم',
              color: const Color(0xFFF5A01D),
            ),
          ),
          if (!_hasMapboxToken)
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'أضف MAPBOX_PUBLIC_TOKEN لتفعيل الخريطة الحية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverlayLocationField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color color;
  final Future<List<String>> Function(String query) onQuerySuggestions;
  final Future<void> Function(String value)? onSuggestionSelected;

  const _OverlayLocationField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onQuerySuggestions,
    this.onSuggestionSelected,
  });

  @override
  State<_OverlayLocationField> createState() => _OverlayLocationFieldState();
}

class _OverlayLocationFieldState extends State<_OverlayLocationField> {
  Timer? _debounce;
  List<String> _suggestions = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    _debounce?.cancel();
    final value = widget.controller.text.trim();
    if (value.length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      setState(() => _loading = true);
      final results = await widget.onQuerySuggestions(value);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = results;
      });
    });
  }

  void _pickSuggestion(String value) {
    widget.controller.text = value;
    widget.controller.selection =
        TextSelection.fromPosition(TextPosition(offset: value.length));
    setState(() => _suggestions = const []);
    if (widget.onSuggestionSelected != null) {
      unawaited(widget.onSuggestionSelected!(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF4F6FB),
            prefixIcon: Icon(widget.icon, color: widget.color, size: 18),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9EAF0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.take(4).length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEFEFF4)),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(CupertinoIcons.location_solid, size: 16),
                  title: Text(
                    suggestion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  onTap: () => _pickSuggestion(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MapTopCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapTopCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.24),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _MapQuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapQuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      minSize: 0,
      padding: EdgeInsets.zero,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xCC12223B), Color(0xCC060A18)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassLocationCard extends StatelessWidget {
  final String title;
  final String value;
  final Color glowColor;
  final IconData icon;

  const _GlassLocationCard({
    required this.title,
    required this.value,
    required this.glowColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.2),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSearchFields extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final Future<List<String>> Function(String query) onQuerySuggestions;
  final Future<void> Function(String value)? onPickupSuggestionSelected;
  final Future<void> Function(String value)? onDropoffSuggestionSelected;

  const _PremiumSearchFields({
    required this.pickupController,
    required this.dropoffController,
    required this.onQuerySuggestions,
    required this.onPickupSuggestionSelected,
    required this.onDropoffSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _OverlayLocationField(
            controller: pickupController,
            hint: 'من أين ستنطلق؟',
            icon: CupertinoIcons.circle_fill,
            color: const Color(0xFF16B7FF),
            onQuerySuggestions: onQuerySuggestions,
            onSuggestionSelected: onPickupSuggestionSelected,
          ),
          const SizedBox(height: 10),
          _OverlayLocationField(
            controller: dropoffController,
            hint: 'إلى أين وجهتك؟',
            icon: CupertinoIcons.location_solid,
            color: const Color(0xFFF5A01D),
            onQuerySuggestions: onQuerySuggestions,
            onSuggestionSelected: onDropoffSuggestionSelected,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final List<String> actions;

  const _QuickActionsGrid({
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (action) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7EAF3)),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final _VehicleOption option;
  final int fare;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.option,
    required this.fare,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minSize: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 174,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFF5A01D) : const Color(0xFFE8ECF5),
            width: selected ? 1.7 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x33E60012)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: selected ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(option.emoji, style: const TextStyle(fontSize: 23)),
                ),
                const Spacer(),
                if (selected)
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: Color(0xFFF5A01D),
                    size: 19,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              option.name,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${option.eta} | ${option.capacity}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${fare.toPrice()} د.ع',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Color(0xFFF5A01D),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInfoPanel extends StatelessWidget {
  final bool isCalculatingDistance;
  final double distanceKm;
  final String etaLabel;
  final int fareIqd;

  const _TripInfoPanel({
    required this.isCalculatingDistance,
    required this.distanceKm,
    required this.etaLabel,
    required this.fareIqd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TripInfoCell(
              title: 'المسافة',
              value: isCalculatingDistance ? 'جاري...' : '${distanceKm.toStringAsFixed(1)} كم',
              icon: CupertinoIcons.map_fill,
            ),
          ),
          Expanded(
            child: _TripInfoCell(
              title: 'وقت الوصول',
              value: etaLabel == '--' ? '--' : '$etaLabel دقيقة',
              icon: CupertinoIcons.clock_fill,
            ),
          ),
          Expanded(
            child: _TripInfoCell(
              title: 'الأجرة',
              value: '${fareIqd.toPrice()} د.ع',
              icon: CupertinoIcons.money_dollar_circle_fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripInfoCell extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TripInfoCell({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF344760)),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ExtraOptionsPanel extends StatelessWidget {
  final String selectedPayment;
  final bool showDrivers;
  final bool shareWithFamily;
  final bool scheduleRide;
  final ValueChanged<String> onPaymentSelected;
  final ValueChanged<bool> onShowDriversChanged;
  final ValueChanged<bool> onShareWithFamilyChanged;
  final ValueChanged<bool> onScheduleRideChanged;
  final TextEditingController noteController;

  const _ExtraOptionsPanel({
    required this.selectedPayment,
    required this.showDrivers,
    required this.shareWithFamily,
    required this.scheduleRide,
    required this.onPaymentSelected,
    required this.onShowDriversChanged,
    required this.onShareWithFamilyChanged,
    required this.onScheduleRideChanged,
    required this.noteController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallOptionChip(
                label: 'الدفع كاش',
                selected: selectedPayment == 'cash',
                onTap: () => onPaymentSelected('cash'),
              ),
              _SmallOptionChip(
                label: 'عرض السائقين',
                selected: showDrivers,
                onTap: () => onShowDriversChanged(!showDrivers),
              ),
              _SmallOptionChip(
                label: 'مشاركة الرحلة مع العائلة',
                selected: shareWithFamily,
                onTap: () => onShareWithFamilyChanged(!shareWithFamily),
              ),
              _SmallOptionChip(
                label: 'جدولة رحلة',
                selected: scheduleRide,
                onTap: () => onScheduleRideChanged(!scheduleRide),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: noteController,
            maxLines: 2,
            textDirection: TextDirection.rtl,
            placeholder: 'ملاحظة للسائق (اختياري)',
            placeholderStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6EAF3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1AE60012) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFF5A01D) : const Color(0xFFE4E9F2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFFF5A01D) : const Color(0xFF33435A),
          ),
        ),
      ),
    );
  }
}

class _PremiumRequestButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PremiumRequestButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF2D37), Color(0xFFF5A01D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66E60012),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: CupertinoButton(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Text(
          'اطلب الآن',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _MovingVehiclesOverlay extends StatefulWidget {
  const _MovingVehiclesOverlay();

  @override
  State<_MovingVehiclesOverlay> createState() => _MovingVehiclesOverlayState();
}

class _MovingVehiclesOverlayState extends State<_MovingVehiclesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          children: [
            Positioned(
              left: 60 + (18 * t),
              top: 145 + (8 * t),
              child: const _TinyVehicleDot(),
            ),
            Positioned(
              right: 70 + (14 * (1 - t)),
              top: 210 + (10 * t),
              child: const _TinyVehicleDot(),
            ),
            Positioned(
              left: 120 + (12 * (1 - t)),
              top: 260 + (6 * t),
              child: const _TinyVehicleDot(),
            ),
          ],
        );
      },
    );
  }
}

class _TinyVehicleDot extends StatelessWidget {
  const _TinyVehicleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF59D),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x88FFF59D), blurRadius: 10, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final double estimatedDistanceKm;

  const _MapPreviewCard({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.estimatedDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPatternPainter(),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              child: _FloatingTag(
                title: pickupAddress.isEmpty ? 'أدخل نقطة الانطلاق' : 'الانطلاق جاهز',
                color: Colors.green,
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: _FloatingTag(
                title: dropoffAddress.isEmpty
                    ? 'أدخل الوجهة'
                    : 'المسافة ${estimatedDistanceKm.toStringAsFixed(1)} كم',
                color: Colors.orange,
              ),
            ),
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  CupertinoIcons.location_solid,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const Positioned(
              left: 32,
              bottom: 38,
              child: _MapPin(color: Colors.redAccent, label: 'A'),
            ),
            const Positioned(
              right: 38,
              top: 58,
              child: _MapPin(color: Colors.green, label: 'B'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final String estimatedTime;
  final String estimatedDistance;
  final int estimatedFare;
  final bool isCalculatingDistance;

  const _QuickStatsRow({
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.estimatedFare,
    this.isCalculatingDistance = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              title: 'وقت الوصول المتوقع',
              value: estimatedTime == '--' ? '--' : '$estimatedTime دقيقة',
              icon: CupertinoIcons.clock_fill,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: _StatBox(
              title: 'المسافة',
              value: isCalculatingDistance
                  ? 'جاري التحديث...'
                  : '$estimatedDistance كم',
              icon: CupertinoIcons.map_fill,
              color: Colors.green,
            ),
          ),
          Expanded(
            child: _StatBox(
              title: 'التكلفة',
              value: '${estimatedFare.toPrice()} د.ع',
              icon: CupertinoIcons.money_dollar_circle_fill,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;

  const _LocationCard({
    required this.pickupController,
    required this.dropoffController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _LocationField(
            label: 'نقطة الانطلاق',
            icon: CupertinoIcons.circle_fill,
            iconColor: Colors.green,
            controller: pickupController,
          ),
          const SizedBox(height: 14),
          _LocationField(
            label: 'الوجهة',
            icon: CupertinoIcons.location_solid,
            iconColor: Colors.redAccent,
            controller: dropoffController,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String selectedPayment;
  final TextEditingController noteController;
  final ValueChanged<String> onPaymentSelected;

  const _PaymentCard({
    required this.selectedPayment,
    required this.noteController,
    required this.onPaymentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طريقة الدفع',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: 'نقدًا',
                  selected: selectedPayment == 'cash',
                  onTap: () => onPaymentSelected('cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: const _SoonChip(
                  label: 'محفظة',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: const _SoonChip(
                  label: 'بطاقة',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ملاحظة للسائق',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: noteController,
            maxLines: 3,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  final String rideName;
  final int fare;
  final String payment;
  final VoidCallback onRequest;

  const _RequestSummaryCard({
    required this.rideName,
    required this.fare,
    required this.payment,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الرحلة',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'الفئة',
            value: rideName,
          ),
          _SummaryRow(
            label: 'الدفع',
            value: _paymentLabel(payment),
          ),
          _SummaryRow(
            label: 'السعر المتوقع',
            value: '${fare.toPrice()} د.ع',
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              onPressed: onRequest,
              child: const Text(
                'اطلب التكسي الآن',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String payment) {
    switch (payment) {
      case 'wallet':
        return 'محفظة';
      case 'card':
        return 'بطاقة';
      default:
        return 'نقدًا';
    }
  }
}

class _CustomerTaxiActionsCard extends StatelessWidget {
  final TaxiRequest request;
  final VoidCallback onCancelPressed;

  const _CustomerTaxiActionsCard({
    required this.request,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canCancelDirectly =
        request.statusKey == 'pending' || request.statusKey == 'new';
    final canRequestCancel = request.statusKey == 'accepted';
    final canCancel = canCancelDirectly || canRequestCancel;

    if (!canCancel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canCancelDirectly
                ? 'يمكنك إلغاء الرحلة الآن لأن الطلب لم يُقبل بعد.'
                : 'يمكنك طلب الإلغاء، وسيصل الطلب للسائق للموافقة.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              onPressed: onCancelPressed,
              child: Text(
                canCancelDirectly ? 'إلغاء الرحلة' : 'طلب إلغاء الرحلة',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiStatusCard extends StatelessWidget {
  final TaxiRequest request;

  const _TaxiStatusCard({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = request.statusKey == 'rejected';
    final isCompleted = request.statusKey == 'completed';
    final isCancelRequested = request.statusKey == 'cancel_requested';
    final isCancelled = request.statusKey == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.car_detailed,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الطلب رقم ${request.requestNumber}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.requestedAtAr,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                text: request.statusAr,
                color: isRejected
                    ? Colors.red
                    : isCancelled
                        ? Colors.green
                    : isCompleted
                        ? Colors.green
                        : Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: isCancelRequested || isCancelled
                ? Text(
                    isCancelRequested
                        ? 'تم إرسال طلب إلغاء الرحلة للسائق، بانتظار موافقته أو رفضه.'
                        : 'تم إلغاء الرحلة بنجاح.',
                    style: TextStyle(
                      color: isCancelled ? Colors.green : Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      fontFamily: 'Cairo',
                    ),
                  )
                : Column(
                    children: [
                      _TaxiTimelineDot(
                        title: 'تم قبول الطلب',
                        subtitle: 'تظهر هذه المرحلة بعد موافقة السائق',
                        color: Colors.blue,
                        icon: CupertinoIcons.checkmark_alt_circle_fill,
                        active: _isTaxiStepReached(request.statusKey, 'accepted'),
                        current: request.statusKey == 'accepted',
                        completed:
                            _isTaxiStepCompleted(request.statusKey, 'accepted'),
                      ),
                      _TaxiTimelineLine(
                        active: _isTaxiStepReached(request.statusKey, 'on_way'),
                      ),
                      _TaxiTimelineDot(
                        title: 'السائق في الطريق',
                        subtitle: 'السيارة متجهة الآن إليك',
                        color: Colors.orange,
                        icon: CupertinoIcons.car_fill,
                        active: _isTaxiStepReached(request.statusKey, 'on_way'),
                        current: request.statusKey == 'on_way',
                        completed:
                            _isTaxiStepCompleted(request.statusKey, 'on_way'),
                      ),
                      _TaxiTimelineLine(
                        active: _isTaxiStepReached(request.statusKey, 'arrived'),
                      ),
                      _TaxiTimelineDot(
                        title: 'وصل للموقع',
                        subtitle: 'وصل السائق إلى نقطة الانطلاق',
                        color: Colors.purple,
                        icon: CupertinoIcons.location_solid,
                        active: _isTaxiStepReached(request.statusKey, 'arrived'),
                        current: request.statusKey == 'arrived',
                        completed:
                            _isTaxiStepCompleted(request.statusKey, 'arrived'),
                      ),
                      _TaxiTimelineLine(
                        active: _isTaxiStepReached(request.statusKey, 'picked_up'),
                      ),
                      _TaxiTimelineDot(
                        title: 'استلام الزبون',
                        subtitle: 'تم استلامك من قبل السائق',
                        color: Colors.teal,
                        icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                        active: _isTaxiStepReached(request.statusKey, 'picked_up'),
                        current: request.statusKey == 'picked_up',
                        completed:
                            _isTaxiStepCompleted(request.statusKey, 'picked_up'),
                      ),
                      _TaxiTimelineLine(
                        active: _isTaxiStepReached(request.statusKey, 'completed'),
                      ),
                      _TaxiTimelineDot(
                        title: 'تم الوصول',
                        subtitle: 'انتهت الرحلة بنجاح',
                        color: Colors.green,
                        icon: CupertinoIcons.check_mark_circled_solid,
                        active: _isTaxiStepReached(request.statusKey, 'completed'),
                        current: isCompleted,
                        completed: isCompleted,
                      ),
                    ],
                  ),
          ),
          if (isRejected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'تم رفض الطلب. يمكنك إنشاء طلب جديد من نفس الصفحة.',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isTaxiStepReached(String statusKey, String stepKey) {
    const order = ['pending', 'accepted', 'on_way', 'arrived', 'picked_up', 'completed'];
    final statusIndex = order.indexOf(statusKey);
    final stepIndex = order.indexOf(stepKey);
    return statusIndex >= stepIndex && stepIndex != -1;
  }

  bool _isTaxiStepCompleted(String statusKey, String stepKey) {
    const order = ['accepted', 'on_way', 'arrived', 'picked_up', 'completed'];
    final statusIndex = order.indexOf(statusKey);
    final stepIndex = order.indexOf(stepKey);
    return statusIndex != -1 && stepIndex != -1 && statusIndex > stepIndex;
  }
}

class _LiveStatusBanner extends StatelessWidget {
  final TaxiRequest request;

  const _LiveStatusBanner({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final details = _liveNoticeFor(request.statusKey);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
              color: Colors.white.withValues(alpha: 0.18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
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
          _StatusBadge(
            text: request.statusAr,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  _LiveNotice _liveNoticeFor(String statusKey) {
    switch (statusKey) {
      case 'accepted':
        return _LiveNotice(
          title: 'تم قبول طلبك',
          subtitle: 'السائق بدأ مراجعة التفاصيل استعدادًا للانطلاق',
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          icon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      case 'on_way':
        return _LiveNotice(
          title: 'السائق في الطريق',
          subtitle: 'تابع الوصول المتوقع إلى موقعك',
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          icon: CupertinoIcons.car_fill,
        );
      case 'arrived':
        return _LiveNotice(
          title: 'وصل للموقع',
          subtitle: 'السائق بانتظارك في نقطة الانطلاق',
          colors: [Colors.purple.shade700, Colors.purple.shade400],
          icon: CupertinoIcons.location_solid,
        );
      case 'picked_up':
        return _LiveNotice(
          title: 'استلام الزبون',
          subtitle: 'بدأت الرحلة فعليًا مع السائق',
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        );
      case 'cancel_requested':
        return _LiveNotice(
          title: 'طلب إلغاء بانتظار السائق',
          subtitle: 'تم إرسال طلب الإلغاء، يرجى انتظار قرار السائق',
          colors: [Colors.orange.shade700, Colors.orange.shade400],
          icon: CupertinoIcons.hourglass,
        );
      case 'cancelled':
        return _LiveNotice(
          title: 'تم إلغاء الرحلة',
          subtitle: 'تمت عملية الإلغاء بنجاح',
          colors: [Colors.green.shade700, Colors.green.shade400],
          icon: CupertinoIcons.check_mark_circled_solid,
        );
      case 'completed':
        return _LiveNotice(
          title: 'تم الوصول',
          subtitle: 'اكتملت الرحلة بنجاح',
          colors: [Colors.green.shade700, Colors.green.shade400],
          icon: CupertinoIcons.check_mark_circled_solid,
        );
      case 'rejected':
        return _LiveNotice(
          title: 'تم رفض الطلب',
          subtitle: 'يمكنك إرسال طلب جديد مباشرة',
          colors: [Colors.red.shade700, Colors.red.shade400],
          icon: CupertinoIcons.xmark_circle_fill,
        );
      default:
        return _LiveNotice(
          title: 'بانتظار السائق',
          subtitle: 'أول سائق متاح سيظهر له طلبك',
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          icon: CupertinoIcons.time,
        );
    }
  }
}

class _LiveNotice {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;

  const _LiveNotice({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });
}

class _TaxiTimelineDot extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool completed;
  final bool current;
  final Color color;
  final IconData icon;

  const _TaxiTimelineDot({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.completed,
    required this.current,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = completed || current ? color : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: active ? 0.12 : 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.2),
          ),
          child: Icon(icon, color: dotColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.black87 : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    height: 1.35,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaxiTimelineLine extends StatelessWidget {
  final bool active;

  const _TaxiTimelineLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 19),
      width: 2,
      height: 16,
      decoration: BoxDecoration(
        color: active ? Colors.orange : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;

  const _LocationField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : const Color(0xFFF2F3F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _SoonChip extends StatelessWidget {
  final String label;

  const _SoonChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'قريباً',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingTag extends StatelessWidget {
  final String title;
  final Color color;

  const _FloatingTag({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;

  const _MapPin({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(
          width: 2,
          height: 18,
          color: color,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white,
                fontSize: emphasize ? 15 : 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (double i = 20; i < size.width; i += 38) {
      canvas.drawLine(Offset(i, 0), Offset(i - 20, size.height), paint);
    }
    for (double y = 30; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VehicleOption {
  final String id;
  final String name;
  final String eta;
  final String capacity;
  final String emoji;
  final double multiplier;

  const _VehicleOption({
    required this.id,
    required this.name,
    required this.eta,
    required this.capacity,
    required this.emoji,
    required this.multiplier,
  });
}

class _RideType {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final Color color;

  _RideType({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.color,
  });
}
