import React, { useEffect } from 'react';

export default function Modal({ open, onClose, title, children, actions, maxWidth = 480 }) {
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => { document.body.style.overflow = ''; };
  }, [open]);

  if (!open) return null;

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 1000,
      background: 'rgba(0,0,0,0.5)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 16,
    }} onClick={e => { if (e.target === e.currentTarget) onClose?.(); }}>
      <div style={{
        background: 'var(--color-white)',
        borderRadius: 18,
        padding: '24px 20px 16px',
        width: '100%', maxWidth,
        maxHeight: '90vh', overflowY: 'auto',
        boxShadow: '0 20px 60px rgba(0,0,0,0.15)',
      }}>
        {title && (
          <h3 style={{
            fontFamily: 'var(--font-family)',
            fontSize: 17, fontWeight: 700,
            color: 'var(--color-text-primary)',
            marginBottom: 16,
          }}>{title}</h3>
        )}
        <div>{children}</div>
        {actions && (
          <div style={{
            display: 'flex', justifyContent: 'flex-end', gap: 10,
            marginTop: 20, paddingTop: 12,
            borderTop: '1px solid var(--color-border-light)',
          }}>
            {actions}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Reusable button components ────────────────────────────────────────────────
export function ModalCancelBtn({ onClick, label = 'Cancel' }) {
  return (
    <button onClick={onClick} style={{
      padding: '8px 18px',
      background: 'transparent', border: 'none',
      fontFamily: 'var(--font-family)', fontSize: 13,
      color: 'var(--color-text-secondary)', cursor: 'pointer',
      borderRadius: 10, fontWeight: 600,
    }}>{label}</button>
  );
}

export function ModalPrimaryBtn({ onClick, label = 'Save', disabled = false, color = 'var(--color-primary)' }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      padding: '8px 20px',
      background: disabled ? 'var(--color-border)' : color,
      border: 'none', borderRadius: 10,
      fontFamily: 'var(--font-family)', fontSize: 13,
      color: '#fff', cursor: disabled ? 'default' : 'pointer',
      fontWeight: 600,
    }}>{label}</button>
  );
}

export function DangerBtn({ onClick, label = 'Delete', disabled = false }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      padding: '8px 20px',
      background: disabled ? 'var(--color-border)' : '#E53935',
      border: 'none', borderRadius: 10,
      fontFamily: 'var(--font-family)', fontSize: 13,
      color: '#fff', cursor: disabled ? 'default' : 'pointer',
      fontWeight: 600,
    }}>{label}</button>
  );
}
