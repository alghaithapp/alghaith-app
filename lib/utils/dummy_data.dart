import '../models/app_models.dart';

class DummyData {
  static final List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'restaurant',
      titleAr: 'المطاعم',
      titleEn: 'Restaurants',
      image: 'assets/images/cat_restaurant.png',
    ),
    ServiceCategory(
      id: 'product',
      titleAr: 'التسوق',
      titleEn: 'Shopping',
      image: 'assets/images/cat_shopping.png',
    ),
    ServiceCategory(
      id: 'cars',
      titleAr: 'السيارات',
      titleEn: 'Cars',
      image: 'assets/images/cat_cars.png',
    ),
    ServiceCategory(
      id: 'professionals',
      titleAr: 'المهنيين',
      titleEn: 'Professionals',
      image: 'assets/images/cat_professionals.png',
    ),
    ServiceCategory(
      id: 'beauty',
      titleAr: 'الصحة والجمال',
      titleEn: 'Health & Beauty',
      image: 'assets/images/cat_beauty.png',
    ),
    ServiceCategory(
      id: 'tourism',
      titleAr: 'السياحة والسفر',
      titleEn: 'Tourism & Travel',
      image: 'assets/images/cat_tourism.png',
    ),
    ServiceCategory(
      id: 'real_estate',
      titleAr: 'العقارات',
      titleEn: 'Real Estate',
      image: 'assets/images/cat_real_estate.png',
    ),
    ServiceCategory(
      id: 'offers',
      titleAr: 'العروض والخصومات',
      titleEn: 'Offers',
      image: 'assets/images/cat_offers.png',
    ),
    ServiceCategory(
      id: 'global_shopping',
      titleAr: 'التسوق العالمي',
      titleEn: 'Global Shopping',
      image: 'assets/images/cat_global.png',
    ),
    ServiceCategory(
      id: 'used',
      titleAr: 'المنتجات المستعملة',
      titleEn: 'Used Products',
      image: 'assets/images/cat_used.png',
    ),
  ];

  static final List<ServiceCategory> shoppingSubCategories = [
    ServiceCategory(
      id: 'home_goods',
      titleAr: 'مواد منزلية',
      titleEn: 'Home Goods',
      image: 'assets/images/shop_home_goods.png',
    ),
    ServiceCategory(
      id: 'food_items',
      titleAr: 'مواد غذائية',
      titleEn: 'Food Items',
      image: 'assets/images/shop_food_items.png',
    ),
    ServiceCategory(
      id: 'construction',
      titleAr: 'مواد إنشائية',
      titleEn: 'Construction',
      image: 'assets/images/shop_construction.png',
    ),
    ServiceCategory(
      id: 'school',
      titleAr: 'لوازم مدرسية',
      titleEn: 'School Supplies',
      image: 'assets/images/shop_school.png',
    ),
    ServiceCategory(
      id: 'bakery',
      titleAr: 'مخابز ومعجنات',
      titleEn: 'Bakeries',
      image: 'assets/images/shop_bakery.png',
    ),
    ServiceCategory(
      id: 'electronics',
      titleAr: 'كهربائيات',
      titleEn: 'Electronics',
      image: 'assets/images/shop_electronics.png',
    ),
    ServiceCategory(
      id: 'meat',
      titleAr: 'لحوم',
      titleEn: 'Meat',
      image: 'assets/images/shop_meat.png',
    ),
    ServiceCategory(
      id: 'grocery',
      titleAr: 'بقالة',
      titleEn: 'Grocery',
      image: 'assets/images/shop_grocery.png',
    ),
    ServiceCategory(
      id: 'shoes_bags',
      titleAr: 'أحذية وحقائب',
      titleEn: 'Shoes & Bags',
      image: 'assets/images/shop_shoes_bags.png',
    ),
    ServiceCategory(
      id: 'kids_clothing',
      titleAr: 'ملابس أطفال',
      titleEn: 'Kids Clothing',
      image: 'assets/images/shop_kids_clothing.png',
    ),
    ServiceCategory(
      id: 'women_clothing',
      titleAr: 'ملابس نسائية',
      titleEn: 'Women Clothing',
      image: 'assets/images/shop_women_clothing.png',
    ),
    ServiceCategory(
      id: 'men_clothing',
      titleAr: 'ملابس رجالية',
      titleEn: 'Men Clothing',
      image: 'assets/images/shop_men_clothing.png',
    ),
    ServiceCategory(
      id: 'cosmetics',
      titleAr: 'مستحضرات تجميل',
      titleEn: 'Cosmetics',
      image: 'assets/images/shop_cosmetics.png',
    ),
    ServiceCategory(
      id: 'gifts',
      titleAr: 'زهور وهدايا',
      titleEn: 'Flowers & Gifts',
      image: 'assets/images/shop_gifts.png',
    ),
  ];

  static final List<ServiceCategory> carsSubCategories = [
    ServiceCategory(
      id: 'taxi_request',
      titleAr: 'طلب تكسي',
      titleEn: 'Taxi Request',
      image: 'assets/images/car_taxi.png',
    ),
    ServiceCategory(
      id: 'car_request',
      titleAr: 'طلب سيارة',
      titleEn: 'Request Car',
      image: 'assets/images/car_request.png',
    ),
    ServiceCategory(
      id: 'car_sell',
      titleAr: 'بيع سيارة',
      titleEn: 'Sell Car',
      image: 'assets/images/car_sell.png',
    ),
    ServiceCategory(
      id: 'car_buy',
      titleAr: 'شراء سيارة',
      titleEn: 'Buy Car',
      image: 'assets/images/car_buy.png',
    ),
  ];

  static final List<ServiceCategory> requestCarOptions = [
    ServiceCategory(
      id: 'truck',
      titleAr: 'سيارة حمل',
      titleEn: 'Truck',
      image: 'assets/images/cat_cars.png',
    ),
    ServiceCategory(
      id: 'bus',
      titleAr: 'سيارة باص',
      titleEn: 'Bus',
      image: 'assets/images/cat_cars.png',
    ),
    ServiceCategory(
      id: 'starx',
      titleAr: 'سيارة ستاركس',
      titleEn: 'Starx',
      image: 'assets/images/cat_cars.png',
    ),
  ];

  static final List<ServiceCategory> tourismSubCategories = [
    ServiceCategory(
      id: 'groups',
      titleAr: 'كروبات سياحية',
      titleEn: 'Tour Groups',
      image: 'assets/images/tour_groups.png',
    ),
    ServiceCategory(
      id: 'hotels',
      titleAr: 'حجز فنادق',
      titleEn: 'Hotel Booking',
      image: 'assets/images/tour_hotels.png',
    ),
    ServiceCategory(
      id: 'flights',
      titleAr: 'تذاكر طيران',
      titleEn: 'Flight Tickets',
      image: 'assets/images/tour_flights.png',
    ),
  ];

  static final List<ServiceCategory> realEstateSubCategories = [
    ServiceCategory(
      id: 'house',
      titleAr: 'دار',
      titleEn: 'House',
      image: 'assets/images/re_house.png',
    ),
    ServiceCategory(
      id: 'land',
      titleAr: 'أرض',
      titleEn: 'Land',
      image: 'assets/images/re_land.png',
    ),
    ServiceCategory(
      id: 'shops',
      titleAr: 'محلات تجارية',
      titleEn: 'Commercial Shops',
      image: 'assets/images/re_shops.png',
    ),
    ServiceCategory(
      id: 'apartment',
      titleAr: 'شقة',
      titleEn: 'Apartment',
      image: 'assets/images/re_apartment.png',
    ),
    ServiceCategory(
      id: 'building',
      titleAr: 'بناية سكنية تجارية',
      titleEn: 'Commercial Residential Building',
      image: 'assets/images/re_building.png',
    ),
    ServiceCategory(
      id: 'farm',
      titleAr: 'مزرعة',
      titleEn: 'Farm',
      image: 'assets/images/re_farm.png',
    ),
  ];

  static final List<ServiceCategory> globalShoppingSubCategories = [
    ServiceCategory(
      id: 'iran',
      titleAr: 'إيران',
      titleEn: 'Iran',
      image: 'assets/images/global_iran.png',
    ),
    ServiceCategory(
      id: 'china',
      titleAr: 'الصين',
      titleEn: 'China',
      image: 'assets/images/global_china.png',
    ),
  ];

  static final List<ServiceCategory> professionalsSubCategories = [
    ServiceCategory(
      id: 'plumber',
      titleAr: 'سباك',
      titleEn: 'Plumber',
      image: 'assets/images/prof_plumber.png',
    ),
    ServiceCategory(
      id: 'electrician',
      titleAr: 'كهربائي',
      titleEn: 'Electrician',
      image: 'assets/images/prof_electrician.png',
    ),
    ServiceCategory(
      id: 'ac_tech',
      titleAr: 'فني تكييف',
      titleEn: 'AC Technician',
      image: 'assets/images/prof_ac.png',
    ),
    ServiceCategory(
      id: 'carpenter',
      titleAr: 'نجار',
      titleEn: 'Carpenter',
      image: 'assets/images/prof_carpenter.png',
    ),
    ServiceCategory(
      id: 'cleaner',
      titleAr: 'تنظيف منازل',
      titleEn: 'Home Cleaner',
      image: 'assets/images/prof_cleaner.png',
    ),
  ];

  static final List<ServiceCategory> healthSubCategories = [
    ServiceCategory(
      id: 'hospitals',
      titleAr: 'مستشفيات',
      titleEn: 'Hospitals',
      image: 'assets/images/health_hospitals.png',
    ),
    ServiceCategory(
      id: 'doctors',
      titleAr: 'أطباء وعيادات',
      titleEn: 'Doctors & Clinics',
      image: 'assets/images/health_doctors.png',
    ),
    ServiceCategory(
      id: 'pharmacies',
      titleAr: 'صيدليات',
      titleEn: 'Pharmacies',
      image: 'assets/images/health_pharmacies.png',
    ),
    ServiceCategory(
      id: 'salon',
      titleAr: 'صالون وتجميل',
      titleEn: 'Salon & Beauty',
      image: 'assets/images/health_salon.png',
    ),
  ];

  static final List<ListItem> items = [];
}
