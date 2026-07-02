import type { CourierSummary, DriverSummary, OperatorDocuments } from '../../../admin-types';
import { AdminAvatar } from '../../components/AdminAvatar';

export type OperatorKind = 'driver' | 'courier';
export type OperatorFilter = 'all' | 'pending' | 'approved' | 'rejected' | 'suspended';

export function operatorAvatarUrl(row: DriverSummary | CourierSummary) {
  const docs = row.documents;
  return (
    docs?.profileImage ||
    docs?.vehicleImage ||
    docs?.carImage ||
    ('vehicleImage' in row ? row.vehicleImage : '') ||
    ('carImage' in row ? row.carImage : '') ||
    ''
  ).trim();
}

export function taxiTypeLabel(value?: string | null) {
  switch (String(value || '').trim()) {
    case 'tuktuk':
      return 'تكتك';
    case 'wazz':
      return 'واز';
    case 'economic':
      return 'تكسي اقتصادي';
    default:
      return value || '—';
  }
}

export function ApprovalStatusBadge({
  row,
}: {
  row: { isApproved: boolean; approvalStatus: string; isSuspended: boolean };
}) {
  if (row.isSuspended) {
    return <span className="adm-badge adm-badge-danger">موقوف</span>;
  }
  if (row.isApproved || row.approvalStatus === 'approved') {
    return <span className="adm-badge adm-badge-success">معتمد</span>;
  }
  if (row.approvalStatus === 'rejected') {
    return <span className="adm-badge adm-badge-danger">مرفوض</span>;
  }
  return <span className="adm-badge adm-badge-warning">معلق</span>;
}

export function OperatorAvatar({ row }: { row: DriverSummary | CourierSummary }) {
  return <AdminAvatar src={operatorAvatarUrl(row)} alt={row.name || row.phone} />;
}

export function operatorDocumentItems(
  kind: OperatorKind,
  row: DriverSummary | CourierSummary,
): Array<{ label: string; url?: string }> {
  const docs: OperatorDocuments = {
    ...(row.documents || {}),
  };
  if (kind === 'driver') {
    const driver = row as DriverSummary;
    if (!docs.carImage && driver.carImage) docs.carImage = driver.carImage;
    if (!docs.vehicleImage && driver.carImage) docs.vehicleImage = driver.carImage;
  } else {
    const courier = row as CourierSummary;
    if (!docs.vehicleImage && courier.vehicleImage) docs.vehicleImage = courier.vehicleImage;
  }

  return [
    { label: 'صورة شخصية', url: docs.profileImage },
    { label: kind === 'driver' ? 'صورة السيارة' : 'صورة الدراجة', url: docs.carImage || docs.vehicleImage },
    { label: 'هوية (الوجه)', url: docs.idFrontImage },
    { label: 'هوية (الظهر)', url: docs.idBackImage },
    { label: 'بطاقة السكن', url: docs.residenceCardImage },
    { label: 'سنوية السيارة (الوجه)', url: docs.vehicleRegFrontImage },
    { label: 'سنوية السيارة (الظهر)', url: docs.vehicleRegBackImage },
  ];
}

export function matchesOperatorFilter(
  row: { approvalStatus: string; isApproved: boolean; isSuspended: boolean },
  filter: OperatorFilter,
) {
  if (filter === 'all') return true;
  if (filter === 'suspended') return row.isSuspended;
  if (filter === 'approved') return row.isApproved || row.approvalStatus === 'approved';
  if (filter === 'rejected') return row.approvalStatus === 'rejected';
  return row.approvalStatus === 'pending' || (!row.isApproved && row.approvalStatus !== 'rejected');
}
