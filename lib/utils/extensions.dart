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
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  final price = read(row['price']);
  if (price > 0) return price;
  final discounted = read(row['discounted_price']);
  if (discounted > 0) return discounted;
  return read(row['original_price']);
}
