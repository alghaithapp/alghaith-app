import React, { ButtonHTMLAttributes, forwardRef } from 'react';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  icon?: React.ReactNode;
  isLoading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ children, className = '', variant = 'primary', icon, isLoading, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={`ui-btn ui-btn-${variant} ${className}`}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading && <span className="spin" style={{ width: 16, height: 16, border: '2px solid currentColor', borderTopColor: 'transparent', borderRadius: '50%', display: 'inline-block' }} />}
        {!isLoading && icon}
        {children}
      </button>
    );
  }
);
Button.displayName = 'Button';
