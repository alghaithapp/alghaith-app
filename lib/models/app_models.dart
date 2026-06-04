class ServiceCategory {
  final String id;
  final String titleAr;
  final String titleEn;
  final String image;

  const ServiceCategory({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.image,
  });
}

class ListItem {
  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final int price;
  final double? rating;
  final String category;
  final String? subCategory;
  /// قسم داخل متجر التاجر (مكسرات، حلويات، …) — ليس قسم التسوق العام.
  final String? sectionId;
  final String categoryLabelAr;
  final String categoryLabelEn;
  final String image;
  final String? imageBase64;
  bool isFavorite;
  final String avgPriceLabelAr;
  final String avgPriceLabelEn;
  final String actionLabelAr;
  final String actionLabelEn;
  final String? address;
  final int? bedrooms;
  final int? bathrooms;
  final int? areaSquareMeter;
  final int? floorCount;
  final String? listingMode;
  final int? prepMinutes;
  bool isAvailable;
  final String? merchantPhone;
  final String? merchantStoreName;
  final double? merchantLatitude;
  final double? merchantLongitude;
  final String? merchantOpenTime;
  final String? merchantCloseTime;
  final bool? merchantIsOpen;

  ListItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.price,
    this.rating,
    required this.category,
    this.subCategory,
    this.sectionId,
    required this.categoryLabelAr,
    required this.categoryLabelEn,
    required this.image,
    this.imageBase64,
    this.isFavorite = false,
    required this.avgPriceLabelAr,
    required this.avgPriceLabelEn,
    required this.actionLabelAr,
    required this.actionLabelEn,
    this.address,
    this.bedrooms,
    this.bathrooms,
    this.areaSquareMeter,
    this.floorCount,
    this.listingMode,
    this.prepMinutes,
    this.isAvailable = true,
    this.merchantPhone,
    this.merchantStoreName,
    this.merchantLatitude,
    this.merchantLongitude,
    this.merchantOpenTime,
    this.merchantCloseTime,
    this.merchantIsOpen,
  });

  ListItem copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    int? price,
    double? rating,
    String? category,
    String? subCategory,
    String? sectionId,
    String? categoryLabelAr,
    String? categoryLabelEn,
    String? image,
    String? imageBase64,
    bool? isFavorite,
    String? avgPriceLabelAr,
    String? avgPriceLabelEn,
    String? actionLabelAr,
    String? actionLabelEn,
    String? address,
    int? bedrooms,
    int? bathrooms,
    int? areaSquareMeter,
    int? floorCount,
    String? listingMode,
    int? prepMinutes,
    bool? isAvailable,
    String? merchantPhone,
    String? merchantStoreName,
    double? merchantLatitude,
    double? merchantLongitude,
    String? merchantOpenTime,
    String? merchantCloseTime,
    bool? merchantIsOpen,
  }) {
    return ListItem(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      sectionId: sectionId ?? this.sectionId,
      categoryLabelAr: categoryLabelAr ?? this.categoryLabelAr,
      categoryLabelEn: categoryLabelEn ?? this.categoryLabelEn,
      image: image ?? this.image,
      imageBase64: imageBase64 ?? this.imageBase64,
      isFavorite: isFavorite ?? this.isFavorite,
      avgPriceLabelAr: avgPriceLabelAr ?? this.avgPriceLabelAr,
      avgPriceLabelEn: avgPriceLabelEn ?? this.avgPriceLabelEn,
      actionLabelAr: actionLabelAr ?? this.actionLabelAr,
      actionLabelEn: actionLabelEn ?? this.actionLabelEn,
      address: address ?? this.address,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      areaSquareMeter: areaSquareMeter ?? this.areaSquareMeter,
      floorCount: floorCount ?? this.floorCount,
      listingMode: listingMode ?? this.listingMode,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      isAvailable: isAvailable ?? this.isAvailable,
      merchantPhone: merchantPhone ?? this.merchantPhone,
      merchantStoreName: merchantStoreName ?? this.merchantStoreName,
      merchantLatitude: merchantLatitude ?? this.merchantLatitude,
      merchantLongitude: merchantLongitude ?? this.merchantLongitude,
      merchantOpenTime: merchantOpenTime ?? this.merchantOpenTime,
      merchantCloseTime: merchantCloseTime ?? this.merchantCloseTime,
      merchantIsOpen: merchantIsOpen ?? this.merchantIsOpen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'descriptionAr': descriptionAr,
      'descriptionEn': descriptionEn,
      'price': price,
      'rating': rating,
      'category': category,
      'subCategory': subCategory,
      'sectionId': sectionId,
      'categoryLabelAr': categoryLabelAr,
      'categoryLabelEn': categoryLabelEn,
      'image': image,
      'imageBase64': imageBase64,
      'isFavorite': isFavorite,
      'avgPriceLabelAr': avgPriceLabelAr,
      'avgPriceLabelEn': avgPriceLabelEn,
      'actionLabelAr': actionLabelAr,
      'actionLabelEn': actionLabelEn,
      'address': address,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'areaSquareMeter': areaSquareMeter,
      'floorCount': floorCount,
      'listingMode': listingMode,
      'prepMinutes': prepMinutes,
      'isAvailable': isAvailable,
      'merchantPhone': merchantPhone,
      'merchantStoreName': merchantStoreName,
      'merchantLatitude': merchantLatitude,
      'merchantLongitude': merchantLongitude,
      'merchantOpenTime': merchantOpenTime,
      'merchantCloseTime': merchantCloseTime,
      'merchantIsOpen': merchantIsOpen,
    };
  }

  factory ListItem.fromMap(Map<String, dynamic> map) {
    return ListItem(
      id: (map['id'] as String?) ?? '',
      nameAr: (map['nameAr'] as String?) ?? '',
      nameEn: (map['nameEn'] as String?) ?? '',
      descriptionAr: (map['descriptionAr'] as String?) ?? '',
      descriptionEn: (map['descriptionEn'] as String?) ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble(),
      category: (map['category'] as String?) ?? '',
      subCategory: map['subCategory'] as String?,
      sectionId: (map['sectionId'] as String?)?.trim().isNotEmpty == true
          ? (map['sectionId'] as String?)?.trim()
          : (map['section_id'] as String?)?.trim(),
      categoryLabelAr: (map['categoryLabelAr'] as String?) ?? '',
      categoryLabelEn: (map['categoryLabelEn'] as String?) ?? '',
      image: (map['image'] as String?) ?? '',
      imageBase64: map['imageBase64'] as String?,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      avgPriceLabelAr: (map['avgPriceLabelAr'] as String?) ?? '',
      avgPriceLabelEn: (map['avgPriceLabelEn'] as String?) ?? '',
      actionLabelAr: (map['actionLabelAr'] as String?) ?? '',
      actionLabelEn: (map['actionLabelEn'] as String?) ?? '',
      address: map['address'] as String?,
      bedrooms: (map['bedrooms'] as num?)?.toInt(),
      bathrooms: (map['bathrooms'] as num?)?.toInt(),
      areaSquareMeter: (map['areaSquareMeter'] as num?)?.toInt(),
      floorCount: (map['floorCount'] as num?)?.toInt(),
      listingMode: map['listingMode'] as String?,
      prepMinutes: (map['prepMinutes'] as num?)?.toInt(),
      isAvailable: (map['isAvailable'] as bool?) ?? true,
      merchantPhone: map['merchantPhone'] as String?,
      merchantStoreName: map['merchantStoreName'] as String?,
      merchantLatitude: (map['merchantLatitude'] as num?)?.toDouble(),
      merchantLongitude: (map['merchantLongitude'] as num?)?.toDouble(),
      merchantOpenTime: map['merchantOpenTime'] as String?,
      merchantCloseTime: map['merchantCloseTime'] as String?,
      merchantIsOpen: map['merchantIsOpen'] as bool?,
    );
  }
}

