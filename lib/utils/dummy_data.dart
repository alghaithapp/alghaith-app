import '../models/app_models.dart';
import '../core/catalog/marketplace_catalog.dart';

class DummyData {
  static List<ServiceCategory> get categories =>
      MarketplaceCatalog.categories
          .map((entry) => entry.asServiceCategory)
          .toList();

  static List<ServiceCategory> get shoppingSubCategories =>
      MarketplaceCatalog.shoppingSubCategories
          .map(
            (sub) => ServiceCategory(
              id: sub.id,
              titleAr: sub.titleAr,
              titleEn: sub.titleEn,
              image: sub.image,
            ),
          )
          .toList();

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

  static final List<ServiceCategory> carRequestVehicleTypes = [
    ServiceCategory(
      id: 'car_4seat',
      titleAr: 'طلب سيارة 4 راكب',
      titleEn: '4-Seat Car Request',
      image: 'assets/images/car_req_4seat.png',
    ),
    ServiceCategory(
      id: 'car_starx11',
      titleAr: 'طلب سيارة 11 راكب',
      titleEn: '11-Seat Car Request',
      image: 'assets/images/car_starx11.png',
    ),
    ServiceCategory(
      id: 'car_truck',
      titleAr: 'طلب سيارة حمل',
      titleEn: 'Truck Request',
      image: 'assets/images/car_truck.png',
    ),
    ServiceCategory(
      id: 'car_bus',
      titleAr: 'طلب سيارة باص',
      titleEn: 'Bus Request',
      image: 'assets/images/car_bus.png',
    ),
  ];

  @Deprecated('Use carRequestVehicleTypes')
  static List<ServiceCategory> get requestCarOptions => carRequestVehicleTypes;

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

  /// شراء — بيع — إيجار (المستوى الأول في العقارات).
  static final List<ServiceCategory> realEstateDealOptions = [
    ServiceCategory(
      id: 'buy',
      titleAr: 'شراء',
      titleEn: 'Buy',
      image: 'assets/images/re_buy.png',
    ),
    ServiceCategory(
      id: 'sell',
      titleAr: 'بيع',
      titleEn: 'Sell',
      image: 'assets/images/re_sell.png',
    ),
    ServiceCategory(
      id: 'rent',
      titleAr: 'إيجار',
      titleEn: 'Rent',
      image: 'assets/images/re_rent.png',
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

  static List<ServiceCategory> get professionalsSubCategories =>
      MarketplaceCatalog.professionalsSubCategories
          .map(
            (sub) => ServiceCategory(
              id: sub.id,
              titleAr: sub.titleAr,
              titleEn: sub.titleEn,
              image: sub.image,
            ),
          )
          .toList();

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
