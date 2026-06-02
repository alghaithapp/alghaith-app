import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/app_provider.dart';
import '../core/config/app_config.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckingOut = false;
  bool _isLocating = false;
  bool _isCalculatingDelivery = false;
  int _deliveryFeeIqd = 0;
  double? _deliveryDistanceKm;
  String? _lastAutoCalcSignature;
  bool _autoCalcScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (provider.cart.isNotEmpty && provider.customerAddress.trim().isNotEmpty) {
        unawaited(_recalculateDeliveryFee(provider));
      }
    });
  }

  String _merchantAddress(List<dynamic> cart) {
    for (final item in cart) {
      final address = item.merchantAddress?.toString().trim() ?? '';
      if (address.isNotEmpty) return address;
    }
    return '';
  }

  _GeoPoint? _merchantLocation(List<dynamic> cart) {
    for (final item in cart) {
      final lat = (item.merchantLatitude as num?)?.toDouble();
      final lng = (item.merchantLongitude as num?)?.toDouble();
      if (lat != null && lng != null) {
        return _GeoPoint(lat, lng);
      }
    }
    return null;
  }

  Future<double?> _fetchRoadDistanceKm({
    required String merchantAddress,
    required String customerAddress,
    required _GeoPoint? merchantLocation,
    required _GeoPoint? customerLocation,
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
              'pickupAddress': merchantAddress,
              'dropoffAddress': customerAddress,
              if (merchantLocation != null) ...{
                'pickupLatitude': merchantLocation.latitude,
                'pickupLongitude': merchantLocation.longitude,
              },
              if (customerLocation != null) ...{
                'dropoffLatitude': customerLocation.latitude,
                'dropoffLongitude': customerLocation.longitude,
              },
            }),
          )
          .timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final payload = jsonDecode(response.body);
      if (payload is! Map) return null;
      return (payload['distanceKm'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  double? _straightLineDistanceKm(_GeoPoint? origin, _GeoPoint? destination) {
    if (origin == null || destination == null) return null;
    final meters = geo.Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (!meters.isFinite || meters <= 0) return null;
    return meters / 1000;
  }

  Future<void> _recalculateDeliveryFee(AppProvider appProvider) async {
    final merchantAddress = _merchantAddress(appProvider.cart);
    final merchantLocation = _merchantLocation(appProvider.cart);
    final customerAddress = appProvider.customerAddress.trim();
    final customerLocation = (appProvider.customerLatitude != null &&
            appProvider.customerLongitude != null)
        ? _GeoPoint(appProvider.customerLatitude!, appProvider.customerLongitude!)
        : null;
    if ((merchantAddress.isEmpty && merchantLocation == null) ||
        (customerAddress.isEmpty && customerLocation == null)) {
      setState(() {
        _deliveryFeeIqd = 0;
        _deliveryDistanceKm = null;
      });
      return;
    }
    setState(() => _isCalculatingDelivery = true);
    try {
      final roadKm = await _fetchRoadDistanceKm(
        merchantAddress: merchantAddress,
        customerAddress: customerAddress,
        merchantLocation: merchantLocation,
        customerLocation: customerLocation,
      );
      var distanceKm = roadKm;
      if (distanceKm == null || distanceKm <= 0) {
        distanceKm = _straightLineDistanceKm(merchantLocation, customerLocation);
      }
      if (!mounted) return;
      final resolvedDistanceKm = distanceKm;
      if (resolvedDistanceKm == null || resolvedDistanceKm <= 0) {
        setState(() {
          _deliveryFeeIqd = 0;
          _deliveryDistanceKm = null;
        });
        return;
      }
      final feeDistanceKm = resolvedDistanceKm;
      setState(() {
        _deliveryDistanceKm = feeDistanceKm;
        _deliveryFeeIqd = AppConfig.calculateDeliveryFee(feeDistanceKm);
      });
      _lastAutoCalcSignature = _autoCalcSignature(appProvider);
    } finally {
      if (mounted) setState(() => _isCalculatingDelivery = false);
    }
  }

  String? _autoCalcSignature(AppProvider appProvider) {
    if (appProvider.cart.isEmpty) return null;
    final merchantAddress = _merchantAddress(appProvider.cart).trim();
    final merchantLocation = _merchantLocation(appProvider.cart);
    final customerAddress = appProvider.customerAddress.trim();
    final customerLat = appProvider.customerLatitude;
    final customerLng = appProvider.customerLongitude;
    final hasMerchant = merchantLocation != null || merchantAddress.isNotEmpty;
    final hasCustomer =
        (customerLat != null && customerLng != null) || customerAddress.isNotEmpty;
    if (!hasMerchant || !hasCustomer) return null;
    final cartSignature = appProvider.cart
        .map((item) => '${item.id}:${item.count}')
        .join('|');
    final merchantSig = merchantLocation == null
        ? merchantAddress
        : '${merchantLocation.latitude.toStringAsFixed(6)},${merchantLocation.longitude.toStringAsFixed(6)}';
    final customerSig = (customerLat != null && customerLng != null)
        ? '${customerLat.toStringAsFixed(6)},${customerLng.toStringAsFixed(6)}'
        : customerAddress;
    return '$cartSignature#$merchantSig#$customerSig';
  }

  void _scheduleAutoFeeCalculation(AppProvider appProvider) {
    final signature = _autoCalcSignature(appProvider);
    if (signature == null) {
      _lastAutoCalcSignature = null;
      if ((_deliveryFeeIqd > 0 || _deliveryDistanceKm != null) &&
          !_isCalculatingDelivery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _deliveryFeeIqd = 0;
            _deliveryDistanceKm = null;
          });
        });
      }
      return;
    }
    if (signature == _lastAutoCalcSignature || _autoCalcScheduled) return;
    _autoCalcScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoCalcScheduled = false;
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final latestSignature = _autoCalcSignature(provider);
      if (latestSignature == null || latestSignature == _lastAutoCalcSignature) {
        return;
      }
      _lastAutoCalcSignature = latestSignature;
      await _recalculateDeliveryFee(provider);
    });
  }

  Future<void> _detectCurrentLocation(AppProvider appProvider) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى تفعيل خدمة الموقع في الهاتف.')),
          );
        }
        return;
      }
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الموقع.')),
          );
        }
        return;
      }
      final current = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final token = AppConfig.mapboxPublicToken.trim();
      String addressText =
          '${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)}';
      if (token.isNotEmpty) {
        try {
          final uri = Uri.parse(
            'https://api.mapbox.com/geocoding/v5/mapbox.places/'
            '${current.longitude},${current.latitude}.json'
            '?language=ar&country=iq&limit=1&access_token=$token',
          );
          final response = await http.get(uri).timeout(AppConfig.apiTimeout);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final payload = jsonDecode(response.body);
            if (payload is Map && payload['features'] is List) {
              final features = payload['features'] as List;
              if (features.isNotEmpty && features.first is Map) {
                final value =
                    (features.first['place_name']?.toString() ?? '').trim();
                if (value.isNotEmpty) {
                  addressText = value;
                }
              }
            }
          }
        } catch (_) {}
      }

      try {
        await appProvider.updateCustomerProfile(
          address: addressText,
          latitude: current.latitude,
          longitude: current.longitude,
        );
      } catch (_) {}
      _lastAutoCalcSignature = null;
      await _recalculateDeliveryFee(appProvider);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickLocationFromMap(AppProvider appProvider) async {
    final result = await Navigator.of(context).push<_PickedLocation>(
      CupertinoPageRoute(
        builder: (_) => _CustomerMapPickerScreen(
          initialLatitude: appProvider.customerLatitude,
          initialLongitude: appProvider.customerLongitude,
        ),
      ),
    );
    if (result == null) return;
    try {
      await appProvider.updateCustomerProfile(
        address: result.address,
        latitude: result.latitude,
        longitude: result.longitude,
      );
    } catch (_) {}
    _lastAutoCalcSignature = null;
    await _recalculateDeliveryFee(appProvider);
  }

  Future<void> _handleCheckout(AppProvider appProvider) async {
    if (_isCheckingOut || appProvider.cart.isEmpty) return;
    if (appProvider.customerLatitude == null || appProvider.customerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك من الخريطة قبل إتمام الطلب.'),
        ),
      );
      return;
    }
    if (appProvider.customerAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك أولاً لحساب رسوم التوصيل.'),
        ),
      );
      return;
    }
    if (_deliveryFeeIqd <= 0) {
      await _recalculateDeliveryFee(appProvider);
      if (!mounted) return;
      if (_deliveryFeeIqd <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حساب رسوم التوصيل. حاول تحديد موقعك مجدداً.'),
          ),
        );
        return;
      }
    }
    setState(() => _isCheckingOut = true);
    try {
      final count = await appProvider.checkout(deliveryFeeIqd: _deliveryFeeIqd);
      if (!mounted || count == 0) return;
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('تم تقديم الطلب بنجاح!'),
          content: Text(
            'تم إرسال $count ${count == 1 ? 'طلب' : 'طلبات'} للتاجر. يمكنك متابعة حالة الطلب من صفحة الطلبات.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('حسنًا'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'تعذر إتمام الطلب حالياً.' : message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    _scheduleAutoFeeCalculation(appProvider);
    final cart = appProvider.cart;
    final deliveryFee = _deliveryFeeIqd;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('السلة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        border: null,
      ),
      child: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.cart,
                      size: 80, color: CupertinoColors.systemGrey4),
                  const SizedBox(height: 16),
                  const Text("سلتك فارغة حالياً",
                      style:
                          TextStyle(color: CupertinoColors.systemGrey)),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              AppImage(
                                imageData: item.image,
                                width: 60,
                                height: 60,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.nameAr,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text("${item.price.toLocaleString()} د.ع",
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: item.count > 1
                                        ? () => appProvider
                                            .decrementCartItem(item.id)
                                        : () =>
                                            appProvider.removeFromCart(item.id),
                                    child: Icon(
                                      item.count > 1
                                          ? CupertinoIcons.minus_circle
                                          : CupertinoIcons.delete_solid,
                                      color: item.count > 1
                                          ? CupertinoColors.systemGrey
                                          : CupertinoColors.systemRed,
                                    ),
                                  ),
                                  Text("${item.count}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () =>
                                        appProvider.incrementCartItem(item.id),
                                    child: const Icon(
                                        CupertinoIcons.plus_circle_fill,
                                        color: Colors.orange),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'موقع التوصيل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            appProvider.customerAddress.trim().isEmpty
                                ? 'لم يتم تحديد الموقع بعد'
                                : appProvider.customerAddress,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          if (appProvider.customerLatitude != null &&
                              appProvider.customerLongitude != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'الإحداثيات: ${appProvider.customerLatitude!.toStringAsFixed(5)}, ${appProvider.customerLongitude!.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          if (_deliveryDistanceKm != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'المسافة التقديرية: ${_deliveryDistanceKm!.toStringAsFixed(1)} كم',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  color: Colors.orange[700],
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: _isLocating
                                      ? null
                                      : () => _detectCurrentLocation(appProvider),
                                  child: _isLocating
                                      ? const CupertinoActivityIndicator(color: Colors.white)
                                      : const Text(
                                          'تحديد موقعي',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickLocationFromMap(appProvider),
                                  child: const Text(
                                    'اختيار من الخريطة',
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isCalculatingDelivery) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'يتم تحديث أجور التوصيل تلقائيًا...',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          _buildSummaryRow("المجموع الفرعي",
                              "${appProvider.cartTotal.toLocaleString()} د.ع"),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                              "رسوم التوصيل",
                              deliveryFee > 0
                                  ? "${deliveryFee.toLocaleString()} د.ع"
                                  : "حدد موقعك أولاً"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1, color: Color(0xFFE5E5EA)),
                          ),
                          _buildSummaryRow("المجموع الكلي",
                              "${(appProvider.cartTotal + (deliveryFee > 0 ? deliveryFee : 0)).toLocaleString()} د.ع",
                              isTotal: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.1))),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.info,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "الدفع يتم نقداً عند استلام الطلب من المندوب",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.brown,
                                  fontWeight: FontWeight.w500),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: Colors.orange[800],
                        borderRadius: BorderRadius.circular(15),
                        onPressed: _isCheckingOut
                            ? null
                            : () => _handleCheckout(appProvider),
                        child: _isCheckingOut
                            ? const CupertinoActivityIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'إتمام الطلب - الدفع عند الاستلام',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: isTotal
                    ? CupertinoColors.black
                    : CupertinoColors.systemGrey,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 17 : 14)),
        Text(value,
            style: TextStyle(
                color: isTotal ? Colors.orange[800] : CupertinoColors.black,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
                fontSize: isTotal ? 20 : 14)),
      ],
    );
  }
}

