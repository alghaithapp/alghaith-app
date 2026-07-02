import { PendingProductsPage } from './PendingProductsPage';
import { PendingOperatorsPage } from './PendingOperatorsPage';
import { ProfessionalsListPage } from '../professionals/ProfessionalsListPage';
import { PendingAccountsPage } from './PendingAccountsPage';

export function PendingCatalogProductsPage() {
  return (
    <PendingProductsPage
      title="منتجات وإعلانات بانتظار الموافقة"
      excludeCategories={['real_estate', 'cars', 'used']}
      emptyHint="لا توجد منتجات أو إعلانات معلقة حالياً."
    />
  );
}

export function PendingRealEstatePage() {
  return (
    <PendingProductsPage
      title="عقارات بانتظار الموافقة"
      categoryFilter="real_estate"
      emptyHint="لا توجد عقارات معلقة حالياً."
    />
  );
}

export function PendingCarsPage() {
  return (
    <PendingProductsPage
      title="إعلانات السيارات المعلقة"
      categoryFilter="cars"
      emptyHint="لا توجد إعلانات سيارات معلقة حالياً."
    />
  );
}

export function PendingUsedPage() {
  return (
    <PendingProductsPage
      title="منتجات مستعملة معلقة"
      categoryFilter="used"
      emptyHint="لا توجد منتجات مستعملة معلقة حالياً."
    />
  );
}

export function PendingTourismAccountsPage() {
  return (
    <PendingAccountsPage
      title="حسابات السياحة المعلقة"
      serviceFilter="tourism"
      emptyHint="لا توجد حسابات سياحة معلقة حالياً."
    />
  );
}

export function ModerationProfessionalsPage() {
  return (
    <ProfessionalsListPage
      title="مهنيين بانتظار الموافقة"
      pendingOnly
      emptyHint="لا يوجد مهنيون بانتظار الموافقة حالياً."
    />
  );
}

export function PendingDriversPage() {
  return (
    <PendingOperatorsPage
      kind="driver"
      title="سائقو التكسي بانتظار الموافقة"
      emptyHint="لا يوجد سائقون معلقون حالياً."
    />
  );
}

export function PendingCouriersPage() {
  return (
    <PendingOperatorsPage
      kind="courier"
      title="مندوبو التوصيل بانتظار الموافقة"
      emptyHint="لا يوجد مندوبون معلقون حالياً."
    />
  );
}
