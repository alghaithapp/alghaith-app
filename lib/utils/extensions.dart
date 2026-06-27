extension NumberFormatting on int {
  String toPrice() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String toLocaleString() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}

int parseProductPrice(Map<String, dynamic> row) {
  int read(dynamic value) {
    if (value is num) return value.toInt();
    final normalized = value?.toString().replaceAll(',', '').trim() ?? '';
    if (normalized.isEmpty) return 0;
    return int.tryParse(normalized) ?? 0;
  }

  for (final key in [
    'price',
    'discounted_price',
    'discountedPrice',
    'original_price',
    'originalPrice',
    'sale_price',
    'salePrice',
  ]) {
    final parsed = read(row[key]);
    if (parsed > 0) return parsed;
  }
  return 0;
}