class OrderLineItem {
  final String nameAr;
  final String nameEn;
  final int quantity;
  final int price;
  final String? image;

  const OrderLineItem({
    required this.nameAr,
    required this.nameEn,
    required this.quantity,
    required this.price,
    this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'quantity': quantity,
      'price': price,
      'image': image,
    };
  }

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      nameAr: (map['nameAr'] as String?) ?? '',
      nameEn: (map['nameEn'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toInt() ?? 0,
      image: map['image'] as String?,
    );
  }
}

class CartItem {
  final String id;
  final String nameAr;
  final String nameEn;
  final int price;
  int count;
  final String image;
  final String category;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? merchantPhone;
  final String? merchantStoreName;
  final String? merchantAddress;
  final double? merchantLatitude;
  final double? merchantLongitude;
  final String? merchantOpenTime;
  final String? merchantCloseTime;
  final bool? merchantIsOpen;
  final String? optionAr;
  final String? optionEn;

  CartItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.price,
    required this.count,
    required this.image,
    required this.category,
    this.descriptionAr,
    this.descriptionEn,
    this.merchantPhone,
    this.merchantStoreName,
    this.merchantAddress,
    this.merchantLatitude,
    this.merchantLongitude,
    this.merchantOpenTime,
    this.merchantCloseTime,
    this.merchantIsOpen,
    this.optionAr,
    this.optionEn,
  });
}

