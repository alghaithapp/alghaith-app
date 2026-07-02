import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { loadPendingProducts, toggleProductApproval } from '../../../admin-api';
import type { PendingProductSummary } from '../../../admin-types';
import { useAdminToken, useAuth } from '../../context/AuthContext';
import { PRODUCT_CATEGORY_LABELS } from './constants';

type Props = {
  title: string;
  categoryFilter?: string;
  excludeCategory?: string;
  excludeCategories?: string[];
  emptyHint: string;
};

export function PendingProductsPage({
  title,
  categoryFilter,
  excludeCategory,
  excludeCategories,
  emptyHint,
}: Props) {
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [rejectReason, setRejectReason] = useState<Record<string, string>>({});

  const { data = [], isLoading } = useQuery({
    queryKey: ['pending-products', categoryFilter ?? 'all'],
    queryFn: () => loadPendingProducts(token, categoryFilter),
    refetchOnMount: 'always',
  });

  const approveMut = useMutation({
    mutationFn: ({
      merchantPhone,
      productId,
      isApproved,
      rejectionMessageAr,
    }: {
      merchantPhone: string;
      productId: string;
      isApproved: boolean;
      rejectionMessageAr?: string;
    }) => toggleProductApproval(token, merchantPhone, productId, isApproved, rejectionMessageAr),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['pending-products'] });
    },
  });

  const filtered = useMemo(() => {
    let base = data;
    const excluded = new Set([
      ...(excludeCategories ?? []),
      ...(excludeCategory ? [excludeCategory] : []),
    ]);
    if (excluded.size > 0) {
      base = base.filter((item) => !excluded.has(item.category));
    }
    const hay = q.trim().toLowerCase();
    if (!hay) return base;
    return base.filter((item) => {
      const name = String(item.name_ar ?? item.nameAr ?? '').toLowerCase();
      const store = String(item.merchantStoreName ?? '').toLowerCase();
      const phone = String(item.merchantPhone ?? '').toLowerCase();
      return `${name} ${store} ${phone}`.includes(hay);
    });
  }, [data, q, excludeCategory, excludeCategories]);

  return (
    <div>
      <div className="adm-page-header">
        <h2 style={{ margin: 0 }}>{title}</h2>
        <span className="adm-badge adm-badge-warning">{filtered.length} معلق</span>
      </div>

      <div className="adm-card" style={{ marginBottom: 16 }}>
        <input
          className="adm-input"
          placeholder="بحث بالاسم أو المتجر أو الهاتف..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {isLoading ? (
        <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>
      ) : filtered.length === 0 ? (
        <div className="adm-card">
          <p style={{ margin: 0, color: 'var(--adm-muted)' }}>{emptyHint}</p>
        </div>
      ) : (
        <div className="adm-table-wrap">
          <table className="adm-table">
            <thead>
              <tr>
                <th>المحتوى</th>
                <th>التاجر</th>
                <th>القسم</th>
                <th>السعر</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((item) => (
                <PendingProductRow
                  key={item.id}
                  item={item}
                  canApprove={hasPermission('canApprove')}
                  rejectReason={rejectReason[item.id] ?? ''}
                  onRejectReasonChange={(value) =>
                    setRejectReason((prev) => ({ ...prev, [item.id]: value }))
                  }
                  onApprove={() =>
                    approveMut.mutate({
                      merchantPhone: item.merchantPhone,
                      productId: item.id,
                      isApproved: true,
                    })
                  }
                  onReject={() =>
                    approveMut.mutate({
                      merchantPhone: item.merchantPhone,
                      productId: item.id,
                      isApproved: false,
                      rejectionMessageAr:
                        rejectReason[item.id]?.trim() || 'تم رفض المحتوى من الإدارة.',
                    })
                  }
                  busy={approveMut.isPending}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function PendingProductRow({
  item,
  canApprove,
  rejectReason,
  onRejectReasonChange,
  onApprove,
  onReject,
  busy,
}: {
  item: PendingProductSummary;
  canApprove: boolean;
  rejectReason: string;
  onRejectReasonChange: (value: string) => void;
  onApprove: () => void;
  onReject: () => void;
  busy: boolean;
}) {
  const name = item.name_ar ?? item.nameAr ?? '—';
  const image = item.image_url ?? item.image;
  const categoryLabel = PRODUCT_CATEGORY_LABELS[item.category] ?? item.category;

  return (
    <tr>
      <td>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {image ? (
            <img src={image} alt="" className="adm-avatar" />
          ) : (
            <div className="adm-avatar adm-avatar-empty">—</div>
          )}
          <div>
            <div>{name}</div>
            {(item.description_ar ?? item.descriptionAr) && (
              <div style={{ fontSize: '0.8rem', color: 'var(--adm-muted)' }}>
                {String(item.description_ar ?? item.descriptionAr).slice(0, 80)}
              </div>
            )}
            {(item.sub_category ?? item.subCategory) && (
              <div style={{ fontSize: '0.75rem', color: 'var(--adm-muted)' }}>
                القسم: {item.sub_category ?? item.subCategory}
              </div>
            )}
          </div>
        </div>
      </td>
      <td>
        <div>{item.merchantStoreName || '—'}</div>
        <div dir="ltr" style={{ fontSize: '0.8rem', color: 'var(--adm-muted)' }}>
          {item.merchantPhone}
        </div>
        <Link
          to={`/admin/merchants/${encodeURIComponent(item.merchantPhone)}`}
          style={{ fontSize: '0.8rem' }}
        >
          عرض التاجر
        </Link>
      </td>
      <td>{categoryLabel}</td>
      <td>{item.price > 0 ? `${item.price.toLocaleString('ar-IQ')} د.ع` : '—'}</td>
      <td>
        {canApprove ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, minWidth: 180 }}>
            <button type="button" className="adm-btn adm-btn-primary" onClick={onApprove} disabled={busy}>
              موافقة
            </button>
            <input
              className="adm-input"
              placeholder="سبب الرفض (اختياري)"
              value={rejectReason}
              onChange={(e) => onRejectReasonChange(e.target.value)}
            />
            <button type="button" className="adm-btn adm-btn-danger" onClick={onReject} disabled={busy}>
              رفض
            </button>
          </div>
        ) : (
          <span className="adm-badge adm-badge-muted">لا صلاحية</span>
        )}
      </td>
    </tr>
  );
}
