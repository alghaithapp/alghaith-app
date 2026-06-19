import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/data/iraq_neighborhoods.dart';
import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';

class TaxiRequestScreen extends StatefulWidget {
  final String? initialVehicleTypeId;
  const TaxiRequestScreen({super.key, this.initialVehicleTypeId});
  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  static const double _centerLat = 32.9256;
  static const double _centerLng = 44.7766;
  static const double _maxRadiusKm = 15.0;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  double _estimatedDistanceKm = 0.0;
  bool _isCalculatingDistance = false;
  LatLng _mapCenter = LatLng(_centerLat, _centerLng);
  int _mapRefreshSeed = 0;
  LatLng? _pickupPosition;
  LatLng? _dropoffPosition;
  List<LatLng> _routePolyline = const [];
  bool _isLocating = false;

  late String _selectedVehicleId;
  bool _isPickupFocused = true;
  List<String> _suggestions = [];
  bool _isSearchingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = (widget.initialVehicleTypeId == 'car_super') ? 'super_taxi' : 'economy_taxi';
    _pickupController.addListener(_onSearchChanged);
    _dropoffController.addListener(_onSearchChanged);
    _pickupFocus.addListener(() { if (_pickupFocus.hasFocus) setState(() => _isPickupFocused = true); });
    _dropoffFocus.addListener(() { if (_dropoffFocus.hasFocus) setState(() => _isPickupFocused = false); });
  }

  @override
  void dispose() {
    _pickupController.dispose(); _dropoffController.dispose(); _noteController.dispose();
    _pickupFocus.dispose(); _dropoffFocus.dispose();
    super.dispose();
  }

  int _roundTo250(int value) => value <= 0 ? 250 : (value / 250).ceil() * 250;

  void _onSearchChanged() {
    final query = (_isPickupFocused ? _pickupController : _dropoffController).text.trim();
    if (query.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _fetchSuggestions(query);
  }

  Future<void> _fetchSuggestions(String query) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty) return;
    setState(() => _isSearchingSuggestions = true);
    try {
      final uri = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?language=ar&country=iq&limit=5&access_token=$token');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = (data['features'] as List).map((f) => f['place_name'].toString()).toList();
        });
      }
    } catch (_) {} finally { setState(() => _isSearchingSuggestions = false); }
  }

  bool _isWithinServiceArea(double lat, double lng) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat - _centerLat) * math.pi / 180;
    final dLon = (lng - _centerLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_centerLat * math.pi / 180) * math.cos(lat * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final distance = earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return distance <= _maxRadiusKm;
  }

  void _showAreaWarning() {
    showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(title: const Text('خارج نطاق الخدمة'), content: const Text('عذراً، خدمة تكسي الغيث متوفرة داخل قضاء الصويرة وبمساحة 15 كم من المركز فقط.'), actions: [CupertinoDialogAction(child: const Text('حسناً'), onPressed: () => Navigator.pop(c))]));
  }

  Future<void> _handleMapTap(LatLng pos) async {
    if (!_isWithinServiceArea(pos.latitude, pos.longitude)) { _showAreaWarning(); return; }
    setState(() => _isLocating = true);
    final address = await _resolveAddress(pos.latitude, pos.longitude);
    setState(() {
      if (_isPickupFocused) { _pickupController.text = address ?? 'موقع مخصص'; _pickupPosition = pos; }
      else { _dropoffController.text = address ?? 'وجهة مخصصة'; _dropoffPosition = pos; }
      _mapRefreshSeed++;
    });
    _updateRoute();
    setState(() => _isLocating = false);
  }

  Future<String?> _resolveAddress(double lat, double lng) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    try {
      final uri = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?limit=1&access_token=$token');
      final response = await http.get(uri);
      return jsonDecode(response.body)['features'][0]['place_name'];
    } catch (_) { return null; }
  }

  Future<void> _updateRoute() async {
    if (_pickupPosition == null || _dropoffPosition == null) return;
    setState(() => _isCalculatingDistance = true);
    final token = AppConfig.effectiveMapboxPublicToken;
    try {
      final uri = Uri.parse('https://api.mapbox.com/directions/v5/mapbox/driving/${_pickupPosition!.longitude},${_pickupPosition!.latitude};${_dropoffPosition!.longitude},${_dropoffPosition!.latitude}?geometries=geojson&access_token=$token');
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      final route = data['routes'][0];
      final coords = route['geometry']['coordinates'] as List;
      setState(() {
        _estimatedDistanceKm = (route['distance'] as num) / 1000.0;
        _routePolyline = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        _mapCenter = LatLng((_pickupPosition!.latitude + _dropoffPosition!.latitude) / 2, (_pickupPosition!.longitude + _dropoffPosition!.longitude) / 2);
        _mapRefreshSeed++;
      });
    } catch (_) {} finally { setState(() => _isCalculatingDistance = false); }
  }

  void _selectSuggestion(String addr) async {
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
    final token = AppConfig.effectiveMapboxPublicToken;
    final uri = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(addr)}.json?limit=1&access_token=$token');
    final response = await http.get(uri);
    final center = jsonDecode(response.body)['features'][0]['center'] as List;
    final pos = LatLng(center[1].toDouble(), center[0].toDouble());
    if (!_isWithinServiceArea(pos.latitude, pos.longitude)) { _showAreaWarning(); return; }
    setState(() {
      if (_isPickupFocused) { _pickupController.text = addr; _pickupPosition = pos; }
      else { _dropoffController.text = addr; _dropoffPosition = pos; }
      _mapCenter = pos; _mapRefreshSeed++;
    });
    _updateRoute();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final baseFare = AppConfig.calculateTaxiFare(_estimatedDistanceKm);
    final vehicles = [
      const _VehicleOption(id: 'economy_taxi', name: 'تكسي اقتصادي', eta: '4 د', capacity: '4 مقاعد', image: '🚕', multiplier: 1.0),
      const _VehicleOption(id: 'super_taxi', name: 'تكسي سوبر', eta: '3 د', capacity: '4 مقاعد', image: '🚘', multiplier: 1.30),
    ];
    final selectedVehicle = vehicles.firstWhere((v) => v.id == _selectedVehicleId, orElse: () => vehicles.first);
    final hasLocations = _pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty;
    final latestReq = provider.taxiRequests.isNotEmpty ? provider.taxiRequests.first : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(child: _TaxiMapBackdrop(mapCenter: _mapCenter, mapRefreshSeed: _mapRefreshSeed, pickupPosition: _pickupPosition, dropoffPosition: _dropoffPosition, routePolyline: _routePolyline, onMapTap: _handleMapTap)),
          Positioned(top: 40, right: 16, child: _CircleBtn(icon: CupertinoIcons.back, onTap: () => Navigator.pop(context))),
          Positioned(left: 16, top: 40, child: _CircleBtn(icon: _isLocating ? CupertinoIcons.refresh : CupertinoIcons.location_fill, onTap: () async {
            final p = await geo.Geolocator.getCurrentPosition();
            _handleMapTap(LatLng(p.latitude, p.longitude));
          })),
          DraggableScrollableSheet(
            initialChildSize: hasLocations ? 0.55 : 0.35, minChildSize: 0.25, maxChildSize: 0.85,
            builder: (c, s) => Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1B2838) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: ListView(controller: s, padding: const EdgeInsets.all(20), children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                _SearchField(controller: _pickupController, focus: _pickupFocus, hint: 'من أين ستنطلق؟', icon: CupertinoIcons.circle_fill, color: Colors.green),
                const SizedBox(height: 10),
                _SearchField(controller: _dropoffController, focus: _dropoffFocus, hint: 'إلى أين وجهتك؟', icon: CupertinoIcons.location_solid, color: Colors.orange),
                if (_isSearchingSuggestions) const Center(child: CupertinoActivityIndicator())
                else if (_suggestions.isNotEmpty) Column(children: _suggestions.map((s) => ListTile(title: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)), onTap: () => _selectSuggestion(s))).toList()),
                if (!hasLocations) ...[
                  const SizedBox(height: 20),
                  const Text('أحياء الصويرة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: IraqNeighborhoods.suwayraNeighborhoods.take(6).map<Widget>((n) => GestureDetector(
                    onTap: () { if (_isPickupFocused) _pickupController.text = n; else _dropoffController.text = n; _updateRoute(); },
                    child: Chip(label: Text(n, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11))),
                  )).toList()),
                  const SizedBox(height: 10),
                  CupertinoButton(child: const Text('الرحلات السابقة', style: TextStyle(fontFamily: 'Cairo')), onPressed: () {
                    final trips = provider.taxiRequests.where((t) => t.statusKey == 'completed').toList();
                    if (trips.isEmpty) return;
                    showCupertinoModalPopup(context: context, builder: (ctx) => CupertinoActionSheet(actions: trips.map((t) => CupertinoActionSheetAction(child: Text('${t.pickupAddressAr} ← ${t.dropoffAddressAr}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)), onPressed: () { Navigator.pop(ctx); setState(() { _pickupController.text = t.pickupAddressAr; _dropoffController.text = t.dropoffAddressAr; }); _updateRoute(); })).toList()));
                  }),
                ],
                if (hasLocations) ...[
                  const SizedBox(height: 20),
                  Row(children: vehicles.map((v) => _VehCard(
                    name: v.name, emoji: v.image, fare: _roundTo250((baseFare * v.multiplier).round()),
                    selected: v.id == _selectedVehicleId, onTap: () => setState(() => _selectedVehicleId = v.id)
                  )).toList()),
                  const SizedBox(height: 20),
                  _Summary(dist: _estimatedDistanceKm, fare: _roundTo250((baseFare * selectedVehicle.multiplier).round())),
                  const SizedBox(height: 15),
                  CupertinoTextField(controller: _noteController, placeholder: 'ملاحظة للسائق', padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(12))),
                  const SizedBox(height: 20),
                  CupertinoButton.filled(child: const Text('طلب التكسي الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onPressed: () async {
                    final fare = _roundTo250((baseFare * selectedVehicle.multiplier).round());
                    final req = TaxiRequest(id: DateTime.now().millisecondsSinceEpoch.toString(), requestNumber: 'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', requestedAtAr: 'اليوم', requestedAtEn: 'Today', customerNameAr: provider.customerName, customerNameEn: provider.customerName, customerPhone: provider.customerPhone, pickupAddressAr: _pickupController.text, pickupAddressEn: _pickupController.text, dropoffAddressAr: _dropoffController.text, dropoffAddressEn: _dropoffController.text, rideTypeId: _selectedVehicleId, rideTypeAr: selectedVehicle.name, rideTypeEn: 'Taxi', fare: fare, statusKey: 'pending', statusAr: 'بانتظار السائق', statusEn: 'Pending', noteAr: _noteController.text, noteEn: _noteController.text, paymentMethodAr: 'نقداً', paymentMethodEn: 'Cash');
                    if (await provider.addTaxiRequest(req)) showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(title: const Text('تم الإرسال'), content: const Text('جارٍ البحث عن سائق...'), actions: [CupertinoDialogAction(child: const Text('حسنًا'), onPressed: () => Navigator.pop(c))]));
                  }),
                ],
                if (latestReq != null) ...[
                  const SizedBox(height: 20),
                  Text('حالة الطلب: ${latestReq.statusAr}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  if (latestReq.statusKey == 'pending' || latestReq.statusKey == 'accepted') CupertinoButton(child: const Text('إلغاء الرحلة', style: TextStyle(color: Colors.red)), onPressed: () async {
                    if (await provider.cancelTaxiRequestByCustomer(latestReq.id) != 'failed') setState(() {});
                  }),
                ]
              ]),
            ),
          )
        ]),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Icon(icon, color: AppColors.primary, size: 22)));
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller; final FocusNode focus; final String hint; final IconData icon; final Color color;
  const _SearchField({required this.controller, required this.focus, required this.hint, required this.icon, required this.color});
  @override Widget build(BuildContext context) => CupertinoTextField(controller: controller, focusNode: focus, placeholder: hint, placeholderStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13), prefix: Padding(padding: const EdgeInsets.only(right: 12), child: Icon(icon, color: color, size: 18)), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(16)));
}

