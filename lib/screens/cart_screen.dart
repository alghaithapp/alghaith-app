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

const _brandRed = Color(0xFFE60012);
const _brandRedGradient = LinearGradient(
  colors: [_brandRed, Color(0xFFFF3D00)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

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
  
  // 1: Normal, 2: Fast
  int _deliveryOption = 1;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

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

  @override
  void dispose() {
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
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
            const SnackBar(content: Text('يرجى تفعيل خدمة الموقع في الهاتف.', style: TextStyle(fontFamily: 'Cairo'))),
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
            const SnackBar(content: Text('تم رفض إذن الموقع.', style: TextStyle(fontFamily: 'Cairo'))),
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
          content: Text('يرجى تحديد موقعك من الخريطة قبل إتمام الطلب.', style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }
    if (appProvider.customerAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك أولاً لحساب رسوم التوصيل.', style: TextStyle(fontFamily: 'Cairo')),
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
            content: Text('تعذر حساب رسوم التوصيل. حاول تحديد موقعك مجدداً.', style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
        return;
      }
    }
    setState(() => _isCheckingOut = true);
    try {
      final count = await appProvider.checkout(
        deliveryFeeIqd: _deliveryOption == 2 ? (_deliveryFeeIqd + 2000) : _deliveryFeeIqd,
      );
      if (!mounted || count == 0) return;
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('تم تقديم الطلب بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
          content: Text(
            'تم إرسال $count ${count == 1 ? 'طلب' : 'طلبات'} للتاجر. يمكنك متابعة حالة الطلب من صفحة الطلبات.',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('حسنًا', style: TextStyle(fontFamily: 'Cairo')),
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
            style: const TextStyle(fontFamily: 'Cairo'),
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
    final restaurantName = cart.isNotEmpty ? (cart.first.merchantStoreName ?? 'المطعم') : '';
    
    final finalDeliveryFee = _deliveryOption == 2 ? (_deliveryFeeIqd + 2000) : _deliveryFeeIqd;
    final totalAmount = appProvider.cartTotal + finalDeliveryFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: cart.isEmpty ? _buildEmptyState() : Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, cart.length, restaurantName),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                    children: [
                      ...cart.map((item) => _CartItemCard(
                        item: item,
                        isFavorite: appProvider.isFavoriteId(item.id),
                        onIncrement: () => appProvider.incrementCartItem(item.id),
                        onDecrement: () {
                          if (item.count > 1) {
                            appProvider.decrementCartItem(item.id);
                          } else {
                            appProvider.removeFromCart(item.id);
                          }
                        },
                        onFavorite: () => appProvider.toggleFavorite(item.id),
                      )),
                      const SizedBox(height: 12),
                      _buildLocationSection(appProvider),
                      const SizedBox(height: 24),
                      _buildDeliveryOptions(),
                      const SizedBox(height: 24),
                      _buildPromoSection(),
                      const SizedBox(height: 24),
                      _buildNotesSection(),
                      const SizedBox(height: 24),
                      _buildOrderSummary(appProvider.cartTotal, finalDeliveryFee, totalAmount),
                      const SizedBox(height: 24),
                      _buildPaymentNotice(),
                    ],
                  ),
                ),
              ],
            ),
            _buildStickyCheckoutBar(totalAmount, cart.length, appProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count, String restaurant) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 16,
            child: _CircleIconButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Column(
            children: [
              const Text(
                'سلة المشتريات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              Text(
                '$count أصناف من $restaurant',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleIconButton(
                  icon: Icons.shopping_cart_outlined,
                  onTap: () {},
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: _brandRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(AppProvider appProvider) {
    final hasLocation = appProvider.customerLatitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'موقع التوصيل',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasLocation) ...[
                          const Icon(Icons.location_off_rounded, color: Colors.grey, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'لم يتم تحديد الموقع بعد',
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                          ),
                          const Text(
                            'حدد موقعك لحساب رسوم التوصيل',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey),
                          ),
                        ] else ...[
                          const Icon(Icons.location_on_rounded, color: _brandRed, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            appProvider.customerAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SmallButton(
                                label: 'تحديد موقعي',
                                color: _brandRed,
                                textColor: Colors.white,
                                isLoading: _isLocating,
                                onTap: () => _detectCurrentLocation(appProvider),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SmallButton(
                                label: 'من الخريطة',
                                color: Colors.white,
                                textColor: Colors.black87,
                                border: true,
                                onTap: () => _pickLocationFromMap(appProvider),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/map_preview.png', // Fallback local image if Mapbox preview not ready
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200),
                        ),
                        Center(
                          child: Icon(Icons.location_on_rounded, color: _brandRed, size: 36),
                        ),
                        if (_deliveryDistanceKm != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Text(
                                '${_deliveryDistanceKm!.toStringAsFixed(1)} كم',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'خيارات التوصيل',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DeliveryOptionCard(
                title: 'توصيل عادي',
                time: '30 - 45 دقيقة',
                selected: _deliveryOption == 1,
                onTap: () => setState(() => _deliveryOption = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DeliveryOptionCard(
                title: 'توصيل سريع',
                time: '15 - 20 دقيقة',
                selected: _deliveryOption == 2,
                onTap: () => setState(() => _deliveryOption = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPromoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'كود الخصم',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  decoration: const InputDecoration(
                    hintText: 'أدخل رمز الخصم',
                    hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              _SmallButton(
                label: 'تطبيق',
                color: _brandRed,
                textColor: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملاحظات الطلب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'ملاحظات إضافية للمطعم أو المندوب',
              hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(int subtotal, int delivery, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملخص الطلب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'المجموع الفرعي', value: '${subtotal.toPrice()} د.ع'),
              const SizedBox(height: 14),
              _SummaryRow(
                label: 'رسوم التوصيل', 
                value: delivery > 0 ? '${delivery.toPrice()} د.ع' : 'حدد الموقع',
                valueColor: delivery > 0 ? Colors.black : Colors.red,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              _SummaryRow(
                label: 'المجموع الكلي', 
                value: '${total.toPrice()} د.ع', 
                isLarge: true,
                valueColor: _brandRed,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: Colors.orange, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الدفع نقداً عند استلام الطلب من المندوب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF9A3412)),
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى تجهيز المبلغ المطلوب عند الاستلام',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCheckoutBar(int total, int count, AppProvider provider) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: _brandRedGradient,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: _brandRed.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _isCheckingOut ? null : () => _handleCheckout(provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${total.toPrice()} د.ع',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        '$count أصناف',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontFamily: 'Cairo',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_isCheckingOut)
                    const CupertinoActivityIndicator(color: Colors.white)
                  else ...[
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'إتمام الطلب',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'الدفع عند الاستلام',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Cairo',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 32),
            const Text(
              'سلتك فارغة حالياً',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'أضف بعض المنتجات للبدء بالتسوق',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: const Text('استعراض المنتجات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final bool isFavorite;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onFavorite;

  const _CartItemCard({
    required this.item,
    required this.isFavorite,
    required this.onIncrement,
    required this.onDecrement,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: AppImage(imageData: item.image),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorite ? _brandRed : Colors.grey,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameAr,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.descriptionAr ?? '',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.price.toPrice()} د.ع',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: _brandRed, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              _QtyBtn(icon: Icons.add, onTap: onIncrement),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${item.count}',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              _QtyBtn(
                icon: item.count > 1 ? Icons.remove : Icons.delete_outline_rounded,
                color: item.count > 1 ? Colors.white : Colors.red.shade50,
                iconColor: item.count > 1 ? Colors.black87 : Colors.red,
                onTap: onDecrement,
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  const _QtyBtn({required this.icon, required this.onTap, this.color, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? Colors.black87),
      ),
    );
  }
}

class _DeliveryOptionCard extends StatelessWidget {
  final String title;
  final String time;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    required this.title,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? _brandRed : Colors.grey.shade200, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    color: selected ? _brandRed : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: _brandRed, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: selected ? _brandRed.withValues(alpha: 0.7) : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLarge;
  final Color? valueColor;

  const _SummaryRow({required this.label, required this.value, this.isLarge = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: isLarge ? FontWeight.w900 : FontWeight.w700,
            fontSize: isLarge ? 18 : 14,
            color: isLarge ? Colors.black : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: isLarge ? 22 : 16,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool border;
  final bool isLoading;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.textColor,
    this.border = false,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: border ? Border.all(color: Colors.grey.shade300) : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                label,
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 11, color: textColor),
              ),
      ),
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
  const _PickedLocation({required this.address, required this.latitude, required this.longitude});
}

class _CustomerMapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  const _CustomerMapPickerScreen({required this.initialLatitude, required this.initialLongitude});
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
          circleColor: _brandRed.value,
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
    if (token.isEmpty) return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    try {
      final uri = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?language=ar&country=iq&limit=1&access_token=$token');
      final response = await http.get(uri).timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is Map && payload['features'] is List) {
          final features = payload['features'] as List;
          if (features.isNotEmpty && features.first is Map) {
            return (features.first['place_name']?.toString() ?? '').trim();
          }
        }
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  Future<void> _confirmLocation() async {
    setState(() => _isResolving = true);
    await _readCenterFromMap();
    final address = await _reverseGeocode(_center.lat.toDouble(), _center.lng.toDouble());
    if (!mounted) return;
    Navigator.of(context).pop(_PickedLocation(address: address, latitude: _center.lat.toDouble(), longitude: _center.lng.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديد موقع التوصيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Stack(
          children: [
            MapWidget(
              styleUri: 'mapbox://styles/mapbox/streets-v12',
              cameraOptions: CameraOptions(center: Point(coordinates: _center), zoom: 14.0),
              onMapCreated: _onMapCreated,
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('حرّك الخريطة لتحديد موقعك بدقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResolving ? null : _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isResolving ? const CupertinoActivityIndicator(color: Colors.white) : const Text('تأكيد الموقع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
