import 'package:latlong2/latlong.dart';

/// مكان مفضل للزبون داخل خدمة التكسي.
class TaxiFavoritePlace {
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final int sortOrder;

  const TaxiFavoritePlace({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.sortOrder = 0,
  });

  LatLng get coord => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
        'sortOrder': sortOrder,
      };

  factory TaxiFavoritePlace.fromMap(Map<String, dynamic> map) {
    return TaxiFavoritePlace(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?)?.trim() ?? 'مكان مفضل',
      address: (map['address'] as String?)?.trim() ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
