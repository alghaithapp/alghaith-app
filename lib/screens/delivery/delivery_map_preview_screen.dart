import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/app_models.dart';
import '../../utils/helpers.dart';
import 'delivery_shared_widgets.dart';

class DeliveryMapPreviewScreen extends StatefulWidget {
  final ActiveOrder order;

  const DeliveryMapPreviewScreen({super.key, required this.order});

  @override
  State<DeliveryMapPreviewScreen> createState() =>
      _DeliveryMapPreviewScreenState();
}

class _DeliveryMapPreviewScreenState extends State<DeliveryMapPreviewScreen> {
  LatLng? _courierPosition;

  LatLng? get _customerPosition {
    final lat = widget.order.customerLatitude;
    final lng = widget.order.customerLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _merchantPosition {
    final lat = widget.order.merchantLatitude;
    final lng = widget.order.merchantLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng get _initialPosition =>
      _merchantPosition ?? _customerPosition ?? const LatLng(33.3152, 44.3661);

  void _onMapReady() {
    unawaited(_loadCourierPosition());
  }

  Future<void> _loadCourierPosition() async {
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
    setState(() {
      _courierPosition = LatLng(current.latitude, current.longitude);
    });
  }

  VoidCallback? _externalNavigationAction() {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final statusKey = widget.order.deliveryStatusKey ?? '';
    final courierLat = _courierPosition?.latitude;
    final courierLng = _courierPosition?.longitude;

    if (statusKey == 'accepted' && merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (const {'picked_up', 'on_way'}.contains(statusKey) &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null &&
        merchantLng != null &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: merchantLat,
            originLongitude: merchantLng,
            travelMode: 'walking',
          );
    }

    if (customerLat != null && customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            travelMode: 'walking',
          );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final hasCustomer = customerLat != null && customerLng != null;
    final hasMerchant = merchantLat != null && merchantLng != null;
    if (!hasCustomer && !hasMerchant) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('الخريطة'),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'هذا الطلب لا يحتوي إحداثيات موقع.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'خريطة التوصيل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _externalNavigationAction(),
          child: const Text(
            'فتح الخرائط',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _initialPosition,
                  initialZoom: 14.8,
                  onMapReady: _onMapReady,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'AlGhaithApp/1.2.59 (com.alghaith.app)',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_merchantPosition != null)
                        Marker(
                          point: _merchantPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 18,
                            height: 18,
                          ),
                        ),
                      if (_customerPosition != null)
                        Marker(
                          point: _customerPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5A01D),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 18,
                            height: 18,
                          ),
                        ),
                      if (_courierPosition != null)
                        Marker(
                          point: _courierPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 16,
                            height: 16,
                          ),
                        ),
                    ],
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
                  if (hasMerchant)
                    DeliveryMapInfoLine(
                      color: const Color(0xFF1976D2),
                      label: 'المتجر',
                      value:
                          '${widget.order.merchantStoreName ?? '-'} · ${merchantLat!.toStringAsFixed(5)}, ${merchantLng!.toStringAsFixed(5)}',
                    ),
                  if (hasCustomer) ...[
                    const SizedBox(height: 6),
                    DeliveryMapInfoLine(
                      color: const Color(0xFFF5A01D),
                      label: 'الزبون',
                      value:
                          '${widget.order.addressAr} · ${customerLat!.toStringAsFixed(5)}, ${customerLng!.toStringAsFixed(5)}',
                    ),
                  ],
                  if (_courierPosition != null) ...[
                    const SizedBox(height: 6),
                    const DeliveryMapInfoLine(
                      color: Color(0xFF2E7D32),
                      label: 'موقعك',
                      value: 'موقع المندوب الحالي',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
