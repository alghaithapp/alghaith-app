import '../../models/app_models.dart';

/// كيف يُتصفّح القسم الفرعي.
enum SubCategoryBrowseMode {
  /// متاجر/مطاعم → ServiceStoresScreen
  stores,

  /// منتجات من API catalog
  catalog,
}

/// نقطة دخول القسم الرئيسي.
enum CategoryEntryMode {
  /// مباشرة لقائمة المتاجر (مطاعم)
  directStores,

  /// شبكة أقسام فرعية ثم تصفح
  subCategoryHub,

  /// كatalog مباشر بدون أقسام فرعية
  directCatalog,

  /// عروض وخصومات
  offers,

  /// عقارات
  realEstate,

  /// مهنيون
  professionals,

  /// سيارات (مع استثناءات تكسي/طلب سيارة)
  cars,
}

class MarketplaceSubCategory extends ServiceCategory {
  final SubCategoryBrowseMode browseMode;

  const MarketplaceSubCategory({
    required super.id,
    required super.titleAr,
    required super.titleEn,
    required super.image,
    this.browseMode = SubCategoryBrowseMode.stores,
  });
}

class MarketplaceCategoryDefinition {
  final String id;
  final String titleAr;
  final String titleEn;
  final String image;
  final CategoryEntryMode entryMode;
  final String apiServiceId;
  final String apiProductCategory;
  final String hubTitleAr;
  final String hubSubtitleAr;
  final String storeTitleAr;
  final String storeSubtitleAr;
  final SubCategoryBrowseMode defaultSubBrowseMode;
  final List<MarketplaceSubCategory> subCategories;
  final bool showCuisineFilters;

  const MarketplaceCategoryDefinition({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.image,
    required this.entryMode,
    required this.apiServiceId,
    required this.apiProductCategory,
    required this.hubTitleAr,
    required this.hubSubtitleAr,
    required this.storeTitleAr,
    required this.storeSubtitleAr,
    this.defaultSubBrowseMode = SubCategoryBrowseMode.stores,
    this.subCategories = const [],
    this.showCuisineFilters = false,
  });

  ServiceCategory get asServiceCategory => ServiceCategory(
        id: id,
        titleAr: titleAr,
        titleEn: titleEn,
        image: image,
      );
}

class MarketplaceCatalog {
  const MarketplaceCatalog._();

