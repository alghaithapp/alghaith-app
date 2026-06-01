class MerchantServiceLabels {
  final String storeLabelAr;
  final String storeLabelEn;
  final String accountTitleAr;
  final String accountTitleEn;
  final String dashboardGreetingAr;
  final String dashboardGreetingEn;
  final String dashboardIntroAr;
  final String dashboardIntroEn;
  final String productsTitleAr;
  final String productsTitleEn;
  final String addItemAr;
  final String addItemEn;
  final String editItemAr;
  final String editItemEn;
  final String itemSingularAr;
  final String itemSingularEn;
  final String itemPluralAr;
  final String itemPluralEn;
  final String actionLabelAr;
  final String actionLabelEn;
  final String searchPlaceholderAr;
  final String searchPlaceholderEn;
  final String storeSettingsTitleAr;
  final String storeSettingsTitleEn;
  final String storeNameLabelAr;
  final String storeNameLabelEn;
  final String descriptionLabelAr;
  final String descriptionLabelEn;
  final String coverLabelAr;
  final String coverLabelEn;
  final String logoLabelAr;
  final String logoLabelEn;
  final String workingHoursLabelAr;
  final String workingHoursLabelEn;
  final String deliveryAreasLabelAr;
  final String deliveryAreasLabelEn;
  final String deliveryFeeLabelAr;
  final String deliveryFeeLabelEn;
  final String businessDescriptionAr;
  final String businessDescriptionEn;

  const MerchantServiceLabels({
    required this.storeLabelAr,
    required this.storeLabelEn,
    required this.accountTitleAr,
    required this.accountTitleEn,
    required this.dashboardGreetingAr,
    required this.dashboardGreetingEn,
    required this.dashboardIntroAr,
    required this.dashboardIntroEn,
    required this.productsTitleAr,
    required this.productsTitleEn,
    required this.addItemAr,
    required this.addItemEn,
    required this.editItemAr,
    required this.editItemEn,
    required this.itemSingularAr,
    required this.itemSingularEn,
    required this.itemPluralAr,
    required this.itemPluralEn,
    required this.actionLabelAr,
    required this.actionLabelEn,
    required this.searchPlaceholderAr,
    required this.searchPlaceholderEn,
    required this.storeSettingsTitleAr,
    required this.storeSettingsTitleEn,
    required this.storeNameLabelAr,
    required this.storeNameLabelEn,
    required this.descriptionLabelAr,
    required this.descriptionLabelEn,
    required this.coverLabelAr,
    required this.coverLabelEn,
    required this.logoLabelAr,
    required this.logoLabelEn,
    required this.workingHoursLabelAr,
    required this.workingHoursLabelEn,
    required this.deliveryAreasLabelAr,
    required this.deliveryAreasLabelEn,
    required this.deliveryFeeLabelAr,
    required this.deliveryFeeLabelEn,
    required this.businessDescriptionAr,
    required this.businessDescriptionEn,
  });
}

