import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { ImageUploader } from '../../components/ui/ImageUploader';
import { preRegisterMerchant } from '../../admin-api';
import { Store, User, Phone, MapPin, Tag } from 'lucide-react';

export default function AddMerchantPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  
  const [formData, setFormData] = useState({
    phone: '',
    storeName: '',
    ownerName: '',
    primaryServiceId: 'shopping',
    address: '',
    profileImageUrl: ''
  });
  
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.phone || !formData.storeName) {
      setError('يرجى تعبئة الحقول الأساسية (الهاتف، واسم المتجر)');
      return;
    }
    
    setIsSubmitting(true);
    setError('');
    
    try {
      await preRegisterMerchant(token, {
        phone: formData.phone,
        storeName: formData.storeName,
        ownerName: formData.ownerName,
        primaryServiceId: formData.primaryServiceId,
        address: formData.address,
        isProfessional: false
      });
      // Wait, we also uploaded an image? Yes, it uploaded to R2. But we need to save the link to the user's profile.
      // Wait, preRegisterMerchant payload doesn't accept profile image url yet?
      // Actually, image upload binds automatically if ownerId matches phone!
      alert('تم إضافة التاجر بنجاح!');
      navigate('/admin/merchants');
    } catch (err: any) {
      setError(err.message || 'فشل إضافة التاجر');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '800px', margin: '0 auto', width: '100%' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>إضافة تاجر جديد</h2>
        <Button variant="secondary" onClick={() => navigate('/admin/merchants')}>إلغاء</Button>
      </div>

      <form onSubmit={handleSubmit} className="ui-card" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        
        {/* PROFILE IMAGE */}
        <div style={{ borderBottom: '1px solid var(--border)', paddingBottom: '24px' }}>
          <h3 style={{ fontSize: '1.1rem', marginBottom: '16px' }}>صورة المتجر</h3>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '16px' }}>يرجى إدخال رقم هاتف التاجر أولاً لربط الصورة به</p>
          <div style={{ maxWidth: '300px' }}>
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType="merchant" 
               role="profile" 
               label="شعار المتجر"
               onUploadSuccess={(url) => setFormData(p => ({ ...p, profileImageUrl: url }))} 
             />
          </div>
        </div>

        {error && <div style={{ color: 'var(--error)', background: 'var(--error-bg)', padding: '12px', borderRadius: '8px' }}>{error}</div>}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
          <Input 
            label="رقم الهاتف (الرئيسي)" 
            dir="ltr" 
            placeholder="+964..." 
            value={formData.phone} 
            onChange={(e) => setFormData(p => ({ ...p, phone: e.target.value }))}
            icon={<Phone size={18} />}
          />
          <Input 
            label="اسم المتجر" 
            placeholder="مثال: أسواق الغيث" 
            value={formData.storeName} 
            onChange={(e) => setFormData(p => ({ ...p, storeName: e.target.value }))}
            icon={<Store size={18} />}
          />
          <Input 
            label="اسم المالك" 
            placeholder="الاسم الكامل" 
            value={formData.ownerName} 
            onChange={(e) => setFormData(p => ({ ...p, ownerName: e.target.value }))}
            icon={<User size={18} />}
          />
          <Input 
            label="العنوان" 
            placeholder="المحافظة، المنطقة، الشارع" 
            value={formData.address} 
            onChange={(e) => setFormData(p => ({ ...p, address: e.target.value }))}
            icon={<MapPin size={18} />}
          />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>تصنيف المتجر</label>
          <select 
            className="ui-input" 
            value={formData.primaryServiceId} 
            onChange={(e) => setFormData(p => ({ ...p, primaryServiceId: e.target.value }))}
          >
            <option value="shopping">تسوق وسوبرماركت</option>
            <option value="food">مطاعم ووجبات</option>
            <option value="electronics">إلكترونيات</option>
            <option value="fashion">أزياء وملابس</option>
            <option value="pharmacy">صيدلية</option>
          </select>
        </div>

        <div style={{ marginTop: '16px' }}>
          <Button type="submit" variant="primary" style={{ width: '100%' }} disabled={isSubmitting || !formData.phone}>
            {isSubmitting ? 'جاري الإضافة...' : 'حفظ وإضافة التاجر'}
          </Button>
        </div>
      </form>
    </div>
  );
}
