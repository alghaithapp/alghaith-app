class MerchantProductSection {
  final String id;
  final String nameAr;
  final int sortOrder;

  const MerchantProductSection({
    required this.id,
    required this.nameAr,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_ar': nameAr,
        'nameAr': nameAr,
        'sort_order': sortOrder,
        'sortOrder': sortOrder,
      };

  factory MerchantProductSection.fromMap(Map<String, dynamic> map) {
    return MerchantProductSection(
      id: (map['id'] as String?)?.trim() ?? '',
      nameAr: (map['name_ar'] as String?)?.trim() ??
          (map['nameAr'] as String?)?.trim() ??
          '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ??
          (map['sortOrder'] as num?)?.toInt() ??
          0,
    );
  }

  MerchantProductSection copyWith({
    String? id,
    String? nameAr,
    int? sortOrder,
  }) {
    return MerchantProductSection(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
