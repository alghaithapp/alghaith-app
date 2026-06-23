import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../utils/polyline_decoder.dart';

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

  /// مسار القيادة — Google Directions ثم Mapbox كاحتياط.
  static Future<List<LatLng>> fetchDrivingRoute(LatLng from, LatLng to) async {
    final google = await _googleDirections(from, to);
    if (google.length >= 2) return google;
    return _mapboxDirections(from, to);
  }

  static Future<List<LatLng>> _googleDirections(LatLng from, LatLng to) async {
    if (!isGoogleConfigured) return const [];
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
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body);
      if (data is! Map || data['status'] != 'OK') return const [];
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return const [];

      final polyline =
          routes.first['overview_polyline']?['points']?.toString();
      if (polyline == null || polyline.isEmpty) return const [];
      return decodeGooglePolyline(polyline);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<LatLng>> _mapboxDirections(LatLng from, LatLng to) async {
    final token = AppConfig.effectiveMapboxPublicToken;
    if (token.isEmpty || !token.startsWith('pk.')) return const [];
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?geometries=geojson&access_token=$token'
        '&language=ar&overview=full',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return const [];
      final geometry = routes[0]['geometry'] as Map?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.length < 2) return const [];

      return coordinates
          .map(
            (c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _fallbackCoordsLabel(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
}
