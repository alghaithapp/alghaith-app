import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config/app_config.dart';

class PickedLocation {
  final String address;
  final double latitude;
  final double longitude;

  const PickedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static final LatLng _defaultCenter = LatLng(33.3152, 44.3661);

  final MapController _mapController = MapController();
  LatLng _center = _defaultCenter;
  bool _isResolving = false;
  String _resolvedAddress = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onPositionChanged(dynamic position, bool hasGesture) {
    if (!hasGesture) return;
    final center = _mapController.camera.center;
    if (!mounted) return;
    setState(() {
      _center = center;
      if (_resolvedAddress.isNotEmpty) {
        _resolvedAddress = '';
      }
    });
  }

  String get _centerSummary =>
      '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';

  Future<String> _reverseGeocode(double lat, double lng) async {
    if (!AppConfig.isMapboxConfigured) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    final token = AppConfig.effectiveMapboxPublicToken;
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
    final address = await _reverseGeocode(
      _center.latitude,
      _center.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolvedAddress = address;
      _isResolving = false;
    });
    Navigator.of(context).pop(
      PickedLocation(
        address: address,
        latitude: _center.latitude,
        longitude: _center.longitude,
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
    final target = LatLng(current.latitude, current.longitude);
    setState(() {
      _center = target;
    });
    _mapController.move(target, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.title,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // الخريطة — OpenStreetMap مجاناً بدون مفتاح
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 14.0,
                        onPositionChanged: _onPositionChanged,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tiles.openfreemap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.alghaith.app',
                        ),
                      ],
                    ),
                  ),
                  // الدبوس في منتصف الخريطة
                  const IgnorePointer(
                    child: Center(
                      child: _CenterLocationPin(),
                    ),
                  ),
                  // زر الموقع الحالي
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
            // الشريط السفلي
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resolvedAddress.isEmpty
                        ? 'حرّك الخريطة حتى يصبح الدبوس فوق الموقع المطلوب: $_centerSummary'
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
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
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

class _CenterLocationPin extends StatelessWidget {
  const _CenterLocationPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFF5A01D),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        Container(
          width: 2,
          height: 18,
          color: const Color(0xFFF5A01D),
        ),
      ],
    );
  }
}
