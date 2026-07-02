import { HealthBeautyMerchantsPage } from './HealthBeautyMerchantsPage';

export function PharmaciesListPage() {
  return (
    <HealthBeautyMerchantsPage
      title="الصيدليات"
      subCategoryId="صيدلية"
      registerPath="/admin/health-beauty/pharmacies/new"
      registerLabel="تسجيل صيدلية"
      emptyHint="لا توجد صيدليات مسجّلة بعد في قسم الصحة والجمال."
    />
  );
}

export function DoctorsListPage() {
  return (
    <HealthBeautyMerchantsPage
      title="الأطباء"
      subCategoryId="أطباء وعيادات"
      registerPath="/admin/health-beauty/doctors/new"
      registerLabel="تسجيل دكتور"
      emptyHint="لا يوجد أطباء أو عيادات مسجّلة بعد في قسم الصحة والجمال."
    />
  );
}
