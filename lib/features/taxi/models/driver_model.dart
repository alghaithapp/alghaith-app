import 'taxi_request.dart';

/// نموذج بيانات السائق
class DriverModel {
  final String phone;
  final String name;
  final TaxiType taxiType;
  final String vehicleModel;
  final String plateNumber;
  final String color;
  final String area;
  final double rating;
  final int totalTrips;
  final bool isAvailable;
  final bool isOnline;
  final bool isApproved;
  final double? currentLat;
  final double? currentLng;
  final List<String> services;

  const DriverModel({
    required this.phone,
    this.name = '',
    this.taxiType = TaxiType.economic,
    this.vehicleModel = '',
    this.plateNumber = '',
    this.color = '',
    this.area = '',
    this.rating = 0.0,
    this.totalTrips = 0,
    this.isAvailable = false,
    this.isOnline = false,
    this.isApproved = false,
    this.currentLat,
    this.currentLng,
    this.services = const [],
  });

  String get vehicleInfo => '$vehicleModel • $plateNumber';

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'taxiType': taxiType.name,
      'vehicleModel': vehicleModel,
      'plateNumber': plateNumber,
      'color': color,
      'area': area,
      'rating': rating,
      'totalTrips': totalTrips,
      'isAvailable': isAvailable,
      'isOnline': isOnline,
      'isApproved': isApproved,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'services': services,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      phone: (map['phone'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      taxiType: TaxiType.values.firstWhere(
        (e) => e.name == map['taxiType'],
        orElse: () => TaxiType.economic,
      ),
      vehicleModel: (map['vehicleModel'] as String?) ?? '',
      plateNumber: (map['plateNumber'] as String?) ?? '',
      color: (map['color'] as String?) ?? '',
      area: (map['area'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (map['totalTrips'] as num?)?.toInt() ?? 0,
      isAvailable: (map['isAvailable'] as bool?) ?? false,
      isOnline: (map['isOnline'] as bool?) ?? false,
      isApproved: (map['isApproved'] as bool?) ?? false,
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      services: map['services'] is List
          ? (map['services'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}
