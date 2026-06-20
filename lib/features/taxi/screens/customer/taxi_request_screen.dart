import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';

import 'package:flutter/cupertino.dart';
import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../utils/taxi_distance_calculator.dart';
import '../../utils/taxi_fare_calculator.dart';
import 'taxi_waiting_screen.dart';
import 'taxi_side_menu_screen.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/data/iraq_neighborhoods.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../utils/guest_gate.dart';
import '../../widgets/taxi_map_widget.dart';
import '../../../../screens/app_settings_screen.dart';

/// شاشة طلب التكسي (مستوى الزبون)
class TaxiRequestScreen extends StatefulWidget {
  const TaxiRequestScreen({super.key});

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _dropoffFocus = FocusNode();
  gmaps.GoogleMapController? _mapController;

  TaxiType _selectedType = TaxiType.economic;
  double _distanceKm = 0.0;
  int _fareEconomic = 0;
  int _fareSuper = 0;
  bool _showCarSelection = false;
  bool _isSearching = false;
  bool _isGettingLocation = false;
  List<String> _suggestions = [];
  bool _isPickupField = false;

  /// تخزين إحداثيات كل اقتراح (لنتائج Mapbox)
  final Map<String, LatLng> _suggestionCoords = {};

  /// إحداثيات موقع الانطلاق والوصول
  LatLng? _pickupCoord;
  LatLng? _dropoffCoord;

  /// نقاط المسار بين الانطلاق والوصول
  List<LatLng>? _routePoints;

  /// عند النقر على الخريطة — true يعني تعيين موقع الانطلاق، false يعني تعيين الوصول
  bool _isSettingPickupByTap = true;

