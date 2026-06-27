import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../utils/polyline_decoder.dart';
import '../utils/route_destination_trim.dart';
import '../utils/taxi_distance_calculator.dart';

/// اقتراح مكان من Google Places أو قاعدة محلية.
class TaxiPlaceSuggestion {
  final String displayName;
  final String? subtitle;
  final LatLng? latLng;
  final String? googlePlaceId;

  const TaxiPlaceSuggestion({
    required this.displayName,
    this.subtitle,
    this.latLng,
    this.googlePlaceId,
  });
}

/// مسار قيادة مع مدة ومسافة من واجهة Directions.
class TaxiDrivingRoute {
  final List<LatLng> points;
  final int? durationSeconds;
  final double? distanceMeters;
  final bool isApproximate;

  const TaxiDrivingRoute({
    this.points = const [],
    this.durationSeconds,
    this.distanceMeters,
    this.isApproximate = false,
  });

  double? get distanceKm {
    final meters = distanceMeters;
    if (meters == null || meters <= 0) return null;
    return meters / 1000.0;
  }
}

/// بحث الأماكن والمسارات عبر Google Maps (نفس بيانات تطبيق Google Maps).
class TaxiPlacesService {
  static const _biasLat = 32.9256;
  static const _biasLng = 44.7766;

  static String get _apiKey => AppConfig.googleMapsApiKey;

  static bool get isGoogleConfigured =>
      _apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_');

