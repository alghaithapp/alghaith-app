import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { translations } from './translations';
import { ListItem, CartItem, ActiveOrder, AppNotification, ServiceCategory } from './types';

// Initial state and realistic assets
const ALL_SERVICE_CATEGORIES: ServiceCategory[] = [
  {
    id: 'restaurant',
    titleAr: 'المطاعم',
    titleEn: 'Restaurants',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ujyY1KjmoNG9ANsyuwhgoAEqVVaUedhZhqHSHw9xPuAQ6WEy1d2eQuVFW_Cek6qaFquYoqb5SQoY7tvW3SXYKsabRTWnDBS7lNeI7V_EP46mgKWZ__YNanmgjl7k_XZz9ZJzFA9ZIAgDMrU-2Om-TmxXoQZvODCkX_7CKEf0aFiq_3RFtFw90EOl2zeZJHAWHDwn_ODvcLk9T4xKVbZLHvEnJcZekJ6TLjm0UBYrO-LW7_JkdYuhaEjeEqY'
  },
  {
    id: 'product',
    titleAr: 'التسوق',
    titleEn: 'Shopping',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uhYTzIRhDjapKjLqhXFMdOysZRItQuTUAO5a0_PZO5We6F67_lheDgmWSVaHdbTXhgqDlOJ2RemxA5z1wW0JyTQ6DpGTzTd0-Q6M51Ck72e4Y0s-HZ-BFpJOeRZxygoOlFs8fRja4tjbQ_fVDLu2zfQAj10UZ38-PUOPetWSC428-E6R2DfVeazhIRVOaQEwWybz2Veo1AhEpj99auOmtEJ1Ier2-8saMrQ2_vo4IPWlRo0aXnXB4kQT_fx'
  },
  {
    id: 'cars',
    titleAr: 'السيارات',
    titleEn: 'Cars',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uh1ugETMU2Zu8fF1q_xhQQhf0sdOToqW5EBMCD77axqYY0UjZ-8n_J6i3GlQZkJxQsVFwteKBTxsIMZC3vPEwKzShzi7YkrtcOiDE3H2W7Akhox6CEZRGlAkflpojYmjNIu2GA7ZwNHTJV9MYzdb9fm4vjlyLB-mfB7JXS8Ivb4G02bzcmX1rnZPCopTq-ZXupL1shYXO9-vifK86ZaQSbk6EQ-joN-upRy6i8bJiqj6XEdzPhbwqNi8hdy'
  },
  {
    id: 'professionals',
    titleAr: 'المهنيين',
    titleEn: 'Professionals',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uiBlkWV-IY9RI_byTIXX_l7fTO2ZMzX7WjliQ6j3aSORJcDWCA1eI5VZuStFm47oolmUsQkM3D7X57eDuki2FzHAHO9oqD-0cYsr37ppIEDcwZnld2dofvEZgi1pQ9aWtCOWYYPLB_fhz2PLC385F_8nB9_sCs4U-jq7OWtOvLKnSLxSdeWl_ZWCPkJuAID5GVhi5T4PCxajpxcWdTadlz_uGFn9UPUbFPjQl_ZuMStr_71XHxjwLFblAx0'
  },
  {
    id: 'beauty',
    titleAr: 'الصحة والجمال',
    titleEn: 'Health & Beauty',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ui5plK7jrhHBOweuemHet5-wQKqOSIuvCWAwQwSe7yVoL4dtc0ShZm4PDLEeiCib0INT7jjttdrusqEcoidMYEtmKYtakZkEu2fXKb6WomkMqla3YCJc2sJI38QC2TRTrbtbQxKef-tv_6O_IrWDTeLACIFdwdf8vFr1GAA71oeWYRZaNdKNqPntrhzWz2XJAuY8g9A2tmp8_lnbSptNtTcRt-WiXKXe7ypYJp2MIqx9tKgqIwb7Nb3537X'
  },
  {
    id: 'tourism',
    titleAr: 'السياحة والسفر',
    titleEn: 'Tourism & Travel',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ujoovnZIqx69FqwKE13Vp_QA1SEDijUxBG3YqMPzr3EQ_VOl0uE4ilWxNjfaSFIHkuysL6gOPeGWMQ0Bn0W90zAlGaNIJvodJgGlGayvLD_IKiyJJpemy3GONZrB74yBN0iHOnwgICeVfeLxJJQsRuGxw36xniuDdirqB1JPcbqMZTRqu9MdRiHeI-fYNY0Y8vL2YMCui87MXQB2B8Q_3uhuvhDz0TMjaTTPT-_7fUnlN42WSTejlqGqllw'
  },
  {
    id: 'real_estate',
    titleAr: 'العقارات',
    titleEn: 'Real Estate',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ugoMP6UlHsnnZs_mPt7HUgY2HKudrPHOuz7VxN9vH6dTJPB497sIuRdRio64-LfgwSS7MtWm9bO_-XbwTCp6LnVeW_cHxtYIyu8OtFClG6jqegvkpUvGk8HspVtsoD1WFD1skmCeI-BVKxrE62uQhIKprMzNphfpfEJfAdgSvvNtiREX3fCHmNWerTi1SAnE5Rtev3AcpvpFw5dCX4UibvnA6tTd_vfNs0N5IxbWTCxidLyRnpOElSKdI0'
  },
  {
    id: 'offers',
    titleAr: 'العروض والخصومات',
    titleEn: 'Offers',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uhvLOo3OOL89nlZPNjzOliyWRJc_rwjTPYmK0G1LGkWhyJnGnbiSkztqhIPeHVsznpi4YCxOyCKXKisEw1lbeZ4n-liGoW_kIbqvW4HANeK2aUhYSV6cFk--SXZ0AyXFo8KzZI64W5EhT9QjPVpfXHdF_l4bYgXtvBEvxH2ew-stnwHQwLA-a-6lc2sGPBZ2e-sMVrQIHNTxlky0P1I_rhAuW-h16zKsZE2wEwAOklls6LfUrm_bAOjlcmu'
  },
  {
    id: 'global_shopping',
    titleAr: 'التسوق العالمي',
    titleEn: 'Global Shopping',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ujVNTBzE6UaSxK1NNx5dbsDzttsF0FZ_3oNzrfDuCVlaZ5Ntu5NptEU9p8gJGtvlVw3xFBzmp781tynozsV8MTUs5R5WMLapCixO90CsmAUvB6a8iQ0nHd1pNq-Xn5-5ml2i4fnvNDC7VGrzC5UgDeFh_LUcsNLBRranxdiPFviPt8ehKM4kODg7W5pZ1CKa8m0xEojsC0qGFBvWRucMCho6kP8hUPkA_z2Q-sGoe3XneQFoWKgoMfuWgsS'
  },
  {
    id: 'used',
    titleAr: 'المنتجات المستعملة',
    titleEn: 'Used Products',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uhPzSadG6sn9vW7NHDZ7MQDm_IKDVb91VBweZx0vzV40DdS8kEssBmKSdAmgNCz6pWrwhpW7Iq1o4h-QGxzzmG0dLkfONtsSPIFBrch7D_BHGHu6NO6iC6tLYlMYi_KM32OQ_NP4xlOuMsVOMQ9jD_0pqZwzh-98c43oo0zCh645gHM-sUyodR1Yusrw-oFrbvOJqGT1-Grm43zHU8WJvV-H_FcHuGAfLOQgep8R578rJMBr_6bBEZ46Xm6'
  }
];

