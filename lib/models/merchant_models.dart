class MerchantOffer {
  final String id;
  final String titleAr;
  final String titleEn;
  final int discountPercent;
  final String startDate;
  final String endDate;
  final List<String> productNamesAr;
  final bool isActive;

  const MerchantOffer({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.discountPercent,
    required this.startDate,
    required this.endDate,
    required this.productNamesAr,
    required this.isActive,
  });

  MerchantOffer copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    int? discountPercent,
    String? startDate,
    String? endDate,
    List<String>? productNamesAr,
    bool? isActive,
  }) {
    return MerchantOffer(
      id: id ?? this.id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      discountPercent: discountPercent ?? this.discountPercent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      productNamesAr: productNamesAr ?? this.productNamesAr,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'discountPercent': discountPercent,
      'startDate': startDate,
      'endDate': endDate,
      'productNamesAr': productNamesAr,
      'isActive': isActive,
    };
  }

  factory MerchantOffer.fromMap(Map<String, dynamic> map) {
    final products = map['productNamesAr'];
    return MerchantOffer(
      id: (map['id'] as String?) ?? '',
      titleAr: (map['titleAr'] as String?) ?? '',
      titleEn: (map['titleEn'] as String?) ?? '',
      discountPercent: (map['discountPercent'] as num?)?.toInt() ?? 0,
      startDate: (map['startDate'] as String?) ?? '',
      endDate: (map['endDate'] as String?) ?? '',
      productNamesAr: products is List
          ? products.map((item) => item.toString()).toList()
          : const <String>[],
      isActive: (map['isActive'] as bool?) ?? false,
    );
  }
}

class MerchantReview {
  final String id;
  final String customerName;
  final int stars;
  final String comment;
  final String date;
  final String? reply;

  const MerchantReview({
    required this.id,
    required this.customerName,
    required this.stars,
    required this.comment,
    required this.date,
    this.reply,
  });

  MerchantReview copyWith({
    String? id,
    String? customerName,
    int? stars,
    String? comment,
    String? date,
    String? reply,
  }) {
    return MerchantReview(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      date: date ?? this.date,
      reply: reply ?? this.reply,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'stars': stars,
      'comment': comment,
      'date': date,
      'reply': reply,
    };
  }

  factory MerchantReview.fromMap(Map<String, dynamic> map) {
    return MerchantReview(
      id: (map['id'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      comment: (map['comment'] as String?) ?? '',
      date: (map['date'] as String?) ?? '',
      reply: map['reply'] as String?,
    );
  }
}

class MerchantNotificationItem {
  final String title;
  final String body;
  final String type;
  final String time;

  const MerchantNotificationItem({
    required this.title,
    required this.body,
    required this.type,
    required this.time,
  });
}

class MerchantEarningPoint {
  final String label;
  final int value;

  const MerchantEarningPoint({
    required this.label,
    required this.value,
  });
}