  static const List<MarketplaceCategoryDefinition> categories = [
    MarketplaceCategoryDefinition(
      id: 'bazar_ghaith',
      titleAr: 'بازار ومطاعم الغيث',
      titleEn: 'Al-Ghaith Bazaar',
      image: 'assets/images/bazar_ghaith_banner.png',
      entryMode: CategoryEntryMode.directStores,
      apiServiceId: 'bazar_ghaith',
      apiProductCategory: 'bazar_ghaith',
      hubTitleAr: 'بازار ومطاعم الغيث',
      hubSubtitleAr: 'كل احتياجاتك في سلة واحدة وبكلفة توصيل 1000 دينار فقط',
      storeTitleAr: 'بازار ومطاعم الغيث',
      storeSubtitleAr: 'اختر منتجاتك من مختلف المتاجر والمطاعم المشمولة',
      showCuisineFilters: true,
    ),
    MarketplaceCategoryDefinition(
      id: 'restaurant',
      titleAr: '\u0627\u0644\u0645\u0637\u0627\u0639\u0645',
      titleEn: 'Restaurants',
      image: 'assets/images/cat_restaurant.png',
      entryMode: CategoryEntryMode.directStores,
      apiServiceId: 'restaurant',
      apiProductCategory: 'restaurant',
      hubTitleAr: 'المطاعم',
      hubSubtitleAr: 'اختر مطعمك المفضل',
      storeTitleAr: 'المطاعم',
      storeSubtitleAr: 'اختر مطعمك المفضل واطلب بسهولة',
      showCuisineFilters: true,
    ),
    MarketplaceCategoryDefinition(
      id: 'product',
      titleAr: 'التسوق',
      titleEn: 'Shopping',
      image: 'assets/images/cat_shopping.png',
      entryMode: CategoryEntryMode.subCategoryHub,
      apiServiceId: 'product',
      apiProductCategory: 'product',
      hubTitleAr: 'أقسام التسوق',
      hubSubtitleAr: 'تصفح المتاجر حسب القسم',
      storeTitleAr: 'المتاجر',
      storeSubtitleAr: 'اختر متجرك واطلب بسهولة',
      defaultSubBrowseMode: SubCategoryBrowseMode.stores,
      subCategories: _shoppingSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'cars',
      titleAr: 'السيارات',
      titleEn: 'Cars',
      image: 'assets/images/cat_cars.png',
      entryMode: CategoryEntryMode.cars,
      apiServiceId: 'cars',
      apiProductCategory: 'cars',
      hubTitleAr: 'قسم السيارات',
      hubSubtitleAr: 'بيع، شراء، وخدمات السيارات',
      storeTitleAr: 'السيارات',
      storeSubtitleAr: 'تصفح إعلانات السيارات',
      defaultSubBrowseMode: SubCategoryBrowseMode.catalog,
      subCategories: _carsSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'professionals',
      titleAr: 'المهنيين',
      titleEn: 'Professionals',
      image: 'assets/images/cat_professionals.png',
      entryMode: CategoryEntryMode.professionals,
      apiServiceId: 'professionals',
      apiProductCategory: 'professionals',
      hubTitleAr: 'المهنيين',
      hubSubtitleAr: 'تواصل مع مهنيين موثوقين',
      storeTitleAr: 'المهنيين',
      storeSubtitleAr: 'اختر المهنة المناسبة',
      subCategories: _professionalsSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'beauty',
      titleAr: 'الصحة والجمال',
      titleEn: 'Health & Beauty',
      image: 'assets/images/cat_beauty.png',
      entryMode: CategoryEntryMode.subCategoryHub,
      apiServiceId: 'beauty',
      apiProductCategory: 'beauty',
      hubTitleAr: 'الصحة والجمال',
      hubSubtitleAr: 'عيادات، صيدليات، وخدمات العناية',
      storeTitleAr: 'الصحة والجمال',
      storeSubtitleAr: 'اختر مزود الخدمة',
      defaultSubBrowseMode: SubCategoryBrowseMode.catalog,
      subCategories: _healthSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'tourism',
      titleAr: 'السياحة والسفر',
      titleEn: 'Tourism & Travel',
      image: 'assets/images/cat_tourism.png',
      entryMode: CategoryEntryMode.subCategoryHub,
      apiServiceId: 'tourism',
      apiProductCategory: 'tourism',
      hubTitleAr: 'السياحة والسفر',
      hubSubtitleAr: 'كروبات، فنادق، وتذاكر',
      storeTitleAr: 'السياحة والسفر',
      storeSubtitleAr: 'استكشف العروض السياحية',
      defaultSubBrowseMode: SubCategoryBrowseMode.catalog,
      subCategories: _tourismSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'real_estate',
      titleAr: 'العقارات',
      titleEn: 'Real Estate',
      image: 'assets/images/cat_real_estate.png',
      entryMode: CategoryEntryMode.realEstate,
      apiServiceId: 'real_estate',
      apiProductCategory: 'real_estate',
      hubTitleAr: 'العقارات',
      hubSubtitleAr: 'بيع، شراء، وإيجار',
      storeTitleAr: 'العقارات',
      storeSubtitleAr: 'تصفح العروض العقارية',
      subCategories: _realEstateSubCategories,
    ),
    MarketplaceCategoryDefinition(
      id: 'offers',
      titleAr: 'العروض والخصومات',
      titleEn: 'Offers',
      image: 'assets/images/cat_offers.png',
      entryMode: CategoryEntryMode.offers,
      apiServiceId: 'offers',
      apiProductCategory: 'offers',
      hubTitleAr: 'العروض والخصومات',
      hubSubtitleAr: 'أفضل الأسعار من التجار',
      storeTitleAr: 'العروض',
      storeSubtitleAr: 'منتجات مخفّضة من المتاجر',
    ),
    MarketplaceCategoryDefinition(
      id: 'used',
      titleAr: 'المنتجات المستعملة',
      titleEn: 'Used Products',
      image: 'assets/images/cat_used.png',
      entryMode: CategoryEntryMode.subCategoryHub,
      apiServiceId: 'used',
      apiProductCategory: 'used',
      hubTitleAr: 'المنتجات المستعملة',
      hubSubtitleAr: 'منتجات مستعملة بحالة جيدة',
      storeTitleAr: 'مستعمل',
      storeSubtitleAr: 'تصفح المنتجات المستعملة',
      defaultSubBrowseMode: SubCategoryBrowseMode.catalog,
      subCategories: _usedSubCategories,
    ),
  ];

