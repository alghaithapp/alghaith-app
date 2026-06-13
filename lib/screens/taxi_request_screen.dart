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
  final String? initialVehicleTypeId;

  const TaxiRequestScreen({super.key, this.initialVehicleTypeId});

  static const bool isComingSoon = false;

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
  final String _selectedPayment = 'cash';

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
          if (pickup.isEmpty) _pickupPosition = null;
          if (dropoff.isEmpty) _dropoffPosition = null;
          _routePolyline = const [];
          _mapRefreshSeed++;
        });
      }
      return;
    }

    if (mounted) setState(() => _isCalculatingDistance = true);

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
        pickupAddress: pickup,
        dropoffAddress: dropoff,
      );
      final fallbackDistanceKm = from == null || to == null
          ? null
          : _haversineDistanceKm(from.latitude, from.longitude, to.latitude, to.longitude);

      final distanceKm = roadDistanceKm ?? fallbackDistanceKm;
      if (distanceKm != null && mounted) {
        setState(() => _estimatedDistanceKm = distanceKm <= 0 ? 0.5 : distanceKm);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isCalculatingDistance = false);
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
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'pickupAddress': pickupAddress, 'dropoffAddress': dropoffAddress}),
      ).timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final payload = jsonDecode(response.body);
      return (payload['distanceKm'] as num?)?.toDouble();
    } catch (_) { return null; }
  }

  Future<_GeoPoint?> _resolveCoordinates(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'json', 'limit': '1', 'q': query});
    final response = await http.get(uri, headers: const {'User-Agent': 'alghaith-app/1.0'});
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    return _GeoPoint(double.parse(first['lat']), double.parse(first['lon']));
  }

  double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double value) => value * math.pi / 180;

  Future<List<Position>> _fetchRoutePolyline({required Position from, required Position to}) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return [from, to];
    try {
      final uri = Uri.parse('https://api.mapbox.com/directions/v5/mapbox/driving/${from.lng},${from.lat};${to.lng},${to.lat}?alternatives=false&overview=full&geometries=geojson&language=ar&access_token=$token');
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        return coordinates.map((c) => Position(c[0].toDouble(), c[1].toDouble())).toList();
      }
    } catch (_) {}
    return [from, to];
  }

  Future<List<String>> _fetchAddressSuggestions(String query) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty || query.length < 2) return const [];
    try {
      final uri = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?language=ar&country=iq&limit=5&access_token=$token');
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      return (data['features'] as List).map((f) => f['place_name'].toString()).toList();
    } catch (_) { return const []; }
  }

  Future<void> _useCurrentLocation() async {
    final permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always) {
      final pos = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _pickupController.text = 'موقعي الحالي';
        _pickupPosition = Position(pos.longitude, pos.latitude);
        _mapCenter = _pickupPosition!;
        _mapRefreshSeed++;
      });
      _scheduleDistanceUpdate();
    }
  }

  void _selectTrip(TaxiRequest trip) {
    setState(() {
      _pickupController.text = trip.pickupAddressAr;
      _dropoffController.text = trip.dropoffAddressAr;
    });
    _scheduleDistanceUpdate();
  }

  void _showPreviousTripsModal(List<TaxiRequest> trips) {
    final completedTrips = trips.where((t) => t.statusKey == 'completed').toList();
    if (completedTrips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد رحلات مكتملة سابقة.')));
      return;
    }
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('الرحلات السابقة', style: TextStyle(fontFamily: 'Cairo')),
        actions: completedTrips.take(5).map((trip) => CupertinoActionSheetAction(
          onPressed: () { Navigator.pop(context); _selectTrip(trip); },
          child: Text('${trip.pickupAddressAr} ← ${trip.dropoffAddressAr}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ),
    );
  }

  static String _mapInitialVehicle(String? id) => (id == 'car_super' || id == 'super_taxi') ? 'super_taxi' : 'economy_taxi';

  List<_VehicleOption> _vehicleOptions() => [
    const _VehicleOption(id: 'economy_taxi', name: 'تكسي اقتصادي', eta: '4 د', capacity: '4 مقاعد', emoji: '🚕', multiplier: 1.0),
    const _VehicleOption(id: 'super_taxi', name: 'تكسي سوبر', eta: '3 د', capacity: '4 مقاعد', emoji: '🚘', multiplier: 1.30),
  ];

  int _roundTo250(int value) => (value / 250).ceil() * 250;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final baseFare = AppConfig.calculateTaxiFare(_estimatedDistanceKm);
    final vehicles = _vehicleOptions();
    final selectedVehicle = vehicles.firstWhere((v) => v.id == _selectedVehicleId, orElse: () => vehicles.first);
    final estimatedFare = _roundTo250((baseFare * selectedVehicle.multiplier).round());
    final hasLocations = _pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty;
    final latestRequest = provider.taxiRequests.isNotEmpty ? provider.taxiRequests.first : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        child: SafeArea(
          child: Stack(
            children: [
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
              Positioned(
                top: 12, left: 14,
                child: _MapTopCircleButton(icon: CupertinoIcons.back, onTap: () => Navigator.pop(context)),
              ),
              DraggableScrollableSheet(
                initialChildSize: hasLocations ? 0.50 : 0.28,
                minChildSize: 0.20, maxChildSize: 0.82,
                snap: true, snapSizes: const [0.28, 0.50, 0.82],
                builder: (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _PremiumSearchFields(
                            pickupController: _pickupController,
                            dropoffController: _dropoffController,
                            onQuerySuggestions: _fetchAddressSuggestions,
                            onPickupSuggestionSelected: (v) => _updateDistanceFromAddresses(),
                            onDropoffSuggestionSelected: (v) => _updateDistanceFromAddresses(),
                          )),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _showPreviousTripsModal(provider.taxiRequests),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF5F7FC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                              child: const Icon(CupertinoIcons.time_solid, color: Color(0xFF007A7A), size: 22),
                            ),
                          ),
                        ],
                      ),
                      if (hasLocations) ...[
                        const SizedBox(height: 20),
                        const Text('اختر نوع المركبة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: vehicles.map((v) => Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _VehicleCard(
                              option: v, fare: _roundTo250((baseFare * v.multiplier).round()),
                              selected: v.id == _selectedVehicleId,
                              onTap: () => setState(() => _selectedVehicleId = v.id),
                            ),
                          ))).toList(),
                        ),
                        const SizedBox(height: 20),
                        _TripInfoPanel(isCalculatingDistance: _isCalculatingDistance, distanceKm: _estimatedDistanceKm, etaLabel: '${(_estimatedDistanceKm * 3).round()}', fareIqd: estimatedFare),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _noteController,
                          placeholder: 'ملاحظة للسائق (اختياري)',
                          placeholderStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(16)),
                        ),
                        const SizedBox(height: 24),
                        _PremiumRequestButton(onPressed: () => _submitTaxiRequest(context: context, appProvider: provider, selectedVehicle: selectedVehicle, estimatedFare: estimatedFare)),
                      ],
                      if (latestRequest != null) ...[
                        const SizedBox(height: 20),
                        _LiveStatusBanner(request: latestRequest),
                        const SizedBox(height: 12),
                        _TaxiStatusCard(request: latestRequest),
                      ]
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

  Future<void> _submitTaxiRequest({required BuildContext context, required AppProvider appProvider, required _VehicleOption selectedVehicle, required int estimatedFare}) async {
    final request = TaxiRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      requestNumber: 'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      requestedAtAr: 'اليوم، ${TimeOfDay.now().format(context)}',
      requestedAtEn: 'Today',
      customerNameAr: appProvider.customerName, customerNameEn: appProvider.customerName,
      customerPhone: appProvider.customerPhone,
      pickupAddressAr: _pickupController.text, pickupAddressEn: _pickupController.text,
      dropoffAddressAr: _dropoffController.text, dropoffAddressEn: _dropoffController.text,
      rideTypeId: selectedVehicle.id, rideTypeAr: selectedVehicle.name, rideTypeEn: selectedVehicle.name,
      fare: estimatedFare, statusKey: 'pending', statusAr: 'بانتظار السائق', statusEn: 'Pending',
      noteAr: _noteController.text, noteEn: _noteController.text,
      paymentMethodAr: 'نقداً', paymentMethodEn: 'Cash',
    );
    if (await appProvider.addTaxiRequest(request) && mounted) {
      showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(title: const Text('تم الإرسال'), content: const Text('جارٍ البحث عن سائق...'), actions: [CupertinoDialogAction(child: const Text('حسنًا'), onPressed: () => Navigator.pop(c))]));
    }
  }
}

