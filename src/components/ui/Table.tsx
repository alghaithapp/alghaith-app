import React from 'react';

export function Table({ children, className = '' }: { children: React.ReactNode, className?: string }) {
  return (
    <div className={`ui-table-container ${className}`}>
      <table className="ui-table">
        {children}
      </table>
    </div>
  );
}

export function Thead({ children }: { children: React.ReactNode }) {
  return <thead>{children}</thead>;
}

export function Tbody({ children }: { children: React.ReactNode }) {
  return <tbody>{children}</tbody>;
}

export function Tr({ children, className = '', onClick }: { children: React.ReactNode, className?: string, onClick?: () => void }) {
  return <tr className={className} onClick={onClick} style={{ cursor: onClick ? 'pointer' : 'default' }}>{children}</tr>;
}

export function Th({ children, className = '' }: { children: React.ReactNode, className?: string }) {
  return <th className={className}>{children}</th>;
}

export function Td({ children, className = '', colSpan }: { children: React.ReactNode, className?: string, colSpan?: number }) {
  return <td className={className} colSpan={colSpan}>{children}</td>;
}
