import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { loadMerchantDetails, loadAdminMerchantProducts, saveAdminMerchantProduct, deleteAdminMerchantProduct, toggleMerchantApproval, suspendAdminAccount } from '../../admin-api';
import { LoaderCircle, Store, Phone, MapPin, Package, Settings, X, Plus, Trash2, Edit } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { Badge } from '../../components/ui/Badge';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';
import { ImageUploader } from '../../components/ui/ImageUploader';

export default function MerchantDetailsPage() {
  const { phone } = useParams();
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';

  const [details, setDetails] = useState<any>(null);
  const [products, setProducts] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isProductsLoading, setIsProductsLoading] = useState(false);

  const [productForm, setProductForm] = useState<any>(null);
  const [isSavingProduct, setIsSavingProduct] = useState(false);

  const fetchDetails = async () => {
    if (!phone) return;
    try {
      const data = await loadMerchantDetails(token, phone);
      setDetails(data);
    } catch (e) {
      console.error(e);
      alert('فشل تحميل تفاصيل التاجر');
      navigate('/admin/merchants');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchProducts = async () => {
    if (!phone) return;
    setIsProductsLoading(true);
    try {
      const prods = await loadAdminMerchantProducts(token, phone);
      setProducts(prods);
    } catch (e) {
      console.error(e);
    } finally {
      setIsProductsLoading(false);
    }
  };

  useEffect(() => {
    fetchDetails();
    fetchProducts();
  }, [phone]);

  const handleToggleApproval = async () => {
    try {
      await toggleMerchantApproval(token, phone!, !details.merchant.isApproved);
      fetchDetails();
    } catch (e) {
      alert('فشل تغيير حالة الموافقة');
    }
  };

  const handleSuspend = async () => {
    if (!confirm('هل أنت متأكد من تغيير حالة الإيقاف للمستخدم؟')) return;
    try {
      await suspendAdminAccount(token, phone!, true); // Or toggle
      alert('تم تغيير حالة الإيقاف للحساب ككل.');
    } catch (e) {
      alert('فشل إيقاف الحساب');
    }
  };

  const handleSaveProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSavingProduct(true);
    try {
      await saveAdminMerchantProduct(token, phone!, productForm);
      setProductForm(null);
      fetchProducts();
    } catch (e: any) {
      alert(e.message || 'فشل حفظ المنتج');
    } finally {
      setIsSavingProduct(false);
    }
  };

  const handleDeleteProduct = async (id: string) => {
    if (!confirm('حذف المنتج؟')) return;
    try {
      await deleteAdminMerchantProduct(token, phone!, id);
      fetchProducts();
    } catch (e) {
      alert('فشل الحذف');
    }
  };

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  const m = details?.merchant || {};
  const stats = details?.stats || {};

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', maxWidth: '1000px', margin: '0 auto' }}>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
           <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
             <Store size={24} color="var(--brand-primary)" />
           </div>
           <div>
             <h2 style={{ margin: 0, display: 'flex', gap: '12px', alignItems: 'center' }}>
               {m.storeName || m.fullName || 'بدون اسم'}
               {m.isApproved ? <Badge variant="success">مفعّل</Badge> : <Badge variant="warning">غير مفعّل</Badge>}
             </h2>
             <span style={{ color: 'var(--text-muted)' }} dir="ltr">{phone}</span>
           </div>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant={m.isApproved ? "secondary" : "primary"} onClick={handleToggleApproval}>
            {m.isApproved ? 'إلغاء التفعيل' : 'تفعيل التاجر'}
          </Button>
          <Button variant="danger" onClick={handleSuspend}>حظر الحساب</Button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '16px' }}>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>المبيعات الكلية</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{new Intl.NumberFormat('ar-IQ').format(stats.totalRevenue || 0)} د.ع</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>الطلبات (مكتمل / كلي)</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>{stats.completedOrders || 0} / {stats.totalOrders || 0}</div>
        </div>
        <div className="ui-card">
          <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '8px' }}>القسم / التصنيف</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>{m.primaryServiceId || 'غير محدد'}</div>
        </div>
      </div>

      {/* MEDIA SECTION */}
      <div className="ui-card padding-none" style={{ overflow: 'hidden' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid var(--border)' }}>
           <h3 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
             الصور ومعرض الأعمال
           </h3>
           <div style={{ marginTop: '16px', display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType={m.primaryServiceId === 'pharmacy' ? 'pharmacy' : m.primaryServiceId === 'doctor' ? 'doctor' : m.isProfessional ? 'professional' : 'merchant'} 
                 role="profile" 
                 label="الصورة الشخصية / الشعار"
                 onUploadSuccess={() => {}} 
               />
             </div>
             <div style={{ width: '200px' }}>
               <ImageUploader 
                 ownerId={phone!} 
                 ownerType={m.primaryServiceId === 'pharmacy' ? 'pharmacy' : m.primaryServiceId === 'doctor' ? 'doctor' : m.isProfessional ? 'professional' : 'merchant'} 
                 role="gallery" 
                 label="معرض الأعمال (صور إضافية)"
                 onUploadSuccess={() => {}} 
               />
             </div>
           </div>
        </div>
      </div>

      {/* PRODUCTS SECTION */}
      <div className="ui-card padding-none" style={{ overflow: 'hidden' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
           <h3 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
             <Package size={20} />
             المنتجات / الخدمات
           </h3>
           <Button variant="primary" onClick={() => setProductForm({ category: m.primaryServiceId })}>
             <Plus size={16} /> إضافة منتج
           </Button>
        </div>
        
        {isProductsLoading ? (
          <div style={{ padding: '32px', textAlign: 'center' }}><LoaderCircle className="spin" /></div>
        ) : products.length === 0 ? (
          <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)' }}>لا توجد منتجات مسجلة لهذا التاجر.</div>
        ) : (
          <Table>
            <Thead>
              <Tr>
                <Th>الاسم</Th>
                <Th>السعر</Th>
                <Th>القسم</Th>
                <Th>متوفر؟</Th>
                <Th>الإجراءات</Th>
              </Tr>
            </Thead>
            <Tbody>
              {products.map(p => (
                <Tr key={p.id}>
                  <Td><strong>{p.nameAr || p.nameEn || 'بدون اسم'}</strong></Td>
                  <Td>{p.price || 0} د.ع</Td>
                  <Td>{p.category}</Td>
                  <Td>{p.isAvailable ? 'نعم' : 'لا'}</Td>
                  <Td>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button onClick={() => setProductForm(p)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--brand-primary)' }}><Edit size={18} /></button>
                      <button onClick={() => handleDeleteProduct(p.id)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--error)' }}><Trash2 size={18} /></button>
                    </div>
                  </Td>
                </Tr>
              ))}
            </Tbody>
          </Table>
        )}
      </div>

      {/* PRODUCT FORM MODAL */}
      {productForm && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', zIndex: 9999, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          <form onSubmit={handleSaveProduct} style={{ background: 'var(--surface)', padding: '24px', borderRadius: '16px', width: '90%', maxWidth: '500px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <h3 style={{ margin: 0 }}>{productForm.id ? 'تعديل منتج' : 'إضافة منتج جديد'}</h3>
              <button type="button" onClick={() => setProductForm(null)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}><X /></button>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '24px' }}>
              <div>
                <label style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>الاسم (عربي)</label>
                <input className="ui-input" value={productForm.nameAr || ''} onChange={e => setProductForm({...productForm, nameAr: e.target.value})} required />
              </div>
              <div>
                <label style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>الوصف</label>
                <textarea className="ui-input" value={productForm.descriptionAr || ''} onChange={e => setProductForm({...productForm, descriptionAr: e.target.value})} />
              </div>
              <div>
                <label style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>السعر (دينار)</label>
                <input type="number" className="ui-input" value={productForm.price || ''} onChange={e => setProductForm({...productForm, price: Number(e.target.value)})} required />
              </div>
              <div>
                <label style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>التصنيف (القسم)</label>
                <input className="ui-input" value={productForm.category || ''} onChange={e => setProductForm({...productForm, category: e.target.value})} required />
              </div>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input type="checkbox" checked={productForm.isAvailable ?? true} onChange={e => setProductForm({...productForm, isAvailable: e.target.checked})} />
                <span>متوفر للبيع</span>
              </label>
            </div>
            
            <Button type="submit" variant="primary" style={{ width: '100%' }} disabled={isSavingProduct}>
              {isSavingProduct ? 'جاري الحفظ...' : 'حفظ المنتج'}
            </Button>
          </form>
        </div>
      )}
    </div>
  );
}
