import 'package:flutter/material.dart';

/// أنواع خدمة التنقل
enum TaxiType { tuktuk, wazz, economic }

extension TaxiTypeX on TaxiType {
  String get toApiName {
    switch (this) {
      case TaxiType.tuktuk:
        return 'tuktuk';
      case TaxiType.wazz:
        return 'wazz';
      case TaxiType.economic:
        return 'economic';
    }
  }

  String get labelAr {
    switch (this) {
      case TaxiType.tuktuk:
        return 'تكتك';
      case TaxiType.wazz:
        return 'واز جيب';
      case TaxiType.economic:
        return 'تكسي اقتصادي';
    }
  }

  String get subtitleAr {
    switch (this) {
      case TaxiType.tuktuk:
        return 'رحلة اقتصادية';
      case TaxiType.wazz:
        return 'سيارة جيب';
      case TaxiType.economic:
        return '4 مقاعد، سيارة';
    }
  }

  /// مسار صورة النوع داخل assets/images/
  String get imageAsset {
    switch (this) {
      case TaxiType.tuktuk:
        return 'assets/images/taxi_tuktuk.png';
      case TaxiType.wazz:
        return 'assets/images/taxi_wazz.png';
      case TaxiType.economic:
        return 'assets/images/taxi_economy.png';
    }
  }

  /// للعرض في تفاصيل الطلب للزبون
  String get customerServiceLabelAr => labelAr;

  IconData get icon {
    switch (this) {
      case TaxiType.tuktuk:
        return Icons.electric_rickshaw_rounded;
      case TaxiType.wazz:
        return Icons.two_wheeler_rounded;
      case TaxiType.economic:
        return Icons.local_taxi_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case TaxiType.tuktuk:
        return const Color(0xFF2E7D32);
      case TaxiType.wazz:
        return const Color(0xFF1565C0);
      case TaxiType.economic:
        return const Color(0xFF1B5E20);
    }
  }

  static TaxiType fromApiName(String? name) {
    switch (name?.trim().toLowerCase()) {
      case 'tuktuk':
      case 'tuk_tuk':
        return TaxiType.tuktuk;
      case 'wazz':
        return TaxiType.wazz;
      case 'super':
      case 'economic':
      default:
        return TaxiType.economic;
    }
  }
}

/// نموذج طلب التكسي
class TaxiRequest {
  final String id;
  final String requestNumber; // TX-XXXXXX
  final String customerName; // فقط اسم أول + أب
  final String customerPhone; // مخفي عن السائق حتى القبول
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final TaxiType taxiType;
  final int fareEconomic;
  final int fareSuper;
  final int fare;
  final String statusKey; // pending -> accepted -> arrived -> picked_up -> completed / cancelled
  final String statusAr;
  final int driverRating;
  final bool cashCollected;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicleInfo;
  final String? vehicleModel;
  final String? plateNumber;
  final double? driverLat;
  final double? driverLng;
  final List<String> rejectedByDriverIds;
  final String? cancellationReason;
  final bool isPaid;
  final String? noteAr;
  final String? assignedDriverName;

  const TaxiRequest({
    required this.id,
    required this.requestNumber,
    this.customerName = '',
    this.customerPhone = '',
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.dropoffLat = 0,
    this.dropoffLng = 0,
    this.distanceKm = 0,
    this.taxiType = TaxiType.economic,
    this.fareEconomic = 0,
    this.fareSuper = 0,
    this.fare = 0,
    this.statusKey = 'pending',
    this.statusAr = '',
    this.driverRating = 0,
    this.cashCollected = false,
    this.acceptedAt,
    this.completedAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverVehicleInfo,
    this.vehicleModel,
    this.plateNumber,
    this.driverLat,
    this.driverLng,
    this.rejectedByDriverIds = const [],
    this.cancellationReason,
    this.isPaid = false,
    this.noteAr,
    this.assignedDriverName,
  });

  String get pickupAddressAr => pickupAddress;
  String get dropoffAddressAr => dropoffAddress;
  String get customerNameAr => customerName;

  bool get isPending => statusKey == 'pending';
  bool get isAccepted => statusKey == 'accepted';
  bool get isOnWay => statusKey == 'on_way';
  bool get isArrived => statusKey == 'arrived';
  bool get isPickedUp => statusKey == 'picked_up';
  bool get isCompleted => statusKey == 'completed';
  bool get isCancelled => statusKey == 'cancelled';
  bool get isCancelRequested => statusKey == 'cancel_requested';

  bool get canCustomerCancel =>
      !isCompleted && !isCancelled && !isPickedUp;

  bool get hasAssignedDriver =>
      isAccepted || isOnWay || isArrived || isPickedUp || isCancelRequested;

  /// يمكن للزبون فتح شاشة التتبع المباشر ولوحة الرحلة
  bool get canShowLiveTracking => hasAssignedDriver;

  String get taxiTypeLabelAr => taxiType.customerServiceLabelAr;

