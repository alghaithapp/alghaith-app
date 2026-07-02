import React, { useEffect } from 'react';
import { X } from 'lucide-react';
import { Card } from './Card';

export interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  maxWidth?: string;
}

export function Modal({ isOpen, onClose, title, children, maxWidth = '500px' }: ModalProps) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => { document.body.style.overflow = 'unset'; };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div className="ui-modal-overlay" onClick={onClose}>
      <div className="ui-modal-content" style={{ maxWidth }} onClick={(e) => e.stopPropagation()}>
        <Card padding="none" className="ui-modal-card">
          {title && (
            <div className="ui-modal-header">
              <h3>{title}</h3>
              <button className="ui-modal-close" onClick={onClose}>
                <X size={20} />
              </button>
            </div>
          )}
          <div className="ui-modal-body">
            {children}
          </div>
        </Card>
      </div>
    </div>
  );
}
