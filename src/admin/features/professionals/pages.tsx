import { ProfessionalsListPage } from './ProfessionalsListPage';

export function AllProfessionalsPage() {
  return (
    <ProfessionalsListPage
      title="كل المهنيين"
      emptyHint="لا يوجد مهنيون مسجلون بعد."
    />
  );
}

export function PendingProfessionalsPage() {
  return (
    <ProfessionalsListPage
      title="طلبات الموافقة"
      pendingOnly
      emptyHint="لا توجد طلبات بانتظار الموافقة حالياً."
    />
  );
}