  static MarketplaceCategoryDefinition? find(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// الأقسام الظاهرة للزبون في الصفحة الرئيسية (شبكة الأقسام).
  /// البازار يُعرض عبر البانر العلوي وليس ضمن هذه القائمة.
  static const Set<String> customerHomeCategoryIds = {
    'restaurant',
    'product',
  };

  static List<ServiceCategory> get homeCategories => categories
      .where((entry) => customerHomeCategoryIds.contains(entry.id))
      .map((entry) => entry.asServiceCategory)
      .toList();

  /// الأقسام المتاحة للتجار للتسجيل فيها (باستثناء الأقسام الإدارية أو الخاصة).
  static List<ServiceCategory> get merchantAvailableCategories => categories
      .where((entry) => entry.id != 'bazar_ghaith')
      .map((entry) => entry.asServiceCategory)
      .toList();

  /// أقسام التسوق — مصدر واحد للزبون والتاجر.
  static List<MarketplaceSubCategory> get shoppingSubCategories =>
      _shoppingSubCategories;

  static const List<MarketplaceSubCategory> _shoppingSubCategories = [
    MarketplaceSubCategory(id: 'home_goods', titleAr: 'مواد منزلية', titleEn: 'Home Goods', image: 'assets/images/shop_home_goods.png'),
    MarketplaceSubCategory(id: 'electrical_appliances', titleAr: 'أجهزة كهربائية', titleEn: 'Electrical Appliances', image: 'assets/images/shop_electronics.png'),
    MarketplaceSubCategory(id: 'food_items', titleAr: 'مواد غذائية', titleEn: 'Food Items', image: 'assets/images/shop_food_items.png'),
    MarketplaceSubCategory(id: 'construction', titleAr: 'مواد إنشائية', titleEn: 'Construction', image: 'assets/images/shop_construction.png'),
    MarketplaceSubCategory(id: 'school', titleAr: 'لوازم مدرسية', titleEn: 'School Supplies', image: 'assets/images/shop_school.png'),
    MarketplaceSubCategory(id: 'bakery', titleAr: 'مخابز ومعجنات', titleEn: 'Bakeries', image: 'assets/images/shop_bakery.png'),
    MarketplaceSubCategory(id: 'meat', titleAr: 'لحوم', titleEn: 'Meat', image: 'assets/images/shop_meat.png'),
    MarketplaceSubCategory(id: 'grocery', titleAr: 'بقالة', titleEn: 'Grocery', image: 'assets/images/shop_grocery.png'),
    MarketplaceSubCategory(id: 'shoes_bags', titleAr: 'أحذية وحقائب', titleEn: 'Shoes & Bags', image: 'assets/images/shop_shoes_bags.png'),
    MarketplaceSubCategory(id: 'kids_clothing', titleAr: 'ملابس أطفال', titleEn: 'Kids Clothing', image: 'assets/images/shop_kids_clothing.png'),
    MarketplaceSubCategory(id: 'women_clothing', titleAr: 'ملابس نسائية', titleEn: 'Women Clothing', image: 'assets/images/shop_women_clothing.png'),
    MarketplaceSubCategory(id: 'men_clothing', titleAr: 'ملابس رجالية', titleEn: 'Men Clothing', image: 'assets/images/shop_men_clothing.png'),
    MarketplaceSubCategory(id: 'cosmetics', titleAr: 'مستحضرات تجميل', titleEn: 'Cosmetics', image: 'assets/images/shop_cosmetics.png'),
    MarketplaceSubCategory(id: 'gifts', titleAr: 'زهور وهدايا', titleEn: 'Flowers & Gifts', image: 'assets/images/shop_gifts.png'),
  ];

  static const List<MarketplaceSubCategory> _carsSubCategories = [
    MarketplaceSubCategory(id: 'car_request', titleAr: 'طلب سيارة', titleEn: 'Request Car', image: 'assets/images/car_request.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'car_sell', titleAr: 'بيع سيارة', titleEn: 'Sell Car', image: 'assets/images/car_sell.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'car_buy', titleAr: 'شراء سيارة', titleEn: 'Buy Car', image: 'assets/images/car_buy.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  /// أنواع «طلب سيارة» + بيع/شراء — للنشر من التاجر.
  static const List<MarketplaceSubCategory> _carServiceSubCategories = [
    MarketplaceSubCategory(id: 'car_4seat', titleAr: 'سيارة 4 راكب', titleEn: '4-Seat Car', image: 'assets/images/car_req_4seat.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'car_truck', titleAr: 'سيارة حمل', titleEn: 'Truck', image: 'assets/images/car_req_truck.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'car_bus', titleAr: 'سيارة باص', titleEn: 'Bus', image: 'assets/images/car_req_bus.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'car_starx11', titleAr: 'سيارة ستاركس 11 نفر', titleEn: 'Starx 11 Seats', image: 'assets/images/car_req_starx11.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  static const List<MarketplaceSubCategory> _tourismSubCategories = [
    MarketplaceSubCategory(id: 'groups', titleAr: 'كروبات سياحية', titleEn: 'Tour Groups', image: 'assets/images/tour_groups.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'hotels', titleAr: 'حجز فنادق', titleEn: 'Hotel Booking', image: 'assets/images/tour_hotels.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'flights', titleAr: 'تذاكر طيران', titleEn: 'Flight Tickets', image: 'assets/images/tour_flights.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  static const List<MarketplaceSubCategory> _healthSubCategories = [
    MarketplaceSubCategory(id: 'hospitals', titleAr: 'مستشفيات', titleEn: 'Hospitals', image: 'assets/images/health_hospitals.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'doctors', titleAr: 'أطباء وعيادات', titleEn: 'Doctors & Clinics', image: 'assets/images/health_doctors.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'pharmacies', titleAr: 'صيدليات', titleEn: 'Pharmacies', image: 'assets/images/health_pharmacies.png', browseMode: SubCategoryBrowseMode.stores),
    MarketplaceSubCategory(id: 'salon', titleAr: 'صالون وتجميل', titleEn: 'Salon & Beauty', image: 'assets/images/health_salon.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  static const List<MarketplaceSubCategory> _realEstateSubCategories = [
    MarketplaceSubCategory(id: 'house', titleAr: 'دار', titleEn: 'House', image: 'assets/images/re_house.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'land', titleAr: 'أرض', titleEn: 'Land', image: 'assets/images/re_land.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'shops', titleAr: 'محلات تجارية', titleEn: 'Commercial Shops', image: 'assets/images/re_shops.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'apartment', titleAr: 'شقة', titleEn: 'Apartment', image: 'assets/images/re_apartment.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'building', titleAr: 'بناية سكنية تجارية', titleEn: 'Building', image: 'assets/images/re_building.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'farm', titleAr: 'مزرعة', titleEn: 'Farm', image: 'assets/images/re_farm.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  static const List<MarketplaceSubCategory> _globalShoppingSubCategories = [
    MarketplaceSubCategory(id: 'china', titleAr: 'الصين', titleEn: 'China', image: 'assets/images/global_china.png'),
  ];

  /// أقسام المهنيين — مصدر واحد للزبون والتاجر.
  static List<MarketplaceSubCategory> get professionalsSubCategories =>
      _professionalsSubCategories;

  static const List<MarketplaceSubCategory> _professionalsSubCategories = [
    MarketplaceSubCategory(id: 'plumber', titleAr: 'سباك', titleEn: 'Plumber', image: 'assets/images/prof_plumber.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'electrician', titleAr: 'كهربائي', titleEn: 'Electrician', image: 'assets/images/prof_electrician.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'ac_tech', titleAr: 'فني تكييف', titleEn: 'AC Technician', image: 'assets/images/prof_ac.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'carpenter', titleAr: 'نجار', titleEn: 'Carpenter', image: 'assets/images/prof_carpenter.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'cleaner', titleAr: 'تنظيف منازل', titleEn: 'Home Cleaner', image: 'assets/images/prof_cleaner.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'blacksmith', titleAr: 'حداد', titleEn: 'Blacksmith', image: 'assets/images/prof_blacksmith.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'painter', titleAr: 'صباغ', titleEn: 'Painter', image: 'assets/images/prof_painter.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'builder', titleAr: 'بناء', titleEn: 'Builder', image: 'assets/images/prof_builder.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'cctv_tech', titleAr: 'فني كاميرات مراقبة', titleEn: 'CCTV Technician', image: 'assets/images/prof_cctv.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'network_tech', titleAr: 'فني إنترنت وشبكات', titleEn: 'Network Technician', image: 'assets/images/prof_network.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'loading_worker', titleAr: 'عامل تحميل وتنزيل', titleEn: 'Loading Worker', image: 'assets/images/prof_loading.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'gardener', titleAr: 'عامل حدائق', titleEn: 'Gardener', image: 'assets/images/prof_gardener.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'aluminum_glass', titleAr: 'فني ألمنيوم وزجاج', titleEn: 'Aluminum & Glass', image: 'assets/images/prof_aluminum_glass.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  static const List<MarketplaceSubCategory> _usedSubCategories = [
    MarketplaceSubCategory(id: 'used_electronics', titleAr: 'إلكترونيات', titleEn: 'Electronics', image: 'assets/images/shop_electronics.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'used_furniture', titleAr: 'أثاث', titleEn: 'Furniture', image: 'assets/images/shop_home_goods.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'used_clothing', titleAr: 'ملابس', titleEn: 'Clothing', image: 'assets/images/shop_women_clothing.png', browseMode: SubCategoryBrowseMode.catalog),
    MarketplaceSubCategory(id: 'used_other', titleAr: 'متنوعات', titleEn: 'Other', image: 'assets/images/cat_used.png', browseMode: SubCategoryBrowseMode.catalog),
  ];

  /// الخدمات التي تدعم الطلب عبر السلة (مطاعم + تسوق فقط).
  static const Set<String> cartEnabledCategoryIds = {
    'restaurant',
    'product',
    'bazar_ghaith',
  };

  static bool usesShoppingCart(String? categoryId) {
    final id = categoryId?.trim();
    if (id == null || id.isEmpty) return false;
    return cartEnabledCategoryIds.contains(id);
  }

  /// كل ما عدا المطاعم والتسوق = إعلان/تواصل (واتساب واتصال).
  static bool isContactListingCategory(String? categoryId) =>
      !usesShoppingCart(categoryId);

  static const Set<String> carServiceSubCategoryIds = {
    'car_4seat',
    'car_truck',
    'car_bus',
    'car_starx11',
  };

  /// أقسام السيارات التي ينشر فيها التاجر (بدون طلب تكسي).
  static List<MarketplaceSubCategory> get carsPublishSubCategories => [
    ..._carServiceSubCategories,
    ..._carsSubCategories.where(
      (sub) => sub.id == 'car_sell' || sub.id == 'car_buy',
    ),
  ];
}