class _VehCard extends StatelessWidget {
  final String name, emoji; final int fare; final bool selected; final VoidCallback onTap;
  const _VehCard({required this.name, required this.emoji, required this.fare, required this.selected, required this.onTap});
  @override Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? AppColors.primary : Colors.grey[200]!, width: 2)), child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 24)), Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)), Text('${fare.toPrice()} د.ع', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w900))]))));
}

class _Summary extends StatelessWidget {
  final double dist; final int fare;
  const _Summary({required this.dist, required this.fare});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    _SumItem(label: 'المسافة', val: '${dist.toStringAsFixed(1)} كم'),
    _SumItem(label: 'الأجرة', val: '${fare.toPrice()} د.ع'),
  ]));
}

class _SumItem extends StatelessWidget {
  final String label, val; const _SumItem({required this.label, required this.val});
  @override Widget build(BuildContext context) => Column(children: [Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey)), Text(val, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14))]);
}

class _TaxiMapBackdrop extends StatefulWidget {
  final LatLng mapCenter; final int mapRefreshSeed; final LatLng? pickupPosition, dropoffPosition; final List<LatLng> routePolyline; final ValueChanged<LatLng> onMapTap;
  const _TaxiMapBackdrop({required this.mapCenter, required this.mapRefreshSeed, this.pickupPosition, this.dropoffPosition, required this.routePolyline, required this.onMapTap});
  @override State<_TaxiMapBackdrop> createState() => _TaxiMapBackdropState();
}

class _TaxiMapBackdropState extends State<_TaxiMapBackdrop> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(32.9256, 44.7766),
        initialZoom: 13.0,
        onTap: (tapPos, latlng) => widget.onMapTap(latlng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'AlGhaithApp/1.2.59 (com.alghaith.app)',
        ),
        if (widget.routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePolyline,
                color: AppColors.accent,
                strokeWidth: 4.0,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.pickupPosition != null)
              Marker(
                point: widget.pickupPosition!,
                child: const Icon(Icons.circle, color: Colors.green, size: 16),
              ),
            if (widget.dropoffPosition != null)
              Marker(
                point: widget.dropoffPosition!,
                child: const Icon(Icons.location_on, color: Colors.orange, size: 24),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant _TaxiMapBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.mapRefreshSeed != old.mapRefreshSeed) {
      _mapController.move(widget.mapCenter, 13.0);
    }
  }
}

class _GeoPoint { final double latitude, longitude; const _GeoPoint(this.latitude, this.longitude); }
class _VehicleOption { final String id, name, eta, capacity, image; final double multiplier; const _VehicleOption({required this.id, required this.name, required this.eta, required this.capacity, required this.image, required this.multiplier}); }