  /// اقتراحات أماكن — Google Places Autocomplete.
  static Future<List<TaxiPlaceSuggestion>> autocomplete(
    String query, {
    LatLng? bias,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !isGoogleConfigured) return [];

    final center = bias ?? const LatLng(_biasLat, _biasLng);
    try {
      final params = {
        'input': trimmed,
        'key': _apiKey,
        'language': 'ar',
        'components': 'country:iq',
        'location': '${center.latitude},${center.longitude}',
        'radius': '80000',
      };
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        params,
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! Map || data['status'] != 'OK') return [];

      final predictions = data['predictions'];
      if (predictions is! List) return [];

      return predictions.take(10).map((item) {
        if (item is! Map) {
          return const TaxiPlaceSuggestion(displayName: '');
        }
        final main =
            (item['structured_formatting']?['main_text'] ?? item['description'])
                ?.toString()
                .trim();
        final secondary =
            item['structured_formatting']?['secondary_text']?.toString().trim();
        final description = item['description']?.toString().trim();
        return TaxiPlaceSuggestion(
          displayName: (main?.isNotEmpty == true ? main! : description) ?? '',
          subtitle: secondary,
          googlePlaceId: item['place_id']?.toString(),
        );
      }).where((s) => s.displayName.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// تفاصيل مكان (إحداثيات دقيقة) من place_id.
  static Future<TaxiPlaceSuggestion?> placeDetails(String placeId) async {
    if (placeId.trim().isEmpty || !isGoogleConfigured) return null;
    try {
      final params = {
        'place_id': placeId,
        'key': _apiKey,
        'language': 'ar',
        'fields': 'geometry,formatted_address,name',
      };
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        params,
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map || data['status'] != 'OK') return null;
      final result = data['result'];
      if (result is! Map) return null;

      final location = result['geometry']?['location'];
      if (location is! Map) return null;
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final name = result['name']?.toString().trim();
      final formatted = result['formatted_address']?.toString().trim();
      return TaxiPlaceSuggestion(
        displayName: (formatted?.isNotEmpty == true
                ? formatted!
                : name?.isNotEmpty == true
                    ? name!
                    : 'موقع محدد'),
        latLng: LatLng(lat, lng),
        googlePlaceId: placeId,
      );
    } catch (_) {
      return null;
    }
  }

  /// تحويل الإحداثيات إلى عنوان (Google Geocoding).
  static Future<String> reverseGeocode(LatLng point) async {
    if (!isGoogleConfigured) {
      return _fallbackCoordsLabel(point);
    }
    try {
      final params = {
        'latlng': '${point.latitude},${point.longitude}',
        'key': _apiKey,
        'language': 'ar',
        'result_type': 'street_address|route|neighborhood|locality|sublocality',
      };
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        params,
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return _fallbackCoordsLabel(point);

      final data = jsonDecode(response.body);
      if (data is! Map || data['status'] != 'OK') {
        return _fallbackCoordsLabel(point);
      }
      final results = data['results'];
      if (results is List && results.isNotEmpty) {
        final address = results.first['formatted_address']?.toString().trim();
        if (address != null && address.isNotEmpty) return address;
      }
    } catch (_) {}
    return _fallbackCoordsLabel(point);
  }

  /// مسار القيادة — الخادم أولاً ثم Google ثم Mapbox ثم خط مباشر.
  static Future<TaxiDrivingRoute> fetchDrivingRoute(LatLng from, LatLng to) async {
    final backend = await _backendDirections(from, to);
    if (backend.points.length >= 2) return _finalizeDrivingRoute(backend, to);

    final google = await _googleDirections(from, to);
    if (google.points.length >= 2) return _finalizeDrivingRoute(google, to);

    final mapbox = await _mapboxDirections(from, to);
    if (mapbox.points.length >= 2) return _finalizeDrivingRoute(mapbox, to);

    return _finalizeDrivingRoute(_straightLineRoute(from, to), to);
  }

  static TaxiDrivingRoute _finalizeDrivingRoute(
    TaxiDrivingRoute route,
    LatLng destination,
  ) {
    if (route.points.length < 2) return route;
    final trimmed = trimRouteNearDestination(
      points: route.points,
      destination: destination,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
    );
    return TaxiDrivingRoute(
      points: trimmed.points,
      distanceMeters: trimmed.distanceMeters,
      durationSeconds: trimmed.durationSeconds,
      isApproximate: route.isApproximate,
    );
  }

  static Future<TaxiDrivingRoute> _backendDirections(LatLng from, LatLng to) async {
    if (!AppConfig.isBackendConfigured) return const TaxiDrivingRoute();
    try {
      final result = await ApiClient.instance.post(
        '/maps/driving-route',
        body: {
          'pickupLatitude': from.latitude,
          'pickupLongitude': from.longitude,
          'dropoffLatitude': to.latitude,
          'dropoffLongitude': to.longitude,
        },
      );
      if (result is! Map) return const TaxiDrivingRoute();

      final rawPoints = result['points'];
      if (rawPoints is! List || rawPoints.length < 2) {
        return const TaxiDrivingRoute();
      }

      final points = <LatLng>[];
      for (final entry in rawPoints) {
        if (entry is! Map) continue;
        final lat = (entry['latitude'] as num?)?.toDouble();
        final lng = (entry['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.length < 2) return const TaxiDrivingRoute();

      final distanceMeters = (result['distanceMeters'] as num?)?.toDouble();
      final durationSeconds = (result['durationSeconds'] as num?)?.toInt();

      return TaxiDrivingRoute(
        points: points,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
      );
    } catch (_) {
      return const TaxiDrivingRoute();
    }
  }

  static TaxiDrivingRoute _straightLineRoute(LatLng from, LatLng to) {
    const steps = 24;
    final points = <LatLng>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
      );
    }

    final distanceKm = TaxiDistanceCalculator.calculateDistance(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    return TaxiDrivingRoute(
      points: points,
      distanceMeters: distanceKm * 1000,
      durationSeconds:
          TaxiDistanceCalculator.estimateDrivingDurationSeconds(distanceKm),
      isApproximate: true,
    );
  }

  static Future<TaxiDrivingRoute> _googleDirections(LatLng from, LatLng to) async {
    if (!isGoogleConfigured) return const TaxiDrivingRoute();
    try {
      final params = {
        'origin': '${from.latitude},${from.longitude}',
        'destination': '${to.latitude},${to.longitude}',
        'key': _apiKey,
        'language': 'ar',
        'mode': 'driving',
      };
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        params,
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const TaxiDrivingRoute();

      final data = jsonDecode(response.body);
      if (data is! Map || data['status'] != 'OK') return const TaxiDrivingRoute();
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return const TaxiDrivingRoute();

      final route = routes.first;
      if (route is! Map) return const TaxiDrivingRoute();

      final polyline = route['overview_polyline']?['points']?.toString();
      if (polyline == null || polyline.isEmpty) return const TaxiDrivingRoute();

      int? durationSeconds;
      double? distanceMeters;
      final legs = route['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map) continue;
          final legDuration = (leg['duration']?['value'] as num?)?.toInt();
          final legDistance = (leg['distance']?['value'] as num?)?.toDouble();
          if (legDuration != null && legDuration > 0) {
            durationSeconds = (durationSeconds ?? 0) + legDuration;
          }
          if (legDistance != null && legDistance > 0) {
            distanceMeters = (distanceMeters ?? 0) + legDistance;
          }
        }
      }

      return TaxiDrivingRoute(
        points: decodeGooglePolyline(polyline),
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
      );
    } catch (_) {
      return const TaxiDrivingRoute();
    }
  }

  static Future<TaxiDrivingRoute> _mapboxDirections(LatLng from, LatLng to) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty || !token.startsWith('pk.')) return const TaxiDrivingRoute();
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?geometries=geojson&access_token=$token'
        '&language=ar&overview=full&approaches=unrestricted;curb',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const TaxiDrivingRoute();

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return const TaxiDrivingRoute();
      final route = routes[0];
      if (route is! Map) return const TaxiDrivingRoute();

      final geometry = route['geometry'] as Map?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.length < 2) {
        return const TaxiDrivingRoute();
      }

      final durationSeconds = (route['duration'] as num?)?.round();
      final distanceMeters = (route['distance'] as num?)?.toDouble();

      return TaxiDrivingRoute(
        points: coordinates
            .map(
              (c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ),
            )
            .toList(),
        durationSeconds:
            durationSeconds != null && durationSeconds > 0 ? durationSeconds : null,
        distanceMeters:
            distanceMeters != null && distanceMeters > 0 ? distanceMeters : null,
      );
    } catch (_) {
      return const TaxiDrivingRoute();
    }
  }

  static String _fallbackCoordsLabel(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
}
