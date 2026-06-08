export interface AdminSession {
  token: string;
  phoneNumber: string;
}

export interface AdminReports {
  totalOrders: number;
  completedOrders: number;
  pendingOrders: number;
  deliveringOrders: number;
  totalSales: number;
  codCollected: number;
  totalMerchants: number;
  openMerchants: number;
  totalProducts: number;
  totalUsers: number;
  recentOrders: AdminRecentOrder[];
}

export interface AdminRecentOrder {
  id: string;
  orderNumber: string;
  statusKey: string;
  statusAr: string;
  price: number;
  merchantStoreName: string;
  customerNameAr: string;
  deliveryStatusKey: string;
  updatedAt: string | null;
}

export interface MerchantSummary {
  phone: string;
  storeName: string;
  description: string;
  primaryServiceId: string;
  isOpen: boolean;
  isFrozen: boolean;
  rating: number;
  isBazaarMember: boolean;
  createdAt: string | null;
  fullName: string;
  role: string;
  totalOrders: number;
  completedOrders: number;
  pendingOrders: number;
  deliveringOrders: number;
  totalRevenue: number;
  lastOrderAt: string | null;
}

export interface MerchantDetails {
  merchant: {
    phone: string;
    storeName: string;
    description: string;
    primaryServiceId: string;
    serviceIds: string[];
    isOpen: boolean;
    isFrozen: boolean;
    isBazaarMember: boolean;
    rating: number;
    address: string;
    deliveryFee: number;
    createdAt: string | null;
    updatedAt: string | null;
    fullName: string;
    role: string;
  };
  stats: {
    totalOrders: number;
    completedOrders: number;
    pendingOrders: number;
    deliveringOrders: number;
    cancelledOrders: number;
    totalRevenue: number;
    codCollected: number;
    averageOrderValue: number;
    totalProducts: number;
  };
  recentOrders: MerchantOrder[];
  products: MerchantProduct[];
}

export interface MerchantOrder {
  id: string;
  orderNumber: string;
  statusKey: string;
  statusAr: string;
  statusEn: string;
  deliveryStatusKey: string;
  deliveryStatusAr: string;
  deliveryStatusEn: string;
  price: number;
  customerName: string;
  customerPhone: string;
  itemCount: number;
  updatedAt: string | null;
  createdAt: string | null;
}

export interface MerchantProduct {
  id: string;
  name: string;
  category: string;
  subCategory: string;
  price: number;
  isAvailable: boolean;
  createdAt: string | null;
}
