import React, { useRef, useState } from 'react';
import { Upload, LoaderCircle, X } from 'lucide-react';
import { uploadImage } from '../../admin-api';
import { useAdminToken } from '../context/AuthContext';

interface Props {
  label: string;
  value?: string;
  onChange: (url: string) => void;
}

export function ImageUploadField({ label, value, onChange }: Props) {
  const token = useAdminToken();
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');

  const handleFile = async (file: File) => {
    if (file.size > 5 * 1024 * 1024) {
      setError('الحد الأقصى 5 ميغابايت');
      return;
    }
    setUploading(true);
    setError('');
    try {
      const url = await uploadImage(token, file);
      onChange(url);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'فشل الرفع');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="adm-field">
      <label className="adm-label">{label}</label>
      <div className="adm-img-upload">
        {uploading ? (
          <LoaderCircle size={28} className="spin" style={{ color: 'var(--adm-brand)' }} />
        ) : value ? (
          <>
            <img src={value} alt="" />
            <button type="button" className="adm-btn adm-btn-secondary" onClick={() => onChange('')}>
              <X size={14} /> إزالة
            </button>
          </>
        ) : (
          <>
            <Upload size={28} color="var(--adm-muted)" />
            <button type="button" className="adm-btn adm-btn-secondary" onClick={() => inputRef.current?.click()}>
              اختر صورة
            </button>
          </>
        )}
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) handleFile(f);
            e.target.value = '';
          }}
        />
      </div>
      {error && <p className="adm-error">{error}</p>}
    </div>
  );
}