class ActiveOrder {
  final String id;
  final String orderNumber;
  final String dateAr;
  final String dateEn;
  final String customerNameAr;
  final String customerNameEn;
  final String customerPhone;
  final String addressAr;
  final String addressEn;
  final String noteAr;
  final String noteEn;
  final String paymentMethodAr;
  final String paymentMethodEn;
  final String statusKey;
  final String statusAr;
  final String statusEn;
  final int price;
  final int itemsCount;
  final String itemsNameAr;
  final String itemsNameEn;
  final List<OrderLineItem> lineItems;
  final String? image;
  final String? iconName;
  final String? deliveryStatusKey;
  final String? deliveryStatusAr;
  final String? deliveryStatusEn;
  final String? assignedCourierName;
  final bool isRestaurantOrder;
  final String? merchantPhone;
  final String? merchantStoreName;
  final bool requiresDelivery;
  final bool codConfirmed;
  final String? deliveredAt;
  final int? estimatedArrivalMinutes;
  final String? estimatedArrivalAt;
  final String? courierPhone;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? createdAt;
  final String? merchantReadAt;
  final String? merchantDecisionAt;
  final bool isPriceLocked;

  ActiveOrder({
    required this.id,
    required this.orderNumber,
    required this.dateAr,
    required this.dateEn,
    this.customerNameAr = 'العميل',
    this.customerNameEn = 'Customer',
    this.customerPhone = '07700000000',
    this.addressAr = 'بغداد، العراق',
    this.addressEn = 'Baghdad, Iraq',
    this.noteAr = '',
    this.noteEn = '',
    this.paymentMethodAr = 'نقدًا',
    this.paymentMethodEn = 'Cash',
    required this.statusKey,
    required this.statusAr,
    required this.statusEn,
    required this.price,
    required this.itemsCount,
    required this.itemsNameAr,
    required this.itemsNameEn,
    this.lineItems = const [],
    this.image,
    this.iconName,
    this.deliveryStatusKey,
    this.deliveryStatusAr,
    this.deliveryStatusEn,
    this.assignedCourierName,
    this.isRestaurantOrder = false,
    this.merchantPhone,
    this.merchantStoreName,
    this.requiresDelivery = true,
    this.codConfirmed = false,
    this.deliveredAt,
    this.estimatedArrivalMinutes,
    this.estimatedArrivalAt,
    this.courierPhone,
    this.customerLatitude,
    this.customerLongitude,
    this.createdAt,
    this.merchantReadAt,
    this.merchantDecisionAt,
    this.isPriceLocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'dateAr': dateAr,
      'dateEn': dateEn,
      'customerNameAr': customerNameAr,
      'customerNameEn': customerNameEn,
      'customerPhone': customerPhone,
      'addressAr': addressAr,
      'addressEn': addressEn,
      'noteAr': noteAr,
      'noteEn': noteEn,
      'paymentMethodAr': paymentMethodAr,
      'paymentMethodEn': paymentMethodEn,
      'statusKey': statusKey,
      'statusAr': statusAr,
      'statusEn': statusEn,
      'price': price,
      'itemsCount': itemsCount,
      'itemsNameAr': itemsNameAr,
      'itemsNameEn': itemsNameEn,
      'lineItems': lineItems.map((item) => item.toMap()).toList(),
      'image': image,
      'iconName': iconName,
      'deliveryStatusKey': deliveryStatusKey,
      'deliveryStatusAr': deliveryStatusAr,
      'deliveryStatusEn': deliveryStatusEn,
      'assignedCourierName': assignedCourierName,
      'isRestaurantOrder': isRestaurantOrder,
      'merchantPhone': merchantPhone,
      'merchantStoreName': merchantStoreName,
      'requiresDelivery': requiresDelivery,
      'codConfirmed': codConfirmed,
      'deliveredAt': deliveredAt,
      'estimatedArrivalMinutes': estimatedArrivalMinutes,
      'estimatedArrivalAt': estimatedArrivalAt,
      'courierPhone': courierPhone,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'createdAt': createdAt,
      'merchantReadAt': merchantReadAt,
      'merchantDecisionAt': merchantDecisionAt,
      'isPriceLocked': isPriceLocked,
    };
  }