class _GeoPoint { final double latitude, longitude; const _GeoPoint(this.latitude, this.longitude); }

class _TaxiMapBackdrop extends StatefulWidget {
  final String pickupAddress, dropoffAddress;
  final double estimatedDistanceKm;
  final Position mapCenter;
  final int mapRefreshSeed;
  final Position? pickupPosition, dropoffPosition;
  final List<Position> routePolyline;
  const _TaxiMapBackdrop({required this.pickupAddress, required this.dropoffAddress, required this.estimatedDistanceKm, required this.mapCenter, required this.mapRefreshSeed, this.pickupPosition, this.dropoffPosition, required this.routePolyline});
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
    await _circles?.deleteAll(); await _lines?.deleteAll();
    if (widget.routePolyline.isNotEmpty) {
      await _lines?.create(PolylineAnnotationOptions(geometry: LineString(coordinates: widget.routePolyline), lineColor: Colors.cyan.value, lineWidth: 5));
    }
    if (widget.pickupPosition != null) await _circles?.create(CircleAnnotationOptions(geometry: Point(coordinates: widget.pickupPosition!), circleColor: Colors.blue.value, circleRadius: 8));
    if (widget.dropoffPosition != null) await _circles?.create(CircleAnnotationOptions(geometry: Point(coordinates: widget.dropoffPosition!), circleColor: Colors.orange.value, circleRadius: 8));

