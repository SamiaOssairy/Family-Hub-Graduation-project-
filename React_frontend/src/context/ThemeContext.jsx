// ═══════════════════════════════════════════════════════════════════════════════
// ThemeContext — manages dark/light mode, language (RTL/LTR), and color palette
// ═══════════════════════════════════════════════════════════════════════════════
import React, { createContext, useContext, useState, useEffect } from 'react';

const ThemeContext = createContext(null);

// ── Color palettes (mirrors Flutter AppPalette enum) ─────────────────────────
export const PALETTES = [
  {
    id: 'teal', displayName: 'Teal', seed: '#00897B',
    vars: {
      '--color-primary': '#00897B', '--color-primary-light': '#5BA89E',
      '--color-primary-surface': '#D1ECEB', '--color-background': '#E4F5F4',
      '--color-text-primary': '#00352E', '--color-text-secondary': '#5FA09A',
      '--color-text-hint': '#8CBFBB', '--color-border': '#95C5C1',
      '--color-border-light': '#CDEAE9',
    },
  },
  {
    id: 'purple', displayName: 'Purple', seed: '#6A1B9A',
    vars: {
      '--color-primary': '#6A1B9A', '--color-primary-light': '#AB47BC',
      '--color-primary-surface': '#EDE7F6', '--color-background': '#F3E5F5',
      '--color-text-primary': '#2A0040', '--color-text-secondary': '#9C27B0',
      '--color-text-hint': '#CE93D8', '--color-border': '#BA68C8',
      '--color-border-light': '#E1BEE7',
    },
  },
  {
    id: 'orange', displayName: 'Orange', seed: '#E65100',
    vars: {
      '--color-primary': '#E65100', '--color-primary-light': '#FF8A65',
      '--color-primary-surface': '#FBE9E7', '--color-background': '#FFF3E0',
      '--color-text-primary': '#4E1500', '--color-text-secondary': '#BF360C',
      '--color-text-hint': '#FFAB91', '--color-border': '#FF8A65',
      '--color-border-light': '#FFCCBC',
    },
  },
  {
    id: 'blue', displayName: 'Blue', seed: '#1565C0',
    vars: {
      '--color-primary': '#1565C0', '--color-primary-light': '#5E92F3',
      '--color-primary-surface': '#E3F2FD', '--color-background': '#EBF5FB',
      '--color-text-primary': '#002171', '--color-text-secondary': '#1E88E5',
      '--color-text-hint': '#90CAF9', '--color-border': '#64B5F6',
      '--color-border-light': '#BBDEFB',
    },
  },
  {
    id: 'pink', displayName: 'Pink', seed: '#AD1457',
    vars: {
      '--color-primary': '#AD1457', '--color-primary-light': '#E91E63',
      '--color-primary-surface': '#FCE4EC', '--color-background': '#FFF0F5',
      '--color-text-primary': '#4A0020', '--color-text-secondary': '#C2185B',
      '--color-text-hint': '#F48FB1', '--color-border': '#F06292',
      '--color-border-light': '#F8BBD0',
    },
  },
  {
    id: 'forest', displayName: 'Forest', seed: '#2E7D32',
    vars: {
      '--color-primary': '#2E7D32', '--color-primary-light': '#66BB6A',
      '--color-primary-surface': '#E8F5E9', '--color-background': '#F1F8E9',
      '--color-text-primary': '#1B3A1E', '--color-text-secondary': '#43A047',
      '--color-text-hint': '#A5D6A7', '--color-border': '#81C784',
      '--color-border-light': '#C8E6C9',
    },
  },
];

function applyPalette(paletteId) {
  const p = PALETTES.find(p => p.id === paletteId) || PALETTES[0];
  const root = document.documentElement;
  Object.entries(p.vars).forEach(([k, v]) => root.style.setProperty(k, v));
}

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(
    () => localStorage.getItem('theme') || 'light'
  );
  const [language, setLanguage] = useState(
    () => localStorage.getItem('language') || 'en'
  );
  const [paletteId, setPaletteId] = useState(
    () => localStorage.getItem('palette') || 'teal'
  );

  // Apply theme to <html> data-theme attribute
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  // Apply RTL/LTR direction
  useEffect(() => {
    document.documentElement.setAttribute('dir', language === 'ar' ? 'rtl' : 'ltr');
    document.documentElement.setAttribute('lang', language);
    localStorage.setItem('language', language);
  }, [language]);

  // Apply color palette CSS vars
  useEffect(() => {
    applyPalette(paletteId);
    localStorage.setItem('palette', paletteId);
  }, [paletteId]);

  function toggleTheme() {
    setTheme(t => t === 'light' ? 'dark' : 'light');
  }

  function toggleLanguage() {
    setLanguage(l => l === 'en' ? 'ar' : 'en');
  }

  function setPalette(id) {
    setPaletteId(id);
  }

  const palette = PALETTES.find(p => p.id === paletteId) || PALETTES[0];

  return (
    <ThemeContext.Provider value={{ theme, language, toggleTheme, toggleLanguage, palette, setPalette, palettes: PALETTES }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider');
  return ctx;
}