const SHOPPING_SUB_CATEGORIES = [
  { id: 'clothes', titleAr: 'ملابس', titleEn: 'Clothing', image: 'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?auto=format&fit=crop&w=400' },
  { id: 'grocery', titleAr: 'بقالة', titleEn: 'Grocery', image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400' },
  { id: 'meat', titleAr: 'لحوم', titleEn: 'Meat', image: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=400' },
  { id: 'food', titleAr: 'مواد غذائية', titleEn: 'Food Items', image: 'https://images.unsplash.com/photo-1506617564039-2f3b650ad755?auto=format&fit=crop&w=400' },
  { id: 'home_goods', titleAr: 'مواد منزلية', titleEn: 'Home Goods', image: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=400' },
  { id: 'construction', titleAr: 'مواد انشائية', titleEn: 'Construction', image: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=400' },
  { id: 'school', titleAr: 'لوازم مدرسية', titleEn: 'School Supplies', image: 'https://images.unsplash.com/photo-1456735190827-d1262f71b8a3?auto=format&fit=crop&w=400' },
  { id: 'bakery', titleAr: 'مخابز ومعجنات', titleEn: 'Bakeries', image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400' },
  { id: 'gifts', titleAr: 'زهور وهدايا', titleEn: 'Flowers & Gifts', image: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=400' },
  { id: 'cosmetics', titleAr: 'كوزمتك', titleEn: 'Cosmetics', image: 'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?auto=format&fit=crop&w=400' },
  { id: 'shoes', titleAr: 'احذية وحقائب', titleEn: 'Shoes & Bags', image: 'https://images.unsplash.com/photo-1549298916-b41d501d3772?auto=format&fit=crop&w=400' },
];

const CARS_SUB_CATEGORIES = [
  { id: 'taxi', titleAr: 'طلب تكسي', titleEn: 'Taxi Request', image: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=400' },
  { id: 'private', titleAr: 'سيارة خاصة', titleEn: 'Private Car', image: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&w=400' },
  { id: 'intercity', titleAr: 'تنقل بين محافظات', titleEn: 'Inter-city Travel', image: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=400' },
  { id: 'truck', titleAr: 'سيارة حمل', titleEn: 'Truck', image: 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=400' },
  { id: 'bus', titleAr: 'سيارة باص', titleEn: 'Bus', image: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=400' },
  { id: 'heavy', titleAr: 'سيارة تاركس', titleEn: 'Heavy Machinery', image: 'https://images.unsplash.com/photo-1586864387967-d02ef85d93e8?auto=format&fit=crop&w=400' },
  { id: 'tuktuk', titleAr: 'تك توك', titleEn: 'Tuk-tuk', image: 'https://images.unsplash.com/photo-1561131668-f63504fc549d?auto=format&fit=crop&w=400' },
  { id: 'waz', titleAr: 'واز', titleEn: 'Waz', image: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=400' },
];

const TOURISM_SUB_CATEGORIES = [
  { id: 'groups', titleAr: 'كروبات سياحية', titleEn: 'Tour Groups', image: 'https://images.unsplash.com/photo-1527631746610-bca00a040d60?auto=format&fit=crop&w=400' },
  { id: 'hotels', titleAr: 'حجز فنادق', titleEn: 'Hotel Booking', image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=400' },
  { id: 'flights', titleAr: 'تذاكر طيران', titleEn: 'Flight Tickets', image: 'https://images.unsplash.com/photo-1436491865332-7a61a109c0f3?auto=format&fit=crop&w=400' },
];

const REAL_ESTATE_SUB_CATEGORIES = [
  { id: 'house', titleAr: 'دار', titleEn: 'House', image: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=400' },
  { id: 'land', titleAr: 'أرض', titleEn: 'Land', image: 'https://images.unsplash.com/photo-1500382017468-9049fee74a62?auto=format&fit=crop&w=400' },
  { id: 'shops', titleAr: 'محلات', titleEn: 'Shops', image: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=400' },
  { id: 'apartment', titleAr: 'شقة', titleEn: 'Apartment', image: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=400' },
  { id: 'building', titleAr: 'بناية', titleEn: 'Building', image: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=400' },
  { id: 'farm', titleAr: 'مزرعة', titleEn: 'Farm', image: 'https://images.unsplash.com/photo-1500382017468-9049fee74a62?auto=format&fit=crop&w=400' },
];

const HEALTH_BEAUTY_SUB_CATEGORIES = [
  { id: 'hospitals', titleAr: 'مستشفيات', titleEn: 'Hospitals', image: 'https://images.unsplash.com/photo-1586773860418-d3b97978c65c?auto=format&fit=crop&w=400' },
  { id: 'doctors', titleAr: 'اطباء وعيادات', titleEn: 'Doctors & Clinics', image: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=400' },
  { id: 'pharmacies', titleAr: 'صيدليات', titleEn: 'Pharmacies', image: 'https://images.unsplash.com/photo-1587854692152-cbe660dbbb88?auto=format&fit=crop&w=400' },
  { id: 'salon', titleAr: 'صالون وتجميل', titleEn: 'Salon & Beauty', image: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=400' },
];

const INITIAL_ITEMS: ListItem[] = [
  {
    id: 'sky-restaurant',
    nameAr: 'مطعم سكاي بي سي',
    nameEn: 'Sky Restaurant',
    descriptionAr: 'أفضل الأطباق العالمية في أجواء فاخرة مع إطلالة بانورامية رائعة تميز زيارتك العائلية والخاصة بالتفرد.',
    descriptionEn: 'The finest international dishes in a luxury setting with a spectacular panoramic view to make your visit unique.',
    price: 35000,
    rating: 4.8,
    category: 'restaurant',
    categoryLabelAr: 'مطاعم',
    categoryLabelEn: 'Restaurants',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ujyY1KjmoNG9ANsyuwhgoAEqVVaUedhZhqHSHw9xPuAQ6WEy1d2eQuVFW_Cek6qaFquYoqb5SQoY7tvW3SXYKsabRTWnDBS7lNeI7V_EP46mgKWZ__YNanmgjl7k_XZz9ZJzFA9ZIAgDMrU-2Om-TmxXoQZvODCkX_7CKEf0aFiq_3RFtFw90EOl2zeZJHAWHDwn_ODvcLk9T4xKVbZLHvEnJcZekJ6TLjm0UBYrO-LW7_JkdYuhaEjeEqY',
    isFavorite: true,
    avgPriceLabelAr: 'متوسط السعر',
    avgPriceLabelEn: 'Avg Price',
    actionLabelAr: 'حجز طاولة',
    actionLabelEn: 'Book Table',
  },
  {
    id: 'headphones-pro',
    nameAr: 'سماعات لاسلكية برو هيدز',
    nameEn: 'Wireless Headphones Pro',
    descriptionAr: 'سماعات لاسلكية عالية الجودة مع خاصية إلغاء الضوضاء النشط وصوت محيطي نقي يناسب مختلف أجهزتك.',
    descriptionEn: 'Premium high-quality wireless headphones with active noise cancellation and pure environmental sound.',
    price: 150000,
    rating: 4.9,
    category: 'product',
    categoryLabelAr: 'منتجات',
    categoryLabelEn: 'Products',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0uhYTzIRhDjapKjLqhXFMdOysZRItQuTUAO5a0_PZO5We6F67_lheDgmWSVaHdbTXhgqDlOJ2RemxA5z1wW0JyTQ6DpGTzTd0-Q6M51Ck72e4Y0s-HZ-BFpJOeRZxygoOlFs8fRja4tjbQ_fVDLu2zfQAj10UZ38-PUOPetWSC428-E6R2DfVeazhIRVOaQEwWybz2Veo1AhEpj99auOmtEJ1Ier2-8saMrQ2_vo4IPWlRo0aXnXB4kQT_fx',
    isFavorite: true,
    avgPriceLabelAr: 'السعر',
    avgPriceLabelEn: 'Price',
    actionLabelAr: 'أضف للسلة',
    actionLabelEn: 'Add to Cart',
  },
  {
    id: 'al-aqiq-villa',
    nameAr: 'فيلا العقيق الفاخرة',
    nameEn: 'Luxury Al-Aqiq Villa',
    descriptionAr: 'فيلا فاخرة بتصميم عصري في حي العقيق، تتميز بمساحات واسعة، مسبح خاص، وحديقة منسقة بأحدث التصاميم المعمارية.',
    descriptionEn: 'A luxury villa with contemporary design in Al-Aqiq neighborhood, featuring spacious areas, a private pool, and landscaped gardens.',
    price: 850000000,
    category: 'real_estate',
    categoryLabelAr: 'عقارات',
    categoryLabelEn: 'Real Estate',
    image: 'https://lh3.googleusercontent.com/aida/ADBb0ugoMP6UlHsnnZs_mPt7HUgY2HKudrPHOuz7VxN9vH6dTJPB497sIuRdRio64-LfgwSS7MtWm9bO_-XbwTCp6LnVeW_cHxtYIyu8OtFClG6jqegvkpUvGk8HspVtsoD1WFD1skmCeI-BVKxrE62uQhIKprMzNphfpfEJfAdgSvvNtiREX3fCHmNWerTi1SAnE5Rtev3AcpvpFw5dCX4UibvnA6tTd_vfNs0N5IxbWTCxidLyRnpOElSKdI0',
    isFavorite: true,
    avgPriceLabelAr: 'السعر المطلوب',
    avgPriceLabelEn: 'Price Required',
    actionLabelAr: 'تواصل',
    actionLabelEn: 'Contact',
    bedrooms: 4,
    bathrooms: 3,
    areaSquareMeter: 450
  }
];

const INITIAL_CART: CartItem[] = [
  {
    id: 'quinoa-salad',
    nameAr: 'سلطة كينوا طازجة',
    nameEn: 'Fresh Quinoa Salad',
    price: 5000,
    count: 2,
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAmyvV4BPbBiPoqA2Yd-5Qt5bu_gNhLcZBcgbWQqwJqe1HylcLJwhsvRnhnipIzTtMeYd7rkwDbOp1oxklS30VTYyarIaIzqitOi1y5k4dKQSKqdMuJAg_V0IWnbea-vwtgfE8G0dept5M3rTiTltrslAgsy6lRi0id1ATW_VkZEWKB1RztS11gjkiLkQSOIc1DySqDj8mA1UZUkyMdkRdmO_B73gDdaoNjqfwoDnatUoRopcRTcOff9gmkWNbRufjNzr84Jvsi5gLO',
    optionAr: 'حجم وسط',
    optionEn: 'Medium Size'
  },
  {
    id: 'orange-juice',
    nameAr: 'عصير برتقال طازج',
    nameEn: 'Fresh Orange Juice',
    price: 4000,
    count: 1,
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAvfswPVgKuKicOjx6LTRj_EFctWE7_xzGGgG3aWPNzvdb6ok0GAEt6-R1Y_SO6ZEoD5ygQrkfIqNjXW02AbqchWTWY3wMre7jW7htIwFRhn_QxHH8JuX68TRzhhkDzY3tqryg-Buk6thX5Zibs6sduS4C8RbtBplivkpvr4SEqJVetcS5fRVzJu0mFE4QZ2OwV4ULIoCHUS2jXrMtC8p6q4jyNcxWdg8XxZy31w04Apw1MmPBT62gOQpdH-aUoiVBZ-JlprAAHNCTz',
    optionAr: 'بدون سكر',
    optionEn: 'No Sugar'
  },
  {
    id: 'v60-coffee',
    nameAr: 'قهوة V60 إثيوبية',
    nameEn: 'Ethiopian V60 Coffee',
    price: 7000,
    count: 1,
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAJbCVu2n1svZG-dVu29OoR_vjNFyGc8NdZs1eUz75pTiumFUl3vDUyqRlcQ_ffhtxDY73WNfVdVSzbiWiv5uAr7cV0inlvyKjeNAC2pIdwG8P1tdQN_gtWsqAuYOECJMwjqevp-2dnPSmm8sG8fzsJoCtQCZa7pdAFQnJxYY2C-suGcJoPk5C_SUBKV-A2gM9ywY_dpTWYSBKrcyc88enUOmgBLVBHOAaMfieggje24JeUolmdpEj7fl2FKgOdsHs8Iomf0PyuVhVw',
    optionAr: 'حار',
    optionEn: 'Hot'
  }
];

const INITIAL_ORDERS: ActiveOrder[] = [
  {
    id: 'o-1',
    orderNumber: 'ORD-8472',
    dateAr: 'اليوم، 10:30 صباحاً',
    dateEn: 'Today, 10:30 AM',
    statusKey: 'delivering',
    statusAr: 'قيد التوصيل',
    statusEn: 'Out for Delivery',
    price: 25000,
    itemsCount: 3,
    itemsNameAr: 'خضار مشكلة، فواكه، وأشياء أخرى...',
    itemsNameEn: 'Assorted vegetables, fruits & others...',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCzq3HijoUx8HZrHBDLde7fcC4wVtXaYFCp7mVRiw_kVGShFAtFY89jbf-onNbSPZL5E-ikB6fuWImpOyVCYNez90EhfaPIX1TsMFriTHTrdGBwjjMogF64aX1EHDsFoDX9OVlZBI8BvXLgWdn2PQq0Gv6IAo1xHTfNbkDKsn6WYw8Fm7cJQlacFW7F0bvP3oscHTJbMQSvMun369PY6DzGPia_26t_S5GhDqqCCSAmYpohtJ_fIHJJ1QoWoVjaFx3DB5myKEJA0oBB'
  },
  {
    id: 'o-2',
    orderNumber: 'ORD-8473',
    dateAr: 'اليوم، 09:15 صباحاً',
    dateEn: 'Today, 09:15 AM',
    statusKey: 'cooking',
    statusAr: 'قيد التحضير',
    statusEn: 'Preparing',
    price: 12500,
    itemsCount: 5,
    itemsNameAr: 'مواد تنظيف ولوازم منزلية',
    itemsNameEn: 'Cleaning agents & home essentials',
    iconName: 'inventory_2'
  }
];

const INITIAL_NOTIFICATIONS: AppNotification[] = [
  {
    id: 'n-1',
    titleAr: 'طلبك في الطريق!',
    titleEn: 'Your order is on the way!',
    bodyAr: 'المندوب في طريقه لتسليم طلبك رقم #10293. يرجى التواجد في الموقع لاستلام الطلب والدفع كاش.',
    bodyEn: 'Our delivery agent is on the way to deliver your order #10293. Please be at your location for COD.',
    timeAr: 'الآن',
    timeEn: 'Now',
    iconName: 'local_shipping',
    read: false,
    type: 'order'
  },
  {
    id: 'n-2',
    titleAr: 'عرض خاص لك 🎁',
    titleEn: 'Special offer for you 🎁',
    bodyAr: 'استخدم الكود GHAITH20 واحصل على خصم 20% على طلبك القادم. العرض صالح لمدة 24 ساعة فقط!',
    bodyEn: 'Use coupon code GHAITH20 and get 20% off your next order. Valid for 24 hours only!',
    timeAr: 'قبل ساعتين',
    timeEn: '2 hours ago',
    iconName: 'sell',
    read: false,
    type: 'promo'
  },
  {
    id: 'n-3',
    titleAr: 'تم تسليم الطلب بنجاح',
    titleEn: 'Order delivered successfully',
    bodyAr: 'شكراً لتسوقك مع الغيث! نأمل أن تنال المنتجات إعجابك الدائم. يمكنك تقييم تجربتك الآن.',
    bodyEn: 'Thank you for shopping with Al-Ghaith! We hope you love your products. You can rate us now.',
    timeAr: 'الأمس',
    timeEn: 'Yesterday',
    iconName: 'check_circle',
    read: true,
    type: 'delivered'
  },
  {
    id: 'n-4',
    titleAr: 'تحديث النظام المعياري',
    titleEn: 'System Update Alert',
    bodyAr: 'سنقوم بإجراء صيانة دورية للتطبيق غداً من الساعة 2 صباحاً حتى 4 صباحاً بتوقيت بغداد لتحسين تجربتكم بشكل ممتاز.',
    bodyEn: 'We will conduct standard system maintenance tomorrow between 2:00 AM and 4:00 AM Baghdad time.',
    timeAr: '٢٤ أكتوبر',
    timeEn: 'Oct 24',
    iconName: 'build',
    read: true,
    type: 'maintenance'
  }
];

export default function App() {
  // Lang state initialization from localStorage or defaults to null for the first launch screen
  const [lang, setLang] = useState<'ar' | 'en' | null>(() => {
    const saved = localStorage.getItem('alghaith_lang');
    return (saved === 'ar' || saved === 'en') ? saved : null;
  });

  const [userRole, setUserRole] = useState<'merchant' | 'customer' | null>(() => {
    const saved = localStorage.getItem('alghaith_user_role');
    return (saved === 'merchant' || saved === 'customer') ? saved : null;
  });

  // Items State (supports favoriting toggles)
  const [items, setItems] = useState<ListItem[]>(() => {
    const saved = localStorage.getItem('alghaith_items');
    return saved ? JSON.parse(saved) : INITIAL_ITEMS;
  });

  // Cart State
  const [cart, setCart] = useState<CartItem[]>(() => {
    const saved = localStorage.getItem('alghaith_cart');
    return saved ? JSON.parse(saved) : INITIAL_CART;
  });

  // Orders State
  const [orders, setOrders] = useState<ActiveOrder[]>(() => {
    const saved = localStorage.getItem('alghaith_orders');
    return saved ? JSON.parse(saved) : INITIAL_ORDERS;
  });

  // Notifications State
  const [notifications, setNotifications] = useState<AppNotification[]>(() => {
    const saved = localStorage.getItem('alghaith_notifications');
    return saved ? JSON.parse(saved) : INITIAL_NOTIFICATIONS;
  });

  // UI States
  const [currentTab, setCurrentTab] = useState<'home' | 'fav' | 'cart' | 'orders' | 'account' | 'notifications' | 'contact'>('home');
  const [merchantTab, setMerchantTab] = useState<'stats' | 'products' | 'orders' | 'account'>('stats');
  const [merchantProducts, setMerchantProducts] = useState<ListItem[]>(() => {
    const saved = localStorage.getItem('alghaith_merchant_products');
    return saved ? JSON.parse(saved) : INITIAL_ITEMS.filter(i => i.category === 'product');
  });
  const [homeFilter, setHomeFilter] = useState<string>('all');
  const [activeSubCategory, setActiveSubCategory] = useState<string | null>(null);
  const [favFilter, setFavFilter] = useState<'all' | 'restaurant' | 'product' | 'real_estate'>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [promoCodeInput, setPromoCodeInput] = useState<string>('');
  const [isPromoApplied, setIsPromoApplied] = useState<boolean>(() => {
    return localStorage.getItem('alghaith_promo_applied') === 'true';
  });
  const [activeSegmentedOrderTab, setActiveSegmentedOrderTab] = useState<'active' | 'previous'>('active');

  // Interactive UI Feedbacks
  const [toast, setToast] = useState<string | null>(null);
  const [trackOrderActive, setTrackOrderActive] = useState<ActiveOrder | null>(null);
  const [bookTableItem, setBookTableItem] = useState<ListItem | null>(null);
  const [bookTableDate, setBookTableDate] = useState<string>('2026-05-28');
  const [bookTableTime, setBookTableTime] = useState<string>('20:00');
  const [bookTableGuests, setBookTableGuests] = useState<number>(2);
  const [checkoutSuccess, setCheckoutSuccess] = useState<boolean>(false);
  const [contactItem, setContactItem] = useState<ListItem | null>(null);
  const [isAddingProduct, setIsAddingProduct] = useState(false);
  const [editingProduct, setEditingProduct] = useState<ListItem | null>(null);
  const [newProductData, setNewProductData] = useState<Partial<ListItem>>({
    nameAr: '',
    nameEn: '',
    price: 0,
    descriptionAr: '',
    descriptionEn: '',
    image: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=400',
    category: 'product',
    categoryLabelAr: 'منتجات',
    categoryLabelEn: 'Products'
  });

  const handleSaveProduct = () => {
    if (!newProductData.nameAr || !newProductData.price) {
      showToastMsg(lang === 'ar' ? 'يرجى ملء البيانات الأساسية' : 'Please fill required data');
      return;
    }

    if (editingProduct) {
      setMerchantProducts(prev => prev.map(p => p.id === editingProduct.id ? { ...editingProduct, ...newProductData } as ListItem : p));
      showToastMsg(lang === 'ar' ? 'تم تحديث المنتج بنجاح' : 'Product updated successfully');
    } else {
      const product: ListItem = {
        ...newProductData,
        id: `p-${Date.now()}`,
        isFavorite: false,
        actionLabelAr: 'أضف للسلة',
        actionLabelEn: 'Add to Cart',
        avgPriceLabelAr: 'السعر',
        avgPriceLabelEn: 'Price'
      } as ListItem;
      setMerchantProducts(prev => [product, ...prev]);
      showToastMsg(lang === 'ar' ? 'تم إضافة المنتج بنجاح' : 'Product added successfully');
    }
    setIsAddingProduct(false);
    setEditingProduct(null);
    setNewProductData({ nameAr: '', nameEn: '', price: 0, descriptionAr: '', descriptionEn: '', image: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=400', category: 'product' });
  };

  const deleteProduct = (id: string) => {
    setMerchantProducts(prev => prev.filter(p => p.id !== id));
    showToastMsg(lang === 'ar' ? 'تم حذف المنتج' : 'Product deleted');
  };

  // Sync to localStorage
  useEffect(() => {
    if (lang) {
      localStorage.setItem('alghaith_lang', lang);
    } else {
      localStorage.removeItem('alghaith_lang');
    }
  }, [lang]);

  useEffect(() => {
    if (userRole) {
      localStorage.setItem('alghaith_user_role', userRole);
    } else {
      localStorage.removeItem('alghaith_user_role');
    }
  }, [userRole]);

  useEffect(() => {
    localStorage.setItem('alghaith_items', JSON.stringify(items));
  }, [items]);

  useEffect(() => {
    localStorage.setItem('alghaith_cart', JSON.stringify(cart));
  }, [cart]);

  useEffect(() => {
    localStorage.setItem('alghaith_orders', JSON.stringify(orders));
  }, [orders]);

  useEffect(() => {
    localStorage.setItem('alghaith_notifications', JSON.stringify(notifications));
  }, [notifications]);

  useEffect(() => {
    localStorage.setItem('alghaith_merchant_products', JSON.stringify(merchantProducts));
  }, [merchantProducts]);

  useEffect(() => {
    localStorage.setItem('alghaith_promo_applied', isPromoApplied ? 'true' : 'false');
  }, [isPromoApplied]);

  const showToastMsg = (msg: string) => {
    setToast(msg);
    setTimeout(() => {
      setToast(null);
    }, 2500);
  };

  const changeLanguage = (newLang: 'ar' | 'en') => {
    setLang(newLang);
    showToastMsg(newLang === 'ar' ? 'تم تغيير لغة التطبيق إلى العربية' : 'App language changed to English');
  };

  // Toggle favorite
  const toggleFavItem = (id: string) => {
    setItems(prev => prev.map(item => {
      if (item.id === id) {
        const nextState = !item.isFavorite;
        showToastMsg(
          lang === 'ar'
            ? nextState ? 'تمت الإضافة للمفضلة ❤️' : 'تمت الإزالة من المفضلة'
            : nextState ? 'Added to favorites ❤️' : 'Removed from favorites'
        );
        return { ...item, isFavorite: nextState };
      }
      return item;
    }));
  };

  // Add Item to class-based Cart dynamically
  const addItemToCart = (item: ListItem | CartItem | { id: string; nameAr: string; nameEn: string; price: number; image: string; optionAr?: string; optionEn?: string }) => {
    setCart(prev => {
      const existing = prev.find(i => i.id === item.id);
      if (existing) {
        return prev.map(i => i.id === item.id ? { ...i, count: i.count + 1 } : i);
      } else {
        return [...prev, {
          id: item.id,
          nameAr: item.nameAr,
          nameEn: item.nameEn,
          price: item.price,
          count: 1,
          image: item.image,
          optionAr: 'optionAr' in item ? item.optionAr : undefined,
          optionEn: 'optionEn' in item ? item.optionEn : undefined,
        }];
      }
    });
    showToastMsg(
      lang === 'ar' 
        ? `تمت إضافة "${item.nameAr}" للسلة🛒` 
        : `Added "${item.nameEn}" to Cart🛒`
    );
  };

  const updateCartQty = (id: string, delta: number) => {
    setCart(prev => prev.map(item => {
      if (item.id === id) {
        const nextCount = item.count + delta;
        return nextCount > 0 ? { ...item, count: nextCount } : null;
      }
      return item;
    }).filter((i): i is CartItem => i !== null));
  };

  // Apply discount GHAITH20 promo code
  const handleApplyPromo = () => {
    if (promoCodeInput.trim().toUpperCase() === 'GHAITH20') {
      setIsPromoApplied(true);
      showToastMsg(lang === 'ar' ? '🎉 تم تطبيق كود الخصم 20%!' : '🎉 Coupon GHAITH20 applied (20% Off)!');
      setPromoCodeInput('');
    } else {
      showToastMsg(lang === 'ar' ? '⚠️ كود غير صحيح. جرب GHAITH20' : '⚠️ Invalid code. Try GHAITH20');
    }
  };

  // Dynamic order execution with cash on delivery only
  const handleCheckout = () => {
    if (cart.length === 0) {
      showToastMsg(lang === 'ar' ? 'السلة فارغة حالياً!' : 'Cart is empty!');
      return;
    }

    const { finalTotal } = getInvoiceDetails();
    const newOrderNum = `ORD-${Math.floor(Math.random() * 9000 + 1000)}`;

    const itemsSummaryAr = cart.map(i => i.nameAr).join('، ').substring(0, 40) + '...';
    const itemsSummaryEn = cart.map(i => i.nameEn).join(', ').substring(0, 40) + '...';

    const newOrder: ActiveOrder = {
      id: `o-new-${Date.now()}`,
      orderNumber: newOrderNum,
      dateAr: 'الآن، الدفع نقداً عند الاستلام',
      dateEn: "Now, Cash on Delivery",
      statusKey: 'processing',
      statusAr: 'جاري تسلم الطلب نقداً عند التوصيل',
      statusEn: 'Processing Handback (COD)',
      price: finalTotal,
      itemsCount: cart.reduce((acc, i) => acc + i.count, 0),
      itemsNameAr: itemsSummaryAr,
      itemsNameEn: itemsSummaryEn,
      image: cart[0].image
    };

    // Add to active orders
    setOrders(prev => [newOrder, ...prev]);

    // Send a live app Notification matching the unread states
    const newNotice: AppNotification = {
      id: `n-new-${Date.now()}`,
      titleAr: `تم قبول طلبك الجديد ${newOrderNum}`,
      titleEn: `Order ${newOrderNum} Confirmed`,
      bodyAr: `شكراً جزيلاً لطلبك! سيتم شحن الطلب إليك فوراً والدفع نقداً عند الاستلام بقيمة ${finalTotal.toLocaleString()} د.ع.`,
      bodyEn: `Your order has been confirmed successfully! Total of IQD ${finalTotal.toLocaleString()} is payable via Cash on Delivery.`,
      timeAr: 'الآن',
      timeEn: 'Now',
      iconName: 'receipt_long',
      read: false,
      type: 'order'
    };
    setNotifications(prev => [newNotice, ...prev]);

    // Flush Cart and Promo code states
    setCart([]);
    setIsPromoApplied(false);
    
    // Switch to success modal
    setCheckoutSuccess(true);
  };

  // Booking a restaurant table
  const handleConfirmTableBooking = () => {
    if (!bookTableItem) return;

    showToastMsg(
      lang === 'ar'
        ? `تم حجز طاولتك بنجاح في ${bookTableItem.nameAr}! 🎉`
        : `Table booked successfully at ${bookTableItem.nameEn}! 🎉`
    );

    // Add to notifications
    const newNotice: AppNotification = {
      id: `n-book-${Date.now()}`,
      titleAr: `تأكيد حجز طاولة في ${bookTableItem.nameAr}`,
      titleEn: `Table Confirmed at ${bookTableItem.nameEn}`,
      bodyAr: `تم حجز طاولتك لعدد ${bookTableGuests} أشخاص بتاريخ ${bookTableDate} الساعة ${bookTableTime}. الحجز مجاني بالكامل والدفع للوجبات عند الحضور نقداً.`,
      bodyEn: `Your table for ${bookTableGuests} guests is booked on ${bookTableDate} at ${bookTableTime}. Free booking, pay for dining directly at the restaurant.`,
      timeAr: 'الآن',
      timeEn: 'Now',
      iconName: 'event',
      read: false,
      type: 'order'
    };
    setNotifications(prev => [newNotice, ...prev]);
    setBookTableItem(null);
  };

  // Invoice calculations
  const getInvoiceDetails = () => {
    const subtotal = cart.reduce((acc, item) => acc + (item.price * item.count), 0);
    const discount = isPromoApplied ? subtotal * 0.20 : 0;
    const delivery = subtotal > 0 ? 3000 : 0; // standard delivery fee IQD
    const tax = subtotal > 0 ? 1000 : 0; // token government system tax IQD
    const finalTotal = subtotal - discount + delivery + tax;

    return { subtotal, discount, delivery, tax, finalTotal };
  };

  const clearAllNotifications = () => {
    setNotifications([]);
    showToastMsg(lang === 'ar' ? 'تم تفريغ صندوق الإشعارات' : 'Notification box cleared');
  };

  const markNotificationsAsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const resetAllData = () => {
    setLang(null);
    setUserRole(null);
    setCart(INITIAL_CART);
    setItems(INITIAL_ITEMS);
    setOrders(INITIAL_ORDERS);
    setNotifications(INITIAL_NOTIFICATIONS);
    setIsPromoApplied(false);
    setCurrentTab('home');
    localStorage.clear();
    showToastMsg('Reset successful');
  };

  // Dynamic filter lists for favorites
  const filteredFavItems = items.filter(i => {
    if (!i.isFavorite) return false;
    if (favFilter === 'all') return true;
    return i.category === favFilter;
  });

  // Dynamic search filtering for the Home category grid and search bar
  const displayedHomeItems = items.filter(i => {
    const matchesFilter = homeFilter === 'all' || i.category === homeFilter;
    const query = searchQuery.toLowerCase().trim();
    if (!query) return matchesFilter;

    const matchesSearch = 
      i.nameAr.toLowerCase().includes(query) || 
      i.nameEn.toLowerCase().includes(query) ||
      i.descriptionAr.toLowerCase().includes(query) ||
      i.descriptionEn.toLowerCase().includes(query);

    return matchesFilter && matchesSearch;
  });

  const t = translations[lang || 'ar'];
  const isRTL = lang !== 'en'; // default Arabic is RTL

  const unreadNotificationsCount = notifications.filter(n => !n.read).length;

  return (
    <div className={`min-h-screen bg-slate-100 flex flex-col justify-start items-center p-0 md:p-6 font-sans antialiased selection:bg-orange-600 selection:text-white ${isRTL ? 'rtl' : 'ltr'}`} dir={isRTL ? 'rtl' : 'ltr'}>
      {/* Toast feedback widget */}
      <AnimatePresence>
        {toast && (
          <motion.div
            initial={{ opacity: 0, y: -50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -50 }}
            className="fixed top-5 z-55 bg-neutral-900/90 text-white backdrop-blur-md px-5 py-3 rounded-full flex items-center gap-2 shadow-2xl border border-neutral-700 font-medium text-sm max-w-sm text-center"
          >
            <span className="material-symbols-outlined text-orange-500 fill-orange-500">notifications_active</span>
            <span>{toast}</span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Container - Beautiful iOS Device Simulation Panel for Desktop & Clean Native View for Mobile */}
      <div className="w-full max-w-md bg-white min-h-screen md:min-h-[850px] md:max-h-[920px] md:rounded-[48px] md:shadow-2xl overflow-hidden flex flex-col relative md:border-[12px] md:border-slate-900 transition-all duration-300">
        
        {/* Welcome / Language Chooser Screen (if lang is null, we present immediate selection) */}
        <AnimatePresence>
          {(!lang || !userRole) && (
            <motion.div
              initial={{ opacity: 1 }}
              exit={{ opacity: 0, y: -200 }}
              className="absolute inset-0 z-50 bg-gradient-to-b from-neutral-900 via-neutral-900 to-black text-white flex flex-col justify-between p-8 pt-safe pb-safe overflow-y-auto"
            >
              {/* Graphics Banner Overlay */}
              <div className="flex flex-col items-center justify-center pt-8 text-center shrink-0">
                <div className="w-20 h-20 rounded-3xl bg-gradient-to-tr from-orange-600 to-amber-500 flex items-center justify-center p-1 text-white shadow-xl mb-6">
                  <span className="material-symbols-outlined text-4xl font-bold">water_drop</span>
                </div>
                <h1 className="text-3xl font-extrabold tracking-tight text-white mb-2 font-cairo">Al-Ghaith</h1>
                <h2 className="text-lg font-bold bg-gradient-to-r from-orange-400 to-amber-300 bg-clip-text text-transparent mb-4 font-cairo">بوابتك للخدمات المتكاملة في العراق</h2>
              </div>

              {!lang ? (
                /* STEP 1: Language Selection Section */
                <div className="flex flex-col gap-5 pb-12">
                  <p className="text-center text-xs uppercase tracking-widest text-neutral-500 font-semibold font-cairo">
                    اختر لغة التطبيق لتبدأ / Select Application Language
                  </p>

                  <div className="grid grid-cols-2 gap-4">
                    <button
                      onClick={() => changeLanguage('ar')}
                      className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-neutral-800/80 border border-neutral-700/60 hover:bg-neutral-800 hover:border-orange-500 transition-all text-center group active:scale-95 h-32"
                    >
                      <span className="text-orange-500 text-lg font-bold font-cairo">العربية</span>
                      <span className="text-[10px] text-neutral-400 group-hover:text-white transition-colors">اللغة الرئيسية (عراقي)</span>
                    </button>

                    <button
                      onClick={() => changeLanguage('en')}
                      className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-neutral-800/80 border border-neutral-700/60 hover:bg-neutral-800 hover:border-orange-500 transition-all text-center group active:scale-95 h-32"
                    >
                      <span className="text-amber-500 text-lg font-bold font-sans">English</span>
                      <span className="text-[10px] text-neutral-400 group-hover:text-white transition-colors">Alternative Language</span>
                    </button>
                  </div>

                  <div className="mt-4 p-4 rounded-xl bg-orange-950/20 border border-orange-900/40 flex items-start gap-3">
                    <span className="material-symbols-outlined text-orange-500 shrink-0">info</span>
                    <div className="text-xs text-orange-200 leading-relaxed font-cairo">
                      هذا التطبيق مخصص للدفع عند الاستلام فقط ومحمي بالكامل لضمان جودة وتيسير الخدمة داخل العراق.
                    </div>
                  </div>
                </div>
              ) : (
                /* STEP 2: Account Type Selection */
                <motion.div
                  initial={{ opacity: 0, x: 50 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="flex flex-col gap-5 pb-12 flex-1 justify-center"
                >
                  <p className="text-center text-xs uppercase tracking-widest text-neutral-500 font-semibold font-cairo mb-2">
                    {lang === 'ar' ? 'اختر نوع الحساب للمتابعة' : 'Select Account Type to Continue'}
                  </p>

                  {/* Customer Option */}
                  <button
                    onClick={() => {
                      setUserRole('customer');
                      showToastMsg(lang === 'ar' ? 'أهلاً بك كزبون في الغيث' : 'Welcome as a Customer');
                    }}
                    className="flex items-center gap-5 p-6 rounded-3xl bg-neutral-800/80 border border-neutral-700/60 hover:border-orange-500 transition-all group active:scale-[0.98] text-right"
                  >
                    <div className="w-14 h-14 rounded-2xl bg-orange-500/10 flex items-center justify-center text-orange-50 text-orange-500 group-hover:bg-orange-500 group-hover:text-white transition-colors shrink-0">
                      <span className="material-symbols-outlined text-3xl">person</span>
                    </div>
                    <div className="flex-1">
                      <h3 className="text-lg font-black text-white font-cairo">{lang === 'ar' ? 'حساب زبون' : 'Customer Account'}</h3>
                      <p className="text-xs text-neutral-400 mt-1 font-cairo">{lang === 'ar' ? 'للتسوق، طلب الطعام، وتصفح العقارات والسيارات' : 'Shop, order food, and browse real estate & cars'}</p>
                    </div>
                    <span className="material-symbols-outlined text-neutral-600 group-hover:text-orange-500">
                      {lang === 'ar' ? 'chevron_left' : 'chevron_right'}
                    </span>
                  </button>

                  {/* Merchant Option */}
                  <button
                    onClick={() => {
                      setUserRole('merchant');
                      showToastMsg(lang === 'ar' ? 'مرحباً بك كشريك تاجر' : 'Welcome as a Merchant Partner');
                    }}
                    className="flex items-center gap-5 p-6 rounded-3xl bg-neutral-800/80 border border-neutral-700/60 hover:border-amber-500 transition-all group active:scale-[0.98] text-right"
                  >
                    <div className="w-14 h-14 rounded-2xl bg-amber-500/10 flex items-center justify-center text-amber-500 group-hover:bg-amber-500 group-hover:text-white transition-colors shrink-0">
                      <span className="material-symbols-outlined text-3xl">storefront</span>
                    </div>
                    <div className="flex-1">
                      <h3 className="text-lg font-black text-white font-cairo">{lang === 'ar' ? 'حساب تاجر' : 'Merchant Account'}</h3>
                      <p className="text-xs text-neutral-400 mt-1 font-cairo">{lang === 'ar' ? 'لإضافة منتجاتك، إدارة طلباتك وعرض خدماتك' : 'List products, manage orders, and show services'}</p>
                    </div>
                    <span className="material-symbols-outlined text-neutral-600 group-hover:text-amber-500">
                      {lang === 'ar' ? 'chevron_left' : 'chevron_right'}
                    </span>
                  </button>

                  <div className="mt-4 flex justify-center">
                    <button
                      onClick={() => setLang(null)}
                      className="text-xs text-neutral-500 hover:text-white underline font-cairo"
                    >
                      {lang === 'ar' ? 'الرجوع لاختيار اللغة' : 'Back to Language Selection'}
                    </button>
                  </div>
                </motion.div>
              )}
            </motion.div>
          )}
        </AnimatePresence>

        {/* Dynamic App Layout if Language is Chosen */}
        <div className="flex-1 flex flex-col overflow-hidden bg-neutral-50 text-neutral-900 font-sans">
          
          {/* TopAppBar: Simulated iOS Header with Dynamic Status */}
          <header className="bg-white/90 border-b border-neutral-100 backdrop-blur-md sticky top-0 z-40 px-5 py-4 pt-3 flex justify-between items-center shrink-0">
            <div className="flex items-center gap-2.5">
              {/* Al-Ghaith Custom Brand Logo Icon (Replacing Menu Button) */}
              <div 
                onClick={() => {
                  setCurrentTab('account');
                  showToastMsg(lang === 'ar' ? 'أهلاً بك في حسابك الشخصي' : 'Welcome to your account settings');
                }}
                className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-600 to-amber-500 text-white flex items-center justify-center shadow-lg hover:scale-105 active:scale-95 transition-all cursor-pointer shrink-0"
                title={lang === 'ar' ? 'حسابي / الغيث' : 'My Account / Al-Ghaith'}
              >
                <span className="material-symbols-outlined text-xl font-bold" style={{ fontVariationSettings: "'FILL' 1" }}>water_drop</span>
              </div>
              <h1 className="text-2xl font-black text-orange-600 font-cairo tracking-tight select-none">
                {t.app_title}
              </h1>
            </div>

            {/* In-App Currency Badge (Iraq Specific) & Notification Icons */}
            <div className="flex items-center gap-2">
              <div className="hidden sm:flex items-center gap-1 bg-amber-50 border border-amber-200 py-1 px-3 rounded-full text-xs text-amber-800 font-semibold">
                <span className="material-symbols-outlined text-xs text-amber-600">payments</span>
                <span>{lang === 'ar' ? 'كاش عند التوصيل' : 'COD Active'}</span>
              </div>
              
              <button
                onClick={() => {
                  setCurrentTab('notifications');
                  markNotificationsAsRead();
                }}
                className="w-10 h-10 rounded-full bg-neutral-100 text-neutral-600 flex items-center justify-center relative transition-colors hover:bg-neutral-200 active:scale-90"
              >
                <span className="material-symbols-outlined text-xl">notifications</span>
                {unreadNotificationsCount > 0 && (
                  <span className="absolute top-2 right-2 w-4 h-4 rounded-full bg-orange-600 text-[10px] font-bold text-white flex items-center justify-center animate-bounce">
                    {unreadNotificationsCount}
                  </span>
                )}
              </button>
            </div>
          </header>

          {/* Core Content Area */}
          <main className="flex-1 overflow-y-auto no-scrollbar pb-24">
            
            <AnimatePresence mode="wait">
              <motion.div
                key={currentTab + homeFilter + favFilter}
                initial={{ opacity: 0, x: isRTL ? 40 : -40 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: isRTL ? -40 : 40 }}
                transition={{ duration: 0.15 }}
                className="p-4"
              >
                
                {/* SCREEN 1: HOME TAB */}
                {currentTab === 'home' && (
                  <div className="space-y-6">
                    {/* Search Component */}
                    <div className="relative">
                      <span className="material-symbols-outlined text-neutral-400 absolute top-3.5 right-4 left-auto">search</span>
                      <input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        placeholder={t.search_placeholder}
                        className={`w-full py-3.5 ${isRTL ? 'pr-11 pl-4' : 'pl-11 pr-4'} bg-white border border-neutral-200 rounded-2xl text-sm text-neutral-800 placeholder-neutral-400 focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500 shadow-sm transition-all`}
                      />
                      {searchQuery && (
                        <button
                          onClick={() => setSearchQuery('')}
                          className={`absolute top-4 ${isRTL ? 'left-4' : 'right-4'} text-neutral-400 hover:text-neutral-600`}
                        >
                          <span className="material-symbols-outlined text-sm">close</span>
                        </button>
                      )}
                    </div>

                    {/* Banner Section */}
                    {searchQuery === '' && (
                      <div className="relative w-full rounded-2xl overflow-hidden shadow-md aspect-[1.8/1] bg-neutral-200">
                        <img
                          alt="Banner Al-Ghaith"
                          className="w-full h-full object-cover"
                          src="https://lh3.googleusercontent.com/aida/ADBb0ugcFEttwTc7Dx86WjAlTPK5Oq2jiB24S-EqOLz3yPHnq9ihXJkdVsj8I2jJN1H27j0cgDgcN0F1Pu0Gv6JMwSPPQBglMppgGpWZjfbIGBRGWLdyyXOtckjXh--7zi3Enq1AFwEoXSgDp5qxDwFJhUt26_2wyLT-OUZJYNmFqPStC-nte0Hxe1EhED0k7kLz-Mw7Wq7cDBdoWkNIyMVkfhdGqYcPOlJHiAF0e-r4PwSxd_JBfmNgz2gk55tE"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/25 to-transparent flex flex-col justify-end p-5">
                          <p className="font-bold text-lg text-white font-cairo mb-1">
                            {lang === 'ar' ? 'اكتشف عالم الغيث العراقي المتكامل' : 'Discover the Al-Ghaith Ecosystem'}
                          </p>
                          <p className="text-xs text-neutral-200 line-clamp-1 font-cairo">
                            {lang === 'ar' ? 'كل متطلباتك اليومية من مطاعم، تسوق، سيارات وعقارات مع كاش عند الاستلام' : 'All your daily needs in restaurants, retail or properties under COD model'}
                          </p>
                        </div>
                      </div>
                    )}

                    {/* Services Sub-Grid */}
                    <div>
                      <h2 className="text-lg font-black text-neutral-800 mb-3 font-cairo flex items-center justify-between">
                        <span>
                          {homeFilter === 'product' && !activeSubCategory
                            ? (lang === 'ar' ? 'أقسام التسوق' : 'Shopping Departments')
                            : homeFilter === 'cars' && !activeSubCategory
                            ? (lang === 'ar' ? 'خدمات السيارات' : 'Car Services')
                            : homeFilter === 'tourism' && !activeSubCategory
                            ? (lang === 'ar' ? 'السياحة والسفر' : 'Tourism & Travel')
                            : homeFilter === 'real_estate' && !activeSubCategory
                            ? (lang === 'ar' ? 'أقسام العقارات' : 'Real Estate Categories')
                            : homeFilter === 'beauty' && !activeSubCategory
                            ? (lang === 'ar' ? 'الصحة والجمال' : 'Health & Beauty')
                            : t.services}
                        </span>
                        {homeFilter !== 'all' && (
                          <button 
                            onClick={() => {
                              if (activeSubCategory) {
                                setActiveSubCategory(null);
                              } else {
                                setHomeFilter('all');
                              }
                            }}
                            className="text-xs text-orange-600 hover:text-orange-500 font-semibold flex items-center gap-1"
                          >
                            <span className="material-symbols-outlined text-xs">arrow_back</span>
                            {lang === 'ar' ? 'رجوع' : 'Back'}
                          </button>
                        )}
                      </h2>
                      
                      <div className="grid grid-cols-2 gap-3 pb-4">
                        {homeFilter === 'product' && !activeSubCategory ? (
                          SHOPPING_SUB_CATEGORIES.map((cat) => (
                            <button
                              key={cat.id}
                              onClick={() => {
                                setActiveSubCategory(cat.id);
                                showToastMsg(lang === 'ar' ? `قسم: ${cat.titleAr}` : `Dept: ${cat.titleEn}`);
                              }}
                              className="relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 border-transparent"
                            >
                              <img
                                alt={cat.titleAr}
                                className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                src={cat.image}
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                              <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                {lang === 'ar' ? cat.titleAr : cat.titleEn}
                              </span>
                            </button>
                          ))
                        ) : homeFilter === 'cars' && !activeSubCategory ? (
                          CARS_SUB_CATEGORIES.map((cat) => (
                            <button
                              key={cat.id}
                              onClick={() => {
                                setActiveSubCategory(cat.id);
                                showToastMsg(lang === 'ar' ? `قسم: ${cat.titleAr}` : `Dept: ${cat.titleEn}`);
                              }}
                              className="relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 border-transparent"
                            >
                              <img
                                alt={cat.titleAr}
                                className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                src={cat.image}
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                              <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                {lang === 'ar' ? cat.titleAr : cat.titleEn}
                              </span>
                            </button>
                          ))
                        ) : homeFilter === 'tourism' && !activeSubCategory ? (
                          TOURISM_SUB_CATEGORIES.map((cat) => (
                            <button
                              key={cat.id}
                              onClick={() => {
                                setActiveSubCategory(cat.id);
                                showToastMsg(lang === 'ar' ? `قسم: ${cat.titleAr}` : `Dept: ${cat.titleEn}`);
                              }}
                              className="relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 border-transparent"
                            >
                              <img
                                alt={cat.titleAr}
                                className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                src={cat.image}
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                              <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                {lang === 'ar' ? cat.titleAr : cat.titleEn}
                              </span>
                            </button>
                          ))
                        ) : homeFilter === 'real_estate' && !activeSubCategory ? (
                          REAL_ESTATE_SUB_CATEGORIES.map((cat) => (
                            <button
                              key={cat.id}
                              onClick={() => {
                                setActiveSubCategory(cat.id);
                                showToastMsg(lang === 'ar' ? `قسم: ${cat.titleAr}` : `Dept: ${cat.titleEn}`);
                              }}
                              className="relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 border-transparent"
                            >
                              <img
                                alt={cat.titleAr}
                                className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                src={cat.image}
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                              <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                {lang === 'ar' ? cat.titleAr : cat.titleEn}
                              </span>
                            </button>
                          ))
                        ) : homeFilter === 'beauty' && !activeSubCategory ? (
                          HEALTH_BEAUTY_SUB_CATEGORIES.map((cat) => (
                            <button
                              key={cat.id}
                              onClick={() => {
                                setActiveSubCategory(cat.id);
                                showToastMsg(lang === 'ar' ? `قسم: ${cat.titleAr}` : `Dept: ${cat.titleEn}`);
                              }}
                              className="relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 border-transparent"
                            >
                              <img
                                alt={cat.titleAr}
                                className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                src={cat.image}
                              />
                              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                              <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                {lang === 'ar' ? cat.titleAr : cat.titleEn}
                              </span>
                            </button>
                          ))
                        ) : (
                          ALL_SERVICE_CATEGORIES.map((cat) => {
                            const isCatActive = homeFilter === cat.id;
                            return (
                              <button
                                key={cat.id}
                                onClick={() => {
                                  setHomeFilter(cat.id);
                                  setActiveSubCategory(null);
                                  showToastMsg(lang === 'ar' ? `فلترة حسب: ${cat.titleAr}` : `Filter by: ${cat.titleEn}`);
                                }}
                                className={`relative rounded-2xl overflow-hidden aspect-square shadow-sm flex flex-col justify-end group active:scale-95 transition-all lg:hover:shadow-md border-2 ${isCatActive ? 'border-orange-500 scale-95 shadow-orange-100' : 'border-transparent'}`}
                              >
                                <img
                                  alt={cat.titleAr}
                                  className="absolute inset-0 w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                                  src={cat.image}
                                />
                                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>
                                <span className="relative z-10 p-3 text-sm font-black text-white font-cairo text-right leading-tight">
                                  {lang === 'ar' ? cat.titleAr : cat.titleEn}
                                </span>
                              </button>
                            );
                          })
                        )}
                      </div>
                    </div>

                    {/* Filtered Active Items Lists as dynamic suggestions for search queries */}
                    <div className="border-t border-neutral-200/60 pt-4">
                      <h3 className="text-sm font-bold text-neutral-500 uppercase tracking-widest mb-3 font-cairo">
                        {(homeFilter === 'product' || homeFilter === 'cars' || homeFilter === 'tourism' || homeFilter === 'real_estate' || homeFilter === 'beauty') && !activeSubCategory
                          ? (lang === 'ar' ? 'اختر قسماً فرعياً أعلاه' : 'Select a sub-department above')
                          : (lang === 'ar' ? 'عروض خدمات مقترحة ومفضلة' : 'Featured Services and Offers')}
                      </h3>

                      {((homeFilter !== 'product' && homeFilter !== 'cars' && homeFilter !== 'tourism' && homeFilter !== 'real_estate' && homeFilter !== 'beauty') || activeSubCategory !== null || searchQuery !== '') && (
                        displayedHomeItems.length === 0 ? (
                          <div className="p-8 text-center bg-white rounded-2xl border border-neutral-100">
                            <span className="material-symbols-outlined text-4xl text-neutral-300 mb-2">search_off</span>
                            <p className="text-sm text-neutral-500 font-cairo">{lang === 'ar' ? 'عذراً، لا توجد نتائج مطابقة لبحثك' : 'Sorry, no matching results found.'}</p>
                          </div>
                        ) : (
                          <div className="space-y-4">
                            {displayedHomeItems.map((item) => (
                              <div
                                key={item.id}
                                className="bg-white rounded-2xl p-4 flex gap-4 shadow-sm border border-neutral-100 transition-all hover:shadow-md active:scale-[0.99]"
                              >
                                <div className="w-20 h-20 rounded-xl overflow-hidden shrink-0 bg-neutral-100 relative">
                                  <img src={item.image} alt={item.nameAr} className="w-full h-full object-cover" />
                                  <div className="absolute top-1 right-1">
                                    <button
                                      onClick={() => toggleFavItem(item.id)}
                                      className="w-7 h-7 bg-white/90 rounded-full flex items-center justify-center text-red-500 shadow-sm"
                                    >
                                      <span className="material-symbols-outlined text-sm font-bold" style={{ fontVariationSettings: item.isFavorite ? "'FILL' 1" : "'FILL' 0" }}>
                                        favorite
                                      </span>
                                    </button>
                                  </div>
                                </div>
                                <div className="flex-1 flex flex-col justify-between">
                                  <div>
                                    <div className="flex justify-between items-start">
                                      <h4 className="text-sm font-black text-neutral-800 line-clamp-1 font-cairo">
                                        {lang === 'ar' ? item.nameAr : item.nameEn}
                                      </h4>
                                      <span className="text-[10px] px-2 py-0.5 bg-neutral-100 rounded text-neutral-500 font-semibold font-cairo">
                                        {lang === 'ar' ? item.categoryLabelAr : item.categoryLabelEn}
                                      </span>
                                    </div>
                                    <p className="text-xs text-neutral-500 line-clamp-2 mt-1 leading-relaxed font-cairo">
                                      {lang === 'ar' ? item.descriptionAr : item.descriptionEn}
                                    </p>
                                  </div>

                                  <div className="flex justify-between items-center mt-2 pt-2 border-t border-dotted border-neutral-100">
                                    <div className="text-left font-mono">
                                      <span className="text-[10px] block text-neutral-400 font-cairo">{lang === 'ar' ? 'بأفضل الأسعار' : 'Best Rates'}</span>
                                      <span className="text-xs font-black text-orange-600">{item.price.toLocaleString()} د.ع</span>
                                    </div>

                                    <button
                                      onClick={() => {
                                        if (item.category === 'restaurant') {
                                          setBookTableItem(item);
                                        } else if (item.category === 'product') {
                                          addItemToCart(item);
                                        } else {
                                          setContactItem(item);
                                        }
                                      }}
                                      className="px-3 py-1.5 bg-orange-600 hover:bg-orange-500 text-white rounded-lg text-xs font-bold font-cairo active:scale-95 transition-all shadow-sm"
                                    >
                                      {lang === 'ar' ? item.actionLabelAr : item.actionLabelEn}
                                    </button>
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        )
                      )}
                    </div>
                  </div>
                )}


                {/* SCREEN 2: FAVORITES TAB */}
                {currentTab === 'fav' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div>
                      <h2 className="text-2xl font-black text-neutral-900 font-cairo">{t.favorites}</h2>
                      <p className="text-xs text-neutral-400 font-cairo">{t.saved_items}</p>
                    </div>

                    {/* Category Filter Pills */}
                    <div className="flex overflow-x-auto gap-2 pb-2 no-scrollbar">
                      {(['all', 'restaurant', 'product', 'real_estate'] as const).map(tab => {
                        const isActive = favFilter === tab;
                        const labelMap = {
                          all: t.all,
                          restaurant: t.restaurants,
                          product: t.products,
                          real_estate: t.real_estate
                        };
                        return (
                          <button
                            key={tab}
                            onClick={() => setFavFilter(tab)}
                            className={`whitespace-nowrap px-4 py-2 text-xs font-bold rounded-full transition-all shadow-sm shrink-0 font-cairo ${isActive ? 'bg-orange-600 text-white shadow-orange-100' : 'bg-white text-neutral-600 hover:bg-neutral-100'}`}
                          >
                            {labelMap[tab]}
                          </button>
                        );
                      })}
                    </div>

                    {/* Results Count list */}
                    {filteredFavItems.length === 0 ? (
                      <div className="py-20 text-center bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center">
                        <span className="material-symbols-outlined text-5xl text-neutral-300 mb-3" style={{ fontVariationSettings: "'FILL' 1" }}>favorite</span>
                        <p className="text-sm text-neutral-500 font-cairo mb-4">{t.no_items_in_fav}</p>
                        <button
                          onClick={() => setCurrentTab('home')}
                          className="px-6 py-2.5 bg-orange-600 text-white font-bold text-xs rounded-xl hover:bg-orange-500 transition-colors font-cairo"
                        >
                          {lang === 'ar' ? 'تصفح وتسوّق الآن' : 'Browse Services Now'}
                        </button>
                      </div>
                    ) : (
                      <div className="grid grid-cols-1 gap-6">
                        {filteredFavItems.map(item => (
                          <article key={item.id} className="bg-white rounded-3xl overflow-hidden shadow-sm border border-neutral-100 flex flex-col hover:shadow-md transition-shadow group">
                            
                            {/* Card Image Container */}
                            <div className="relative aspect-video sm:aspect-[2/1] bg-neutral-200">
                              <img src={item.image} alt={item.nameAr} className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-102" />
                              
                              <button
                                onClick={() => toggleFavItem(item.id)}
                                className="absolute top-3 right-3 p-2 bg-white/90 backdrop-blur-md rounded-full shadow-md text-red-500 hover:scale-110 active:scale-90 transition-transform"
                              >
                                <span className="material-symbols-outlined leading-none align-middle" style={{ fontVariationSettings: "'FILL' 1" }}>
                                  favorite
                                </span>
                              </button>

                              {item.rating && (
                                <div className="absolute bottom-3 left-3 px-2.5 py-1 bg-white/95 backdrop-blur-md rounded-xl flex items-center gap-1 shadow-sm font-semibold text-xs">
                                  <span className="material-symbols-outlined text-amber-500 text-sm" style={{ fontVariationSettings: "'FILL' 1" }}>star</span>
                                  <span>{item.rating}</span>
                                </div>
                              )}
                            </div>

                            {/* Card Details Body */}
                            <div className="p-5 flex flex-col flex-1">
                              <div className="flex justify-between items-start gap-2 mb-2">
                                <h3 className="font-bold text-lg text-neutral-900 group-hover:text-orange-600 transition-colors line-clamp-1 font-cairo">
                                  {lang === 'ar' ? item.nameAr : item.nameEn}
                                </h3>
                                <span className="text-[10px] px-2.5 py-1 bg-neutral-100 rounded-lg text-neutral-500 font-bold shrink-0 font-cairo">
                                  {lang === 'ar' ? item.categoryLabelAr : item.categoryLabelEn}
                                </span>
                              </div>

                              <p className="text-xs text-neutral-500 mb-4 leading-relaxed line-clamp-2 font-cairo">
                                {lang === 'ar' ? item.descriptionAr : item.descriptionEn}
                              </p>

                              {/* Nested real estate facts if applicable */}
                              {item.category === 'real_estate' && (
                                <div className="flex gap-4 mb-4 text-xs text-neutral-500 font-semibold bg-neutral-50 p-3 rounded-2xl">
                                  <div className="flex items-center gap-1 font-cairo">
                                    <span className="material-symbols-outlined text-sm text-neutral-400">bed</span>
                                    <span>{item.bedrooms} {t.rooms}</span>
                                  </div>
                                  <div className="flex items-center gap-1 font-cairo">
                                    <span className="material-symbols-outlined text-sm text-neutral-400">bathtub</span>
                                    <span>{item.bathrooms} {t.bathrooms}</span>
                                  </div>
                                  <div className="flex items-center gap-1 font-cairo">
                                    <span className="material-symbols-outlined text-sm text-neutral-400">square_foot</span>
                                    <span>{item.areaSquareMeter} {t.area}</span>
                                  </div>
                                </div>
                              )}

                              {/* Pricing and Action trigger footer */}
                              <div className="mt-auto flex justify-between items-center pt-4 border-t border-neutral-100">
                                <div className="flex flex-col">
                                  <span className="text-[11px] text-neutral-400 font-cairo">
                                    {lang === 'ar' ? item.avgPriceLabelAr : item.avgPriceLabelEn}
                                  </span>
                                  <span className="text-md font-extrabold text-neutral-800 font-mono">
                                    {item.price.toLocaleString()} د.ع
                                  </span>
                                </div>

                                <button
                                  onClick={() => {
                                    if (item.category === 'restaurant') {
                                      setBookTableItem(item);
                                    } else if (item.category === 'product') {
                                      addItemToCart(item);
                                    } else {
                                      setContactItem(item);
                                    }
                                  }}
                                  className="px-5 py-2.5 bg-orange-600 hover:bg-orange-500 text-white text-xs font-black rounded-xl transition-all active:scale-95 shadow-md shadow-orange-100 font-cairo"
                                >
                                  {lang === 'ar' ? item.actionLabelAr : item.actionLabelEn}
                                </button>
                              </div>

                            </div>
                          </article>
                        ))}
                      </div>
                    )}
                  </div>
                )}


                {/* SCREEN 3: SHOPPING CART TAB */}
                {currentTab === 'cart' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div>
                      <h2 className="text-2xl font-black text-neutral-950 font-cairo">{t.cart_title}</h2>
                      <p className="text-xs text-neutral-400 font-cairo">
                        {cart.length > 0 ? `${cart.length} ${lang === 'ar' ? 'عناصر مضافة في سلتك' : 'added items available'}` : t.no_items_in_cart}
                      </p>
                    </div>

                    {cart.length === 0 ? (
                      <div className="py-20 text-center bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center">
                        <span className="material-symbols-outlined text-5xl text-neutral-300 mb-3" style={{ fontVariationSettings: "'FILL' 1" }}>shopping_cart_checkout</span>
                        <p className="text-sm text-neutral-500 font-cairo mb-4">{t.no_items_in_cart}</p>
                        <button
                          onClick={() => {
                            setCurrentTab('home');
                            setHomeFilter('product');
                          }}
                          className="px-6 py-2.5 bg-orange-600 text-white font-bold text-xs rounded-xl hover:bg-orange-500 transition-colors font-cairo"
                        >
                          {lang === 'ar' ? 'تصفح منتجات الأسواق' : 'Browse Store Products'}
                        </button>
                      </div>
                    ) : (
                      <div className="space-y-4">
                        {/* Cart List Grouped */}
                        <div className="space-y-3">
                          {cart.map((item) => (
                            <div key={item.id} className="bg-white rounded-2xl p-3 flex gap-4 items-center shadow-sm border border-neutral-100">
                              <div className="w-16 h-16 rounded-xl overflow-hidden shrink-0 bg-neutral-100">
                                <img src={item.image} alt={item.nameAr} className="w-full h-full object-cover" />
                              </div>

                              <div className="flex-1 flex flex-col justify-between">
                                <div className="flex justify-between items-start">
                                  <div>
                                    <h3 className="font-bold text-xs text-neutral-900 font-cairo">
                                      {lang === 'ar' ? item.nameAr : item.nameEn}
                                    </h3>
                                    {(item.optionAr || item.optionEn) && (
                                      <p className="text-[10px] text-neutral-400 font-semibold font-cairo">
                                        {lang === 'ar' ? item.optionAr : item.optionEn}
                                      </p>
                                    )}
                                  </div>
                                  <button
                                    onClick={() => updateCartQty(item.id, -item.count)}
                                    className="text-neutral-300 hover:text-red-500"
                                  >
                                    <span className="material-symbols-outlined text-xs">delete</span>
                                  </button>
                                </div>

                                <div className="flex justify-between items-center mt-2 pt-1 border-t border-dotted border-neutral-100">
                                  <span className="text-xs font-black text-orange-600 font-mono">
                                    {(item.price * item.count).toLocaleString()} د.ع
                                  </span>

                                  {/* Stepper with continuous curves */}
                                  <div className="flex items-center bg-neutral-100 rounded-full py-0.5 px-2">
                                    <button
                                      onClick={() => updateCartQty(item.id, -1)}
                                      className="w-6 h-6 rounded-full hover:bg-neutral-200 flex items-center justify-center text-neutral-600"
                                    >
                                      <span className="material-symbols-outlined text-sm font-bold">remove</span>
                                    </button>
                                    <span className="text-xs font-bold w-6 text-center text-neutral-800 font-mono">
                                      {item.count}
                                    </span>
                                    <button
                                      onClick={() => updateCartQty(item.id, 1)}
                                      className="w-6 h-6 rounded-full hover:bg-neutral-200 flex items-center justify-center text-orange-600"
                                    >
                                      <span className="material-symbols-outlined text-sm font-bold">add</span>
                                    </button>
                                  </div>
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>

                        {/* Order Notes / Dynamic Promo Code Apply Form */}
                        <div className="bg-white rounded-2xl p-4 shadow-sm border border-neutral-100">
                          <label className="text-xs font-bold text-neutral-600 block mb-2 font-cairo">
                            {t.apply_promo}
                          </label>
                          <div className="flex gap-2">
                            <input
                              type="text"
                              value={promoCodeInput}
                              onChange={(e) => setPromoCodeInput(e.target.value)}
                              placeholder={t.promo_code_placeholder}
                              className={`flex-1 px-3 py-2 bg-neutral-50 border border-neutral-200 rounded-xl text-neutral-800 focus:outline-none focus:border-orange-500 font-mono text-xs ${isRTL ? 'text-right' : 'text-left'}`}
                            />
                            <button
                              onClick={handleApplyPromo}
                              className="px-4 py-2 bg-neutral-900 hover:bg-neutral-800 text-white font-bold text-xs rounded-xl active:scale-95 transition-all font-cairo"
                            >
                              {lang === 'ar' ? 'تطبيق' : 'Apply'}
                            </button>
                          </div>
                          {isPromoApplied && (
                            <p className="text-[11px] text-emerald-600 font-bold mt-1.5 flex items-center gap-1 font-cairo">
                              <span className="material-symbols-outlined text-sm font-semibold">check_circle</span>
                              <span>{t.promo_applied}</span>
                            </p>
                          )}
                          <p className="text-[10px] text-neutral-400 mt-2 font-cairo">
                            ℹ️ hint: {lang === 'ar' ? 'استخدم كود GHAITH20 للحصول على خصم 20% فوراً.' : 'use coupon GHAITH20 to instantly save 20%.'}
                          </p>
                        </div>

                        {/* Summary Block */}
                        <div className="bg-white rounded-2xl p-4 shadow-sm border border-neutral-100 space-y-2 text-xs">
                          <div className="flex justify-between items-center text-neutral-500">
                            <span className="font-cairo">{t.subtotal}</span>
                            <span className="font-mono">{getInvoiceDetails().subtotal.toLocaleString()} د.ع</span>
                          </div>
                          {isPromoApplied && (
                            <div className="flex justify-between items-center text-emerald-600 font-semibold">
                              <span className="font-cairo">%خصم الكود الـ 20</span>
                              <span className="font-mono">-{getInvoiceDetails().discount.toLocaleString()} د.ع</span>
                            </div>
                          )}
                          <div className="flex justify-between items-center text-neutral-500">
                            <span className="font-cairo">{t.delivery_fees}</span>
                            <span className="font-mono">{getInvoiceDetails().delivery.toLocaleString()} د.ع</span>
                          </div>
                          <div className="flex justify-between items-center text-neutral-500">
                            <span className="font-cairo">{t.tax}</span>
                            <span className="font-mono">{getInvoiceDetails().tax.toLocaleString()} د.ع</span>
                          </div>

                          <div className="h-px bg-neutral-100 my-2"></div>

                          <div className="flex justify-between items-center mt-1">
                            <span className="text-sm font-bold text-neutral-800 font-cairo">{t.total}</span>
                            <span className="text-xl font-black text-orange-600 font-mono">
                              {getInvoiceDetails().finalTotal.toLocaleString()} د.ع
                            </span>
                          </div>
                        </div>

                        {/* Payment Type Reminder Card */}
                        <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex gap-3 items-start">
                          <span className="material-symbols-outlined text-amber-600 shrink-0 mt-0.5">local_shipping</span>
                          <div className="text-xs text-amber-900 leading-relaxed font-cairo">
                            <strong>{t.payment_methods}:</strong> {t.payment_desc}. {lang === 'ar' ? 'الدفع يتم للمندوب نقداً فور جلب المنتجات ومعاينتها بيدك.' : 'Payment is paid directly to the courier agent in cash upon package check.'}
                          </div>
                        </div>

                        {/* Checkout Button */}
                        <button
                          onClick={handleCheckout}
                          className="w-full bg-orange-600 hover:bg-orange-500 text-white font-black text-sm py-4 rounded-2xl transition-all active:scale-[0.98] shadow-lg shadow-orange-100 font-cairo uppercase"
                        >
                          {t.checkout}
                        </button>
                      </div>
                    )}
                  </div>
                )}


                {/* SCREEN 4: MY ORDERS TAB */}
                {currentTab === 'orders' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div>
                      <h2 className="text-2xl font-black text-neutral-950 font-cairo">{t.orders}</h2>
                      <p className="text-xs text-neutral-400 font-cairo">
                        {lang === 'ar' ? 'تتبع حالات توصيل طلبات الكاش الخاصة بك بالتحديث المباشر' : 'Track Cash on Delivery order statuses live'}
                      </p>
                    </div>

                    {/* iOS Tab Segments */}
                    <div className="bg-neutral-200/60 p-1 rounded-2xl flex">
                      <button
                        onClick={() => setActiveSegmentedOrderTab('active')}
                        className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all font-cairo ${activeSegmentedOrderTab === 'active' ? 'bg-white shadow-sm text-neutral-800' : 'text-neutral-500 hover:text-neutral-800'}`}
                      >
                        {t.current_orders}
                      </button>
                      <button
                        onClick={() => setActiveSegmentedOrderTab('previous')}
                        className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all font-cairo ${activeSegmentedOrderTab === 'previous' ? 'bg-white shadow-sm text-neutral-800' : 'text-neutral-500 hover:text-neutral-800'}`}
                      >
                        {t.previous_orders}
                      </button>
                    </div>

                    {/* Active Order Log list render */}
                    {activeSegmentedOrderTab === 'active' ? (
                      orders.length === 0 ? (
                        <div className="py-20 text-center bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center">
                          <span className="material-symbols-outlined text-5xl text-neutral-300 mb-3" style={{ fontVariationSettings: "'FILL' 0" }}>receipt_long</span>
                          <p className="text-sm text-neutral-500 font-cairo mb-4">{t.no_orders}</p>
                          <button
                            onClick={() => setCurrentTab('home')}
                            className="px-6 py-2.5 bg-orange-600 text-white font-bold text-xs rounded-xl hover:bg-orange-500 transition-colors font-cairo"
                          >
                            {lang === 'ar' ? 'تسوق واطلب الآن كاش' : 'Order Now via Cash On Delivery'}
                          </button>
                        </div>
                      ) : (
                        <div className="space-y-4">
                          {orders.map((order) => {
                            const isDelivered = order.statusKey === 'processing' ? false : true;
                            return (
                              <div key={order.id} className="bg-white rounded-3xl p-4 shadow-sm border border-neutral-100 relative">
                                <div className="flex justify-between items-start gap-2 mb-3">
                                  <div>
                                    <h3 className="font-extrabold text-sm text-neutral-800 font-mono">
                                      {lang === 'ar' ? `طلب ${order.orderNumber}` : `Order #${order.orderNumber}`}
                                    </h3>
                                    <p className="text-[10px] text-neutral-400 font-semibold font-cairo mt-0.5">
                                      {lang === 'ar' ? order.dateAr : order.dateEn}
                                    </p>
                                  </div>

                                  <span className="bg-orange-50 text-orange-600 max-w-xs px-2.5 py-1 rounded-full text-[10px] font-bold font-cairo shrink-0 flex items-center gap-1">
                                    <span className="w-1.5 h-1.5 rounded-full bg-orange-600 animate-ping"></span>
                                    {lang === 'ar' ? order.statusAr : order.statusEn}
                                  </span>
                                </div>

                                <div className="flex items-center gap-3 mb-4">
                                  <div className="w-12 h-12 rounded-xl bg-orange-50/60 shrink-0 flex items-center justify-center overflow-hidden">
                                    {order.image ? (
                                      <img src={order.image} alt="product photo" className="w-full h-full object-cover" />
                                    ) : (
                                      <span className="material-symbols-outlined text-orange-600 text-lg">
                                        {order.iconName || 'package_2'}
                                      </span>
                                    )}
                                  </div>
                                  <div className="flex-1">
                                    <p className="text-xs font-bold text-neutral-800 line-clamp-1 font-cairo">
                                      {lang === 'ar' ? order.itemsNameAr : order.itemsNameEn}
                                    </p>
                                    <p className="text-[10px] text-neutral-400 font-semibold font-cairo mt-0.5">
                                      {order.itemsCount} {t.items}
                                    </p>
                                  </div>
                                </div>

                                {/* Dynamic actions footer */}
                                <div className="flex justify-between items-center pt-3 border-t border-neutral-100">
                                  <span className="text-sm font-black text-neutral-800 font-mono">
                                    {order.price.toLocaleString()} د.ع
                                  </span>

                                  <div className="flex gap-2">
                                    <button
                                      onClick={() => {
                                        setTrackOrderActive(order);
                                      }}
                                      className="bg-orange-600 text-white font-bold text-xs py-2 px-4 rounded-xl hover:bg-orange-500 transition-all active:scale-95 font-cairo"
                                    >
                                      {t.track_order}
                                    </button>
                                  </div>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )
                    ) : (
                      // Previous finished order logs
                      <div className="space-y-4">
                        <div className="bg-white rounded-3xl p-5 shadow-sm border border-neutral-100 opacity-75">
                          <div className="flex justify-between items-start gap-2 mb-3">
                            <div>
                              <h3 className="font-extrabold text-sm text-neutral-800 font-mono">ORD-3129</h3>
                              <p className="text-[10px] text-neutral-400 font-semibold font-cairo">٢٤ أبريل، ٢٠٢٦</p>
                            </div>
                            <span className="bg-neutral-100 text-neutral-500 px-3 py-1 rounded-full text-[10px] font-bold font-cairo">
                              {lang === 'ar' ? 'تم التوصيل كاش' : 'COD Delivered'}
                            </span>
                          </div>
                          <p className="text-xs text-neutral-500 font-cairo">
                            {lang === 'ar' ? 'وجبة مشاوي مشكلة عائلية، حمص ومتبل' : 'Family BBQ mix Grill, Hummus & appetizers'}
                          </p>
                          <div className="flex justify-between items-center pt-3 border-t border-neutral-100 mt-3 font-mono">
                            <span className="text-xs font-bold">45,000 د.ع</span>
                            <span className="text-[10px] font-bold font-cairo text-neutral-400">COD Paid ✅</span>
                          </div>
                        </div>

                        <div className="bg-white rounded-3xl p-5 shadow-sm border border-neutral-100 opacity-75">
                          <div className="flex justify-between items-start gap-2 mb-3">
                            <div>
                              <h3 className="font-extrabold text-sm text-neutral-800 font-mono">ORD-1092</h3>
                              <p className="text-[10px] text-neutral-400 font-semibold font-cairo">٢ أبريل، ٢٠٢٦</p>
                            </div>
                            <span className="bg-neutral-100 text-neutral-500 px-3 py-1 rounded-full text-[10px] font-bold font-cairo">
                              {lang === 'ar' ? 'تم التوصيل كاش' : 'COD Delivered'}
                            </span>
                          </div>
                          <p className="text-xs text-neutral-500 font-cairo">
                            {lang === 'ar' ? 'ساعة ذكية عازلة للماء الجيل العاشر' : 'Waterproof Smartwatch Gen 10'}
                          </p>
                          <div className="flex justify-between items-center pt-3 border-t border-neutral-100 mt-3 font-mono">
                            <span className="text-xs font-bold">85,000 د.ع</span>
                            <span className="text-[10px] font-bold font-cairo text-neutral-400">COD Paid ✅</span>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}


                {/* SCREEN 5: USER REGISTERED ACCOUNT TAB */}
                {currentTab === 'account' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div>
                      <h2 className="text-2xl font-black text-neutral-950 font-cairo">{t.account}</h2>
                      <p className="text-xs text-neutral-400 font-cairo">
                        {lang === 'ar' ? 'تعديل تفاصيل حسابك وإدارة الخيارات' : 'Edit account preferences and controls'}
                      </p>
                    </div>

                    {/* Profile Panel Banner with custom squircle avatar image */}
                    <section className="bg-white rounded-3xl overflow-hidden shadow-sm border border-neutral-100 p-4 flex items-center gap-4">
                      <div className="w-16 h-16 rounded-full overflow-hidden bg-neutral-100 shrink-0 border border-neutral-200 relative">
                        <img
                          alt="أحمد خالد"
                          className="w-full h-full object-cover"
                          src="https://lh3.googleusercontent.com/aida-public/AB6AXuAchXbMOyumk8sUl-10AMqODUGj-Fp7VlsQY_7FAHXFLyTxtsmyCj7FWzwnUPPyDnjboA6eTJtr3rxVzhxbaom2zZ0uU8z91G8ppOWSKRI6BNLBCEka3eLBbfmv_AM0G_H2v25AvAvziV2GdWgWGe_g4qY9ZnBd0gltGJnknlAEuhPOS4TYr_Im5LeNWKHi9Oj3AyEV7OFWskXywxdaTbhRn73oVBn0PlQalpU_RNsk_-gtdGBEkNQBiy3-49gGTJITnLgd1ldGH-Zl"
                        />
                      </div>
                      <div className="flex-grow">
                        <h2 className="text-lg font-black text-neutral-800 leading-snug font-cairo">أحمد خالد</h2>
                        <p className="text-xs text-neutral-400 font-mono">ahmed.khaled@example.com</p>
                        
                        <div className="mt-2 inline-flex items-center gap-1 bg-amber-50 text-amber-600 px-2.5 py-1 rounded-xl">
                          <span className="material-symbols-outlined text-xs" style={{ fontVariationSettings: "'FILL' 1" }}>star</span>
                          <span className="text-[10px] font-bold font-cairo">{t.active_membership}</span>
                        </div>
                      </div>
                    </section>

                    {/* Group Tiles 1: Actions */}
                    <section className="bg-white rounded-3xl overflow-hidden shadow-sm border border-neutral-100">
                      <ul className="divide-y divide-neutral-100">
                        <li>
                          <a href="#" onClick={(e) => { e.preventDefault(); showToastMsg(lang==='ar'?'بغداد - الكرادة داحل':'Baghdad - Karada Inside'); }} className="flex items-center justify-between p-4 active:bg-neutral-50 transition-colors">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center">
                                <span className="material-symbols-outlined text-sm">location_on</span>
                              </div>
                              <span className="text-xs font-bold text-neutral-800 font-cairo">{t.my_addresses}</span>
                            </div>
                            <span className="material-symbols-outlined text-neutral-400 text-xs">
                              {isRTL ? 'chevron_left' : 'chevron_right'}
                            </span>
                          </a>
                        </li>
                        <li>
                          <a href="#" onClick={(e) => { e.preventDefault(); showToastMsg(lang==='ar'?'الدفع نقداً فقط مفعّل':'Standard Cash mode only enabled'); }} className="flex items-center justify-between p-4 active:bg-neutral-50 transition-colors">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
                                <span className="material-symbols-outlined text-sm">credit_card</span>
                              </div>
                              <div className="flex flex-col">
                                <span className="text-xs font-bold text-neutral-800 font-cairo">{t.payment_methods}</span>
                                <span className="text-[10px] text-neutral-400 font-semibold font-cairo">{t.payment_desc}</span>
                              </div>
                            </div>
                            <span className="material-symbols-outlined text-neutral-400 text-xs">
                              {isRTL ? 'chevron_left' : 'chevron_right'}
                            </span>
                          </a>
                        </li>
                        <li>
                          <a href="#" onClick={(e) => { e.preventDefault(); setActiveSegmentedOrderTab('previous'); setCurrentTab('orders'); }} className="flex items-center justify-between p-4 active:bg-neutral-50 transition-colors">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-xl bg-neutral-100 text-neutral-600 flex items-center justify-center">
                                <span className="material-symbols-outlined text-sm font-semibold">receipt_long</span>
                              </div>
                              <span className="text-xs font-bold text-neutral-800 font-cairo">{t.order_history}</span>
                            </div>
                            <span className="material-symbols-outlined text-neutral-400 text-xs">
                              {isRTL ? 'chevron_left' : 'chevron_right'}
                            </span>
                          </a>
                        </li>
                        <li>
                          <a href="#" onClick={(e) => { e.preventDefault(); showToastMsg(lang === 'ar' ? 'الإعدادات قيد التطوير' : 'Settings coming soon'); }} className="flex items-center justify-between p-4 active:bg-neutral-50 transition-colors">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                                <span className="material-symbols-outlined text-sm">settings</span>
                              </div>
                              <span className="text-xs font-bold text-neutral-800 font-cairo">{t.settings}</span>
                            </div>
                            <span className="material-symbols-outlined text-neutral-400 text-xs">
                              {isRTL ? 'chevron_left' : 'chevron_right'}
                            </span>
                          </a>
                        </li>
                        <li>
                          <a href="#" onClick={(e) => { e.preventDefault(); setCurrentTab('contact'); }} className="flex items-center justify-between p-4 active:bg-neutral-50 transition-colors">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-xl bg-green-50 text-emerald-600 flex items-center justify-center">
                                <span className="material-symbols-outlined text-sm">headset_mic</span>
                              </div>
                              <span className="text-xs font-bold text-neutral-800 font-cairo">{lang === 'ar' ? 'اتصل بنا' : 'Contact Us'}</span>
                            </div>
                            <span className="material-symbols-outlined text-neutral-400 text-xs">
                              {isRTL ? 'chevron_left' : 'chevron_right'}
                            </span>
                          </a>
                        </li>
                      </ul>
                    </section>

                    {/* Settings Segment */}
                    <section className="bg-white rounded-3xl overflow-hidden shadow-sm border border-neutral-100 p-4 space-y-4">
                      <div className="flex items-center gap-3 border-b border-neutral-50 pb-3">
                        <span className="material-symbols-outlined text-orange-600">settings</span>
                        <h3 className="text-sm font-black text-neutral-800 font-cairo">{t.settings}</h3>
                      </div>

                      {/* Language Changer inside the app settings segment */}
                      <div className="space-y-2">
                        <label className="text-[11px] font-bold text-neutral-400 block font-cairo">
                          {t.change_language}
                        </label>
                        <div className="grid grid-cols-2 gap-2">
                          <button
                            onClick={() => {
                              setLang('ar');
                              showToastMsg('تم تعيين اللغة العربية كلغة رئيسية');
                            }}
                            className={`py-2 px-3 text-xs font-bold rounded-xl transition-all border ${lang === 'ar' ? 'bg-orange-600 text-white border-orange-500' : 'bg-neutral-50 text-neutral-600 border-neutral-200'}`}
                          >
                            العربية (العراق)
                          </button>
                          
                          <button
                            onClick={() => {
                              setLang('en');
                              showToastMsg('English language applied');
                            }}
                            className={`py-2 px-3 text-xs font-bold rounded-xl transition-all border ${lang === 'en' ? 'bg-orange-600 text-white border-orange-500' : 'bg-neutral-50 text-neutral-600 border-neutral-200'}`}
                          >
                            English
                          </button>
                        </div>
                      </div>
                    </section>

                    {/* About details of the app */}
                    <section className="bg-white rounded-3xl p-4 shadow-sm border border-neutral-100 space-y-2 text-xs">
                      <h4 className="font-bold text-neutral-800 font-cairo">{t.about_app}</h4>
                      <p className="text-neutral-500 leading-relaxed font-cairo">
                        {t.about_desc}
                      </p>
                      <p className="text-[10px] text-neutral-400 font-mono mt-2">
                        Build Version: 1.4.0 (Flutter Layout Compliant React Framework)
                      </p>
                    </section>

                    {/* Logout Button - Modernized destructive style */}
                    <section className="pt-2">
                      <button
                        onClick={resetAllData}
                        className="w-full bg-white border border-neutral-100 hover:bg-red-50 group py-4 px-5 rounded-[28px] shadow-sm flex items-center justify-between transition-all active:scale-[0.98]"
                      >
                        <div className="flex items-center gap-4">
                          <div className="w-11 h-11 rounded-2xl bg-red-50 text-red-500 flex items-center justify-center group-hover:bg-red-500 group-hover:text-white transition-all duration-300">
                            <span className="material-symbols-outlined text-xl">logout</span>
                          </div>
                          <div className="text-right">
                            <span className="block text-sm font-black text-red-600 font-cairo leading-none">{t.logout}</span>
                            <span className="text-[10px] text-neutral-400 font-cairo mt-1.5">{lang === 'ar' ? 'تسجيل الخروج من الحساب الحالي' : 'Sign out of your current account'}</span>
                          </div>
                        </div>
                        <span className="material-symbols-outlined text-neutral-300 group-hover:text-red-300 transition-colors">
                          {isRTL ? 'chevron_left' : 'chevron_right'}
                        </span>
                      </button>
                    </section>
                  </div>
                )}


                {/* SCREEN 6: NOTIFICATIONS BOX VIEW */}
                {currentTab === 'notifications' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div className="flex justify-between items-center">
                      <div>
                        <h2 className="text-2xl font-black text-neutral-900 font-cairo">{t.notifications}</h2>
                        <p className="text-xs text-neutral-400 font-cairo">
                          {lang === 'ar' ? 'إخطارات توصيل الطلبات والخصومات المتاحة حالياً' : 'Your live order delivery logs and special deals'}
                        </p>
                      </div>

                      {notifications.length > 0 && (
                        <button
                          onClick={clearAllNotifications}
                          className="text-xs font-bold text-red-500 hover:text-red-600 font-cairo shrink-0"
                        >
                          {t.clear_all}
                        </button>
                      )}
                    </div>

                    {notifications.length === 0 ? (
                      <div className="py-20 text-center bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center">
                        <span className="material-symbols-outlined text-5xl text-neutral-300 mb-3" style={{ fontVariationSettings: "'FILL' 0" }}>notifications_off</span>
                        <p className="text-sm text-neutral-500 font-cairo">{t.no_notifications}</p>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {notifications.map((n) => (
                          <article 
                            key={n.id} 
                            className={`bg-white rounded-2xl p-4 shadow-sm border border-neutral-150 relative flex gap-3.5 items-start transition-all active:scale-[0.99] cursor-pointer ${!n.read ? 'border-r-4 border-r-orange-600' : 'opacity-85'}`}
                          >
                            {/* Icon colored status */}
                            <div className="w-10 h-10 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center shrink-0">
                              <span className="material-symbols-outlined text-[20px]">{n.iconName}</span>
                            </div>

                            {/* Alert Content */}
                            <div className="flex-1 min-w-0">
                              <div className="flex justify-between items-start gap-1 mb-1">
                                <h3 className="text-xs font-black text-neutral-800 font-cairo truncate">
                                  {lang === 'ar' ? n.titleAr : n.titleEn}
                                </h3>
                                <span className="text-[9px] text-neutral-400 shrink-0 font-cairo">
                                  {lang === 'ar' ? n.timeAr : n.timeEn}
                                </span>
                              </div>
                              <p className="text-xs text-neutral-500 leading-relaxed font-cairo">
                                {lang === 'ar' ? n.bodyAr : n.bodyEn}
                              </p>
                            </div>
                          </article>
                        ))}
                      </div>
                    )}

                    <button
                      onClick={() => setCurrentTab('home')}
                      className="w-full py-3 bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-bold rounded-xl font-cairo"
                    >
                      {lang === 'ar' ? 'العودة للرئيسية' : 'Back to Home'}
                    </button>
                  </div>
                )}

                {/* SCREEN 7: CONTACT US PAGE */}
                {currentTab === 'contact' && (
                  <div className="space-y-6">
                    {/* Header */}
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => setCurrentTab('account')}
                        className="w-10 h-10 rounded-full bg-white shadow-sm flex items-center justify-center text-neutral-600 active:scale-90 transition-all"
                      >
                        <span className="material-symbols-outlined">{isRTL ? 'arrow_forward' : 'arrow_back'}</span>
                      </button>
                      <div>
                        <h2 className="text-2xl font-black text-neutral-900 font-cairo">{lang === 'ar' ? 'اتصل بنا' : 'Contact Us'}</h2>
                        <p className="text-xs text-neutral-400 font-cairo">
                          {lang === 'ar' ? 'نحن هنا لمساعدتك في أي وقت' : 'We are here to help you anytime'}
                        </p>
                      </div>
                    </div>

                    {/* Support Cards */}
                    <div className="grid grid-cols-1 gap-4">
                      <div className="bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center text-center space-y-3">
                        <div className="w-16 h-16 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center">
                          <span className="material-symbols-outlined text-3xl">chat_bubble</span>
                        </div>
                        <h3 className="font-bold text-lg text-neutral-800 font-cairo">{lang === 'ar' ? 'واتساب الغيث' : 'WhatsApp Support'}</h3>
                        <p className="text-xs text-neutral-500 font-cairo leading-relaxed">
                          {lang === 'ar' ? 'تواصل معنا مباشرة عبر الواتساب للحصول على رد سريع.' : 'Contact us directly on WhatsApp for a quick response.'}
                        </p>
                        <button
                          onClick={() => showToastMsg(lang === 'ar' ? 'جاري فتح واتساب...' : 'Opening WhatsApp...')}
                          className="w-full py-3 bg-emerald-600 text-white font-bold rounded-2xl active:scale-95 transition-all font-cairo"
                        >
                          {lang === 'ar' ? 'إرسال رسالة' : 'Send Message'}
                        </button>
                      </div>

                      <div className="bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center text-center space-y-3">
                        <div className="w-16 h-16 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center">
                          <span className="material-symbols-outlined text-3xl">call</span>
                        </div>
                        <h3 className="font-bold text-lg text-neutral-800 font-cairo">{lang === 'ar' ? 'الدعم الهاتفي' : 'Phone Support'}</h3>
                        <p className="text-xs text-neutral-500 font-cairo leading-relaxed">
                          {lang === 'ar' ? 'يمكنك الاتصال بنا مباشرة للتحدث مع أحد موظفينا.' : 'You can call us directly to speak with our staff.'}
                        </p>
                        <button
                          onClick={() => showToastMsg(lang === 'ar' ? 'جاري الاتصال...' : 'Calling Support...')}
                          className="w-full py-3 bg-orange-600 text-white font-bold rounded-2xl active:scale-95 transition-all font-cairo"
                        >
                          {lang === 'ar' ? 'اتصل الآن' : 'Call Now'}
                        </button>
                      </div>

                      <div className="bg-white rounded-3xl p-6 shadow-sm border border-neutral-100 flex flex-col items-center text-center space-y-3">
                        <div className="w-16 h-16 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center">
                          <span className="material-symbols-outlined text-3xl">mail</span>
                        </div>
                        <h3 className="font-bold text-lg text-neutral-800 font-cairo">{lang === 'ar' ? 'البريد الإلكتروني' : 'Email Support'}</h3>
                        <p className="text-xs text-neutral-500 font-cairo leading-relaxed">
                          {lang === 'ar' ? 'راسلنا عبر البريد الإلكتروني للاستفسارات الرسمية.' : 'Email us for formal inquiries.'}
                        </p>
                        <button
                          onClick={() => showToastMsg(lang === 'ar' ? 'جاري فتح البريد...' : 'Opening Email...')}
                          className="w-full py-3 bg-neutral-900 text-white font-bold rounded-2xl active:scale-95 transition-all font-cairo"
                        >
                          {lang === 'ar' ? 'إرسال إيميل' : 'Send Email'}
                        </button>
                      </div>
                    </div>

                    <p className="text-center text-[10px] text-neutral-400 font-cairo pt-4">
                      {lang === 'ar' ? 'ساعات العمل: 9 صباحاً - 9 مساءً' : 'Working Hours: 9 AM - 9 PM'}
                    </p>
                  </div>
                )}

              </motion.div>
            </AnimatePresence>

          </main>

          {/* Persistent Floating Bottom Tab Bar with exact matching design styles & counter indicators */}
          <nav className="fixed bottom-0 w-full max-w-md bg-white/95 border-t border-neutral-100 backdrop-blur-md px-2 py-2 flex justify-around items-center rounded-t-3xl shadow-[0_-8px_30px_rgba(0,0,0,0.05)] z-40 shrink-0 pb-safe">
            {/* Nav Item 1: Home/الرئيسية */}
            <button
              onClick={() => setCurrentTab('home')}
              className={`flex flex-col items-center justify-center flex-1 p-2 rounded-xl transition-all ${currentTab === 'home' ? 'text-orange-600 font-black' : 'text-neutral-400'}`}
            >
              <span className="material-symbols-outlined text-xl mb-0.5" style={{ fontVariationSettings: currentTab === 'home' ? "'FILL' 1" : "'FILL' 0" }}>
                home
              </span>
              <span className="text-[10px] tracking-tight font-cairo leading-none">{t.home}</span>
            </button>

            {/* Nav Item 2: Favorites/المفضلة */}
            <button
              onClick={() => setCurrentTab('fav')}
              className={`flex flex-col items-center justify-center flex-1 p-2 rounded-xl transition-all ${currentTab === 'fav' ? 'text-orange-600 font-black' : 'text-neutral-400'}`}
            >
              <span className="material-symbols-outlined text-xl mb-0.5" style={{ fontVariationSettings: currentTab === 'fav' ? "'FILL' 1" : "'FILL' 0" }}>
                favorite
              </span>
              <span className="text-[10px] tracking-tight font-cairo leading-none">{t.favorites}</span>
            </button>

            {/* Nav Item 3: Cart/سلة المشتريات */}
            <button
              onClick={() => setCurrentTab('cart')}
              className={`flex flex-col items-center justify-center flex-1 p-2 rounded-xl relative transition-all ${currentTab === 'cart' ? 'text-orange-600 font-black' : 'text-neutral-400'}`}
            >
              <span className="material-symbols-outlined text-xl mb-0.5" style={{ fontVariationSettings: currentTab === 'cart' ? "'FILL' 1" : "'FILL' 0" }}>
                shopping_cart
              </span>
              {cart.length > 0 && (
                <span className="absolute top-1.5 right-1.5 min-w-4 h-4 rounded-full bg-orange-600 text-[9px] font-bold text-white flex items-center justify-center px-1">
                  {cart.reduce((sum, item) => sum + item.count, 0)}
                </span>
              )}
              <span className="text-[10px] tracking-tight font-cairo leading-none">{t.cart}</span>
            </button>

            {/* Nav Item 4: Orders/الطلبات */}
            <button
              onClick={() => setCurrentTab('orders')}
              className={`flex flex-col items-center justify-center flex-1 p-2 rounded-xl relative transition-all ${currentTab === 'orders' ? 'text-orange-600 font-black' : 'text-neutral-400'}`}
            >
              <span className="material-symbols-outlined text-xl mb-0.5" style={{ fontVariationSettings: currentTab === 'orders' ? "'FILL' 1" : "'FILL' 0" }}>
                receipt_long
              </span>
              {orders.length > 0 && (
                <span className="absolute top-[6px] right-5 w-2 h-2 rounded-full bg-orange-500 animate-ping"></span>
              )}
              <span className="text-[10px] tracking-tight font-cairo leading-none">{t.orders}</span>
            </button>

            {/* Nav Item 5: My Account/حسابي */}
            <button
              onClick={() => setCurrentTab('account')}
              className={`flex flex-col items-center justify-center flex-1 p-2 rounded-xl transition-all ${currentTab === 'account' ? 'text-orange-600 font-black' : 'text-neutral-400'}`}
            >
              <span className="material-symbols-outlined text-xl mb-0.5" style={{ fontVariationSettings: currentTab === 'account' ? "'FILL' 1" : "'FILL' 0" }}>
                person
              </span>
              <span className="text-[10px] tracking-tight font-cairo leading-none">{t.account}</span>
            </button>
          </nav>

        </div>

        {/* ======================================= */}
        {/* MODAL 1: ORDER TRACKING TIMELINE */}
        {/* ======================================= */}
        <AnimatePresence>
          {trackOrderActive && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end justify-center font-sans"
            >
              <motion.div
                initial={{ y: 300 }}
                animate={{ y: 0 }}
                exit={{ y: 300 }}
                className="bg-white w-full rounded-t-[32px] p-6 space-y-5 shadow-2xl overflow-y-auto max-h-[90%] pb-safe"
              >
                <div className="flex justify-between items-center pb-3 border-b border-neutral-100">
                  <h3 className="text-md font-black text-neutral-800 font-cairo flex items-center gap-2">
                    <span className="material-symbols-outlined text-orange-600 animate-pulse">explore</span>
                    <span>{t.tracking_active}</span>
                  </h3>
                  <button
                    onClick={() => setTrackOrderActive(null)}
                    className="w-8 h-8 rounded-full bg-neutral-100 flex items-center justify-center hover:bg-neutral-200 transition-colors"
                  >
                    <span className="material-symbols-outlined text-xs">close</span>
                  </button>
                </div>

                <div className="text-center py-2">
                  <span className="text-[11px] font-bold text-neutral-400 tracking-wider block font-cairo">ORDER NUMBER</span>
                  <span className="text-xl font-black text-orange-600 underline decoration-dotted font-mono">{trackOrderActive.orderNumber}</span>
                  <p className="text-xs text-neutral-500 mt-2 font-cairo">{t.delivery_estimate}</p>
                </div>

                {/* Vertical Timeline Steps */}
                <div className="relative pr-6 left-auto border-r border-neutral-100 mr-4 space-y-6">
                  {/* Step 1: Received */}
                  <div className="relative">
                    <div className="absolute top-1 -right-[31px] w-5 h-5 rounded-full bg-orange-600 text-white flex items-center justify-center text-[10px] shadow-sm font-bold">✓</div>
                    <div className="text-xs">
                      <h4 className="font-extrabold text-neutral-800 font-cairo">{t.tracking_step_1}</h4>
                      <p className="text-[10px] text-emerald-600 font-bold mt-0.5 font-cairo">تم التأكيد والدفع كاش عند التسليم</p>
                    </div>
                  </div>

                  {/* Step 2: Preparing */}
                  <div className="relative">
                    <div className="absolute top-1 -right-[31px] w-5 h-5 rounded-full bg-orange-600 text-white flex items-center justify-center text-[10px] shadow-sm font-bold">✓</div>
                    <div className="text-xs">
                      <h4 className="font-extrabold text-neutral-800 font-cairo">{t.tracking_step_2}</h4>
                      <p className="text-[10px] text-neutral-400 font-semibold mt-0.5 font-cairo">الطلب في المطبخ/المستودع الرئيسي</p>
                    </div>
                  </div>

                  {/* Step 3: Out for courier */}
                  <div className="relative">
                    <div className="absolute top-1 -right-[31px] w-5 h-5 rounded-full bg-orange-100 border-2 border-orange-500 text-orange-600 flex items-center justify-center text-[10px] font-bold shadow-sm animate-pulse">3</div>
                    <div className="text-xs">
                      <h4 className="font-extrabold text-orange-600 font-cairo">{t.tracking_step_3}</h4>
                      <p className="text-[10px] text-orange-500 font-semibold mt-0.5 font-cairo">المندوب بالدراجة قادم لموقعك كاش</p>
                    </div>
                  </div>

                  {/* Step 4: Finished */}
                  <div className="relative">
                    <div className="absolute top-1 -right-[31px] w-5 h-5 rounded-full bg-neutral-100 border-2 border-neutral-300 text-neutral-400 flex items-center justify-center text-[10px] font-bold shadow-sm">4</div>
                    <div className="text-xs opacity-50">
                      <h4 className="font-bold text-neutral-500 font-cairo">{t.tracking_step_4}</h4>
                      <p className="text-[10px] mt-0.5 font-cairo">الدفع كاش واستلام المنتوج بيدك</p>
                    </div>
                  </div>
                </div>

                <div className="p-3 bg-neutral-50 rounded-2xl border border-neutral-100 text-xs text-neutral-500 leading-relaxed font-cairo">
                  ⚠️ {t.tracking_desc}
                </div>

                <button
                  onClick={() => setTrackOrderActive(null)}
                  className="w-full py-3.5 bg-neutral-900 hover:bg-neutral-850 text-white font-bold text-xs rounded-xl font-cairo"
                >
                  {t.close}
                </button>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ======================================= */}
        {/* MODAL 2: RESTAURANT TABLE BOOKING FORM */}
        {/* ======================================= */}
        <AnimatePresence>
          {bookTableItem && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end justify-center font-sans"
            >
              <motion.div
                initial={{ y: 300 }}
                animate={{ y: 0 }}
                exit={{ y: 300 }}
                className="bg-white w-full rounded-t-[32px] p-6 space-y-4 shadow-2xl overflow-y-auto max-h-[90%] pb-safe"
              >
                <div className="flex justify-between items-center pb-3 border-b border-neutral-50">
                  <h3 className="text-md font-black text-neutral-800 font-cairo">
                    {lang === 'ar' ? `حجز طاولة في ${bookTableItem.nameAr}` : `Book Table at ${bookTableItem.nameEn}`}
                  </h3>
                  <button
                    onClick={() => setBookTableItem(null)}
                    className="w-8 h-8 rounded-full bg-neutral-100 flex items-center justify-center hover:bg-neutral-200"
                  >
                    <span className="material-symbols-outlined text-xs">close</span>
                  </button>
                </div>

                <div className="space-y-3 text-xs">
                  <div>
                    <label className="font-bold text-neutral-600 block mb-1 font-cairo">تاريخ الحفل والعشاء</label>
                    <input
                      type="date"
                      value={bookTableDate}
                      onChange={(e) => setBookTableDate(e.target.value)}
                      className="w-full p-2.5 bg-neutral-50 border border-neutral-200 rounded-xl"
                    />
                  </div>

                  <div>
                    <label className="font-bold text-neutral-600 block mb-1 font-cairo">الساعة والموعد</label>
                    <input
                      type="time"
                      value={bookTableTime}
                      onChange={(e) => setBookTableTime(e.target.value)}
                      className="w-full p-2.5 bg-neutral-50 border border-neutral-200 rounded-xl font-mono"
                    />
                  </div>

                  <div>
                    <label className="font-bold text-neutral-600 block mb-1 font-cairo">عدد المدعوين</label>
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => setBookTableGuests(Math.max(1, bookTableGuests - 1))}
                        className="w-8 h-8 bg-neutral-100 rounded-full flex items-center justify-center font-bold text-neutral-800"
                      >
                        -
                      </button>
                      <span className="font-black text-sm">{bookTableGuests}</span>
                      <button
                        onClick={() => setBookTableGuests(bookTableGuests + 1)}
                        className="w-8 h-8 bg-neutral-100 rounded-full flex items-center justify-center font-bold text-neutral-800"
                      >
                        +
                      </button>
                    </div>
                  </div>

                  <div className="p-3 bg-emerald-50 text-emerald-800 border border-emerald-100 rounded-xl font-cairo">
                    ✓ {lang === 'ar' ? 'رسوم حجز الطاولات مجاني بالكامل! كاش فقط.' : 'Our reservation service is 100% free! Play for diners at place.'}
                  </div>
                </div>

                <div className="flex gap-2 pt-2">
                  <button
                    onClick={() => setBookTableItem(null)}
                    className="flex-1 py-3 bg-neutral-100 text-neutral-600 rounded-xl font-bold font-cairo text-xs"
                  >
                    {lang === 'ar' ? 'إلغاء' : 'Cancel'}
                  </button>
                  <button
                    onClick={handleConfirmTableBooking}
                    className="flex-1 py-3 bg-orange-600 text-white rounded-xl font-black text-xs active:scale-[0.98] font-cairo"
                  >
                    {lang === 'ar' ? 'تأكيد الحجز المجاني' : 'Confirm Free Booking'}
                  </button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ======================================= */}
        {/* MODAL 3: CHECKOUT ORDER SUCCESS STATUS */}
        {/* ======================================= */}
        <AnimatePresence>
          {checkoutSuccess && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-55 bg-black/60 backdrop-blur-sm flex items-center justify-center p-6 font-sans"
            >
              <motion.div
                initial={{ scale: 0.9, y: 50 }}
                animate={{ scale: 1, y: 0 }}
                exit={{ scale: 0.9, y: 50 }}
                className="bg-white rounded-[32px] p-6 text-center max-w-sm w-full space-y-4 shadow-2xl border border-neutral-100"
              >
                <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto text-3xl font-bold">
                  ✓
                </div>

                <div>
                  <h3 className="text-lg font-black text-neutral-800 font-cairo">{t.checkout_success}</h3>
                  <p className="text-xs text-neutral-500 mt-2 leading-relaxed font-cairo">
                    {t.checkout_success_subtitle}
                  </p>
                </div>

                <div className="bg-orange-50 p-4 rounded-2xl border border-orange-100 text-left text-xs text-orange-950/80 font-mono space-y-1">
                  <div className="flex justify-between">
                    <span className="font-cairo font-bold">طريقة الاستلام:</span>
                    <span className="font-cairo font-semibold">توصيل كاش للدراجة</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="font-cairo font-bold">طريقة السداد:</span>
                    <span className="font-cairo font-bold text-orange-600">نقداً عند الاستلام</span>
                  </div>
                </div>

                <button
                  onClick={() => {
                    setCheckoutSuccess(false);
                    setCurrentTab('orders');
                    setActiveSegmentedOrderTab('active');
                  }}
                  className="w-full py-3.5 bg-orange-600 hover:bg-orange-500 text-white text-xs font-black rounded-xl active:scale-95 transition-all font-cairo shadow-lg shadow-orange-100"
                >
                  {lang === 'ar' ? 'متابعة الطلب وتتبعه 📦' : 'Track Order Status 📦'}
                </button>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ======================================= */}
        {/* MODAL 4: CONTACT US / REAL ESTATE DETAILS */}
        {/* ======================================= */}
        <AnimatePresence>
          {contactItem && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end justify-center font-sans"
            >
              <motion.div
                initial={{ y: 300 }}
                animate={{ y: 0 }}
                exit={{ y: 300 }}
                className="bg-white w-full rounded-t-[32px] p-6 space-y-4 shadow-2xl max-h-[90%] pb-safe"
              >
                <div className="flex justify-between items-center pb-3 border-b border-neutral-50">
                  <h3 className="text-md font-black text-neutral-800 font-cairo">
                    {lang === 'ar' ? `تواصل للاستفسار عن ${contactItem.nameAr}` : `Inquiry for ${contactItem.nameEn}`}
                  </h3>
                  <button
                    onClick={() => setContactItem(null)}
                    className="w-8 h-8 rounded-full bg-neutral-100 flex items-center justify-center"
                  >
                    <span className="material-symbols-outlined text-xs">close</span>
                  </button>
                </div>

                <div className="text-center p-4 bg-orange-50 border border-orange-100 rounded-2xl">
                  <p className="text-xs text-neutral-500 font-cairo">سعر العقار التقريبي</p>
                  <span className="text-2xl font-black text-orange-600 font-mono">{contactItem.price.toLocaleString()} د.ع</span>
                </div>

                <div className="space-y-3">
                  <p className="text-xs text-neutral-500 font-cairo">
                    {lang === 'ar' 
                      ? 'اختر وسيلة للتواصل المباشر المجاني مع مستشار عقارات الغيث لتأكيد تفاصيل العقار والزيارة الحية.' 
                      : 'Please choose below to connect with our official Al-Ghaith property consultant.'}
                  </p>

                  <div className="grid grid-cols-2 gap-3 pt-2">
                    <button
                      onClick={() => {
                        showToastMsg(lang === 'ar' ? 'اتصال بالرقم 07700000000...' : 'Dialing official line...');
                        setContactItem(null);
                      }}
                      className="py-3 px-4 bg-orange-600 text-white rounded-xl font-bold text-xs flex items-center justify-center gap-2 active:scale-95 font-cairo"
                    >
                      <span className="material-symbols-outlined text-sm">phone</span>
                      <span>{lang === 'ar' ? 'اتصال كاش' : 'Call'}</span>
                    </button>
                    
                    <button
                      onClick={() => {
                        showToastMsg(lang === 'ar' ? 'فتح محادثة واتساب الرسمية...' : 'Opening WhatsApp conversation...');
                        setContactItem(null);
                      }}
                      className="py-3 px-4 bg-emerald-600 text-white rounded-xl font-bold text-xs flex items-center justify-center gap-2 active:scale-95 font-cairo"
                    >
                      <span className="material-symbols-outlined text-sm">chat_bubble</span>
                      <span>واتساب الغيث</span>
                    </button>
                  </div>
                </div>

                <button
                  onClick={() => setContactItem(null)}
                  className="w-full py-3 bg-neutral-100 text-neutral-600 text-xs font-bold rounded-xl font-cairo"
                >
                  {t.close}
                </button>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

      </div>

      {/* Side explanation info panel for Desktop Screen users to understand the build context */}
      <div className="hidden md:flex flex-col max-w-md w-full mt-6 bg-slate-900 border border-slate-800 text-neutral-300 p-6 rounded-3xl text-sm leading-relaxed shadow-xl space-y-4">
        <h4 className="font-extrabold text-white text-base font-cairo flex items-center gap-2">
          <span className="material-symbols-outlined text-orange-500">smartphone</span>
          <span>دليل نظام تجربة الغيث iOS / Android</span>
        </h4>
        <p className="text-xs text-neutral-400 font-cairo leading-relaxed">
          لقد قمنا ببناء محاكي تطبيق متكامل يعتمد على تصميم **Flutter** المعياري ويدعم اللغتين العربية والإنجليزية بذكاء. جميع العمليات تفاعلية وتتم بصورة فورية:
        </p>
        <ul className="text-xs text-neutral-400 font-cairo list-disc pl-5 space-y-1">
          <li><strong>أمان كامل:</strong> التطبيق مهيأ حصرياً لنموذج <strong>(الدفع نقداً عند الاستلام)</strong> ولا توجد أي عمليات دفع الكتروني (لا توجد عمليات شراء داخل التطبيق) تلبيةً لرغبتك الدقيقة.</li>
          <li><strong>اكواد الخصم:</strong> أدخل كود الخصم الفعال <b>GHAITH20</b> لخصم 20% مباشرة في سلة المشتريات.</li>
          <li><strong>قاعدة بيانات محلية:</strong> سيتم تذكر المنتجات المختارة في السلة، والمفضلات والطلبات حتى بعد إعادة تحميل الصفحة.</li>
          <li><strong>تحكم كامل باللغات:</strong> يمكنك تغيير لغة التطبيق في أي وقت من شاشة حسابي.</li>
        </ul>
        <div className="p-3 rounded-2xl bg-slate-850 border border-slate-800 text-center text-[10px] text-amber-500 font-semibold font-mono">
          Vite • React • Tailwind • Framer Motion
        </div>
      </div>
    </div>
  );
}
