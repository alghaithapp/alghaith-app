import '../../../core/network/api_client.dart';
import '../models/taxi_favorite_place.dart';

class TaxiFavoritesService {
  static const _basePath = '/db/taxi/favorite-places';

  static Future<List<TaxiFavoritePlace>> loadPlaces() async {
    final result = await ApiClient.instance.get(_basePath);
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => TaxiFavoritePlace.fromMap(Map<String, dynamic>.from(item)))
        .where((place) => place.address.isNotEmpty && place.lat != 0 && place.lng != 0)
        .toList();
  }

  static Future<List<TaxiFavoritePlace>> savePlace(TaxiFavoritePlace place) async {
    final result = await ApiClient.instance.put(
      _basePath,
      body: place.toJson(),
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => TaxiFavoritePlace.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<TaxiFavoritePlace>> deletePlace(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return const [];
    final result = await ApiClient.instance.delete('$_basePath/$trimmed');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => TaxiFavoritePlace.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
