class MarketplaceSubCategoryStats {
  final String id;
  final int productCount;
  final int storeCount;

  const MarketplaceSubCategoryStats({
    required this.id,
    this.productCount = 0,
    this.storeCount = 0,
  });

  int get totalCount =>
      productCount > storeCount ? productCount : storeCount;

  factory MarketplaceSubCategoryStats.fromMap(Map<String, dynamic> map) {
    return MarketplaceSubCategoryStats(
      id: map['id']?.toString() ?? '',
      productCount: (map['productCount'] as num?)?.toInt() ?? 0,
      storeCount: (map['storeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarketplaceCategoryStats {
  final String id;
  final int storeCount;
  final int productCount;
  final int totalCount;
  final List<MarketplaceSubCategoryStats> subCategories;

  const MarketplaceCategoryStats({
    required this.id,
    this.storeCount = 0,
    this.productCount = 0,
    this.totalCount = 0,
    this.subCategories = const [],
  });

  factory MarketplaceCategoryStats.fromMap(Map<String, dynamic> map) {
    final subs = map['subCategories'];
    return MarketplaceCategoryStats(
      id: map['id']?.toString() ?? '',
      storeCount: (map['storeCount'] as num?)?.toInt() ?? 0,
      productCount: (map['productCount'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
      subCategories: subs is List
          ? subs
              .whereType<Map>()
              .map((item) => MarketplaceSubCategoryStats.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  MarketplaceSubCategoryStats? subStats(String subCategoryId) {
    for (final sub in subCategories) {
      if (sub.id == subCategoryId) return sub;
    }
    return null;
  }
}

class MarketplaceStatsSnapshot {
  final List<MarketplaceCategoryStats> categories;
  final int offerCount;
  final int professionalCount;
  final int realEstateCount;
  final DateTime? updatedAt;

  const MarketplaceStatsSnapshot({
    this.categories = const [],
    this.offerCount = 0,
    this.professionalCount = 0,
    this.realEstateCount = 0,
    this.updatedAt,
  });

  factory MarketplaceStatsSnapshot.fromMap(Map<String, dynamic> map) {
    final rows = map['categories'];
    DateTime? updatedAt;
    final rawUpdated = map['updatedAt']?.toString();
    if (rawUpdated != null && rawUpdated.isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdated);
    }
    return MarketplaceStatsSnapshot(
      categories: rows is List
          ? rows
              .whereType<Map>()
              .map((item) => MarketplaceCategoryStats.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      offerCount: (map['offerCount'] as num?)?.toInt() ?? 0,
      professionalCount: (map['professionalCount'] as num?)?.toInt() ?? 0,
      realEstateCount: (map['realEstateCount'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
    );
  }

  MarketplaceCategoryStats? category(String id) {
    for (final entry in categories) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  int totalForCategory(String id) {
    final entry = category(id);
    if (entry == null) return 0;
    if (entry.totalCount > 0) return entry.totalCount;
    return entry.productCount > entry.storeCount
        ? entry.productCount
        : entry.storeCount;
  }

  int totalForSubCategory(String categoryId, String subCategoryId) {
    final entry = category(categoryId)?.subStats(subCategoryId);
    if (entry == null) return 0;
    return entry.totalCount;
  }
}
