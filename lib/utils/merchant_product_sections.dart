import '../models/merchant_product_section.dart';

/// أقسام المتجر التي ينشئها تاجر التسوق (داخل صفحة المتجر).
class MerchantProductSections {
  MerchantProductSections._();

  static const String otherKey = '_other';

  static List<MerchantProductSection> parseFromStore(
    Map<String, dynamic>? store,
  ) {
    if (store == null) return const [];
    final raw = store['productSections'] ?? store['product_sections'];
    return parseList(raw);
  }

  static List<MerchantProductSection> parseFromProfile(
    Map<String, dynamic>? profile,
  ) {
    if (profile == null) return const [];
    final raw = profile['product_sections'] ?? profile['productSections'];
    return parseList(raw);
  }

  static List<MerchantProductSection> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final sections = raw
        .whereType<Map>()
        .map((item) => MerchantProductSection.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((section) => section.id.isNotEmpty && section.nameAr.isNotEmpty)
        .toList();
    sections.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.nameAr.compareTo(b.nameAr);
    });
    return sections;
  }

  static List<Map<String, dynamic>> toPayload(List<MerchantProductSection> list) {
    return list.map((section) => section.toMap()).toList();
  }

  static String sectionIdFromProduct(Map<String, dynamic> row) {
    return (row['section_id'] ?? row['sectionId'])?.toString().trim() ?? '';
  }

  static String? nameForId(
    List<MerchantProductSection> sections,
    String? sectionId,
  ) {
    final id = sectionId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final section in sections) {
      if (section.id == id) return section.nameAr;
    }
    return null;
  }

  static bool profileHasSections(Map<String, dynamic>? profile) {
    return parseFromProfile(profile).isNotEmpty;
  }

  static List<MerchantStoreSectionTab> tabsForStore({
    required List<MerchantProductSection> sections,
    required List<Map<String, dynamic>> products,
  }) {
    if (sections.isEmpty) return const [];

    final knownIds = sections.map((e) => e.id).toSet();
    var hasOther = false;
    for (final product in products) {
      final id = sectionIdFromProduct(product);
      if (id.isEmpty || !knownIds.contains(id)) {
        hasOther = true;
        break;
      }
    }

    final tabs = <MerchantStoreSectionTab>[
      const MerchantStoreSectionTab(key: null, label: 'الكل'),
    ];
    for (final section in sections) {
      final count = products
          .where((p) => sectionIdFromProduct(p) == section.id)
          .length;
      if (count > 0) {
        tabs.add(
          MerchantStoreSectionTab(key: section.id, label: section.nameAr),
        );
      }
    }
    if (hasOther) {
      tabs.add(
        const MerchantStoreSectionTab(key: otherKey, label: 'أخرى'),
      );
    }
    return tabs;
  }

  static List<Map<String, dynamic>> filterProducts({
    required List<Map<String, dynamic>> products,
    required List<MerchantProductSection> sections,
    required String? selectedKey,
  }) {
    if (selectedKey == null) return products;

    final knownIds = sections.map((e) => e.id).toSet();
    if (selectedKey == otherKey) {
      return products.where((row) {
        final id = sectionIdFromProduct(row);
        return id.isEmpty || !knownIds.contains(id);
      }).toList();
    }

    return products
        .where((row) => sectionIdFromProduct(row) == selectedKey)
        .toList();
  }
}

class MerchantStoreSectionTab {
  final String? key;
  final String label;

  const MerchantStoreSectionTab({required this.key, required this.label});
}
