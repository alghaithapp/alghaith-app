import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAccounts } from '../../hooks/useAdminData';
import { suspendAdminAccount } from '../../admin-api';
import { LoaderCircle, Car, X, UserX } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { Badge } from '../../components/ui/Badge';
import { ImageUploader } from '../../components/ui/ImageUploader';

export default function DriverDetailsPage() {
  const { phone } = useParams();
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';

  const { data: accounts = [], isLoading, refetch } = useAccounts(token);
  
  const driver = accounts.find((a: any) => a.phone === phone && a.kind === 'driver');

  const [isToggling, setIsToggling] = useState(false);

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  if (!driver) {
    return (
      <div style={{ padding: '32px', textAlign: 'center' }}>
        <h3>السائق غير موجود</h3>
        <Button variant="secondary" onClick={() => navigate('/admin/drivers')}>العودة</Button>
      </div>
    );
  }

  const handleSuspend = async () => {
    setIsToggling(true);
    try {
      await suspendAdminAccount(token, phone!, !driver.isSuspended);
      refetch();
    } catch (e) {
      alert('فشل تغيير حالة الإيقاف');
    } finally {
      setIsToggling(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '1000px', margin: '0 auto' }}>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
           <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
             <Car size={24} color="var(--brand-primary)" />
           </div>
           <div>
             <h2 style={{ margin: 0, display: 'flex', gap: '12px', alignItems: 'center' }}>
               {driver.displayName || driver.fullName || 'بدون اسم'}
               {driver.isSuspended ? <Badge variant="danger">موقوف</Badge> : <Badge variant="success">نشط</Badge>}
             </h2>
             <span style={{ color: 'var(--text-muted)' }} dir="ltr">{phone}</span>
           </div>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant={driver.isSuspended ? "secondary" : "danger"} onClick={handleSuspend} disabled={isToggling}>
            <UserX size={16} /> {driver.isSuspended ? 'فك الحظر' : 'حظر الحساب'}
          </Button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>تاريخ الانضمام</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>{driver.createdAt ? new Date(driver.createdAt).toLocaleDateString('ar-IQ') : 'غير متوفر'}</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>حالة الحساب</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>{driver.isSuspended ? 'موقوف (لا يمكنه الدخول)' : 'فعال ونشط'}</div>
        </div>
        <div className="ui-card" style={{ gridColumn: '1 / -1' }}>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>ملاحظة</div>
          <div>تفاصيل رحلات هذا السائق تظهر في قسم عمليات التاكسي.</div>
        </div>
      </div>

      {/* MEDIA SECTION */}
      <div className="ui-card padding-none" style={{ overflow: 'hidden' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid var(--border)' }}>
           <h3 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
             المستندات والصور
           </h3>
           <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '8px' }}>إدارة الصورة الشخصية وصور الهوية/الرخصة الخاصة بالسائق.</p>
           
           <div style={{ marginTop: '16px', display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="driver" 
                 role="profile" 
                 label="الصورة الشخصية"
                 onUploadSuccess={() => {}} 
               />
             </div>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="driver" 
                 role="license" 
                 label="صورة إجازة السوق / السنوية"
                 onUploadSuccess={() => {}} 
               />
             </div>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="driver" 
                 role="vehicle" 
                 label="صورة المركبة"
                 onUploadSuccess={() => {}} 
               />
             </div>
           </div>
        </div>
      </div>

    </div>
  );
}
