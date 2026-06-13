 import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/data/iraq_neighborhoods.dart';
import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';

/// شاشة طلب التكسي — تصميم احترافي بألوان تطبيق الغيث
/// مع أحياء قضاء الصويرة كخيارات سريعة وزر تحديد الموقع الحالي.
class TaxiRequestScreen extends StatefulWidget {
  final String? initialVehicleTypeId;

  const TaxiRequestScreen({super.key, this.initialVehicleTypeId});

  static const bool isComingSoon = false;

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  // إحداثيات الصويرة كمركز افتراضي
  static const double _defaultLat = 32.9250;
  static const double _defaultLng = 44.7750;
  static final Position _defaultMapCenter = Position(_defaultLng, _defaultLat);

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  Timer? _distanceDebounce;
  double _estimatedDistanceKm = 0.0;
  bool _isCalculatingDistance = false;
  Position _mapCenter = _defaultMapCenter;
  int _mapRefreshSeed = 0;
  Position? _pickupPosition;
  Position? _dropoffPosition;
  List<Position> _routePolyline = const [];
  bool _isLocating = false;

  late String _selectedVehicleId;
  bool _isPickupFocused = true; // أي حقل البحث نشط حالياً

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = _mapInitialVehicle(widget.initialVehicleTypeId);
    _pickupController.addListener(_scheduleDistanceUpdate);
    _dropoffController.addListener(_scheduleDistanceUpdate);
    _pickupFocus.addListener(() => setState(() => _isPickupFocused = true));
    _dropoffFocus.addListener(() => setState(() => _isPickupFocused = false));
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
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    super.dispose();
  }

  void _scheduleDistanceUpdate() {
    _distanceDebounce?.cancel();
    _distanceDebounce = Timer(const Duration(milliseconds: 600), _updateDistanceFromAddresses);
  }

  Future<void> _updateDistanceFromAddresses() async {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      if (mounted) setState(() {
        if (pickup.isEmpty) _pickupPosition = null;
        if (dropoff.isEmpty) _dropoffPosition = null;
        _routePolyline = const [];
        _mapRefreshSeed++;
      });
      return;
    }
    if (mounted) setState(() => _isCalculatingDistance = true);
    try {
      final from = await _resolveCoordinates('$pickup، واسط، العراق');
      final to = await _resolveCoordinates('$dropoff، واسط، العراق');
      if (from != null && to != null && mounted) {
        final pickupPos = Position(from.longitude, from.latitude);
        final dropoffPos = Position(to.longitude, to.latitude);
        final centerPos = Position(
          (pickupPos.lng + dropoffPos.lng) / 2,
          (pickupPos.lat + dropoffPos.lat) / 2,
        );
        final routePoints = await _fetchRoutePolyline(from: pickupPos, to: dropoffPos);
        setState(() {
          _pickupPosition = pickupPos;
          _dropoffPosition = dropoffPos;
          _routePolyline = routePoints;
          _mapCenter = centerPos;
          _mapRefreshSeed++;
        });
      }
      final roadDistanceKm = await _fetchRoadDistanceKmFromBackend(
        pickupAddress: pickup, dropoffAddress: dropoff,
      );
      final fallback = from == null || to == null
          ? null
          : _haversineDistanceKm(from.latitude, from.longitude, to.latitude, to.longitude);
      final distanceKm = roadDistanceKm ?? fallback;
      if (distanceKm != null && mounted) {
        setState(() => _estimatedDistanceKm = distanceKm <= 0 ? 0.5 : distanceKm);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isCalculatingDistance = false);
    }
  }

  Future<double?> _fetchRoadDistanceKmFromBackend({
    required String pickupAddress, required String dropoffAddress,
  }) async {
    final baseUrl = AppConfig.normalizedDatabaseUrl;
    if (baseUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$baseUrl/maps/route-distance');
      final response = await http.post(uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'pickupAddress': pickupAddress, 'dropoffAddress': dropoffAddress}),
      ).timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        return (payload['distanceKm'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

  Future<_GeoPoint?> _resolveCoordinates(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json', 'limit': '1', 'q': query,
      });
      final response = await http.get(uri,
        headers: {'User-Agent': 'alghaith-app/1.0 taxi'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final first = data.first as Map;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) return _GeoPoint(lat, lon);
        }
      }
    } catch (_) {}
    return null;
  }

  double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double v) => v * math.pi / 180;

  Future<List<Position>> _fetchRoutePolyline({required Position from, required Position to}) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return [from, to];
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?alternatives=false&overview=full&geometries=geojson&language=ar&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = (routes.first as Map)['geometry'] as Map?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null) {
            return coords.map((c) => Position(
              (c[0] as num).toDouble(), (c[1] as num).toDouble(),
            )).toList();
          }
        }
      }
    } catch (_) {}
    return [from, to];
  }

  /// تحديد الموقع الحالي وتعيينه كنقطة انطلاق
  Future<void> _useCurrentLocation() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showSnackBar('يرجى تفعيل خدمة الموقع في الهاتف.');
      return;
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) _showSnackBar('تم رفض إذن الموقع، لا يمكن تحديد موقعك.');
      return;
    }
    if (mounted) setState(() => _isLocating = true);
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
      final address = await _resolveAddressFromCoordinates(pos.latitude, pos.longitude);
      final label = (address != null && address.isNotEmpty)
          ? address
          : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      if (mounted) {
        setState(() {
          _pickupController.text = label;
          _pickupPosition = Position(pos.longitude, pos.latitude);
          _mapCenter = Position(pos.longitude, pos.latitude);
          _mapRefreshSeed++;
        });
        _scheduleDistanceUpdate();
      }
    } catch (_) {
      if (mounted) _showSnackBar('تعذر قراءة موقعك الحالي حالياً.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String?> _resolveAddressFromCoordinates(double lat, double lng) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (!token.startsWith('pk.')) return null;
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?language=ar&country=iq&limit=1&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          return (features.first as Map)['place_name']?.toString().trim();
        }
      }
    } catch (_) {}
    return null;
  }

  void _selectNeighborhood(String name) {
    if (_isPickupFocused) {
      _pickupController.text = 'حي $name، الصويرة';
    } else {
      _dropoffController.text = 'حي $name، الصويرة';
    }
    _scheduleDistanceUpdate();
  }

  void _showPreviousTripsModal(List<TaxiRequest> trips) {
    final completed = trips.where((t) => t.statusKey == 'completed').toList();
    if (completed.isEmpty) {
      _showSnackBar('لا توجد رحلات مكتملة سابقة.');
      return;
    }
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('الرحلات السابقة', style: TextStyle(fontFamily: 'Cairo')),
        actions: completed.take(5).map((trip) => CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            setState(() {
              _pickupController.text = trip.pickupAddressAr;
              _dropoffController.text = trip.dropoffAddressAr;
            });
            _scheduleDistanceUpdate();
          },
          child: Text('${trip.pickupAddressAr} ← ${trip.dropoffAddressAr}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _mapInitialVehicle(String? id) =>
      (id == 'car_super' || id == 'super_taxi') ? 'super_taxi' : 'economy_taxi';

  List<_VehicleOption> _vehicleOptions() => [
    const _VehicleOption(id: 'economy_taxi', name: 'تكسي اقتصادي', eta: '4 د', capacity: '4 مقاعد', image: '🚕', multiplier: 1.0),
    const _VehicleOption(id: 'super_taxi', name: 'تكسي سوبر', eta: '3 د', capacity: '4 مقاعد', image: '🚘', multiplier: 1.30),
    const _VehicleOption(id: 'truck', name: 'سيارة حمل', eta: '8 د', capacity: 'حمل', image: '🚚', multiplier: 1.85),
    const _VehicleOption(id: 'bus', name: 'باص ركاب', eta: '10 د', capacity: 'باص', image: '🚌', multiplier: 2.1),
    const _VehicleOption(id: 'starx11', name: 'ستاركس 11', eta: '6 د', capacity: '11 راكب', image: '🚐', multiplier: 1.75),
  ];

  int _roundTo250(int value) => value <= 0 ? 250 : (value / 250).ceil() * 250;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final baseFare = AppConfig.calculateTaxiFare(_estimatedDistanceKm);
    final vehicles = _vehicleOptions();
    final selectedVehicle = vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId, orElse: () => vehicles.first,
    );
    final estimatedFare = _roundTo250((baseFare * selectedVehicle.multiplier).round());
    final hasLocations = _pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty;
    final latestRequest = provider.taxiRequests.isNotEmpty ? provider.taxiRequests.first : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : AppColors.scaffold;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // خريطة Mapbox
              Positioned.fill(
                child: _TaxiMapBackdrop(
                  pickupAddress: _pickupController.text,
                  dropoffAddress: _dropoffController.text,
                  estimatedDistanceKm: _estimatedDistanceKm,
                  mapCenter: _mapCenter,
                  mapRefreshSeed: _mapRefreshSeed,
                  pickupPosition: _pickupPosition,
                  dropoffPosition: _dropoffPosition,
                  routePolyline: _routePolyline,
                ),
              ),

              // زر الرجوع في الأعلى
              Positioned(
                top: 12, right: 14,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.chevron_right, color: AppColors.primary, size: 22),
                  ),
                ),
              ),

              // زر الموقع الحالي + SOS
              Positioned(
                left: 14, top: 60,
                child: Column(
                  children: [
                    _QuickActionButton(
                      icon: _isLocating ? CupertinoIcons.refresh : CupertinoIcons.location_fill,
                      label: 'موقعي',
                      color: AppColors.primary,
                      isLoading: _isLocating,
                      onTap: _useCurrentLocation,
                    ),
                    const SizedBox(height: 10),
                    _QuickActionButton(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      label: 'SOS',
                      color: AppColors.error,
                      onTap: () => _showSnackBar('سيتم الاتصال بالطوارئ قريباً'),
                    ),
                  ],
                ),
              ),

              // الورقة السفلية القابلة للسحب
              DraggableScrollableSheet(
                initialChildSize: hasLocations ? 0.55 : 0.35,
                minChildSize: 0.20,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.35, 0.55, 0.85],
                builder: (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2838) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20, offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      // مقبض السحب
                      Center(
                        child: Container(
                          width: 44, height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[600] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // حقلي البحث — الانطلاق والوجهة
                      _BuildAddressFields(
                        pickupController: _pickupController,
                        dropoffController: _dropoffController,
                        pickupFocus: _pickupFocus,
                        dropoffFocus: _dropoffFocus,
                        onPickupSuggestion: _selectNeighborhood,
                        onDropoffSuggestion: _selectNeighborhood,
                        onPreviousTrips: () => _showPreviousTripsModal(provider.taxiRequests),
                      ),

                      // أحياء الصويرة السريعة
                      if (!hasLocations) ...[
                        const SizedBox(height: 16),
                        _BuildSuwayraNeighborhoods(
                          onSelect: _selectNeighborhood,
                        ),
                      ],

                      // إذا تم إدخال الموقع — عرض المركبات والسعر
                      if (hasLocations) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.car_fill, color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'اختر نوع المركبة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: vehicles.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final v = vehicles[index];
                              final fare = _roundTo250((baseFare * v.multiplier).round());
                              return _VehicleCard(
                                option: v, fare: fare,
                                selected: v.id == _selectedVehicleId,
                                onTap: () => setState(() => _selectedVehicleId = v.id),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ملخص الرحلة
                        _BuildTripSummary(
                          isCalculatingDistance: _isCalculatingDistance,
                          distanceKm: _estimatedDistanceKm,
                          fareIqd: estimatedFare,
                          pickup: _pickupController.text,
                          dropoff: _dropoffController.text,
                        ),
                        const SizedBox(height: 16),

                        // ملاحظة للسائق
                        _BuildNoteField(controller: _noteController, isDark: isDark),
                        const SizedBox(height: 20),

                        // زر طلب التكسي
                        _PremiumRequestButton(
                          onPressed: hasLocations
                              ? () => _submitTaxiRequest(
                                  context: context,
                                  appProvider: provider,
                                  selectedVehicle: selectedVehicle,
                                  estimatedFare: estimatedFare,
                                )
                              : null,
                          rideType: selectedVehicle.name,
                          fare: estimatedFare,
                        ),
                      ],

                      // عرض حالة الطلب إذا كان موجوداً
                      if (latestRequest != null) ...[
                        const SizedBox(height: 16),
                        _LiveStatusBanner(request: latestRequest),
                        const SizedBox(height: 10),
                        _TaxiStatusCard(request: latestRequest),
                        const SizedBox(height: 10),
                        _CustomerTaxiActionsCard(
                          request: latestRequest,
                          onCancelPressed: () => _handleCustomerCancel(context, provider, latestRequest),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCustomerCancel(BuildContext context, AppProvider provider, TaxiRequest request) async {
    final isPending = request.statusKey == 'pending' || request.statusKey == 'new';
    final isAccepted = request.statusKey == 'accepted';
    if (!isPending && !isAccepted) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isPending ? 'إلغاء الطلب' : 'طلب إلغاء الرحلة'),
        content: Text(isPending
            ? 'سيتم إلغاء الطلب مباشرة.'
            : 'سيتم إرسال طلب إلغاء إلى السائق.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await provider.cancelTaxiRequestByCustomer(request.id);
    if (!context.mounted) return;
    _showSnackBar(result == 'cancelled'
        ? 'تم إلغاء الرحلة بنجاح.'
        : result == 'requested'
            ? 'تم إرسال طلب الإلغاء إلى السائق.'
            : 'لا يمكن إلغاء الرحلة في حالتها الحالية.');
  }

  Future<void> _submitTaxiRequest({
    required BuildContext context,
    required AppProvider appProvider,
    required _VehicleOption selectedVehicle,
    required int estimatedFare,
  }) async {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      _showSnackBar('يرجى إدخال نقطة الانطلاق والوجهة.');
      return;
    }
    final request = TaxiRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      requestNumber: 'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      requestedAtAr: 'اليوم، ${TimeOfDay.now().format(context)}',
      requestedAtEn: 'Today',
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
      statusEn: 'Pending',
      noteAr: _noteController.text.trim(),
      noteEn: _noteController.text.trim(),
      paymentMethodAr: 'نقداً',
      paymentMethodEn: 'Cash',
    );
    final saved = await appProvider.addTaxiRequest(request);
    if (!context.mounted) return;
    if (!saved) {
      _showSnackBar('تعذّر إرسال الطلب. تحقق من الاتصال وحاول مجدداً.');
      return;
    }
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('تم إرسال الطلب'),
        content: const Text('✅ تم استلام طلبك وجارٍ البحث عن أقرب سائق.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسنًا', style: TextStyle(color: AppColors.primary)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

// ================== المكونات البصرية ==================

/// أحياء الصويرة السريعة
class _BuildSuwayraNeighborhoods extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _BuildSuwayraNeighborhoods({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_city, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              'أحياء قضاء الصويرة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: IraqNeighborhoods.suwayraNeighborhoods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final name = IraqNeighborhoods.suwayraNeighborhoods[index];
              return GestureDetector(
                onTap: () => onSelect(name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.primaryDark.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: IraqNeighborhoods.suwayraLandmarks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final name = IraqNeighborhoods.suwayraLandmarks[index];
              return GestureDetector(
                onTap: () => onSelect(name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, color: AppColors.accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// حقلي الانطلاق والوجهة
class _BuildAddressFields extends StatelessWidget {
  final TextEditingController pickupController, dropoffController;
  final FocusNode pickupFocus, dropoffFocus;
  final ValueChanged<String> onPickupSuggestion, onDropoffSuggestion;
  final VoidCallback onPreviousTrips;

  const _BuildAddressFields({
    required this.pickupController, required this.dropoffController,
    required this.pickupFocus, required this.dropoffFocus,
    required this.onPickupSuggestion, required this.onDropoffSuggestion,
    required this.onPreviousTrips,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF2A3A4E) : const Color(0xFFF0F4F8);

    return Column(
      children: [
        // حقل الانطلاق
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: pickupFocus.hasFocus
                      ? (isDark ? const Color(0xFF1B2838) : Colors.white)
                      : fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: pickupFocus.hasFocus
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: pickupFocus.hasFocus
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 8)]
                      : null,
                ),
                child: CupertinoTextField(
                  controller: pickupController,
                  focusNode: pickupFocus,
                  placeholder: 'من أين ستنطلق؟',
                  placeholderStyle: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 12, height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0xFF2E7D32), blurRadius: 4)],
                      ),
                    ),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => pickupController.clear(),
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // خط ربط بين الحقلين
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[200],
              ),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.arrow_down, size: 12, color: AppColors.accent),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? Colors.grey[700] : Colors.grey[200],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // حقل الوجهة
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: dropoffFocus.hasFocus
                      ? (isDark ? const Color(0xFF1B2838) : Colors.white)
                      : fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dropoffFocus.hasFocus
                        ? AppColors.accent
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: dropoffFocus.hasFocus
                      ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 8)]
                      : null,
                ),
                child: CupertinoTextField(
                  controller: dropoffController,
                  focusNode: dropoffFocus,
                  placeholder: 'إلى أين وجهتك؟',
                  placeholderStyle: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.flag, size: 14, color: AppColors.accent),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => dropoffController.clear(),
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // زر الرحلات السابقة
            GestureDetector(
              onTap: onPreviousTrips,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(CupertinoIcons.clock, color: AppColors.primary, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ملخص الرحلة — المسافة + الأجرة
class _BuildTripSummary extends StatelessWidget {
  final bool isCalculatingDistance;
  final double distanceKm;
  final int fareIqd;
  final String pickup, dropoff;

  const _BuildTripSummary({
    required this.isCalculatingDistance,
    required this.distanceKm,
    required this.fareIqd,
    required this.pickup,
    required this.dropoff,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A3A4E) : const Color(0xFFF0F7FF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.map_fill, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('المسافة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCalculatingDistance ? 'جاري الحساب...' : '${distanceKm.toStringAsFixed(1)} كم',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.money_dollar_circle_fill, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        const Text('الأجرة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fareIqd.toPrice()} د.ع',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حقل الملاحظة
class _BuildNoteField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  const _BuildNoteField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2A3A4E) : const Color(0xFFF0F4F8);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: 'ملاحظة للسائق (اختياري)',
        placeholderStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[500],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        style: TextStyle(
          fontFamily: 'Cairo', fontSize: 13,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(CupertinoIcons.pencil, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ================== المكونات المكررة مع تحسين الألوان ==================

class _GeoPoint {
  final double latitude, longitude;
  const _GeoPoint(this.latitude, this.longitude);
}

class _TaxiMapBackdrop extends StatefulWidget {
  final String pickupAddress, dropoffAddress;
  final double estimatedDistanceKm;
  final Position mapCenter;
  final int mapRefreshSeed;
  final Position? pickupPosition, dropoffPosition;
  final List<Position> routePolyline;
  const _TaxiMapBackdrop({
    required this.pickupAddress, required this.dropoffAddress,
    required this.estimatedDistanceKm, required this.mapCenter,
    required this.mapRefreshSeed, this.pickupPosition, this.dropoffPosition,
    required this.routePolyline,
  });
  @override State<_TaxiMapBackdrop> createState() => _TaxiMapBackdropState();
}

class _TaxiMapBackdropState extends State<_TaxiMapBackdrop> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles;
  PolylineAnnotationManager? _lines;

  void _onMapCreated(MapboxMap m) async {
    _map = m;
    _circles = await m.annotations.createCircleAnnotationManager();
    _lines = await m.annotations.createPolylineAnnotationManager();
    _updateMap();
  }

  void _updateMap() async {
    if (_map == null) return;
    await _circles?.deleteAll();
    await _lines?.deleteAll();

    if (widget.routePolyline.isNotEmpty) {
      await _lines?.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: widget.routePolyline),
        lineColor: AppColors.accent.value,
        lineWidth: 4,
        lineOpacity: 0.8,
      ));
    }
    if (widget.pickupPosition != null) {
      await _circles?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: widget.pickupPosition!),
        circleColor: const Color(0xFF2E7D32).value,
        circleRadius: 10,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 2,
      ));
    }
    if (widget.dropoffPosition != null) {
      await _circles?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: widget.dropoffPosition!),
        circleColor: AppColors.accent.value,
        circleRadius: 10,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 2,
      ));
    }
    try {
      await _map?.setCamera(CameraOptions(
        center: Point(coordinates: widget.mapCenter),
        zoom: 13, pitch: 0, bearing: 0,
      ));
    } catch (_) {}
  }

  @override
  void didUpdateWidget(old) { super.didUpdateWidget(old); _updateMap(); }

  @override
  Widget build(BuildContext context) => MapWidget(
    styleUri: 'mapbox://styles/mapbox/navigation-day-v1',
    onMapCreated: _onMapCreated,
  );
}

