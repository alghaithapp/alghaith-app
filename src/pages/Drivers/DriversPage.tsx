import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAccounts } from '../../hooks/useAdminData';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Pagination } from '../../components/ui/Pagination';
import { Search, LoaderCircle, Car, X, Plus } from 'lucide-react';
import { preRegisterDriver } from '../../admin-api';

import PreRegisterDriverModal from '../../components/PreRegisterDriverModal';

export default function DriversPage() {
  const navigate = useNavigate();
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const { data: accounts = [], isLoading, refetch } = useAccounts(token);
  
  const [search, setSearch] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [filter, setFilter] = useState('all');
  const pageSize = 20;

  // Drivers are accounts with kind = 'driver'
  const drivers = accounts.filter(a => a.kind === 'driver');

  // Filter & Search
  const filtered = drivers.filter((d: any) => {
    if (filter === 'suspended' && !d.isSuspended) return false;
    if (filter === 'active' && d.isSuspended) return false;
    if (search) {
      const s = search.toLowerCase();
      if (!d.phone?.includes(s) && !d.displayName?.toLowerCase().includes(s)) return false;
    }
    return true;
  });

  const [selectedDriver, setSelectedDriver] = useState<any>(null);
  const [showDriverPreRegister, setShowDriverPreRegister] = useState(false);
  const [isRegistering, setIsRegistering] = useState(false);

  const paginated = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  if (isLoading) {
    return <div className="loading-state"><LoaderCircle className="spin" size={32} /></div>;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      
      {/* ADD MODAL */}
      {showDriverPreRegister && (
        <PreRegisterDriverModal
          open={showDriverPreRegister}
          isBusy={isRegistering}
          onClose={() => { if (!isRegistering) setShowDriverPreRegister(false); }}
          onSubmit={async (payload) => {
            setIsRegistering(true);
            try {
              await preRegisterDriver(token, payload);
              setShowDriverPreRegister(false);
              refetch();
            } finally {
              setIsRegistering(false);
            }
          }}
        />
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px', alignItems: 'center' }}>
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
          {['all', 'active', 'suspended'].map(f => (
            <button
              key={f}
              className={`filter-chip ${filter === f ? 'active' : ''}`}
              onClick={() => { setFilter(f); setCurrentPage(1); }}
            >
              {f === 'all' ? 'الكل' : f === 'active' ? 'نشط' : 'موقوف'}
            </button>
          ))}
        </div>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant="primary" onClick={() => setShowDriverPreRegister(true)}>
            <Plus size={16} /> إضافة سائق تكسي
          </Button>
        </div>
      </div>
      
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '16px' }}>
        <div className="topbar-search" style={{ position: 'relative', width: '300px' }}>
          <Search size={18} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            className="ui-input"
            style={{ paddingRight: '40px' }}
            placeholder="ابحث عن سائق..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setCurrentPage(1); }}
          />
        </div>
      </div>

      <div className="ui-card padding-none">
        <Table>
          <Thead>
            <Tr>
              <Th>السائق</Th>
              <Th>رقم الهاتف</Th>
              <Th>تاريخ التسجيل</Th>
              <Th>الحالة</Th>
              <Th>الإجراءات</Th>
            </Tr>
          </Thead>
          <Tbody>
            {paginated.map((d: any) => (
              <Tr key={d.phone}>
                <Td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ background: 'var(--surface-elevated)', padding: '12px', borderRadius: '12px' }}>
                      <Car size={24} color="var(--brand-primary)" />
                    </div>
                    <strong style={{ fontSize: '1.1rem' }}>{d.displayName || d.fullName || 'بدون اسم'}</strong>
                  </div>
                </Td>
                <Td dir="ltr" style={{ textAlign: 'right', fontWeight: '500', fontSize: '1.05rem' }}>{d.phone}</Td>
                <Td>{new Date(d.createdAt).toLocaleDateString('ar-IQ')}</Td>
                <Td>
                  {d.isSuspended ? <Badge variant="danger">موقوف</Badge> : <Badge variant="success">نشط</Badge>}
                </Td>
                <Td>
                  <Button variant="secondary" onClick={() => navigate(`/admin/drivers/${encodeURIComponent(d.phone)}`)}>إدارة السائق</Button>
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
