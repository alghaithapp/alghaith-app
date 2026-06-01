export interface ListItem {
  id: string;
  nameAr: string;
  nameEn: string;
  descriptionAr: string;
  descriptionEn: string;
  price: number;
  rating?: number;
  category: 'restaurant' | 'product' | 'real_estate' | 'service';
  categoryLabelAr: string;
  categoryLabelEn: string;
  image: string;
  isFavorite: boolean;
  // Specific properties
  avgPriceLabelAr?: string;
  avgPriceLabelEn?: string;
  actionLabelAr: string;
  actionLabelEn: string;
  bedrooms?: number;
  bathrooms?: number;
  areaSquareMeter?: number;
}

export interface CartItem {
  id: string;
  nameAr: string;
  nameEn: string;
  price: number;
  count: number;
  image: string;
  optionAr?: string;
  optionEn?: string;
}

export interface ActiveOrder {
  id: string;
  orderNumber: string;
  dateAr: string;
  dateEn: string;
  statusKey: 'delivering' | 'cooking' | 'processing';
  statusAr: string;
  statusEn: string;
  price: number;
  itemsCount: number;
  itemsNameAr: string;
  itemsNameEn: string;
  image?: string;
  iconName?: string;
}

export interface AppNotification {
  id: string;
  titleAr: string;
  titleEn: string;
  bodyAr: string;
  bodyEn: string;
  timeAr: string;
  timeEn: string;
  iconName: string;
  read: boolean;
  type: 'order' | 'promo' | 'delivered' | 'maintenance';
}

export interface ServiceCategory {
  id: string;
  titleAr: string;
  titleEn: string;
  image: string;
}
