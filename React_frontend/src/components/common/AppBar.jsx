// AppBar — mirrors Flutter's AppBar with back button and title
import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, ArrowRight } from 'lucide-react';
import { useTheme } from '../../context/ThemeContext';

export default function AppBar({ title, actions, onBack }) {
  const navigate = useNavigate();
  const { language } = useTheme();
  const isRTL = language === 'ar';

  const handleBack = () => {
    if (onBack) { onBack(); return; }
    navigate(-1);
  };

  return (
    <header style={{
      background: 'var(--color-background)',
      padding: '0 4px',
      display: 'flex', alignItems: 'center',
      height: 56, flexShrink: 0,
      position: 'sticky', top: 0, zIndex: 100,
    }}>
      <button onClick={handleBack} style={{
        background: 'none', border: 'none',
        width: 44, height: 44, borderRadius: '50%',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer', color: 'var(--color-primary)',
        flexShrink: 0,
      }}>
        {isRTL ? <ArrowRight size={22} /> : <ArrowLeft size={22} />}
      </button>
      <h1 style={{
        flex: 1,
        fontFamily: 'var(--font-family)',
        fontSize: 17, fontWeight: 700,
        color: 'var(--color-text-primary)',
        margin: 0,
      }}>{title}</h1>
      {actions && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          {actions}
        </div>
      )}
    </header>
  );
}

export function IconBtn({ icon: Icon, onClick, color = 'var(--color-primary)', badge = false }) {
  return (
    <div style={{ position: 'relative' }}>
      <button onClick={onClick} style={{
        background: 'none', border: 'none',
        width: 44, height: 44, borderRadius: '50%',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer', color,
      }}>
        <Icon size={22} />
      </button>
      {badge && (
        <span style={{
          position: 'absolute', top: 8, right: 8,
          width: 8, height: 8, borderRadius: '50%',
          background: '#E53935',
          border: '1.5px solid var(--color-background)',
        }} />
      )}
    </div>
  );
}
