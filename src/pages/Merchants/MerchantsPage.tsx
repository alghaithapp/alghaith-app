import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMerchants } from '../../hooks/useAdminData';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Pagination } from '../../components/ui/Pagination';
import { Search, LoaderCircle, Store, X, Wrench, Stethoscope, Plus } from 'lucide-react';
import { loadMerchantDetails } from '../../admin-api';

export default function MerchantsPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const { data: merchants = [], isLoading, refetch } = useMerchants(token);
  
  const [search, setSearch] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [filter, setFilter] = useState('all'); // 'all' | 'pending' | 'approved'
  const pageSize = 20;

  const [selectedMerchantDetails, setSelectedMerchantDetails] = useState<any>(null);
  const [isDetailsLoading, setIsDetailsLoading] = useState(false);

  const handleOpenDetails = async (phone: string) => {
    setIsDetailsLoading(true);
    setSelectedMerchantDetails({ phone }); // show skeleton
    try {
      const details = await loadMerchantDetails(token, phone);
      setSelectedMerchantDetails(details);
    } catch (e) {
      alert('فشل جلب التفاصيل');
      setSelectedMerchantDetails(null);
    } finally {
      setIsDetailsLoading(false);
    }
  };

  // Filter & Search
  const filtered = merchants.filter((m: any) => {
    if (filter === 'pending' && m.isApproved) return false;
    if (filter === 'approved' && !m.isApproved) return false;
    if (search) {
      const s = search.toLowerCase();
      if (!m.phone?.includes(s) && !m.storeName?.toLowerCase().includes(s)) return false;
    }
    return true;
  });

  const paginated = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>



      <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
          {['all', 'pending', 'approved'].map(f => (
            <button
              key={f}
              className={`filter-chip ${filter === f ? 'active' : ''}`}
              onClick={() => { setFilter(f); setCurrentPage(1); }}
            >
              {f === 'all' ? 'الكل' : f === 'pending' ? 'بانتظار التفعيل' : 'مفعلون'}
            </button>
          ))}
        </div>
        
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          <Button variant="primary" onClick={() => window.location.href = '#/admin/merchants/add'}>
            <Plus size={16} /> إضافة تاجر
          </Button>
          <Button variant="secondary" onClick={() => window.location.href = '#/admin/merchants/add-professional'}>
            <Wrench size={16} /> إضافة مهني
          </Button>
          <Button variant="secondary" onClick={() => window.location.href = '#/admin/merchants/add-doctor'}>
            <Stethoscope size={16} /> طبيب / صيدلية
          </Button>
        </div>
      </div>
      
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '16px' }}>
        <div className="topbar-search" style={{ position: 'relative', width: '300px' }}>
          <Search size={18} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            className="ui-input"
            style={{ paddingRight: '40px' }}
            placeholder="ابحث عن تاجر..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setCurrentPage(1); }}
          />
        </div>
      </div>

      <div className="ui-card padding-none">
        <Table>
          <Thead>
            <Tr>
              <Th>التاجر</Th>
              <Th>رقم الهاتف</Th>
              <Th>الحالة</Th>
              <Th>المبيعات الكلية</Th>
              <Th>الإجراءات</Th>
            </Tr>
          </Thead>
          <Tbody>
            {paginated.map((m: any) => (
              <Tr key={m.phone}>
                <Td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
                      <Store size={24} color="var(--brand-primary)" />
                    </div>
                    <div>
                      <strong style={{ fontSize: '1.1rem', display: 'block' }}>{m.storeName || 'بدون اسم'}</strong>
                      <span style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>{m.fullName || '—'}</span>
                    </div>
                  </div>
                </Td>
                <Td dir="ltr" style={{ textAlign: 'right', fontWeight: '500', fontSize: '1.05rem' }}>{m.phone}</Td>
                <Td>
                  {m.isFrozen ? <Badge variant="danger">حساب مجمد</Badge> : (m.isApproved ? <Badge variant="success">مفعّل</Badge> : <Badge variant="warning">بانتظار التفعيل</Badge>)}
                </Td>
                <Td style={{ fontWeight: 'bold' }}>{new Intl.NumberFormat('ar-IQ').format(m.totalRevenue || 0)} د.ع</Td>
                <Td>
                  <Button variant="secondary" onClick={() => navigate(`/admin/merchants/${encodeURIComponent(m.phone)}`)}>إدارة التاجر</Button>
                </Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
        {filtered.length > 0 && (
          <Pagination 
            currentPage={currentPage} 
            totalItems={filtered.length} 
            pageSize={pageSize} 
            onPageChange={setCurrentPage} 
          />
        )}
      </div>

    </div>
  );
}
