import React, { useState } from 'react';
import { useAccounts, useAdminMutations } from '../../hooks/useAdminData';
import { Table, Thead, Tbody, Tr, Th, Td } from '../../components/ui/Table';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Pagination } from '../../components/ui/Pagination';
import { Search, LoaderCircle, UserX, RefreshCw, Trash2, Shield } from 'lucide-react';

export default function AccountsPage() {
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const { data: accounts = [], isLoading } = useAccounts(token);
  const { suspendAccount, deleteAccount, updateRole } = useAdminMutations(token);
  
  const [search, setSearch] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [filter, setFilter] = useState('all');
  const pageSize = 20;

  // Filter & Search
  const filtered = accounts.filter(a => {
    if (filter !== 'all' && a.kind !== filter) return false;
    if (search) {
      const s = search.toLowerCase();
      if (!a.phone?.includes(s) && !a.displayName?.toLowerCase().includes(s)) return false;
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
          {['all', 'customer', 'merchant', 'courier', 'driver', 'admin'].map(f => (
            <button
              key={f}
              className={`filter-chip ${filter === f ? 'active' : ''}`}
              onClick={() => { setFilter(f); setCurrentPage(1); }}
            >
              {f === 'all' ? 'الكل' : f}
            </button>
          ))}
        </div>
        
        <div className="topbar-search" style={{ position: 'relative', width: '300px' }}>
          <Search size={18} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            className="ui-input"
            style={{ paddingRight: '40px' }}
            placeholder="ابحث برقم الهاتف أو الاسم..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setCurrentPage(1); }}
          />
        </div>
      </div>

      <div className="ui-card padding-none">
        <Table>
          <Thead>
            <Tr>
              <Th>الاسم</Th>
              <Th>رقم الهاتف</Th>
              <Th>النوع</Th>
              <Th>تاريخ التسجيل</Th>
              <Th>الحالة</Th>
              <Th>الإجراءات</Th>
            </Tr>
          </Thead>
          <Tbody>
            {paginated.map(a => (
              <Tr key={a.phone}>
                <Td>{a.displayName || a.fullName || 'بدون اسم'}</Td>
                <Td dir="ltr" style={{ textAlign: 'right' }}>{a.phone}</Td>
                <Td>
                  <Badge variant="neutral">{a.kind}</Badge>
                </Td>
                <Td>{a.createdAt ? new Date(a.createdAt).toLocaleDateString('ar-IQ') : '—'}</Td>
                <Td>
                  {a.isSuspended ? <Badge variant="error">معلق</Badge> : <Badge variant="success">نشط</Badge>}
                </Td>
                <Td>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <select
                      className="ui-input"
                      style={{ padding: '4px 8px', height: '32px', fontSize: '0.8rem' }}
                      value={a.kind}
                      onChange={(e) => updateRole.mutate({ phone: a.phone, role: e.target.value })}
                    >
                      <option value="customer">زبون</option>
                      <option value="merchant">تاجر</option>
                      <option value="driver">سائق تكسي</option>
                      <option value="courier">مندوب توصيل</option>
                      <option value="admin">مشرف (أدمن)</option>
                    </select>
                    <Button variant={a.isSuspended ? "secondary" : "danger"} onClick={() => suspendAccount.mutate({ phone: a.phone, isSuspended: !a.isSuspended })}>
                      {a.isSuspended ? 'فك التعليق' : 'تعليق'}
                    </Button>
                    <Button variant="danger" onClick={() => { if (window.confirm('هل أنت متأكد من حذف الحساب نهائياً؟')) deleteAccount.mutate(a.phone); }}>
                      <Trash2 size={16} />
                    </Button>
                  </div>
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
