import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { ImageUploader } from '../../components/ui/ImageUploader';
import { preRegisterDoctorPharmacy } from '../../admin-api';
import { User, Phone, MapPin, Stethoscope, Mail } from 'lucide-react';

export default function AddDoctorPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  
  const [formData, setFormData] = useState({
    phone: '',
    name: '',
    specialty: '',
    address: '',
    type: 'doctor', // doctor | pharmacy
    email: '',
  });
  
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.phone || !formData.name) {
      setError('يرجى تعبئة الحقول الأساسية');
      return;
    }
    
    setIsSubmitting(true);
    setError('');
    
    try {
      await preRegisterDoctorPharmacy(token, {
        phone: formData.phone,
        fullName: formData.name,
        specialty: formData.specialty,
        clinicAddress: formData.address,
        isPharmacy: formData.type === 'pharmacy'
      });
      alert('تمت الإضافة بنجاح!');
      navigate('/admin/merchants');
    } catch (err: any) {
      setError(err.message || 'فشل إضافة الطبيب/الصيدلية');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '800px', margin: '0 auto', width: '100%' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>إضافة طبيب / صيدلية</h2>
        <Button variant="secondary" onClick={() => navigate('/admin/merchants')}>إلغاء</Button>
      </div>

      <form onSubmit={handleSubmit} className="ui-card" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        
        {/* MEDIA SECTION */}
        <div style={{ borderBottom: '1px solid var(--border)', paddingBottom: '24px' }}>
          <h3 style={{ fontSize: '1.1rem', marginBottom: '16px' }}>الصور والوثائق</h3>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '16px' }}>يرجى إدخال رقم الهاتف أولاً ليتم ربط الصور بالحساب.</p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType={formData.type === 'pharmacy' ? 'pharmacy' : 'doctor'} 
               role="profile" 
               label="الصورة الشخصية / الشعار"
               onUploadSuccess={() => {}} 
             />
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType={formData.type === 'pharmacy' ? 'pharmacy' : 'doctor'} 
               role="clinic" 
               label="صورة العيادة / الصيدلية"
               onUploadSuccess={() => {}} 
             />
          </div>
        </div>

        {error && <div style={{ color: 'var(--error)', background: 'var(--error-bg)', padding: '12px', borderRadius: '8px' }}>{error}</div>}

        <div style={{ display: 'flex', gap: '16px', marginBottom: '8px' }}>
           <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input type="radio" name="type" checked={formData.type === 'doctor'} onChange={() => setFormData(p => ({ ...p, type: 'doctor'}))} />
              <span>طبيب / عيادة</span>
           </label>
           <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input type="radio" name="type" checked={formData.type === 'pharmacy'} onChange={() => setFormData(p => ({ ...p, type: 'pharmacy'}))} />
              <span>صيدلية</span>
           </label>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
          <Input 
            label="رقم الهاتف" 
            dir="ltr" 
            placeholder="+964..." 
            value={formData.phone} 
            onChange={(e) => setFormData(p => ({ ...p, phone: e.target.value }))}
            icon={<Phone size={18} />}
          />
          <Input 
            label="الاسم الكامل" 
            placeholder="د. محمد / صيدلية الشفاء" 
            value={formData.name} 
            onChange={(e) => setFormData(p => ({ ...p, name: e.target.value }))}
            icon={<User size={18} />}
          />
          <Input 
            label="التخصص" 
            placeholder="مثال: طبيب أسنان" 
            value={formData.specialty} 
            onChange={(e) => setFormData(p => ({ ...p, specialty: e.target.value }))}
            icon={<Stethoscope size={18} />}
          />
          <Input 
            label="العنوان" 
            placeholder="المنطقة، الشارع، المبنى" 
            value={formData.address} 
            onChange={(e) => setFormData(p => ({ ...p, address: e.target.value }))}
            icon={<MapPin size={18} />}
          />
        </div>

        <div style={{ marginTop: '16px' }}>
          <Button type="submit" variant="primary" style={{ width: '100%' }} disabled={isSubmitting || !formData.phone}>
            {isSubmitting ? 'جاري الإضافة...' : 'حفظ'}
          </Button>
        </div>
      </form>
    </div>
  );
}