class _GeoPoint {
  final double latitude;
  final double longitude;

  const _GeoPoint(this.latitude, this.longitude);
}

class _PickedLocation {
  final String address;
  final double latitude;
  final double longitude;

  const _PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class _CustomerMapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const _CustomerMapPickerScreen({
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<_CustomerMapPickerScreen> createState() => _CustomerMapPickerScreenState();
}

class _CustomerMapPickerScreenState extends State<_CustomerMapPickerScreen> {
  static final Position _defaultCenter = Position(44.3661, 33.3152);

  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  Position _center = _defaultCenter;
  bool _isResolving = false;
  String _resolvedAddress = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = Position(widget.initialLongitude!, widget.initialLatitude!);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    try {
      _circleManager = await map.annotations.createCircleAnnotationManager();
      await _refreshCenterMarker();
    } catch (_) {}
  }

  Future<void> _refreshCenterMarker() async {
    final manager = _circleManager;
    if (manager == null) return;
    try {
      await manager.deleteAll();
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _center),
          circleColor: const Color(0xFFE60012).value,
          circleRadius: 8,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2,
        ),
      );
    } catch (_) {}
  }

  Future<void> _readCenterFromMap() async {
    final map = _map;
    if (map == null) return;
    try {
      final state = await map.getCameraState();
      final center = state.center.coordinates;
      setState(() {
        _center = Position(center.lng, center.lat);
      });
      await _refreshCenterMarker();
    } catch (_) {}
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final token = AppConfig.mapboxPublicToken.trim();
    if (token.isEmpty) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '$lng,$lat.json?language=ar&country=iq&limit=1&access_token=$token',
      );
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['features'] is! List) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final features = payload['features'] as List;
      if (features.isEmpty || features.first is! Map) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final address = (features.first['place_name']?.toString() ?? '').trim();
      if (address.isEmpty) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      return address;
    } catch (_) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isResolving = true);
    await _readCenterFromMap();
    final address = await _reverseGeocode(
      _center.lat.toDouble(),
      _center.lng.toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _resolvedAddress = address;
      _isResolving = false;
    });
    Navigator.of(context).pop(
      _PickedLocation(
        address: address,
        latitude: _center.lat.toDouble(),
        longitude: _center.lng.toDouble(),
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }
    final current = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );
    final target = Position(current.longitude, current.latitude);
    setState(() => _center = target);
    await _map?.setCamera(
      CameraOptions(
        center: Point(coordinates: target),
        zoom: 15.0,
      ),
    );
    await _refreshCenterMarker();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'تحديد موقع التوصيل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapWidget(
                      styleUri: 'mapbox://styles/mapbox/streets-v12',
                      cameraOptions: CameraOptions(
                        center: Point(coordinates: _center),
                        zoom: 14.0,
                      ),
                      onMapCreated: _onMapCreated,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.white,
                      onPressed: _moveToCurrentLocation,
                      child: const Text(
                        'موقعي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resolvedAddress.isEmpty
                        ? 'حرّك الخريطة ثم اضغط تأكيد الموقع'
                        : _resolvedAddress,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: Colors.deepOrange,
                      onPressed: _isResolving ? null : _confirmLocation,
                      child: _isResolving
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text(
                              'تأكيد هذا الموقع',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
