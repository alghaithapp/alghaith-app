import React from 'react';

type Props = {
  src?: string | null;
  alt?: string;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
};

const sizeClass = {
  sm: '',
  md: 'adm-avatar-lg',
  lg: 'adm-avatar-xl',
} as const;

export function pickMerchantAvatarUrl(item: {
  avatarImageUrl?: string | null;
  profileImageUrl?: string | null;
  logoImageUrl?: string | null;
  coverImageUrl?: string | null;
  clinicImageUrl?: string | null;
}) {
  return (
    item.avatarImageUrl ||
    item.profileImageUrl ||
    item.logoImageUrl ||
    item.coverImageUrl ||
    item.clinicImageUrl ||
    ''
  ).trim();
}

export function AdminAvatar({ src, alt = '', size = 'sm', className = '' }: Props) {
  const url = String(src || '').trim();
  const classes = ['adm-avatar', sizeClass[size], className].filter(Boolean).join(' ');
  if (!url) {
    return <div className={`${classes} adm-avatar-empty`}>—</div>;
  }
  return <img src={url} alt={alt} className={classes} loading="lazy" />;
}

type MediaItem = {
  label: string;
  url?: string | null;
};

export function AdminMediaGallery({ items }: { items: MediaItem[] }) {
  const visible = items.filter((item) => String(item.url || '').trim());
  if (!visible.length) {
    return <p style={{ margin: 0, color: 'var(--adm-muted)' }}>لا توجد صور مرفوعة.</p>;
  }
  return (
    <div className="adm-media-grid">
      {visible.map((item) => (
        <figure key={item.label} className="adm-media-card">
          <img src={item.url!} alt={item.label} className="adm-media-preview" loading="lazy" />
          <figcaption>{item.label}</figcaption>
        </figure>
      ))}
    </div>
  );
}