MerchantServiceLabels merchantServiceLabels(String categoryId) {
  switch (categoryId) {
    case 'restaurant':
      return const MerchantServiceLabels(
        storeLabelAr: 'مطعم',
        storeLabelEn: 'Restaurant',
        accountTitleAr: 'حساب المطعم',
        accountTitleEn: 'Restaurant Account',
        dashboardGreetingAr: 'هذا مطعمك على الغيث',
        dashboardGreetingEn: 'Your restaurant on Al-Ghaith',
        dashboardIntroAr: 'أدر المنيو والطلبات والمبيعات وساعات العمل بسهولة.',
        dashboardIntroEn:
            'Manage menu, orders, sales and working hours easily.',
        productsTitleAr: 'المنيو',
        productsTitleEn: 'Menu',
        addItemAr: 'إضافة وجبة',
        addItemEn: 'Add Meal',
        editItemAr: 'تعديل وجبة',
        editItemEn: 'Edit Meal',
        itemSingularAr: 'وجبة',
        itemSingularEn: 'Meal',
        itemPluralAr: 'وجبات',
        itemPluralEn: 'Meals',
        actionLabelAr: 'أضف للسلة',
        actionLabelEn: 'Add to Cart',
        searchPlaceholderAr: 'ابحث في المنيو',
        searchPlaceholderEn: 'Search menu',
        storeSettingsTitleAr: 'إعدادات المطعم',
        storeSettingsTitleEn: 'Restaurant Settings',
        storeNameLabelAr: 'اسم المطعم',
        storeNameLabelEn: 'Restaurant name',
        descriptionLabelAr: 'وصف المطعم',
        descriptionLabelEn: 'Restaurant description',
        coverLabelAr: 'صورة المطعم',
        coverLabelEn: 'Restaurant cover',
        logoLabelAr: 'شعار المطعم',
        logoLabelEn: 'Restaurant logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق التوصيل',
        deliveryAreasLabelEn: 'Delivery areas',
        deliveryFeeLabelAr: 'رسوم التوصيل',
        deliveryFeeLabelEn: 'Delivery fee',
        businessDescriptionAr: 'مطعم',
        businessDescriptionEn: 'Restaurant',
      );
    case 'cars':
      return const MerchantServiceLabels(
        storeLabelAr: 'معرض سيارات',
        storeLabelEn: 'Car Showroom',
        accountTitleAr: 'حساب المعرض',
        accountTitleEn: 'Showroom Account',
        dashboardGreetingAr: 'هذا معرضك على الغيث',
        dashboardGreetingEn: 'Your showroom on Al-Ghaith',
        dashboardIntroAr:
            'أدر السيارات المعروضة، والاستفسارات، والتواصل من مكان واحد.',
        dashboardIntroEn:
            'Manage listed cars, inquiries and contact in one place.',
        productsTitleAr: 'السيارات',
        productsTitleEn: 'Cars',
        addItemAr: 'إضافة سيارة',
        addItemEn: 'Add Car',
        editItemAr: 'تعديل سيارة',
        editItemEn: 'Edit Car',
        itemSingularAr: 'سيارة',
        itemSingularEn: 'Car',
        itemPluralAr: 'سيارات',
        itemPluralEn: 'Cars',
        actionLabelAr: 'عرض التفاصيل',
        actionLabelEn: 'View Details',
        searchPlaceholderAr: 'ابحث عن سيارة',
        searchPlaceholderEn: 'Search car',
        storeSettingsTitleAr: 'إعدادات المعرض',
        storeSettingsTitleEn: 'Showroom Settings',
        storeNameLabelAr: 'اسم المعرض',
        storeNameLabelEn: 'Showroom name',
        descriptionLabelAr: 'وصف المعرض',
        descriptionLabelEn: 'Showroom description',
        coverLabelAr: 'صورة المعرض',
        coverLabelEn: 'Showroom cover',
        logoLabelAr: 'شعار المعرض',
        logoLabelEn: 'Showroom logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق الخدمة',
        deliveryAreasLabelEn: 'Service areas',
        deliveryFeeLabelAr: 'رسوم النقل',
        deliveryFeeLabelEn: 'Transport fee',
        businessDescriptionAr: 'معرض سيارات',
        businessDescriptionEn: 'Showroom',
      );
    case 'product':
      return const MerchantServiceLabels(
        storeLabelAr: 'متجر',
        storeLabelEn: 'Store',
        accountTitleAr: 'حساب المتجر',
        accountTitleEn: 'Store Account',
        dashboardGreetingAr: 'هذا متجرك على الغيث',
        dashboardGreetingEn: 'Your store on Al-Ghaith',
        dashboardIntroAr: 'أدر المنتجات والطلبات والعروض بطريقة سهلة وسريعة.',
        dashboardIntroEn: 'Manage products, orders and offers with ease.',
        productsTitleAr: 'المنتجات',
        productsTitleEn: 'Products',
        addItemAr: 'إضافة منتج',
        addItemEn: 'Add Product',
        editItemAr: 'تعديل منتج',
        editItemEn: 'Edit Product',
        itemSingularAr: 'منتج',
        itemSingularEn: 'Product',
        itemPluralAr: 'منتجات',
        itemPluralEn: 'Products',
        actionLabelAr: 'أضف للسلة',
        actionLabelEn: 'Add to Cart',
        searchPlaceholderAr: 'ابحث عن منتج',
        searchPlaceholderEn: 'Search product',
        storeSettingsTitleAr: 'إعدادات المتجر',
        storeSettingsTitleEn: 'Store Settings',
        storeNameLabelAr: 'اسم المتجر',
        storeNameLabelEn: 'Store name',
        descriptionLabelAr: 'وصف المتجر',
        descriptionLabelEn: 'Store description',
        coverLabelAr: 'صورة المتجر',
        coverLabelEn: 'Store cover',
        logoLabelAr: 'شعار المتجر',
        logoLabelEn: 'Store logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق التوصيل',
        deliveryAreasLabelEn: 'Delivery areas',
        deliveryFeeLabelAr: 'رسوم التوصيل',
        deliveryFeeLabelEn: 'Delivery fee',
        businessDescriptionAr: 'متجر',
        businessDescriptionEn: 'Store',
      );
    case 'real_estate':
      return const MerchantServiceLabels(
        storeLabelAr: 'مكتب عقاري',
        storeLabelEn: 'Real Estate Office',
        accountTitleAr: 'حساب المكتب العقاري',
        accountTitleEn: 'Real Estate Account',
        dashboardGreetingAr: 'هذا مكتبك العقاري على الغيث',
        dashboardGreetingEn: 'Your real estate office on Al-Ghaith',
        dashboardIntroAr: 'أدر العقارات المعروضة والطلبات والاستفسارات بسهولة.',
        dashboardIntroEn: 'Manage listings, leads, and inquiries easily.',
        productsTitleAr: 'العقارات',
        productsTitleEn: 'Properties',
        addItemAr: 'إضافة عقار',
        addItemEn: 'Add Property',
        editItemAr: 'تعديل عقار',
        editItemEn: 'Edit Property',
        itemSingularAr: 'عقار',
        itemSingularEn: 'Property',
        itemPluralAr: 'عقارات',
        itemPluralEn: 'Properties',
        actionLabelAr: 'تواصل',
        actionLabelEn: 'Contact',
        searchPlaceholderAr: 'ابحث عن عقار',
        searchPlaceholderEn: 'Search property',
        storeSettingsTitleAr: 'إعدادات المكتب',
        storeSettingsTitleEn: 'Office Settings',
        storeNameLabelAr: 'اسم المكتب',
        storeNameLabelEn: 'Office name',
        descriptionLabelAr: 'وصف المكتب',
        descriptionLabelEn: 'Office description',
        coverLabelAr: 'صورة المكتب',
        coverLabelEn: 'Office cover',
        logoLabelAr: 'شعار المكتب',
        logoLabelEn: 'Office logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق الخدمة',
        deliveryAreasLabelEn: 'Service areas',
        deliveryFeeLabelAr: 'رسوم التوصيل',
        deliveryFeeLabelEn: 'Delivery fee',
        businessDescriptionAr: 'مكتب عقاري',
        businessDescriptionEn: 'Office',
      );
    case 'professionals':
      return const MerchantServiceLabels(
        storeLabelAr: 'مهني',
        storeLabelEn: 'Professional',
        accountTitleAr: 'حساب المهني',
        accountTitleEn: 'Professional Account',
        dashboardGreetingAr: 'هذا ملفك المهني على الغيث',
        dashboardGreetingEn: 'Your professional dashboard on Al-Ghaith',
        dashboardIntroAr:
            'أدر خدماتك واستقبل طلبات العملاء عبر واتساب بدون عمولة مباشرة.',
        dashboardIntroEn:
            'Manage your services and receive customer requests without direct fees.',
        productsTitleAr: 'الخدمات',
        productsTitleEn: 'Services',
        addItemAr: 'إضافة خدمة',
        addItemEn: 'Add Service',
        editItemAr: 'تعديل خدمة',
        editItemEn: 'Edit Service',
        itemSingularAr: 'خدمة',
        itemSingularEn: 'Service',
        itemPluralAr: 'خدمات',
        itemPluralEn: 'Services',
        actionLabelAr: 'تواصل',
        actionLabelEn: 'Contact',
        searchPlaceholderAr: 'ابحث عن خدمة',
        searchPlaceholderEn: 'Search service',
        storeSettingsTitleAr: 'إعدادات المهني',
        storeSettingsTitleEn: 'Professional Settings',
        storeNameLabelAr: 'اسم المهني',
        storeNameLabelEn: 'Professional name',
        descriptionLabelAr: 'وصف المهني',
        descriptionLabelEn: 'Professional description',
        coverLabelAr: 'صورة المهني',
        coverLabelEn: 'Professional cover',
        logoLabelAr: 'صورة الملف',
        logoLabelEn: 'Profile image',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق الخدمة',
        deliveryAreasLabelEn: 'Service areas',
        deliveryFeeLabelAr: 'بدون رسوم مباشرة',
        deliveryFeeLabelEn: 'No direct fee',
        businessDescriptionAr: 'مهني',
        businessDescriptionEn: 'Professional',
      );
    default:
      return const MerchantServiceLabels(
        storeLabelAr: 'متجر',
        storeLabelEn: 'Store',
        accountTitleAr: 'حساب التاجر',
        accountTitleEn: 'Merchant Account',
        dashboardGreetingAr: 'هذه لوحة التاجر على الغيث',
        dashboardGreetingEn: 'Your merchant dashboard on Al-Ghaith',
        dashboardIntroAr: 'أدر منتجاتك وطلباتك بسهولة.',
        dashboardIntroEn: 'Manage your items and orders easily.',
        productsTitleAr: 'المنتجات',
        productsTitleEn: 'Products',
        addItemAr: 'إضافة عنصر',
        addItemEn: 'Add Item',
        editItemAr: 'تعديل عنصر',
        editItemEn: 'Edit Item',
        itemSingularAr: 'عنصر',
        itemSingularEn: 'Item',
        itemPluralAr: 'عناصر',
        itemPluralEn: 'Items',
        actionLabelAr: 'أضف للسلة',
        actionLabelEn: 'Add to Cart',
        searchPlaceholderAr: 'ابحث هنا',
        searchPlaceholderEn: 'Search here',
        storeSettingsTitleAr: 'إعدادات التاجر',
        storeSettingsTitleEn: 'Merchant Settings',
        storeNameLabelAr: 'اسم المتجر',
        storeNameLabelEn: 'Store name',
        descriptionLabelAr: 'الوصف',
        descriptionLabelEn: 'Description',
        coverLabelAr: 'صورة الغلاف',
        coverLabelEn: 'Cover image',
        logoLabelAr: 'الشعار',
        logoLabelEn: 'Logo',
        workingHoursLabelAr: 'أوقات العمل',
        workingHoursLabelEn: 'Working hours',
        deliveryAreasLabelAr: 'مناطق الخدمة',
        deliveryAreasLabelEn: 'Service areas',
        deliveryFeeLabelAr: 'رسوم الخدمة',
        deliveryFeeLabelEn: 'Service fee',
        businessDescriptionAr: 'متجر',
        businessDescriptionEn: 'Store',
      );
  }
}
