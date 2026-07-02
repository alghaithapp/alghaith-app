import React, { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  deleteAdminMerchantProduct,
  loadAdminMerchantProducts,
  loadMerchantDetails,
  toggleMerchantApproval,
  toggleMerchantFreeze,
} from '../../../admin-api';
import { useAdminToken, useAuth } from '../../context/AuthContext';
import { AdminAvatar, AdminMediaGallery, pickMerchantAvatarUrl } from '../../components/AdminAvatar';
import { formatPrimaryServiceLabel } from '../../utils/serviceLabels';

export function MerchantDetailPage() {
  const { phone = '' } = useParams();
  const merchantPhone = decodeURIComponent(phone);
  const token = useAdminToken();
  const { hasPermission } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [tab, setTab] = useState<'info' | 'products'>('info');

  const { data, isLoading, error } = useQuery({
    queryKey: ['merchant-details', merchantPhone],
    queryFn: () => loadMerchantDetails(token, merchantPhone),
    enabled: Boolean(merchantPhone),
  });

  const { data: products = [], refetch: refetchProducts, error: productsError, isLoading: productsLoading } = useQuery({
    queryKey: ['merchant-products', merchantPhone],
    queryFn: () => loadAdminMerchantProducts(token, merchantPhone),
    enabled: Boolean(merchantPhone) && tab === 'products',
  });

  const approveMut = useMutation({
    mutationFn: (approved: boolean) => toggleMerchantApproval(token, merchantPhone, approved),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['merchant-details', merchantPhone] }),
  });

  const freezeMut = useMutation({
    mutationFn: (frozen: boolean) => toggleMerchantFreeze(token, merchantPhone, frozen),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['merchant-details', merchantPhone] }),
  });

  const deleteProductMut = useMutation({
    mutationFn: (id: string) => deleteAdminMerchantProduct(token, merchantPhone, id),
    onSuccess: () => refetchProducts(),
  });

  if (isLoading) return <p style={{ color: 'var(--adm-muted)' }}>جاري التحميل...</p>;
  if (error || !data) return <p className="adm-error">{error instanceof Error ? error.message : 'غير موجود'}</p>;

  const m = data.merchant;
  const productRows = (products.length ? products : data.products) as Array<{
    id: string;
    name?: string;
    nameAr?: string;
    title?: string;
    price?: number;
    image?: string;
    imageUrl?: string;
    isAvailable?: boolean;
    available?: boolean;
  }>;

  const productLabel = (p: { name?: string; nameAr?: string; title?: string; id: string }) =>
    p.name || p.nameAr || p.title || p.id;

  return (
    <div>
      <div className="adm-page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <AdminAvatar
            src={pickMerchantAvatarUrl(m)}
            alt={m.storeName || m.fullName || merchantPhone}
            size="lg"
          />
          <h1 style={{ margin: 0 }}>{m.storeName || m.fullName || merchantPhone}</h1>
        </div>
        <button type="button" className="adm-btn adm-btn-secondary" onClick={() => navigate('/admin/merchants')}>
          رجوع
        </button>
      </div>

      <div className="adm-tabs">
        <button type="button" className={`adm-tab ${tab === 'info' ? 'active' : ''}`} onClick={() => setTab('info')}>
          المعلومات
        </button>
        <button type="button" className={`adm-tab ${tab === 'products' ? 'active' : ''}`} onClick={() => setTab('products')}>
          المنتجات ({data.stats?.totalProducts ?? productRows.length})
        </button>
      </div>

      {tab === 'info' && (
        <div className="adm-card">
          <h3 style={{ marginTop: 0 }}>الصور</h3>
          <AdminMediaGallery
            items={[
              { label: 'صورة البروفايل', url: m.profileImageUrl },
              { label: 'الشعار', url: m.logoImageUrl },
              { label: 'صورة الغلاف', url: m.coverImageUrl },
              { label: 'صورة العيادة / الواجهة', url: m.clinicImageUrl },
              ...(m.workSampleUrls || []).map((url, index) => ({
                label: `عمل سابق ${index + 1}`,
                url,
              })),
            ]}
          />
          <div className="adm-grid adm-grid-2" style={{ marginBottom: 20, marginTop: 24 }}>
            <div><span className="adm-stat-label">الهاتف</span><div dir="ltr">{m.phone}</div></div>
            <div><span className="adm-stat-label">القسم</span><div>{formatPrimaryServiceLabel(m.primaryServiceId)}</div></div>
            <div><span className="adm-stat-label">العنوان</span><div>{m.address || '—'}</div></div>
            <div><span className="adm-stat-label">التقييم</span><div>{m.rating}</div></div>
            <div>
              <span className="adm-stat-label">الموافقة</span>
              <div>{(m.isApproved ?? m.approvalStatus === 'approved') ? <span className="adm-badge adm-badge-success">معتمد</span> : <span className="adm-badge adm-badge-warning">معلق</span>}</div>
            </div>
            <div>
              <span className="adm-stat-label">التجميد</span>
              <div>{m.isFrozen ? <span className="adm-badge adm-badge-danger">مجمد</span> : <span className="adm-badge adm-badge-success">نشط</span>}</div>
            </div>
          </div>
          {hasPermission('canApprove') && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button type="button" className="adm-btn adm-btn-primary" onClick={() => approveMut.mutate(!(m.isApproved ?? m.approvalStatus === 'approved'))}>
                {(m.isApproved ?? m.approvalStatus === 'approved') ? 'إلغاء الموافقة' : 'موافقة'}
              </button>
              <button type="button" className="adm-btn adm-btn-secondary" onClick={() => freezeMut.mutate(!m.isFrozen)}>
                {m.isFrozen ? 'إلغاء التجميد' : 'تجميد المتجر'}
              </button>
            </div>
          )}
          {data.stats && (
            <div className="adm-grid adm-grid-3" style={{ marginTop: 24 }}>
              <div className="adm-card" style={{ padding: 12 }}>
                <div className="adm-stat-value">{data.stats.totalOrders}</div>
                <div className="adm-stat-label">الطلبات</div>
              </div>
              <div className="adm-card" style={{ padding: 12 }}>
                <div className="adm-stat-value">{data.stats.totalRevenue?.toLocaleString('ar-IQ')}</div>
                <div className="adm-stat-label">الإيراد (د.ع)</div>
              </div>
              <div className="adm-card" style={{ padding: 12 }}>
                <div className="adm-stat-value">{data.stats.totalProducts}</div>
                <div className="adm-stat-label">المنتجات</div>
              </div>
            </div>
          )}
        </div>
      )}

      {tab === 'products' && (
        <div className="adm-table-wrap">
          {productsLoading && <p style={{ padding: 16, color: 'var(--adm-muted)' }}>جاري تحميل المنتجات...</p>}
          {productsError && (
            <p className="adm-error" style={{ padding: 16 }}>
              {productsError instanceof Error ? productsError.message : 'تعذر تحميل المنتجات'}
            </p>
          )}
          <table className="adm-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>الاسم</th>
                <th>السعر</th>
                <th>متوفر</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {productRows.map((p) => (
                <tr key={p.id}>
                  <td>
                    {(p.image || p.imageUrl) && (
                      <img src={p.image || p.imageUrl} alt="" style={{ width: 48, height: 48, objectFit: 'cover', borderRadius: 8 }} />
                    )}
                  </td>
                  <td>{productLabel(p)}</td>
                  <td>{Number(p.price || 0).toLocaleString('ar-IQ')} د.ع</td>
                  <td>{(p.isAvailable ?? p.available) !== false ? 'نعم' : 'لا'}</td>
                  <td>
                    {hasPermission('canDelete') && (
                      <button
                        type="button"
                        className="adm-btn adm-btn-danger"
                        onClick={() => {
                          if (confirm('حذف هذا المنتج؟')) deleteProductMut.mutate(p.id);
                        }}
                      >
                        حذف
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!productRows.length && !productsLoading && (
            <p style={{ padding: 16, color: 'var(--adm-muted)' }}>لا توجد منتجات</p>
          )}
        </div>
      )}
    </div>
  );
}