    _map?.setCamera(CameraOptions(center: Point(coordinates: widget.mapCenter), zoom: 13, pitch: 0, bearing: 0));
  }

  @override void didUpdateWidget(old) { super.didUpdateWidget(old); _updateMap(); }

  @override Widget build(BuildContext context) => MapWidget(styleUri: 'mapbox://styles/mapbox/navigation-day-v1', onMapCreated: _onMapCreated);
}

class _VehicleCard extends StatelessWidget {
  final _VehicleOption option; final int fare; final bool selected; final VoidCallback onTap;
  const _VehicleCard({required this.option, required this.fare, required this.selected, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? Colors.orange : Colors.grey[200]!, width: 2)),
      child: Column(children: [
        Text(option.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(option.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        Text('${fare.toPrice()} د.ع', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w900)),
      ]),
    ),
  );
}

class _PremiumSearchFields extends StatelessWidget {
  final TextEditingController pickupController, dropoffController;
  final Future<List<String>> Function(String) onQuerySuggestions;
  final ValueChanged<String> onPickupSuggestionSelected, onDropoffSuggestionSelected;
  const _PremiumSearchFields({required this.pickupController, required this.dropoffController, required this.onQuerySuggestions, required this.onPickupSuggestionSelected, required this.onDropoffSuggestionSelected});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF5F7FC), borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      _LocationTextField(controller: pickupController, hint: 'من أين ستنطلق؟', icon: CupertinoIcons.circle_fill, color: Colors.blue),
      const SizedBox(height: 10),
      _LocationTextField(controller: dropoffController, hint: 'إلى أين وجهتك؟', icon: CupertinoIcons.location_solid, color: Colors.orange),
    ]),
  );
}

class _LocationTextField extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData icon; final Color color;
  const _LocationTextField({required this.controller, required this.hint, required this.icon, required this.color});
  @override Widget build(BuildContext context) => CupertinoTextField(
    controller: controller, placeholder: hint,
    prefix: Padding(padding: const EdgeInsets.only(right: 12), child: Icon(icon, color: color, size: 18)),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
  );
}

class _TripInfoPanel extends StatelessWidget {
  final bool isCalculatingDistance; final double distanceKm; final String etaLabel; final int fareIqd;
  const _TripInfoPanel({required this.isCalculatingDistance, required this.distanceKm, required this.etaLabel, required this.fareIqd});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _InfoItem(icon: CupertinoIcons.map_fill, label: '${distanceKm.toStringAsFixed(1)} كم', title: 'المسافة'),
      _InfoItem(icon: CupertinoIcons.clock_fill, label: '$etaLabel د', title: 'وصول'),
      _InfoItem(icon: CupertinoIcons.money_dollar_circle_fill, label: '${fareIqd.toPrice()} د.ع', title: 'الأجرة'),
    ]),
  );
}

class _InfoItem extends StatelessWidget {
  final IconData icon; final String label, title;
  const _InfoItem({required this.icon, required this.label, required this.title});
  @override Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 18, color: Colors.blueGrey),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
    Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)),
  ]);
}

class _VehicleOption {
  final String id, name, eta, capacity, emoji; final double multiplier;
  const _VehicleOption({required this.id, required this.name, required this.eta, required this.capacity, required this.emoji, required this.multiplier});
}

class _MapTopCircleButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _MapTopCircleButton({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Icon(icon, color: Colors.black87, size: 20)));
}

class _FloatingTag extends StatelessWidget {
  final String title; final Color color;
  const _FloatingTag({required this.title, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')));
}

class _PremiumRequestButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _PremiumRequestButton({required this.onPressed});
  @override Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF007A7A), Color(0xFF009688)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
    child: CupertinoButton(onPressed: onPressed, child: const Text('طلب التكسي الآن', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
  );
}

class _LiveStatusBanner extends StatelessWidget {
  final TaxiRequest request; const _LiveStatusBanner({required this.request});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(CupertinoIcons.info_circle_fill, color: Colors.blue), const SizedBox(width: 10), Expanded(child: Text(request.statusAr, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.blue)))]));
}

class _TaxiStatusCard extends StatelessWidget {
  final TaxiRequest request; const _TaxiStatusCard({required this.request});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)), child: Column(children: [Text('رقم الرحلة: ${request.requestNumber}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('الأجرة: ${request.fare.toPrice()} د.ع', style: const TextStyle(fontFamily: 'Cairo', color: Colors.orange, fontWeight: FontWeight.w900))]));
}

class _CustomerTaxiActionsCard extends StatelessWidget {
  final TaxiRequest request; final VoidCallback onCancelPressed;
  const _CustomerTaxiActionsCard({required this.request, required this.onCancelPressed});
  @override Widget build(BuildContext context) => CupertinoButton(onPressed: onCancelPressed, child: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')));
}

class _MovingVehiclesOverlay extends StatelessWidget { const _MovingVehiclesOverlay(); @override Widget build(BuildContext context) => const SizedBox.shrink(); }
class _MapPatternPainter extends CustomPainter { @override void paint(Canvas canvas, ui.Size size) {} @override bool shouldRepaint(old) => false; }
