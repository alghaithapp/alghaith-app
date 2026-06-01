class AppTranslations {
  static Map<String, Map<String, String>> data = {
    'ar': {
      'app_title': 'الغيث',
      'home': 'الرئيسية',
      'favorites': 'المفضلة',
      'cart': 'السلة',
      'orders': 'طلباتي',
      'account': 'حسابي',
      'search_placeholder': 'ابحث عن مطاعم، منتجات، عقارات...',
      'services': 'الخدمات المتوفرة',
      'all': 'الكل',
      'restaurants': 'المطاعم',
      'products': 'منتجات',
      'real_estate': 'العقارات',
      'add_to_cart': 'أضف للسلة',
      'checkout': 'إتمام الطلب - الدفع عند الاستلام',
      'total': 'المجموع الكلي',
      'cod_notice': 'الدفع نقداً عند الاستلام فقط',
      'order_success': 'تم تقديم الطلب بنجاح!',
      'track_order': 'تتبع الطلب',
      'logout': 'تسجيل الخروج',
      'dashboard': 'الإحصائيات',
      'my_products': 'منتجاتي',
    },
    'en': {
      'app_title': 'Al-Ghaith',
      'home': 'Home',
      'favorites': 'Favorites',
      'cart': 'Cart',
      'orders': 'Orders',
      'account': 'Account',
      'search_placeholder': 'Search restaurants, products...',
      'services': 'Available Services',
      'all': 'All',
      'restaurants': 'Restaurants',
      'products': 'Products',
      'real_estate': 'Real Estate',
      'add_to_cart': 'Add to Cart',
      'checkout': 'Checkout - Cash on Delivery',
      'total': 'Total',
      'cod_notice': 'Cash on Delivery Only',
      'order_success': 'Order placed successfully!',
      'track_order': 'Track Order',
      'logout': 'Logout',
      'dashboard': 'Dashboard',
      'my_products': 'My Products',
    }
  };

  static String t(String key, String lang) {
    return data[lang]?[key] ?? key;
  }
}
