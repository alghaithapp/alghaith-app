import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/navigation/customer_navigation.dart';
import '../../../core/ui/app_bottom_nav_style.dart';
import '../../../models/app_models.dart';
import '../../../utils/extensions.dart';
import '../../../utils/guest_gate.dart';
import '../../../widgets/location_picker_screen.dart';
import 'catalog_search_screen.dart';
import 'cart_shared_widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckingOut = false;
  bool _isLocating = false;
  bool _isCalculatingDelivery = false;
  bool _isApplyingPromo = false;
  int _deliveryFeeIqd = 0;
  Map<String, int> _merchantDeliveryFees = {};
  double? _deliveryDistanceKm;
  String? _lastAutoCalcSignature;
  bool _autoCalcScheduled = false;

  // 1: Normal, 2: Fast
  int _deliveryOption = 1;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      final appliedPromo = provider.appliedCartPromo;
      if (appliedPromo != null) {
        _promoController.text = appliedPromo.code;
      }
      if (provider.cart.isNotEmpty &&
          provider.customerAddress.trim().isNotEmpty) {
        unawaited(_recalculateDeliveryFee(provider));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode(AppProvider provider) async {
    if (_isApplyingPromo) return;
    final code = _promoController.text.trim();
    if (provider.appliedCartPromo != null &&
        provider.appliedCartPromo!.code.toUpperCase() == code.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'كود الخصم مطبّق بالفعل.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    setState(() => _isApplyingPromo = true);
    try {
      final result = await provider.applyCartPromoCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.messageAr,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: result.success ? const Color(0xFF15803D) : null,
        ),
      );
      if (result.success && result.promo != null) {
        _promoController.text = result.promo!.code;
      }
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  void _onHeaderCartTap(AppProvider provider) {
    if (_scrollController.hasClients && _scrollController.offset > 80) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const CatalogSearchScreen()),
    );
  }

  String _merchantAddress(List<dynamic> cart) {
    for (final item in cart) {
      final address = item.merchantAddress?.toString().trim() ?? '';
      if (address.isNotEmpty) return address;
    }
    return '';
  }

  CartGeoPoint? _merchantLocation(List<dynamic> cart) {
    for (final item in cart) {
      final lat = (item.merchantLatitude as num?)?.toDouble();
      final lng = (item.merchantLongitude as num?)?.toDouble();
      if (lat != null && lng != null) {
        return CartGeoPoint(lat, lng);
      }
    }
    return null;
  }

  Future<double?> _fetchRoadDistanceKm({
    required String merchantAddress,
    required String customerAddress,
    required CartGeoPoint? merchantLocation,
    required CartGeoPoint? customerLocation,
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
              'routeProfile': 'delivery',
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

  double? _straightLineDistanceKm(CartGeoPoint? origin, CartGeoPoint? destination) {
    if (origin == null || destination == null) return null;
    final meters = geo.Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (!meters.isFinite || meters <= 0) return null;
    // الطريق الفعلي أطول من الخط المستقيم؛ نطبّق معامل تصحيح حتى لا
    // يقلّ سعر التوصيل عند تعذّر مسار Mapbox.
    return (meters / 1000) * AppConfig.straightLineRoadFactor;
  }

  Future<void> _recalculateDeliveryFee(AppProvider appProvider) async {
    final sig = _autoCalcSignature(appProvider);
    _lastAutoCalcSignature = sig;

    if (appProvider.cart.isEmpty) {
      setState(() {
        _deliveryFeeIqd = 0;
        _merchantDeliveryFees = {};
        _deliveryDistanceKm = null;
      });
      return;
    }

    final isBazarCart = appProvider.cart.first.category == 'bazar_ghaith';

    final customerAddress = appProvider.customerAddress.trim();
    final customerLocation = (appProvider.customerLatitude != null &&
            appProvider.customerLongitude != null)
        ? CartGeoPoint(
            appProvider.customerLatitude!, appProvider.customerLongitude!)
        : null;

    if (customerAddress.isEmpty && customerLocation == null) {
      setState(() {
        _deliveryFeeIqd = 0;
        _merchantDeliveryFees = {};
        _deliveryDistanceKm = null;
      });
      return;
    }

    setState(() => _isCalculatingDelivery = true);

    try {
      // تجميع المنتجات حسب المتجر
      final grouped = <String, List<CartItem>>{};
      for (final item in appProvider.cart) {
        final phone = item.merchantPhone ?? 'unknown';
        grouped.putIfAbsent(phone, () => []).add(item);
      }

      int totalFee = 0;
      double maxDistance = 0;
      final newMerchantFees = <String, int>{};

      // إذا كان بازار، نحسب كلفة واحدة للمجموعة كاملة (لأول متجر مثلاً أو الأبعد)
      if (isBazarCart) {
        // نأخذ أول متجر كممثل للمجموعة في البازار
        final representative = appProvider.cart.first;
        final mLoc = (representative.merchantLatitude != null &&
                representative.merchantLongitude != null)
            ? CartGeoPoint(representative.merchantLatitude!,
                representative.merchantLongitude!)
            : null;
        final mAddr = representative.merchantAddress ?? '';

        final dist = await _calculateSingleDistance(
          mAddr,
          customerAddress,
          mLoc,
          customerLocation,
        );

        if (dist != null && dist > 0) {
          totalFee = AppConfig.calculateBazarDeliveryFee(dist);
          maxDistance = dist;
        }
      } else {
        // في الأقسام الأخرى، نحسب لكل متجر على حدة ونجمع
        for (final entry in grouped.entries) {
          final phone = entry.key;
          final items = entry.value;
          final first = items.first;

          final mLoc = (first.merchantLatitude != null &&
                  first.merchantLongitude != null)
              ? CartGeoPoint(first.merchantLatitude!, first.merchantLongitude!)
              : null;
          final mAddr = first.merchantAddress ?? '';

          final dist = await _calculateSingleDistance(
            mAddr,
            customerAddress,
            mLoc,
            customerLocation,
          );

          if (dist != null && dist > 0) {
            final fee = AppConfig.calculateDeliveryFee(dist);
            newMerchantFees[phone] = fee;
            totalFee += fee;
            if (dist > maxDistance) maxDistance = dist;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _deliveryFeeIqd = totalFee;
        _merchantDeliveryFees = newMerchantFees;
        _deliveryDistanceKm = maxDistance > 0 ? maxDistance : null;
      });
    } finally {
      if (mounted) setState(() => _isCalculatingDelivery = false);
    }
  }

  Future<double?> _calculateSingleDistance(
    String mAddr,
    String cAddr,
    CartGeoPoint? mLoc,
    CartGeoPoint? cLoc,
  ) async {
    if (mAddr.isEmpty && mLoc == null) return null;

    final roadKm = await _fetchRoadDistanceKm(
      merchantAddress: mAddr,
      customerAddress: cAddr,
      merchantLocation: mLoc,
      customerLocation: cLoc,
    );

    if (roadKm != null && roadKm > 0) return roadKm;

    return _straightLineDistanceKm(mLoc, cLoc);
  }

  String? _autoCalcSignature(AppProvider appProvider) {
    if (appProvider.cart.isEmpty) return null;
    final merchantAddress = _merchantAddress(appProvider.cart).trim();
    final merchantLocation = _merchantLocation(appProvider.cart);
    final customerAddress = appProvider.customerAddress.trim();
    final customerLat = appProvider.customerLatitude;
    final customerLng = appProvider.customerLongitude;
    final hasMerchant = merchantLocation != null || merchantAddress.isNotEmpty;
    final hasCustomer = (customerLat != null && customerLng != null) ||
        customerAddress.isNotEmpty;
    if (!hasMerchant || !hasCustomer) return null;
    final cartSignature =
        appProvider.cart.map((item) => '${item.id}:${item.count}').join('|');
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
      final latestSignature = _autoCalcSignature(appProvider);
      if (latestSignature == null ||
          latestSignature == _lastAutoCalcSignature) {
        return;
      }
      _lastAutoCalcSignature = latestSignature;
      await _recalculateDeliveryFee(appProvider);
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
            const SnackBar(
                content: Text('يرجى تفعيل خدمة الموقع في الهاتف.',
                    style: TextStyle(fontFamily: 'Cairo'))),
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
            const SnackBar(
                content: Text('تم رفض إذن الموقع.',
                    style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
        return;
      }
      final current = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      String addressText =
          '${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)}';
      if (AppConfig.isMapboxConfigured) {
        final token = AppConfig.effectiveMapboxPublicToken;
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
    final result = await Navigator.of(context).push<PickedLocation>(
      CupertinoPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'تحديد موقع التوصيل',
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
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإتمام الشراء ومتابعة طلبك.',
    )) {
      return;
    }
    if (appProvider.customerLatitude == null ||
        appProvider.customerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك من الخريطة قبل إتمام الطلب.',
              style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }
    if (appProvider.customerAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك أولاً لحساب رسوم التوصيل.',
              style: TextStyle(fontFamily: 'Cairo')),
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
            content: Text('تعذر حساب رسوم التوصيل. حاول تحديد موقعك مجدداً.',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        );
        return;
      }
    }
    setState(() => _isCheckingOut = true);
    try {
      final count = await appProvider.checkout(
        deliveryFeeIqd:
            _deliveryOption == 2 ? (_deliveryFeeIqd + 2000) : _deliveryFeeIqd,
        merchantDeliveryFees: _merchantDeliveryFees,
        orderNotes: _notesController.text.trim(),
      );
      if (!mounted || count == 0) return;
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('تم تقديم الطلب بنجاح!',
              style: TextStyle(fontFamily: 'Cairo')),
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
    final restaurantName =
        cart.isNotEmpty ? (cart.first.merchantStoreName ?? 'المطعم') : '';

    final finalDeliveryFee =
        _deliveryOption == 2 ? (_deliveryFeeIqd + 2000) : _deliveryFeeIqd;
    final subtotal = appProvider.cartTotal;
    final promoDiscount = appProvider.cartPromoDiscountIqd;
    final totalAmount = subtotal - promoDiscount + finalDeliveryFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: cart.isEmpty
            ? _buildEmptyState(appProvider)
            : Stack(
                children: [
                  Column(
                    children: [
                      _buildHeader(
                          context, cart.length, restaurantName, appProvider),
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 170),
                          children: [
                            ...cart.map((item) => CartItemCard(
                                  item: item,
                                  isFavorite: appProvider.isFavoriteId(item.id),
                                  onIncrement: () =>
                                      appProvider.incrementCartItem(item.id),
                                  onDecrement: () {
                                    if (item.count > 1) {
                                      appProvider.decrementCartItem(item.id);
                                    } else {
                                      appProvider.removeFromCart(item.id);
                                    }
                                  },
                                  onFavorite: () =>
                                      appProvider.toggleFavorite(item.id),
                                )),
                            const SizedBox(height: 12),
                            _buildLocationSection(appProvider),
                            if (cart.isNotEmpty &&
                                cart.first.category != 'bazar_ghaith') ...[
                              const SizedBox(height: 24),
                              _buildDeliveryOptions(),
                            ],
                            const SizedBox(height: 24),
                            _buildPromoSection(appProvider),
                            const SizedBox(height: 24),
                            _buildOrderSummary(
                              subtotal,
                              promoDiscount,
                              finalDeliveryFee,
                              totalAmount,
                              appProvider.appliedCartPromo?.labelAr,
                            ),
                            const SizedBox(height: 24),
                            _buildNotesSection(),
                            const SizedBox(height: 24),
                            _buildPaymentNotice(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildStickyCheckoutBar(
                      totalAmount, cart.length, appProvider),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int count,
    String restaurant,
    AppProvider provider,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CartCircleIconButton(
            icon: Icons.arrow_forward_ios_rounded,
            onTap: () => goToCustomerHome(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'سلة المشتريات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (count > 0 && restaurant.isNotEmpty)
                    Text(
                      provider.cartHasMultipleMerchants
                          ? '$count ${count == 1 ? 'صنف' : 'أصناف'} من بازار ومطاعم الغيث'
                          : '$count ${count == 1 ? 'صنف' : 'أصناف'} من $restaurant',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CartCircleIconButton(
                icon: Icons.shopping_cart_outlined,
                onTap: () => _onHeaderCartTap(provider),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: cartBrandRed,
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
        ],
      ),
    );
  }

  Widget _buildLocationSection(AppProvider appProvider) {
    final hasLocation = appProvider.customerLatitude != null &&
        appProvider.customerLongitude != null;
    final address = appProvider.customerAddress.trim();
    final addressLines = _splitAddressLines(address);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'موقع التوصيل',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasLocation) ...[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.location_searching_rounded,
                              color: cartBrandRed.withValues(alpha: 0.7),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لم يتم تحديد الموقع بعد',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'حدد موقعك لحساب رسوم التوصيل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: cartBrandRed,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            addressLines.title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          if (addressLines.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              addressLines.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        CartPillButton(
                          label: 'تحديد موقعي',
                          filled: true,
                          isLoading: _isLocating,
                          onTap: () => _detectCurrentLocation(appProvider),
                        ),
                        const SizedBox(height: 8),
                        CartPillButton(
                          label: 'اختيار من الخريطة',
                          filled: false,
                          onTap: () => _pickLocationFromMap(appProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: CartMiniMapPreview(
                    latitude: appProvider.customerLatitude,
                    longitude: appProvider.customerLongitude,
                    distanceKm: _deliveryDistanceKm,
                    isCalculating: _isCalculatingDelivery,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ({String title, String subtitle}) _splitAddressLines(String address) {
    if (address.isEmpty) {
      return (title: 'الموقع محدد', subtitle: '');
    }
    final parts = address
        .split('،')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 1) {
      return (title: address, subtitle: '');
    }
    return (title: parts.first, subtitle: parts.sublist(1).join('، '));
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'خيارات التوصيل',
          style: TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CartDeliveryOptionCard(
                title: 'توصيل عادي',
                selected: _deliveryOption == 1,
                onTap: () => setState(() => _deliveryOption = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CartDeliveryOptionCard(
                title: 'توصيل سريع',
                selected: _deliveryOption == 2,
                onTap: () => setState(() => _deliveryOption = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPromoSection(AppProvider provider) {
    final appliedPromo = provider.appliedCartPromo;
    final discount = provider.cartPromoDiscountIqd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'كود الخصم',
          style: TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  enabled: !_isApplyingPromo,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _applyPromoCode(provider),
                  decoration: const InputDecoration(
                    hintText: 'أدخل رمز الخصم',
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: CartSmallButton(
                  label: provider.appliedCartPromo != null ? 'إزالة' : 'تطبيق',
                  color: provider.appliedCartPromo != null
                      ? Colors.grey.shade100
                      : cartBrandRed,
                  textColor: provider.appliedCartPromo != null
                      ? Colors.black87
                      : Colors.white,
                  border: provider.appliedCartPromo != null,
                  isLoading: _isApplyingPromo,
                  onTap: () {
                    if (provider.appliedCartPromo != null) {
                      provider.clearCartPromo();
                      _promoController.clear();
                      return;
                    }
                    unawaited(_applyPromoCode(provider));
                  },
                ),
              ),
            ],
          ),
        ),
        if (appliedPromo != null && discount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${appliedPromo.labelAr} (-${discount.toPrice()} \u062f.\u0639)',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF166534),
              ),
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
          style: TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'ملاحظات إضافية للمطعم أو المندوب',
              hintStyle: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(
    int subtotal,
    int promoDiscount,
    int delivery,
    int total,
    String? promoLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملخص الطلب',
          style: TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              CartSummaryRow(
                  label: 'مجموع سعر المنتجات', value: '${subtotal.toPrice()} د.ع'),
              if (promoDiscount > 0) ...[
                const SizedBox(height: 14),
                CartSummaryRow(
                  label: promoLabel ?? '\u062e\u0635\u0645',
                  value: '-${promoDiscount.toPrice()} د.ع',
                  valueColor: const Color(0xFF15803D),
                ),
              ],
              const SizedBox(height: 14),
              CartSummaryRow(
                label: 'رسوم التوصيل',
                value:
                    delivery > 0 ? '${delivery.toPrice()} د.ع' : 'حدد الموقع',
                valueColor: delivery > 0 ? Colors.black : Colors.red,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              CartSummaryRow(
                label: 'المجموع الكلي',
                value: '${total.toPrice()} د.ع',
                isLarge: true,
                valueColor: cartBrandRed,
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
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF9A3412)),
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى تجهيز المبلغ المطلوب عند الاستلام',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.orange.shade800),
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
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              gradient: cartBrandRedGradient,
              borderRadius: BorderRadius.circular(42),
              boxShadow: [
                BoxShadow(
                  color: cartBrandRed.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(42),
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
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            '$count ${count == 1 ? 'صنف' : 'أصناف'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
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
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Column(
      children: [
        _buildHeader(context, 0, '', provider),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cartBrandRed.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 88,
                      color: cartBrandRed.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'سلتك فارغة حالياً',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'أضف بعض المنتجات للبدء بالتسوق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  AppBottomNavStyle.primaryActionButton(
                    onPressed: () => goToCustomerHome(context),
                    child: const Text(
                      'استعراض المنتجات',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
