import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
          circleColor: const Color(0xFFF5A01D).value,
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
    if (!AppConfig.isMapboxConfigured) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    final token = AppConfig.mapboxPublicToken.trim();
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
      PickedLocation(
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
    setState(() {
      _center = target;
      if (!AppConfig.isMapboxConfigured) {
        _resolvedAddress =
            '${target.lat.toDouble().toStringAsFixed(5)}, ${target.lng.toDouble().toStringAsFixed(5)}';
      }
    });
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
                  if (AppConfig.isMapboxConfigured)
                    Positioned.fill(
                      child: MapWidget(
                        styleUri: 'mapbox://styles/mapbox/streets-v12',
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: _center),
                          zoom: 14.0,
                        ),
                        onMapCreated: _onMapCreated,
                      ),
                    )
                  else
                    const Positioned.fill(
                      child: _MapUnavailableNotice(),
                    ),
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

class _MapUnavailableNotice extends StatelessWidget {
  const _MapUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF0),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 52, color: Color(0xFF607D8B)),
          SizedBox(height: 14),
          Text(
            'الخريطة غير متاحة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'مفتاح Mapbox (MAPBOX_PUBLIC_TOKEN) غير مضبوط في هذا البناء.\n'
            'بدون المفتاح تظهر الإحداثيات فقط بدل الخريطة والعنوان.\n'
            'استخدم زر «موقعي» ثم «تأكيد» مؤقتاً، أو أضف المفتاح عند التشغيل.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF5A6B6E),
            ),
          ),
        ],
      ),
    );
  }
}
