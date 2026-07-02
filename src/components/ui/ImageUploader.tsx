import React, { useRef, useState } from 'react';
import { Upload, X, LoaderCircle, Image as ImageIcon } from 'lucide-react';
import { Button } from './Button';

interface ImageUploaderProps {
  ownerId: string;
  ownerType: string;
  role: string;
  onUploadSuccess: (url: string) => void;
  label?: string;
  defaultImage?: string;
}

export function ImageUploader({ ownerId, ownerType, role, onUploadSuccess, label = 'رفع صورة', defaultImage }: ImageUploaderProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [preview, setPreview] = useState<string | null>(defaultImage || null);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      setError('حجم الصورة يجب أن لا يتجاوز 5 ميغابايت');
      return;
    }

    setIsUploading(true);
    setError(null);

    try {
      // 1. Read as Base64
      const reader = new FileReader();
      reader.readAsDataURL(file);
      await new Promise((resolve) => {
        reader.onload = resolve;
      });
      const base64 = reader.result as string;

      // 2. Upload to server
      // Wait, is the API URL correct? Let's use the current domain's backend API URL or standard fetch path.
      // Usually it's mapped to the domain, but in local dev it's port 8080.
      // Looking at `admin-api.ts`, it uses DATABASE_API_BASE_URL which is from Vite env.
      const API_BASE = import.meta.env.VITE_DATABASE_API_BASE_URL || 'http://localhost:8080';
      
      const res = await fetch(`${API_BASE}/media/upload`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          imageBase64: base64,
          ownerType,
          ownerId,
          role
        })
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'فشل رفع الصورة');

      setPreview(data.url || data.publicUrl);
      onUploadSuccess(data.url || data.publicUrl);

    } catch (err: any) {
      setError(err.message || 'حدث خطأ غير متوقع');
    } finally {
      setIsUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
      {label && <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{label}</span>}
      
      <div 
        style={{ 
          border: '2px dashed var(--border)', 
          borderRadius: '12px', 
          padding: '16px', 
          display: 'flex', 
          flexDirection: 'column', 
          alignItems: 'center', 
          justifyContent: 'center',
          gap: '12px',
          background: 'var(--surface-elevated)',
          position: 'relative',
          overflow: 'hidden',
          minHeight: '150px'
        }}
      >
        {isUploading ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', color: 'var(--brand-primary)' }}>
            <LoaderCircle className="spin" size={32} />
            <span style={{ fontSize: '0.85rem' }}>جاري الرفع...</span>
          </div>
        ) : preview ? (
          <>
            <img src={preview} alt="Preview" style={{ maxWidth: '100%', maxHeight: '200px', objectFit: 'contain', borderRadius: '8px' }} />
            <button 
              type="button"
              onClick={() => { setPreview(null); onUploadSuccess(''); }}
              style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.5)', color: 'white', border: 'none', borderRadius: '50%', padding: '4px', cursor: 'pointer' }}
            >
              <X size={16} />
            </button>
          </>
        ) : (
          <>
            <div style={{ padding: '16px', background: 'var(--surface)', borderRadius: '50%' }}>
              <ImageIcon size={32} color="var(--text-muted)" />
            </div>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>اضغط لرفع الصورة أو اسحبها هنا</span>
            <Button type="button" variant="secondary" onClick={() => inputRef.current?.click()} icon={<Upload size={16} />}>
              اختر صورة
            </Button>
          </>
        )}
        
        <input 
          type="file" 
          ref={inputRef} 
          style={{ display: 'none' }} 
          accept="image/*"
          onChange={handleFileChange}
        />
      </div>
      {error && <span style={{ color: 'var(--error)', fontSize: '0.8rem' }}>{error}</span>}
    </div>
  );
}
