export interface TranslationKeys {
  app_title: string;
  choose_language: string;
  arabic: string;
  english: string;
  start: string;
  welcome_msg: string;
  home: string;
  favorites: string;
  cart: string;
  orders: string;
  account: string;
  no_iap_warning: string;
  search_placeholder: string;
  services: string;
  all: string;
  restaurants: string;
  products: string;
  real_estate: string;
  average_price: string;
  price: string;
  price_required: string;
  book_table: string;
  add_to_cart: string;
  contact: string;
  rooms: string;
  bathrooms: string;
  area: string;
  subtotal: string;
  delivery_fees: string;
  tax: string;
  total: string;
  apply_promo: string;
  promo_code_placeholder: string;
  invalid_promo: string;
  promo_applied: string;
  checkout: string;
  checkout_success: string;
  checkout_success_subtitle: string;
  current_orders: string;
  previous_orders: string;
  track_order: string;
  order_details: string;
  my_addresses: string;
  payment_methods: string;
  payment_desc: string;
  order_history: string;
  settings: string;
  help_center: string;
  about_app: string;
  logout: string;
  notifications: string;
  clear_all: string;
  no_notifications: string;
  no_items_in_cart: string;
  no_items_in_fav: string;
  no_orders: string;
  language: string;
  change_language: string;
  items: string;
  now: string;
  add_item_toast: string;
  saved_items: string;
  active_membership: string;
  about_desc: string;
  tracking_active: string;
  tracking_step_1: string;
  tracking_step_2: string;
  tracking_step_3: string;
  tracking_step_4: string;
  tracking_desc: string;
  close: string;
  cod_badge: string;
  cart_title: string;
  order_placed: string;
  delivery_estimate: string;
}

