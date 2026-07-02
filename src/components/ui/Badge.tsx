import React from 'react';

export interface BadgeProps {
  variant?: 'success' | 'error' | 'warning' | 'info' | 'neutral';
  children: React.ReactNode;
  className?: string;
  icon?: React.ReactNode;
}

export function Badge({ variant = 'neutral', children, className = '', icon }: BadgeProps) {
  return (
    <span className={`ui-badge ui-badge-${variant} ${className}`}>
      {icon && <span style={{ marginLeft: 6, display: 'inline-flex' }}>{icon}</span>}
      {children}
    </span>
  );
}