  bool get _hasBothLocations =>
      _pickupController.text.trim().isNotEmpty &&
      _dropoffController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pickupController.addListener(() => _onTextChanged(true));
    _dropoffController.addListener(() => _onTextChanged(false));
  }

  void _onTextChanged(bool isPickup) {
    final controller = isPickup ? _pickupController : _dropoffController;
    final query = controller.text.trim();
    _isPickupField = isPickup;
    if (query.length < 1) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    // البحث في قاعدة بيانات الصويرة (40+ حي وقرية ومحل)
    final results = IraqNeighborhoods.search(query, maxResults: 10);
    if (results.isNotEmpty) {
      setState(() {
        _suggestionCoords.clear();
        for (final r in results) {
          _suggestionCoords[r.place.name] = r.place.latlng;
        }
        _suggestions = results.map((r) => r.place.name).toList();
        _isSearching = false;
      });
      return;
    }
    // إذا ما لقينا محلياً → ابحث في Mapbox
    _fetchSuggestions(query);
  }

  Future<void> _fetchSuggestions(String query) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty || !token.startsWith('pk.')) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
        '?language=ar&country=iq&limit=5&access_token=$token',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          setState(() {
            _suggestionCoords.clear();
            _suggestions = features.map((f) {
              final name = f['place_name'].toString();
              final center = f['center'] as List?;
              if (center != null && center.length >= 2) {
                _suggestionCoords[name] = LatLng(
                  (center[1] as num).toDouble(),
                  (center[0] as num).toDouble(),
                );
              }
              return name;
            }).toList();
            _isSearching = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  void _selectSuggestion(String address) {
    final controller = _isPickupField ? _pickupController : _dropoffController;

    // الحصول على الإحداثيات من التخزين المؤقت
    final coord = _suggestionCoords[address];

    setState(() {
      controller.text = address;
      _suggestions = [];
      _showCarSelection = false;

      if (_isPickupField) {
        // --- تم اختيار موقع الانطلاق ---
        _pickupCoord = coord;
        _dropoffCoord = null;
        _routePoints = null;
        // تحريك الخريطة إلى منطقة الانطلاق
        if (coord != null) {
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(coord.latitude, coord.longitude),
              15.0,
            ),
          );
        }
      } else {
        // --- تم اختيار موقع الوصول ---
        _dropoffCoord = coord;
        // حساب المسار إذا توفر كلا الموقعين
        if (_pickupCoord != null && coord != null) {
          _fetchRoute(_pickupCoord!, coord);
        }
      }
    });
    FocusScope.of(context).unfocus();
  }

  /// جلب المسار من Mapbox Directions API
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty || !token.startsWith('pk.')) return;
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?geometries=geojson&access_token=$token'
        '&language=ar&overview=full',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map?;
          final coordinates = geometry?['coordinates'] as List?;
          if (coordinates != null && coordinates.length >= 2) {
            setState(() {
              _routePoints = coordinates
                  .map((c) => LatLng(
                        (c[1] as num).toDouble(),
                        (c[0] as num).toDouble(),
                      ))
                  .toList();
            });
            return;
          }
        }
      }
    } catch (_) {}
    setState(() => _routePoints = null);
  }

  void _onRequestTrip() {
    _calculateFares();
    setState(() => _showCarSelection = true);
  }

  void _onDismissCarSelection() {
    setState(() => _showCarSelection = false);
  }

  void _calculateFares() {
    // استخدام الإحداثيات الحقيقية إن وُجدت
    final pickup = _pickupCoord ?? const LatLng(32.9256, 44.7766);
    final dropoff = _dropoffCoord ?? const LatLng(32.9300, 44.7800);

    _distanceKm = TaxiDistanceCalculator.calculateDistance(
      pickup.latitude, pickup.longitude,
      dropoff.latitude, dropoff.longitude,
    );
    final result = TaxiFareCalculator.calculateFare(
      _distanceKm, taxiType: _selectedType,
    );
    setState(() {
      _fareEconomic = result.fareEconomic;
      _fareSuper = result.fareSuper;
    });
  }

  void _onConfirmRequest() {
    // إذا كان زائر، نطلب تسجيل الدخول أولاً
    if (!GuestGate.requireAccount(context, message: 'سجّل دخولك لطلب التكسي.')) {
      return;
    }

    final pickup = _pickupCoord ?? const LatLng(32.9256, 44.7766);
    final dropoff = _dropoffCoord ?? const LatLng(32.9300, 44.7800);

    final provider = context.read<TaxiProvider>();
    provider.createTaxiRequest(
      pickupAddress: _pickupController.text,
      dropoffAddress: _dropoffController.text,
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      dropoffLat: dropoff.latitude,
      dropoffLng: dropoff.longitude,
      distanceKm: _distanceKm,
      taxiType: _selectedType.name,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TaxiWaitingScreen()),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _dropoffFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب تكسي'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: const _TaxiBackButton(),
          actions: const [
            Padding(
              padding: EdgeInsets.only(left: 15),
              child: _TaxiMenuButton(),
            ),
          ],
        ),
        body: Stack(
          children: [
            // ── خلفية الخريطة (مع الإحداثيات والمسار) ──
            TaxiMapWidget(
              onMapCreated: (controller) => _mapController = controller,
              pickupLocation: _pickupCoord,
              dropoffLocation: _dropoffCoord,
              routePoints: _routePoints,
              showCrosshair: _pickupCoord == null,
              onMapTap: _onMapTapped,
              onPickupDragEnd: _onPickupDragEnd,
              onDropoffDragEnd: _onDropoffDragEnd,
            ),

            // ── حقول البحث العائمة ──
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
                    trailing: GestureDetector(
                      onTap: _isGettingLocation ? null : _getCurrentLocation,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isGettingLocation
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.gps_fixed, size: 18, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // حقل "إلى أين؟"
                  _buildSearchField(
                    controller: _dropoffController,
                    hint: 'إلى أين؟',
                    icon: Icons.search,
                    iconColor: AppColors.primary,
                    focusNode: _dropoffFocus,
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
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(_suggestions[i],
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                          onTap: () => _selectSuggestion(_suggestions[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── زر "اطلب رحلة" (يظهر بعد تحديد الوجهة) ──
            if (_hasBothLocations && !_showCarSelection)
              Positioned(
                bottom: 40, left: 20, right: 20,
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

            // ── Bottom Sheet: اختيار السيارة (بعد الضغط على "اطلب رحلة") ──
            if (_showCarSelection)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: AppColors.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      'وقت الوصول: 5 دقائق',
                                      style: TextStyle(
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

                          // ── بطاقة اقتصادي ──
                          _FareOptionCard(
                            icon: Icons.local_taxi,
                            iconColor: AppColors.success,
                            title: 'اقتصادي',
                            subtitle: '4 مقاعد، قياسي',
                            price: '$_fareEconomic د.ع',
                            isSelected: _selectedType == TaxiType.economic,
                            onTap: () => setState(() => _selectedType = TaxiType.economic),
                          ),
                          const SizedBox(height: 10),

                          // ── بطاقة سوبر ──
                          _FareOptionCard(
                            icon: Icons.directions_car,
                            iconColor: AppColors.primary,
                            title: 'سوبر',
                            subtitle: 'حديث (2020+)، تقييم عالي',
                            price: '$_fareSuper د.ع',
                            isSelected: _selectedType == TaxiType.superTaxiType,
                            onTap: () => setState(() => _selectedType = TaxiType.superTaxiType),
                          ),
                          const SizedBox(height: 14),

                          const SizedBox(height: 16),

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
      // الرجوع إلى حقل الانطلاق
      setState(() => _isSettingPickupByTap = true);
    }
  }

  /// الحصول على موقع الهاتف الحالي وتعيينه كنقطة انطلاق
  Future<void> _getCurrentLocation() async {
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
        });
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(latlng.latitude, latlng.longitude),
            15.0,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحصول على الموقع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  /// تحويل إحداثيات (lat,lng) إلى عنوان نصي عبر Mapbox Reverse Geocoding
  Future<String> _reverseGeocode(LatLng latlng) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isNotEmpty && token.startsWith('pk.')) {
      try {
        final uri = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/'
          '${latlng.longitude},${latlng.latitude}.json'
          '?language=ar&access_token=$token',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            return features[0]['place_name']?.toString() ?? 'موقع محدد';
          }
        }
      } catch (_) {}
    }
    return '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    FocusNode? focusNode,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
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

/// زر القائمة الجانبية — في الزاوية اليسرى مقابل زر الرجوع
class _TaxiMenuButton extends StatelessWidget {
  const _TaxiMenuButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaxiSideMenuScreen()),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.menu,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ── بطاقة خيار الأجرة ──
class _FareOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  const _FareOptionCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.price, required this.isSelected,
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
            Container(
              width: 64, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)),
                      if (title == 'اقتصادي') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.group, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Text('4',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                      if (title == 'سوبر') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, size: 14, color: AppColors.accent),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600,
                  color: title == 'سوبر' && !isSelected ? Colors.black : AppColors.primary,
                )),
          ],
        ),
      ),
    );
  }
}