export const translations: Record<'ar' | 'en', TranslationKeys> = {
  ar: {
    app_title: "الغيث",
    choose_language: "اختر لغة التطبيق لتبدأ",
    arabic: "العربية",
    english: "English",
    start: "ابدأ الآن",
    welcome_msg: "أهلاً بك في تطبيق الغيث",
    home: "رئيسية",
    favorites: "المفضلة",
    cart: "سلة المشتريات",
    orders: "الطلبات",
    account: "حسابي",
    no_iap_warning: "تنبيه: هذا التطبيق يدعم الدفع نقداً عند الاستلام فقط (لا يوجد دفع أو شراء داخل التطبيق).",
    search_placeholder: "ابحث عن الخدمات والمطاعم والعقارات...",
    services: "الخدمات",
    all: "الكل",
    restaurants: "المطاعم",
    products: "المنتجات",
    real_estate: "عقارات",
    average_price: "متوسط السعر",
    price: "السعر",
    price_required: "السعر المطلوب",
    book_table: "حجز طاولة",
    add_to_cart: "أضف للسلة",
    contact: "تواصل",
    rooms: "غرف",
    bathrooms: "حمام",
    area: "م²",
    subtotal: "المجموع الفرعي",
    delivery_fees: "رسوم التوصيل",
    tax: "الضريبة",
    total: "الإجمالي",
    apply_promo: "إضافة كود خصم",
    promo_code_placeholder: "أدخل كود الخصم (مثل GHAITH20)",
    invalid_promo: "كود الخصم غير صحيح أو منتهي",
    promo_applied: "تم تطبيق خصم 20% بنجاح!",
    checkout: "إتمام الطلب (الدفع عند الاستلام)",
    checkout_success: "🎉 تم تقديم طلبك بنجاح!",
    checkout_success_subtitle: "تم اعتماد خيار (الدفع نقداً عند الاستلام). المندوب سيتواصل معك للتأكيد والتوصيل.",
    current_orders: "الحالية",
    previous_orders: "السابقة",
    track_order: "تتبع الطلب",
    order_details: "تفاصيل الطلب",
    my_addresses: "عناويني",
    payment_methods: "طرق الدفع",
    payment_desc: "الدفع عند الاستلام (كاش) فقط",
    order_history: "سجل الطلبات",
    settings: "الإعدادات",
    help_center: "مركز المساعدة",
    about_app: "عن التطبيق",
    logout: "تسجيل الخروج",
    notifications: "الإشعارات",
    clear_all: "مسح الكل",
    no_notifications: "صندوق الإشعارات فارغ!",
    no_items_in_cart: "سلة المشتريات فارغة. أضف بعض المنتجات الرائعة!",
    no_items_in_fav: "لم تقم بحفظ أي عنصر في المفضلة بعد.",
    no_orders: "لا توجد طلبات جارية حالياً.",
    language: "اللغة المعتمدة",
    change_language: "تغيير لغة التطبيق",
    items: "عناصر",
    now: "الآن",
    add_item_toast: "تم إضافة العنصر إلى السلة بنجاح!",
    saved_items: "عناصرك المحفوظة",
    active_membership: "عضو ذهبي",
    about_desc: "تطبيق الغيث هو بوابتك المتكاملة في العراق للوصول للمطاعم الفاخرة، خدمات التسوق المتنوعة، وحجز العقارات والسيارات وتأجيرها، مع الدعم الكامل لعملية الدفع نقداً عند الاستلام لضمان راحتك وأمانك.",
    tracking_active: "تتبع طلبك النشط",
    tracking_step_1: "تم استلام الطلب",
    tracking_step_2: "جاري التجهيز والتحضير",
    tracking_step_3: "الطلب مع المندوب وفي الطريق",
    tracking_step_4: "تم التسليم بنجاح",
    tracking_desc: "يرجى التواجد في الموقع لتسليم الطلب بسلاسة.",
    close: "إغلاق",
    cod_badge: "الدفع عند الاستلام متاح",
    cart_title: "سلتي",
    order_placed: "تم الطلب بنجاح",
    delivery_estimate: "الوقت المقدر للتوصيل: 30 - 45 دقيقة"
  },
  en: {
    app_title: "Al-Ghaith",
    choose_language: "Choose Application Language",
    arabic: "العربية",
    english: "English",
    start: "Get Started",
    welcome_msg: "Welcome to Al-Ghaith",
    home: "Home",
    favorites: "Favorites",
    cart: "Cart",
    orders: "My Orders",
    account: "My Account",
    no_iap_warning: "Warning: This application only supports Cash on Delivery (COD). No in-app payment required.",
    search_placeholder: "Search clinics, services, restaurants, products...",
    services: "Services",
    all: "All",
    restaurants: "Restaurants",
    products: "Products",
    real_estate: "Real Estate",
    average_price: "Average Price",
    price: "Price",
    price_required: "Price Required",
    book_table: "Book Table",
    add_to_cart: "Add to Cart",
    contact: "Contact us",
    rooms: "Rooms",
    bathrooms: "Baths",
    area: "m²",
    subtotal: "Subtotal",
    delivery_fees: "Delivery Fees",
    tax: "VAT / Tax",
    total: "Total",
    apply_promo: "Add Promo Code",
    promo_code_placeholder: "Enter coupon (e.g., GHAITH20)",
    invalid_promo: "Promo code is invalid or expired",
    promo_applied: "20% discount applied successfully!",
    checkout: "Complete Order (Cash on Delivery)",
    checkout_success: "🎉 Order Placed Successfully!",
    checkout_success_subtitle: "Your order is set to 'Cash on Delivery'. Our delivery representative will contact you shortly.",
    current_orders: "Active",
    previous_orders: "History",
    track_order: "Track Order",
    order_details: "Order Details",
    my_addresses: "My Addresses",
    payment_methods: "Payment Methods",
    payment_desc: "Cash on Delivery (COD) Only",
    order_history: "Order History",
    settings: "Settings",
    help_center: "Help Center",
    about_app: "About App",
    logout: "Log Out",
    notifications: "Notifications",
    clear_all: "Clear All",
    no_notifications: "Your notification bin is empty!",
    no_items_in_cart: "Your shopping cart is empty.",
    no_items_in_fav: "No items saved to favorites yet.",
    no_orders: "No active orders found.",
    language: "App Language",
    change_language: "Change Language",
    items: "items",
    now: "Now",
    add_item_toast: "Item added to cart successfully!",
    saved_items: "Your saved items",
    active_membership: "Gold Member",
    about_desc: "Al-Ghaith is your all-in-one Iraqi application for premium dining, retail shopping services, real estate opportunities, and car rentals - supporting Cash on Delivery (COD) for your absolute safety and security.",
    tracking_active: "Track Active Order",
    tracking_step_1: "Order Received",
    tracking_step_2: "Preparing & Packing",
    tracking_step_3: "Out for Delivery",
    tracking_step_4: "Delivered successfully",
    tracking_desc: "Please ensure your presence at the delivery location.",
    close: "Close",
    cod_badge: "Cash on Delivery available",
    cart_title: "My Cart",
    order_placed: "Order Placed",
    delivery_estimate: "Estimated delivery: 30 - 45 mins"
  }
};
