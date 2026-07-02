import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { ImageUploader } from '../../components/ui/ImageUploader';
import { preRegisterProfessional } from '../../admin-api';
import { User, Phone, MapPin, Wrench } from 'lucide-react';

export default function AddProfessionalPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  
  const [formData, setFormData] = useState({
    phone: '',
    fullName: '',
    profession: '',
    experienceYears: '',
    address: '',
  });
  
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.phone || !formData.fullName) {
      setError('يرجى تعبئة الحقول الأساسية');
      return;
    }
    
    setIsSubmitting(true);
    setError('');
    
    try {
      await preRegisterProfessional(token, {
        phone: formData.phone,
        fullName: formData.fullName,
        profession: formData.profession,
        experienceYears: Number(formData.experienceYears) || 0,
        address: formData.address,
      });
      alert('تم إضافة المهني بنجاح!');
      navigate('/admin/merchants');
    } catch (err: any) {
      setError(err.message || 'فشل إضافة المهني');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '800px', margin: '0 auto', width: '100%' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>إضافة مهني (صنايعي)</h2>
        <Button variant="secondary" onClick={() => navigate('/admin/merchants')}>إلغاء</Button>
      </div>

      <form onSubmit={handleSubmit} className="ui-card" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        
        {/* MEDIA SECTION */}
        <div style={{ borderBottom: '1px solid var(--border)', paddingBottom: '24px' }}>
          <h3 style={{ fontSize: '1.1rem', marginBottom: '16px' }}>معرض الأعمال والصور</h3>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '16px' }}>الرجاء كتابة رقم الهاتف أولاً ليتم حفظ الصور له.</p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType="professional" 
               role="profile" 
               label="الصورة الشخصية"
               onUploadSuccess={() => {}} 
             />
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType="professional" 
               role="gallery" 
               label="صورة لعمل سابق 1"
               onUploadSuccess={() => {}} 
             />
             <ImageUploader 
               ownerId={formData.phone || 'temp'} 
               ownerType="professional" 
               role="gallery" 
               label="صورة لعمل سابق 2"
               onUploadSuccess={() => {}} 
             />
          </div>
        </div>

        {error && <div style={{ color: 'var(--error)', background: 'var(--error-bg)', padding: '12px', borderRadius: '8px' }}>{error}</div>}

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
            placeholder="مثال: أحمد النجار" 
            value={formData.fullName} 
            onChange={(e) => setFormData(p => ({ ...p, fullName: e.target.value }))}
            icon={<User size={18} />}
          />
          <Input 
            label="المهنة / الحرفة" 
            placeholder="مثال: نجار، كهربائي، سباك" 
            value={formData.profession} 
            onChange={(e) => setFormData(p => ({ ...p, profession: e.target.value }))}
            icon={<Wrench size={18} />}
          />
          <Input 
            label="سنوات الخبرة" 
            type="number"
            placeholder="مثال: 5" 
            value={formData.experienceYears} 
            onChange={(e) => setFormData(p => ({ ...p, experienceYears: e.target.value }))}
          />
          <div style={{ gridColumn: '1 / -1' }}>
            <Input 
              label="العنوان ومناطق العمل" 
              placeholder="مثال: بغداد - الكرادة وضواحيها" 
              value={formData.address} 
              onChange={(e) => setFormData(p => ({ ...p, address: e.target.value }))}
              icon={<MapPin size={18} />}
            />
          </div>
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
