/// أنواع التكسي
enum TaxiType { economic, superTaxiType }

extension TaxiTypeX on TaxiType {
  /// القيمة التي يتوقعها السيرفر
  String get toApiName {
    switch (this) {
      case TaxiType.superTaxiType:
        return 'super';
      case TaxiType.economic:
        return 'economic';
    }
  }

  static TaxiType fromApiName(String? name) {
    switch (name) {
      case 'super':
        return TaxiType.superTaxiType;
      case 'economic':
        return TaxiType.economic;
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
  final TaxiType taxiType; // 🟢 economic / 🔵 super
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
  final String? driverVehicleInfo; // نوع السيارة + لوحة
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
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.pickupLat = 0.0,
    this.pickupLng = 0.0,
    this.dropoffLat = 0.0,
    this.dropoffLng = 0.0,
    this.distanceKm = 0.0,
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
    this.rejectedByDriverIds = const [],
    this.cancellationReason,
    this.isPaid = false,
    this.noteAr,
    this.assignedDriverName,
  });

  String get rideTypeAr => taxiTypeLabelAr;
  String get customerNameAr => customerName;
  String get pickupAddressAr => pickupAddress;
  String get dropoffAddressAr => dropoffAddress;

  bool get isPending => statusKey == 'pending';
  bool get isAccepted => statusKey == 'accepted';
  bool get isArrived => statusKey == 'arrived';
  bool get isPickedUp => statusKey == 'picked_up';
  bool get isCompleted => statusKey == 'completed';
  bool get isCancelled => statusKey == 'cancelled';

  String get taxiTypeLabelAr {
    switch (taxiType) {
      case TaxiType.superTaxiType:
        return '\u{1F535} \u{633}\u{648}\u{628}\u{631}';
      case TaxiType.economic:
        return '\u{1F7E2} \u{627}\u{642}\u{62A}\u{635}\u{627}\u{62F}\u{64A}';
    }
  }

  String get statusLabelAr {
    switch (statusKey) {
      case 'pending':
        return '\u{642}\u{64A}\u{62F} \u{627}\u{644}\u{627}\u{646}\u{62A}\u{638}\u{627}\u{631}';
      case 'accepted':
        return '\u{62A}\u{645} \u{627}\u{644}\u{642}\u{628}\u{648}\u{644}';
      case 'arrived':
        return '\u{648}\u{635}\u{644} \u{627}\u{644}\u{633}\u{627}\u{626}\u{642}';
      case 'picked_up':
        return '\u{62A}\u{645} \u{627}\u{644}\u{627}\u{633}\u{62A}\u{644}\u{627}\u{645}';
      case 'completed':
        return '\u{645}\u{643}\u{62A}\u{645}\u{644}';
      case 'cancelled':
        return '\u{645}\u{644}\u{63A}\u{64A}';
      default:
        return statusAr.isNotEmpty ? statusAr : statusKey;
    }
  }

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
      'taxiType': taxiType.name,
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
      rejectedByDriverIds: rejectedByDriverIds ?? this.rejectedByDriverIds,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isPaid: isPaid ?? this.isPaid,
      noteAr: noteAr ?? this.noteAr,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
    );
  }
}
