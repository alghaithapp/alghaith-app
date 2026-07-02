import React from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { deleteAdminAccount, toggleMerchantFreeze } from '../../admin-api';
import { useAdminToken, useAuth } from '../context/AuthContext';

type Props = {
  phone: string;
  label: string;
  isFrozen?: boolean;
  invalidateKeys?: string[];
};

export function MerchantQuickActions({
  phone,
  label,
  isFrozen = false,
  invalidateKeys = ['merchants', 'professionals'],
}: Props) {
  const token = useAdminToken();
  const { hasPermission, role } = useAuth();
  const qc = useQueryClient();

  const canHide =
    hasPermission('canApprove') ||
    hasPermission('canSuspend') ||
    role === 'admin' ||
    role === 'super_admin' ||
    role === 'moderator';
  const canDeleteMerchant = hasPermission('canDelete');

  const invalidate = () => {
    for (const key of invalidateKeys) {
      qc.invalidateQueries({ queryKey: [key] });
    }
  };

  const freezeMut = useMutation({
    mutationFn: (frozen: boolean) => toggleMerchantFreeze(token, phone, frozen),
    onSuccess: invalidate,
  });

  const deleteMut = useMutation({
    mutationFn: () => deleteAdminAccount(token, phone),
    onSuccess: invalidate,
  });

  if (!canHide && !canDeleteMerchant) {
    return <span style={{ color: 'var(--adm-muted)', fontSize: 12 }}>—</span>;
  }

  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      {canHide && (
        <button
          type="button"
          className="adm-btn adm-btn-secondary"
          style={{ padding: '4px 10px', fontSize: 12 }}
          disabled={freezeMut.isPending}
          onClick={() => {
            const action = isFrozen ? 'إظهار' : 'إخفاء';
            if (!window.confirm(`${action} ${label} للمستخدمين؟`)) return;
            freezeMut.mutate(!isFrozen);
          }}
        >
          {isFrozen ? 'إظهار' : 'إخفاء'}
        </button>
      )}
      {canDeleteMerchant && (
        <button
          type="button"
          className="adm-btn adm-btn-danger"
          style={{ padding: '4px 10px', fontSize: 12 }}
          disabled={deleteMut.isPending}
          onClick={() => {
            if (!window.confirm(`حذف ${label} نهائياً؟ لا يمكن التراجع.`)) return;
            deleteMut.mutate();
          }}
        >
          حذف
        </button>
      )}
    </div>
  );
}
