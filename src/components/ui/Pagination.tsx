import React from 'react';
import { ChevronRight, ChevronLeft } from 'lucide-react';

interface PaginationProps {
  currentPage: number;
  totalItems: number;
  pageSize: number;
  onPageChange: (page: number) => void;
}

export function Pagination({ currentPage, totalItems, pageSize, onPageChange }: PaginationProps) {
  const totalPages = Math.ceil(totalItems / pageSize);
  if (totalPages <= 1) return null;

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '16px', marginTop: '32px', padding: '16px 0', borderTop: '1px solid var(--border)' }}>
      <button 
        className="ui-btn ui-btn-secondary" 
        disabled={currentPage === 1}
        onClick={() => onPageChange(currentPage - 1)}
        style={{ padding: '8px 12px' }}
      >
        <ChevronRight size={18} />
      </button>
      
      <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-secondary)' }}>
        صفحة <strong style={{ color: 'var(--text-primary)' }}>{currentPage}</strong> من {totalPages}
      </span>
      
      <button 
        className="ui-btn ui-btn-secondary" 
        disabled={currentPage === totalPages}
        onClick={() => onPageChange(currentPage + 1)}
        style={{ padding: '8px 12px' }}
      >
        <ChevronLeft size={18} />
      </button>
    </div>
  );
}
