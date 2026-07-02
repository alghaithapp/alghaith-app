import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCouriers } from '../../hooks/useAdminData';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Pagination } from '../../components/ui/Pagination';
import { Search, LoaderCircle, Bike } from 'lucide-react';

export default function CouriersPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const { data: couriers = [], isLoading } = useCouriers(token);
  
  const [search, setSearch] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [filter, setFilter] = useState('all');
  const pageSize = 20;

  const filtered = couriers.filter((c: any) => {
    if (filter === 'pending' && c.isApproved) return false;
    if (filter === 'approved' && !c.isApproved) return false;
    if (search) {
      const s = search.toLowerCase();
      if (!c.phone?.includes(s) && !c.name?.toLowerCase().includes(s)) return false;
    }
    return true;
  });

  const paginated = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', justifyContent: 'space-between' }}>
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
        
        <div className="topbar-search" style={{ position: 'relative', width: '300px' }}>
          <Search size={18} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            className="ui-input"
            style={{ paddingRight: '40px' }}
            placeholder="ابحث عن مندوب..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setCurrentPage(1); }}
          />
        </div>
      </div>

      <div className="ui-card padding-none">
        <Table>
          <Thead>
            <Tr>
              <Th>المندوب</Th>
              <Th>رقم الهاتف</Th>
              <Th>الحالة</Th>
              <Th>المتاحة</Th>
              <Th>الإجراءات</Th>
            </Tr>
          </Thead>
          <Tbody>
            {paginated.map((c: any) => (
              <Tr key={c.phone}>
                <Td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
                      <Bike size={24} color="var(--brand-primary)" />
                    </div>
                    <strong style={{ fontSize: '1.1rem' }}>{c.name || 'بدون اسم'}</strong>
                  </div>
                </Td>
                <Td dir="ltr" style={{ textAlign: 'right', fontWeight: '500', fontSize: '1.05rem' }}>{c.phone}</Td>
                <Td>
                  {c.isFrozen ? <Badge variant="danger">حساب مجمد</Badge> : (c.isApproved ? <Badge variant="success">مفعّل</Badge> : <Badge variant="warning">بانتظار التفعيل</Badge>)}
                </Td>
                <Td>
                  {c.available ? <Badge variant="success">متاح</Badge> : <Badge variant="neutral">غير متاح</Badge>}
                </Td>
                <Td>
                  <Button variant="secondary" onClick={() => navigate(`/admin/couriers/${encodeURIComponent(c.phone)}`)}>إدارة المندوب</Button>
                </Td>
              </Tr>
            ))}
          </Tbody>
        </Table>
        {filtered.length > 0 && (
          <Pagination 
            currentPage={currentPage} 
            totalPages={Math.ceil(filtered.length / pageSize)} 
            onPageChange={setCurrentPage} 
          />
        )}
        {filtered.length === 0 && (
          <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)' }}>
            لا يوجد مندوبين مطابقين للبحث.
          </div>
        )}
      </div>
    </div>
  );
}