class _VehicleOption {
  final String id, name, eta, capacity, image;
  final double multiplier;
  const _VehicleOption({
    required this.id, required this.name, required this.eta,
    required this.capacity, required this.image, required this.multiplier,
  });
}

class _VehicleCard extends StatelessWidget {
  final _VehicleOption option;
  final int fare;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.option, required this.fare,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF2A3A4E) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 8)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(option.image, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              option.name,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textPrimary),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${fare.toPrice()} د.ع',
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 11,
                fontWeight: FontWeight.w900, color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon, required this.label, required this.color,
    this.isLoading = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? const CupertinoActivityIndicator()
            : Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _PremiumRequestButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String rideType;
  final int fare;

  const _PremiumRequestButton({
    required this.onPressed,
    this.rideType = 'تكسي',
    this.fare = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.car_fill, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'طلب $rideType',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 1, height: 20,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Text(
                '${fare.toPrice()} د.ع',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatusBanner extends StatelessWidget {
  final TaxiRequest request;
  const _LiveStatusBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 6)],
            ),
            child: Center(
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الطلب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  request.statusAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            request.requestNumber,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiStatusCard extends StatelessWidget {
  final TaxiRequest request;
  const _TaxiStatusCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3A4E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.doc_text_fill, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text('تفاصيل الرحلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _tripDetail('رقم الرحلة', request.requestNumber),
              _tripDetail('طريقة الدفع', request.paymentMethodAr),
              _tripDetail('الأجرة', '${request.fare.toPrice()} د.ع'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripDetail(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _CustomerTaxiActionsCard extends StatelessWidget {
  final TaxiRequest request;
  final VoidCallback onCancelPressed;
  const _CustomerTaxiActionsCard({required this.request, required this.onCancelPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        onPressed: onCancelPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14),
            color: AppColors.error.withValues(alpha: 0.05),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.delete_solid, color: AppColors.error, size: 16),
              SizedBox(width: 8),
              Text('إلغاء الرحلة', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
