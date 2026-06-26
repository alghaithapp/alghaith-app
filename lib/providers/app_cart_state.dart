import '../../core/catalog/marketplace_catalog.dart';
import '../../core/checkout/cart_promo.dart';
import '../../models/app_models.dart';

/// Shopping cart and promo state (extracted from [AppProvider]).
class AppCartState {
  final List<CartItem> cart = [];
  CartPromoDefinition? appliedPromo;
  int lastActivityMs = 0;
  final Set<String> timerEmitted = <String>{};
  String selectedCategory = 'all';
  String? activeSubCategory;

  void reset() {
    cart.clear();
    appliedPromo = null;
    lastActivityMs = 0;
    timerEmitted.clear();
    selectedCategory = 'all';
    activeSubCategory = null;
  }

  void touchActivity() {
    lastActivityMs = DateTime.now().millisecondsSinceEpoch;
    timerEmitted.remove('cart_abandoned');
  }

  int get total => cart.fold(0, (sum, item) => sum + (item.price * item.count));

  int get promoDiscountIqd => appliedPromo?.discountForSubtotal(total) ?? 0;

  int get payableTotal => total - promoDiscountIqd;

  int get count => cart.fold(0, (sum, item) => sum + item.count);

  bool get hasMultipleMerchants {
    final merchants = cart
        .map((item) => item.merchantPhone?.trim())
        .whereType<String>()
        .where((phone) => phone.isNotEmpty)
        .toSet();
    return merchants.length > 1;
  }

  bool canAddItem(ListItem item, {required bool fromStoreListing}) {
    if (!fromStoreListing &&
        !MarketplaceCatalog.usesShoppingCart(item.category)) {
      return false;
    }
    if (item.merchantIsFrozen == true) return false;

    final merchantPhone = item.merchantPhone?.trim();
    if (cart.isEmpty || merchantPhone == null || merchantPhone.isEmpty) {
      return true;
    }

    final firstItem = cart.first;
    final existingMerchant = firstItem.merchantPhone?.trim();
    final isNewItemOrderable = item.category == 'bazar_ghaith' ||
        item.category == 'restaurant' ||
        item.category == 'product';
    final isCartOrderable = firstItem.category == 'bazar_ghaith' ||
        firstItem.originalCategory == 'bazar_ghaith' ||
        firstItem.category == 'restaurant' ||
        firstItem.originalCategory == 'restaurant' ||
        firstItem.category == 'product' ||
        firstItem.originalCategory == 'product';
    if (isNewItemOrderable && isCartOrderable) return true;
    if (existingMerchant == null || existingMerchant.isEmpty) return true;
    return existingMerchant == merchantPhone;
  }

  bool addItem(ListItem item) {
    final index = cart.indexWhere((entry) => entry.id == item.id);
    if (index != -1) {
      cart[index].count++;
    } else {
      cart.add(CartItem(
        id: item.id,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        price: item.price,
        count: 1,
        image: item.imageBase64 ?? item.image,
        category: item.category,
        originalCategory: item.originalCategory ?? item.category,
        descriptionAr: item.descriptionAr,
        descriptionEn: item.descriptionEn,
        merchantPhone: item.merchantPhone,
        merchantStoreName: item.merchantStoreName,
        merchantLatitude: item.merchantLatitude,
        merchantLongitude: item.merchantLongitude,
        merchantOpenTime: item.merchantOpenTime,
        merchantCloseTime: item.merchantCloseTime,
        merchantIsOpen: item.merchantIsOpen,
        merchantIsFrozen: item.merchantIsFrozen,
      ));
    }
    touchActivity();
    return true;
  }

  void incrementItem(String id) {
    final index = cart.indexWhere((item) => item.id == id);
    if (index == -1) return;
    cart[index].count++;
    touchActivity();
  }

  void decrementItem(String id) {
    final index = cart.indexWhere((item) => item.id == id);
    if (index == -1) return;
    if (cart[index].count > 1) {
      cart[index].count--;
    } else {
      cart.removeAt(index);
    }
  }

  void removeItem(String id) {
    cart.removeWhere((item) => item.id == id);
    if (cart.isEmpty) {
      appliedPromo = null;
    } else {
      touchActivity();
    }
  }

  void clear() {
    if (cart.isEmpty) return;
    cart.clear();
    appliedPromo = null;
    lastActivityMs = 0;
    timerEmitted.remove('cart_abandoned');
  }

  void clearPromo() {
    appliedPromo = null;
  }

  void resetHome() {
    selectedCategory = 'all';
    activeSubCategory = null;
  }
}
