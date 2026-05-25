import React from 'react';
import { PackageOpen } from 'lucide-react';

export default function EmptyState({ icon: Icon = PackageOpen, message = 'No data available' }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: '48px 16px', gap: 16,
    }}>
      <Icon size={60} color="var(--color-text-hint)" strokeWidth={1.5} />
      <p style={{
        fontFamily: 'var(--font-family)',
        fontSize: 14, color: 'var(--color-text-secondary)',
        textAlign: 'center', fontWeight: 500,
      }}>{message}</p>
    </div>
  );
}
