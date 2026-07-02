import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useCouriers } from '../../hooks/useAdminData';
import { toggleCourierApproval, suspendAdminAccount } from '../../admin-api';
import { LoaderCircle, Bike, Phone, X, Edit, UserX } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { Badge } from '../../components/ui/Badge';
import { ImageUploader } from '../../components/ui/ImageUploader';

export default function CourierDetailsPage() {
  const { phone } = useParams();
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';

  const { data: couriers = [], isLoading, refetch } = useCouriers(token);
  
  const courier = couriers.find((c: any) => c.phone === phone);

  const [isToggling, setIsToggling] = useState(false);

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  if (!courier) {
    return (
      <div style={{ padding: '32px', textAlign: 'center' }}>
        <h3>المندوب غير موجود</h3>
        <Button variant="secondary" onClick={() => navigate('/admin/couriers')}>العودة</Button>
      </div>
    );
  }

  const handleToggleApproval = async () => {
    setIsToggling(true);
    try {
      await toggleCourierApproval(token, phone!, !courier.isApproved);
      refetch();
    } catch (e) {
      alert('فشل تغيير حالة الموافقة');
    } finally {
      setIsToggling(false);
    }
  };

  const handleSuspend = async () => {
    if (!confirm('هل أنت متأكد من تغيير حالة الإيقاف للمستخدم؟')) return;
    try {
      await suspendAdminAccount(token, phone!, true);
      alert('تم تغيير حالة الإيقاف للحساب ككل.');
    } catch (e) {
      alert('فشل إيقاف الحساب');
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '1000px', margin: '0 auto' }}>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
           <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
             <Bike size={24} color="var(--brand-primary)" />
           </div>
           <div>
             <h2 style={{ margin: 0, display: 'flex', gap: '12px', alignItems: 'center' }}>
               {courier.name || 'بدون اسم'}
               {courier.isApproved ? <Badge variant="success">مفعّل</Badge> : <Badge variant="warning">غير مفعّل</Badge>}
             </h2>
             <span style={{ color: 'var(--text-muted)' }} dir="ltr">{phone}</span>
           </div>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant={courier.isApproved ? "secondary" : "primary"} onClick={handleToggleApproval} disabled={isToggling}>
            {courier.isApproved ? 'إلغاء التفعيل' : 'تفعيل المندوب'}
          </Button>
          <Button variant="danger" onClick={handleSuspend}><UserX size={16} /> حظر الحساب</Button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>الطلبات المكتملة</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{courier.completedOrders || 0}</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>التقييم</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{courier.rating?.toFixed(1) || '0.0'}</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>حالة التوفر</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>{courier.available ? 'متاح للتوصيل' : 'غير متاح'}</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>نوع المركبة</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>{courier.vehicleType || 'غير محدد'} ({courier.vehiclePlate || '-'})</div>
        </div>
      </div>

      {/* MEDIA SECTION */}
      <div className="ui-card padding-none" style={{ overflow: 'hidden' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid var(--border)' }}>
           <h3 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
             المستندات والصور
           </h3>
           <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '8px' }}>إدارة الصورة الشخصية وصور الهوية/الرخصة الخاصة بالمندوب.</p>
           
           <div style={{ marginTop: '16px', display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="courier" 
                 role="profile" 
                 label="الصورة الشخصية"
                 onUploadSuccess={() => {}} 
               />
             </div>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="courier" 
                 role="license" 
                 label="صورة الرخصة / الهوية"
                 onUploadSuccess={() => {}} 
               />
             </div>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType="courier" 
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
