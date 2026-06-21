import React from 'react';
import { XCircle, ExternalLink, Image as ImageIcon } from 'lucide-react';

interface DocumentsModalProps {
  documents: Record<string, string> | null;
  displayName: string;
  onClose: () => void;
}

const DOCUMENT_LABELS: Record<string, string> = {
  profileImage: 'صورة شخصية',
  vehicleImage: 'صورة المركبة/الدراجة',
  idFrontImage: 'الهوية الوطنية (أمام)',
  idBackImage: 'الهوية الوطنية (خلف)',
  residenceCardImage: 'بطاقة السكن',
  vehicleRegFrontImage: 'سنوية السيارة (أمام)',
  vehicleRegBackImage: 'سنوية السيارة (خلف)',
};

export default function DocumentsModal({
  documents,
  displayName,
  onClose,
}: DocumentsModalProps) {
  if (!documents) return null;

  // Filter out empty or undefined documents
  const validDocs = Object.entries(documents).filter(([_, url]) => url && url.trim() !== '');

  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onClick={onClose}
    >
      <div
        className="modal-card wide-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth: '800px', width: '90%' }}
      >
        <div className="modal-header">
          <div className="modal-title" id="modal-title">
            <ImageIcon className="icon" size={20} />
            <h2>مستندات: {displayName}</h2>
          </div>
          <button
            type="button"
            className="icon-button"
            aria-label="إغلاق النافذة"
            onClick={onClose}
          >
            <XCircle size={20} />
          </button>
        </div>

        <div className="modal-body">
          {validDocs.length === 0 ? (
            <div className="empty-state" style={{ padding: '40px 0', textAlign: 'center' }}>
              <p>لا توجد مستندات مرفوعة لهذا الحساب.</p>
            </div>
          ) : (
            <div
              className="documents-grid"
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
                gap: '16px',
                padding: '16px 0',
              }}
            >
              {validDocs.map(([key, url]) => (
                <div
                  key={key}
                  className="document-card"
                  style={{
                    border: '1px solid var(--border)',
                    borderRadius: '8px',
                    overflow: 'hidden',
                    display: 'flex',
                    flexDirection: 'column',
                  }}
                >
                  <div
                    style={{
                      height: '150px',
                      backgroundColor: 'var(--bg-subtle)',
                      backgroundImage: `url(${url})`,
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                    }}
                  />
                  <div
                    style={{
                      padding: '12px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      backgroundColor: 'var(--surface)',
                    }}
                  >
                    <span style={{ fontSize: '0.85rem', fontWeight: 500 }}>
                      {DOCUMENT_LABELS[key] || key}
                    </span>
                    <a
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      title="فتح في نافذة جديدة"
                      style={{ color: 'var(--color-primary)', display: 'flex' }}
                    >
                      <ExternalLink size={16} />
                    </a>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="modal-footer">
          <button type="button" className="button secondary" onClick={onClose}>
            إغلاق
          </button>
        </div>
      </div>
    </div>
  );
}