  String get statusLabelAr {
    switch (statusKey) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'تم القبول';
      case 'arrived':
        return 'وصل السائق';
      case 'picked_up':
        return 'تم الاستلام';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'cancel_requested':
        return 'بانتظار موافقة السائق على الإلغاء';
      default:
        return statusAr.isNotEmpty ? statusAr : statusKey;
    }
  }

  String get rideTypeAr => taxiTypeLabelAr;

  String get vehicleModelDisplay {
    final model = vehicleModel?.trim();
    if (model != null && model.isNotEmpty) return model;
    final info = driverVehicleInfo?.trim() ?? '';
    if (info.contains(' / ')) return info.split(' / ').first.trim();
    return info.isNotEmpty ? info : 'مركبة';
  }

  String get plateNumberDisplay {
    final plate = plateNumber?.trim();
    if (plate != null && plate.isNotEmpty) return plate;
    final info = driverVehicleInfo?.trim() ?? '';
    if (info.contains(' / ')) {
      return info.split(' / ').last.trim();
    }
    return '';
  }

  bool get hasDriverLocation =>
      driverLat != null && driverLng != null && driverLat != 0 && driverLng != 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'distanceKm': distanceKm,
      'taxiType': taxiType.toApiName,
      'fareEconomic': fareEconomic,
      'fareSuper': fareSuper,
      'fare': fare,
      'statusKey': statusKey,
      'statusAr': statusAr,
      'driverRating': driverRating,
      'cashCollected': cashCollected,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverVehicleInfo': driverVehicleInfo,
      'vehicleModel': vehicleModel,
      'plateNumber': plateNumber,
      'driverLat': driverLat,
      'driverLng': driverLng,
      'rejectedByDriverIds': rejectedByDriverIds,
      'cancellationReason': cancellationReason,
      'isPaid': isPaid,
      if (noteAr != null) 'noteAr': noteAr,
      if (assignedDriverName != null) 'assignedDriverName': assignedDriverName,
    };
  }

  factory TaxiRequest.fromMap(Map<String, dynamic> map) {
    return TaxiRequest(
      id: (map['id'] as String?) ?? '',
      requestNumber: (map['requestNumber'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      pickupAddress: (map['pickupAddress'] as String?) ?? '',
      dropoffAddress: (map['dropoffAddress'] as String?) ?? '',
      pickupLat: (map['pickupLat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (map['pickupLng'] as num?)?.toDouble() ?? 0.0,
      dropoffLat: (map['dropoffLat'] as num?)?.toDouble() ?? 0.0,
      dropoffLng: (map['dropoffLng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      taxiType: TaxiTypeX.fromApiName(map['taxiType']?.toString()),
      fareEconomic: (map['fareEconomic'] as num?)?.toInt() ?? 0,
      fareSuper: (map['fareSuper'] as num?)?.toInt() ?? 0,
      fare: (map['fare'] as num?)?.toInt() ?? 0,
      statusKey: (map['statusKey'] as String?) ?? 'pending',
      statusAr: (map['statusAr'] as String?) ?? '',
      driverRating: (map['driverRating'] as num?)?.toInt() ?? 0,
      cashCollected: (map['cashCollected'] as bool?) ?? false,
      acceptedAt: map['acceptedAt'] != null
          ? DateTime.tryParse(map['acceptedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      driverId: map['driverId'] as String?,
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      driverVehicleInfo: map['driverVehicleInfo'] as String?,
      vehicleModel: map['vehicleModel'] as String?,
      plateNumber: map['plateNumber'] as String?,
      driverLat: (map['driverLat'] as num?)?.toDouble(),
      driverLng: (map['driverLng'] as num?)?.toDouble(),
      rejectedByDriverIds: map['rejectedByDriverIds'] is List
          ? (map['rejectedByDriverIds'] as List)
              .map((e) => e.toString())
              .toList()
          : const [],
      cancellationReason: map['cancellationReason'] as String?,
      isPaid: (map['isPaid'] as bool?) ?? false,
      noteAr: map['noteAr'] as String?,
      assignedDriverName: map['assignedDriverName'] as String?,
    );
  }

  TaxiRequest copyWith({
    String? id,
    String? requestNumber,
    String? customerName,
    String? customerPhone,
    String? pickupAddress,
    String? dropoffAddress,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    double? distanceKm,
    TaxiType? taxiType,
    int? fareEconomic,
    int? fareSuper,
    int? fare,
    String? statusKey,
    String? statusAr,
    int? driverRating,
    bool? cashCollected,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverVehicleInfo,
    String? vehicleModel,
    String? plateNumber,
    double? driverLat,
    double? driverLng,
    List<String>? rejectedByDriverIds,
    String? cancellationReason,
    bool? isPaid,
    String? noteAr,
    String? assignedDriverName,
  }) {
    return TaxiRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      distanceKm: distanceKm ?? this.distanceKm,
      taxiType: taxiType ?? this.taxiType,
      fareEconomic: fareEconomic ?? this.fareEconomic,
      fareSuper: fareSuper ?? this.fareSuper,
      fare: fare ?? this.fare,
      statusKey: statusKey ?? this.statusKey,
      statusAr: statusAr ?? this.statusAr,
      driverRating: driverRating ?? this.driverRating,
      cashCollected: cashCollected ?? this.cashCollected,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverVehicleInfo: driverVehicleInfo ?? this.driverVehicleInfo,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      plateNumber: plateNumber ?? this.plateNumber,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      rejectedByDriverIds: rejectedByDriverIds ?? this.rejectedByDriverIds,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isPaid: isPaid ?? this.isPaid,
      noteAr: noteAr ?? this.noteAr,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
    );
  }
}
