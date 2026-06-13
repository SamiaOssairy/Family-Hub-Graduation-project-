// Avatar component — mirrors Flutter's _buildAvatar helper
import React from 'react';

const PALETTE = [
  { bg: '#E3F2FD', text: '#1565C0', border: '#90CAF9' },
  { bg: '#FFF3E0', text: '#E65100', border: '#FFCC80' },
  { bg: '#FCE4EC', text: '#C2185B', border: '#F48FB1' },
  { bg: 'var(--color-primary-surface)', text: 'var(--color-primary)', border: 'var(--color-border)' },
  { bg: '#F3E5F5', text: '#7B1FA2', border: '#CE93D8' },
  { bg: 'var(--color-background)', text: 'var(--color-primary)', border: 'var(--color-border)' },
];

export default function Avatar({ name = '', size = 40 }) {
  const initials = name.length >= 2
    ? name.substring(0, 2).toUpperCase()
    : (name || '?').toUpperCase();
  const idx = name ? name.charCodeAt(0) % PALETTE.length : 0;
  const c = PALETTE[idx];
  const fontSize = size * 0.33;

  return (
    <div style={{
      width: size,
      height: size,
      borderRadius: '50%',
      backgroundColor: c.bg,
      border: `2px solid ${c.border}`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
    }}>
      <span style={{
        fontSize,
        fontWeight: 700,
        color: c.text,
        fontFamily: 'var(--font-family)',
        lineHeight: 1,
      }}>
        {initials}
      </span>
    </div>
  );
}
