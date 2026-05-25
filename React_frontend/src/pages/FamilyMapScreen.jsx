// ═══════════════════════════════════════════════════════════════════════════════
// FamilyMapScreen — React equivalent of flutter_app/lib/pages/family_map_screen.dart
// Location module: shows family member locations on a map.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect } from 'react';
import { useTheme } from '../context/ThemeContext';
import BottomNavBar from '../components/common/BottomNavBar';
import api from '../api/apiService';
import './FamilyMapScreen.css';

// Avatar color system (matches Flutter's home.dart)
const AVATAR_BG    = ['#E3F2FD','#F3E5F5','#FCE4EC','#FFF3E0','#D1ECEB','#E4F5F4'];
const AVATAR_COLOR = ['#1565C0','#6A1B9A','#AD1457','#E65100','#00352E','#00897B'];
function getAvatarColors(index) {
  return { bg: AVATAR_BG[index % AVATAR_BG.length], color: AVATAR_COLOR[index % AVATAR_COLOR.length] };
}
function getAvatarEmoji(memberType) {
  const t = (memberType || '').toLowerCase();
  if (t === 'parent')                         return '👑';
  if (t.includes('child') || t.includes('kid')) return '👶';
  return '👤';
}

// ─────────────────────────────────────────────────────────────────────────────
export default function FamilyMapScreen() {
  const { language } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;

  const [members,  setMembers]  = useState([]);
  const [loading,  setLoading]  = useState(true);

  useEffect(() => {
    loadFamilyLocations();
  }, []);

  async function loadFamilyLocations() {
    setLoading(true);
    try {
      const res = await api.get('/location/family-members');
      setMembers(res.data?.data?.members || []);
    } catch {
      // Silent — show empty state
    } finally {
      setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="fm-root">

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="fm-header">
        <div className="fm-header-icon">📍</div>
        <div className="fm-header-text">
          <span className="fm-header-title">{t('Family Map', 'خريطة العائلة')}</span>
          <span className="fm-header-sub">{t('Track family member locations', 'تتبع مواقع أفراد العائلة')}</span>
        </div>
        <button className="fm-refresh-btn" onClick={loadFamilyLocations} title={t('Refresh', 'تحديث')}>
          🔄
        </button>
      </div>

      {/* ── Map Placeholder ───────────────────────────────────────────────── */}
      <div className="fm-map-placeholder">
        <div className="fm-map-icon">🗺️</div>
        <h3 className="fm-map-title">{t('Interactive Map', 'خريطة تفاعلية')}</h3>
        <p className="fm-map-sub">
          {t(
            'Full map integration with real-time family tracking is coming soon.',
            'التكامل الكامل مع الخريطة وتتبع العائلة في الوقت الفعلي قادم قريباً.'
          )}
        </p>
      </div>

      {/* ── Members List ──────────────────────────────────────────────────── */}
      <div className="fm-scroll">
        <div className="fm-content">
          <span className="fm-section-label">{t('FAMILY MEMBERS', 'أفراد العائلة')}</span>

          {loading ? (
            <div className="fm-center"><div className="fm-spinner" /></div>
          ) : members.length === 0 ? (
            <div className="fm-card fm-center" style={{ padding: 24 }}>
              <span className="fm-empty-text">
                {t('No location data available', 'لا تتوفر بيانات الموقع')}
              </span>
            </div>
          ) : (
            <div className="fm-card">
              {members.map((m, i) => {
                const { bg, color } = getAvatarColors(i);
                const memberType = m.member_type_id?.type || m.memberType?.type || '';
                const isSharing = m.is_sharing_enabled ?? false;
                return (
                  <React.Fragment key={m._id || i}>
                    {i > 0 && <div className="fm-divider" />}
                    <div className="fm-member-row">
                      <div className="fm-avatar" style={{ background: bg }}>
                        <span style={{ color }}>{getAvatarEmoji(memberType)}</span>
                      </div>
                      <div className="fm-member-info">
                        <span className="fm-member-name">{m.username || m.mail}</span>
                        <span className="fm-member-mail">{m.mail}</span>
                      </div>
                      <div className={`fm-status-badge${isSharing ? ' on' : ' off'}`}>
                        {isSharing
                          ? t('Sharing', 'يشارك')
                          : t('Hidden', 'مخفي')}
                      </div>
                    </div>
                  </React.Fragment>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <BottomNavBar activeIndex={3} />
    </div>
  );
}
