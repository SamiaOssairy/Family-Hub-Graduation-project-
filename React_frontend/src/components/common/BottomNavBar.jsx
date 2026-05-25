// ═══════════════════════════════════════════════════════════════════════════════
// BottomNavBar — shared bottom nav matching Flutter's _buildBottomNav() exactly
// 5 tabs: Home(0), Dashboard(1), AI Chat(2), Location(3), Settings(4)
// ═══════════════════════════════════════════════════════════════════════════════
import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useTheme } from '../../context/ThemeContext';
import './BottomNavBar.css';

const NAV_ITEMS = [
  { index: 0, emoji: '🏠', label: 'Home',      labelAr: 'الرئيسية',    route: '/home' },
  { index: 1, emoji: '⊞',  label: 'Dashboard', labelAr: 'لوحة التحكم', route: '/dashboard' },
  { index: 2, emoji: '🤖', label: 'AI Chat',   labelAr: 'المساعد',     route: '/planning-chat' },
  { index: 3, emoji: '📍', label: 'Location',  labelAr: 'الموقع',      route: '/family-map' },
  { index: 4, emoji: '⚙️', label: 'Settings',  labelAr: 'الإعدادات',   route: '/settings' },
];

export default function BottomNavBar({ activeIndex }) {
  const navigate = useNavigate();
  const { language } = useTheme();

  return (
    <nav className="bnav-root">
      {NAV_ITEMS.map(item => {
        const isActive = item.index === activeIndex;
        return (
          <button
            key={item.index}
            className={`bnav-item ${isActive ? 'active' : ''}`}
            onClick={() => {
              if (item.index !== activeIndex) navigate(item.route);
            }}
          >
            <span className={`bnav-pill ${isActive ? 'active' : ''}`}>
              {item.emoji}
            </span>
            <span className="bnav-label">
              {language === 'ar' ? item.labelAr : item.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
}
