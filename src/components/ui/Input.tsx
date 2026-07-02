import React, { InputHTMLAttributes, forwardRef } from 'react';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className = '', label, error, id, ...props }, ref) => {
    const inputId = id || props.name;
    return (
      <div className="ui-input-group" style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        {label && (
          <label htmlFor={inputId} style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={`ui-input ${error ? 'error' : ''} ${className}`}
          {...props}
        />
        {error && <span style={{ color: 'var(--error)', fontSize: '0.8rem' }}>{error}</span>}
      </div>
    );
  }
);
Input.displayName = 'Input';
