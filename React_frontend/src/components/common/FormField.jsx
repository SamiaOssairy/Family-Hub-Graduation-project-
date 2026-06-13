// Reusable form field — mirrors Flutter's custom TextField style
import React from 'react';

export default function FormField({
  label, value, onChange, type = 'text',
  placeholder, required, rows, min, max, step,
  style: extraStyle,
}) {
  const base = {
    width: '100%', fontFamily: 'var(--font-family)', fontSize: 13,
    color: 'var(--color-text-primary)',
    background: 'var(--color-background)',
    border: '1px solid var(--color-border)',
    borderRadius: 'var(--radius-input)', padding: '10px 12px',
    // Guaranteed height so an EMPTY date input (which collapses on iOS Safari)
    // stays the same height as a filled one and as the other fields.
    minHeight: 42,
    outline: 'none', boxSizing: 'border-box',
    transition: 'border-color 0.2s',
    ...extraStyle,
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, width: '100%' }}>
      {label && (
        <label style={{
          fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
          color: 'var(--color-text-secondary)',
        }}>
          {label}{required && ' *'}
        </label>
      )}
      {rows ? (
        <textarea
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder={placeholder}
          rows={rows}
          style={{ ...base, resize: 'vertical', lineHeight: 1.5 }}
          onFocus={e => e.target.style.borderColor = 'var(--color-primary)'}
          onBlur={e => e.target.style.borderColor = 'var(--color-border)'}
        />
      ) : (
        <input
          type={type}
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder={placeholder}
          required={required}
          min={min} max={max} step={step}
          style={base}
          onFocus={e => e.target.style.borderColor = 'var(--color-primary)'}
          onBlur={e => e.target.style.borderColor = 'var(--color-border)'}
        />
      )}
    </div>
  );
}

export function SelectField({ label, value, onChange, options, required, placeholder }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, width: '100%' }}>
      {label && (
        <label style={{
          fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
          color: 'var(--color-text-secondary)',
        }}>
          {label}{required && ' *'}
        </label>
      )}
      <select
        value={value}
        onChange={e => onChange(e.target.value)}
        style={{
          width: '100%', fontFamily: 'var(--font-family)', fontSize: 13,
          color: 'var(--color-text-primary)',
          background: 'var(--color-background)',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-input)',
          padding: '10px 12px', outline: 'none',
          cursor: 'pointer',
        }}
        onFocus={e => e.target.style.borderColor = 'var(--color-primary)'}
        onBlur={e => e.target.style.borderColor = 'var(--color-border)'}
      >
        {placeholder && <option value="">{placeholder}</option>}
        {options.map(o => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </div>
  );
}