  factory ActiveOrder.fromMap(Map<String, dynamic> map) {
    final lineItemsValue = map['lineItems'];
    return ActiveOrder(
      id: (map['id'] as String?) ?? '',
      orderNumber: (map['orderNumber'] as String?) ?? '',
      dateAr: (map['dateAr'] as String?) ?? '',
      dateEn: (map['dateEn'] as String?) ?? '',
      customerNameAr: (map['customerNameAr'] as String?) ?? 'العميل',
      customerNameEn: (map['customerNameEn'] as String?) ?? 'Customer',
      customerPhone: (map['customerPhone'] as String?) ?? '07700000000',
      addressAr: (map['addressAr'] as String?) ?? 'بغداد، العراق',
      addressEn: (map['addressEn'] as String?) ?? 'Baghdad, Iraq',
      noteAr: (map['noteAr'] as String?) ?? '',
      noteEn: (map['noteEn'] as String?) ?? '',
      paymentMethodAr: (map['paymentMethodAr'] as String?) ?? 'نقداً',
      paymentMethodEn: (map['paymentMethodEn'] as String?) ?? 'Cash',
      statusKey: (map['statusKey'] as String?) ?? 'pending',
      statusAr: (map['statusAr'] as String?) ?? '',
      statusEn: (map['statusEn'] as String?) ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      itemsCount: (map['itemsCount'] as num?)?.toInt() ?? 0,
      itemsNameAr: (map['itemsNameAr'] as String?) ?? '',
      itemsNameEn: (map['itemsNameEn'] as String?) ?? '',
      lineItems: lineItemsValue is List
          ? lineItemsValue
              .whereType<Map>()
              .map((item) => OrderLineItem.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      image: map['image'] as String?,
      iconName: map['iconName'] as String?,
      deliveryStatusKey: map['deliveryStatusKey'] as String?,
      deliveryStatusAr: map['deliveryStatusAr'] as String?,
      deliveryStatusEn: map['deliveryStatusEn'] as String?,
      assignedCourierName: map['assignedCourierName'] as String?,
      isRestaurantOrder: (map['isRestaurantOrder'] as bool?) ?? false,
      merchantPhone: map['merchantPhone'] as String?,
      merchantStoreName: map['merchantStoreName'] as String?,
      requiresDelivery: (map['requiresDelivery'] as bool?) ?? true,
      codConfirmed: (map['codConfirmed'] as bool?) ?? false,
      deliveredAt: map['deliveredAt'] as String?,
      estimatedArrivalMinutes: (map['estimatedArrivalMinutes'] as num?)?.toInt(),
      estimatedArrivalAt: map['estimatedArrivalAt'] as String?,
      courierPhone: map['courierPhone'] as String?,
      customerLatitude: (map['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (map['customerLongitude'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as String?,
      merchantReadAt: map['merchantReadAt'] as String?,
      merchantDecisionAt: map['merchantDecisionAt'] as String?,
      isPriceLocked: (map['isPriceLocked'] as bool?) ?? false,
    );
  }
}

class TaxiRequest {
  final String id;
  final String requestNumber;
  final String requestedAtAr;
  final String requestedAtEn;
  final String customerNameAr;
  final String customerNameEn;
  final String customerPhone;
  final String pickupAddressAr;
  final String pickupAddressEn;
  final String dropoffAddressAr;
  final String dropoffAddressEn;
  final String rideTypeId;
  final String rideTypeAr;
  final String rideTypeEn;
  final int fare;
  final String statusKey;
  final String statusAr;
  final String statusEn;
  final String noteAr;
  final String noteEn;
  final String paymentMethodAr;
  final String paymentMethodEn;
  final String? assignedDriverName;
  final String? vehicleType;

  const TaxiRequest({
    required this.id,
    required this.requestNumber,
    required this.requestedAtAr,
    required this.requestedAtEn,
    required this.customerNameAr,
    required this.customerNameEn,
    required this.customerPhone,
    required this.pickupAddressAr,
    required this.pickupAddressEn,
    required this.dropoffAddressAr,
    required this.dropoffAddressEn,
    required this.rideTypeId,
    required this.rideTypeAr,
    required this.rideTypeEn,
    required this.fare,
    required this.statusKey,
    required this.statusAr,
    required this.statusEn,
    required this.noteAr,
    required this.noteEn,
    required this.paymentMethodAr,
    required this.paymentMethodEn,
    this.assignedDriverName,
    this.vehicleType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'requestedAtAr': requestedAtAr,
      'requestedAtEn': requestedAtEn,
      'customerNameAr': customerNameAr,
      'customerNameEn': customerNameEn,
      'customerPhone': customerPhone,
      'pickupAddressAr': pickupAddressAr,
      'pickupAddressEn': pickupAddressEn,
      'dropoffAddressAr': dropoffAddressAr,
      'dropoffAddressEn': dropoffAddressEn,
      'rideTypeId': rideTypeId,
      'rideTypeAr': rideTypeAr,
      'rideTypeEn': rideTypeEn,
      'fare': fare,
      'statusKey': statusKey,
      'statusAr': statusAr,
      'statusEn': statusEn,
      'noteAr': noteAr,
      'noteEn': noteEn,
      'paymentMethodAr': paymentMethodAr,
      'paymentMethodEn': paymentMethodEn,
      'assignedDriverName': assignedDriverName,
      'vehicleType': vehicleType,
    };
  }

  factory TaxiRequest.fromMap(Map<String, dynamic> map) {
    return TaxiRequest(
      id: (map['id'] as String?) ?? '',
      requestNumber: (map['requestNumber'] as String?) ?? '',
      requestedAtAr: (map['requestedAtAr'] as String?) ?? '',
      requestedAtEn: (map['requestedAtEn'] as String?) ?? '',
      customerNameAr: (map['customerNameAr'] as String?) ?? '',
      customerNameEn: (map['customerNameEn'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      pickupAddressAr: (map['pickupAddressAr'] as String?) ?? '',
      pickupAddressEn: (map['pickupAddressEn'] as String?) ?? '',
      dropoffAddressAr: (map['dropoffAddressAr'] as String?) ?? '',
      dropoffAddressEn: (map['dropoffAddressEn'] as String?) ?? '',
      rideTypeId: (map['rideTypeId'] as String?) ?? '',
      rideTypeAr: (map['rideTypeAr'] as String?) ?? '',
      rideTypeEn: (map['rideTypeEn'] as String?) ?? '',
      fare: (map['fare'] as num?)?.toInt() ?? 0,
      statusKey: (map['statusKey'] as String?) ?? 'pending',
      statusAr: (map['statusAr'] as String?) ?? '',
      statusEn: (map['statusEn'] as String?) ?? '',
      noteAr: (map['noteAr'] as String?) ?? '',
      noteEn: (map['noteEn'] as String?) ?? '',
      paymentMethodAr: (map['paymentMethodAr'] as String?) ?? 'نقداً',
      paymentMethodEn: (map['paymentMethodEn'] as String?) ?? 'Cash',
      assignedDriverName: map['assignedDriverName'] as String?,
      vehicleType: map['vehicleType'] as String?,
    );
  }
}
