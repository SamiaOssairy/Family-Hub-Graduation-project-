// ═══════════════════════════════════════════════════════════════════════════════
// DashboardScreen — React equivalent of flutter_app/lib/pages/dashboard_screen.dart
// Module hub with 16 categories grid, announcements, family events.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTheme } from '../context/ThemeContext';
import BottomNavBar from '../components/common/BottomNavBar';
import api from '../api/apiService';
import './DashboardScreen.css';

// ── Module definitions (matches Flutter _modules list exactly) ────────────────
const MODULES = [
  { label: 'Tasks',      labelAr: 'المهام',         emoji: '✅', route: '/tasks',                iconBg: 'var(--color-primary-surface)', iconColor: 'var(--color-primary)' },
  { label: 'Budget',     labelAr: 'الميزانية',       emoji: '💰', route: '/budget',               iconBg: 'var(--color-background)', iconColor: 'var(--color-primary)' },
  { label: 'Events',     labelAr: 'الأحداث',         emoji: '📅', route: '/future-events',        iconBg: '#FFF3E0', iconColor: '#E65100' },
  { label: 'Wallet',     labelAr: 'المحفظة',         emoji: '💳', route: '/combined-wallet',      iconBg: 'var(--color-primary-surface)', iconColor: 'var(--color-text-primary)' },
  { label: 'Rewards',    labelAr: 'المكافآت',        emoji: '🏆', route: '/rewards',              iconBg: '#FFF8E1', iconColor: '#F9A825' },
  { label: 'Wishlist',   labelAr: 'الأمنيات',        emoji: '⭐', route: '/wishlist',             iconBg: '#FFF8E1', iconColor: '#F9A825' },
  { label: 'Redeem',     labelAr: 'استبدال',         emoji: '🎁', route: '/redeem',               iconBg: '#FCE4EC', iconColor: '#AD1457' },
  { label: 'Status',     labelAr: 'الحالة',          emoji: '📈', route: '/status',               iconBg: '#E3F2FD', iconColor: '#1565C0' },
  { label: 'Points',     labelAr: 'النقاط',          emoji: '⭐', route: '/family-points',        iconBg: '#FCE4EC', iconColor: '#AD1457' },
  { label: 'Food Hub',   labelAr: 'مركز الطعام',     emoji: '🍽️', route: '/food-hub',             iconBg: '#FFF3E0', iconColor: '#E65100' },
  { label: 'Inventory',  labelAr: 'المخزون',         emoji: '📦', route: '/inventory',            iconBg: '#EDE7F6', iconColor: '#6A1B9A' },
  { label: 'Recipes',    labelAr: 'الوصفات',         emoji: '📖', route: '/recipes',              iconBg: 'var(--color-background)', iconColor: 'var(--color-primary)' },
  { label: 'Meals',      labelAr: 'الوجبات',         emoji: '🍴', route: '/meals',                iconBg: '#E0F7FA', iconColor: '#00838F' },
  { label: 'Leftovers',  labelAr: 'بقايا الطعام',   emoji: '🥡', route: '/leftovers',            iconBg: '#FBE9E7', iconColor: '#BF360C' },
  { label: 'Receipts',   labelAr: 'الإيصالات',       emoji: '🧾', route: '/receipts',             iconBg: '#E8EAF6', iconColor: '#283593' },
  { label: 'Groceries',  labelAr: 'البقالة',         emoji: '🛒', route: '/groceries',            iconBg: 'var(--color-primary-surface)', iconColor: 'var(--color-text-primary)' },
  { label: 'Categories', labelAr: 'الفئات',          emoji: '📂', route: '/inventory-categories', iconBg: '#F3E5F5', iconColor: '#7B1FA2' },
  { label: 'Analytics',  labelAr: 'التحليلات',        emoji: '📊', route: '/combined-analytics',   iconBg: '#E3F2FD', iconColor: '#1565C0' },
];

// Routes actually implemented in the React app
const IMPLEMENTED = new Set([
  '/home', '/tasks', '/task-management', '/rewards', '/redeem', '/wishlist',
  '/family-points', '/status', '/food-hub', '/recipes', '/meals',
  '/meal-suggestions', '/leftovers', '/inventory', '/inventory-categories',
  '/inventory-alerts', '/groceries', '/receipts', '/planning-chat',
  '/dashboard', '/settings',
  '/budget', '/budget/add-expense', '/future-events', '/event-funding',
  '/combined-wallet', '/wallet-details',
  '/combined-analytics',
]);

// ─────────────────────────────────────────────────────────────────────────────
export default function DashboardScreen() {
  const navigate = useNavigate();
  const { language } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;

  const [editMode, setEditMode] = useState(false);

  // Announcements (local state — no backend, same as Flutter)
  const [announcements, setAnnouncements] = useState([]);
  const [showAnnModal, setShowAnnModal]   = useState(false);
  const [annTitle, setAnnTitle]           = useState('');
  const [annContent, setAnnContent]       = useState('');

  // Family events (local state — no backend, same as Flutter)
  const [events, setEvents]             = useState([
    { id: 1, title: 'Family Game Night', description: 'Every Friday at 7 PM!', imageUrl: 'https://picsum.photos/seed/game/300/200' },
  ]);
  const [showEventModal, setShowEventModal] = useState(false);
  const [eventTitle, setEventTitle]         = useState('');
  const [eventDesc, setEventDesc]           = useState('');

  // Notifications (inventory alerts)
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifs, setShowNotifs] = useState(false);
  const [notifList, setNotifList] = useState([]);

  const loadUnreadCount = useCallback(async () => {
    try {
      const res = await api.get('/inventory-alerts/unread-count');
      setUnreadCount(res.data?.data?.unreadCount || 0);
    } catch { /* silent */ }
  }, []);

  useEffect(() => { loadUnreadCount(); }, [loadUnreadCount]);

  async function openNotifs() {
    setShowNotifs(true);
    api.post('/inventory-alerts/generate').catch(() => {});
    try {
      const res = await api.get('/inventory-alerts');
      const alerts = (res.data?.data?.alerts || []).map(a => ({
        id: a._id || '',
        alertType: a.alert_type || '',
        message: a.alert_message || a.message || 'Inventory alert',
        isRead: a.is_read === true,
        time: a.createdAt || a.created_at || null,
      }));
      alerts.sort((x, y) => {
        const tx = x.time ? new Date(x.time).getTime() : 0;
        const ty = y.time ? new Date(y.time).getTime() : 0;
        return ty - tx;
      });
      setNotifList(alerts);
    } catch {
      setNotifList([]);
    }
  }

  async function markAllNotifsRead() {
    try {
      await api.patch('/inventory-alerts/mark-all-read');
      setUnreadCount(0);
      setNotifList(prev => prev.map(a => ({ ...a, isRead: true })));
    } catch { /* silent */ }
  }

  async function markOneNotifRead(alert) {
    try {
      await api.patch(`/inventory-alerts/${alert.id}/read`);
      setNotifList(prev => prev.map(a => a.id === alert.id ? { ...a, isRead: true } : a));
      setUnreadCount(prev => Math.max(0, prev - 1));
    } catch { /* silent */ }
  }

  function notifIcon(alertType) {
    switch (alertType) {
      case 'low_stock':     return '📦';
      case 'expiring_soon': return '⏰';
      case 'expired':       return '⚠️';
      default:              return '📦';
    }
  }

  function relativeTime(dt) {
    const diff = Date.now() - new Date(dt).getTime();
    const mins  = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    if (mins < 1)   return 'just now';
    if (mins < 60)  return `${mins} min ago`;
    if (hours < 24) return `${hours} hr ago`;
    return new Date(dt).toLocaleDateString();
  }

  // Toast
  const [toast, setToast] = useState(null);
  const showToast = msg => { setToast(msg); setTimeout(() => setToast(null), 2500); };

  // ── Module tap ────────────────────────────────────────────────────────────
  function handleModuleClick(route) {
    if (IMPLEMENTED.has(route)) {
      navigate(route);
    } else {
      showToast(`${t('Coming soon', 'قريباً')} ✨`);
    }
  }

  // ── Add announcement ──────────────────────────────────────────────────────
  function addAnnouncement() {
    if (!annTitle.trim()) return;
    setAnnouncements(prev => [{ id: Date.now(), title: annTitle, content: annContent }, ...prev]);
    setAnnTitle(''); setAnnContent('');
    setShowAnnModal(false);
  }

  // ── Add event ─────────────────────────────────────────────────────────────
  function addEvent() {
    if (!eventTitle.trim()) return;
    const seed = Date.now();
    setEvents(prev => [...prev, {
      id: seed,
      title: eventTitle,
      description: eventDesc,
      imageUrl: `https://picsum.photos/seed/${seed}/300/200`,
    }]);
    setEventTitle(''); setEventDesc('');
    setShowEventModal(false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="ds-root">
      <div className="ds-scroll">
        <div className="ds-content">

          {/* ── Header ───────────────────────────────────────────────────── */}
          <div className="ds-header">
            <div className="ds-header-avatar"><span>👨‍👩‍👧‍👦</span></div>
            <div className="ds-header-text">
              <span className="ds-header-title">{t('Family Dashboard', 'لوحة العائلة')}</span>
              <span className="ds-header-sub">{t('Manage your family activities', 'إدارة أنشطة عائلتك')}</span>
            </div>
            <button className="ds-notif-btn" title={t('Notifications', 'الإشعارات')} onClick={openNotifs}>
              🔔
              {unreadCount > 0 && <span className="ds-notif-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>}
            </button>
          </div>

          {/* ── Categories / Modules ─────────────────────────────────────── */}
          <div className="ds-section">
            <div className="ds-section-row">
              <span className="ds-section-label">{t('CATEGORIES', 'الفئات')}</span>
              <div className="ds-edit-row">
                <span className="ds-edit-label">{t('Edit Mode', 'وضع التعديل')}</span>
                <div
                  className={`ds-toggle${editMode ? ' on' : ''}`}
                  onClick={() => setEditMode(v => !v)}
                >
                  <div className="ds-toggle-knob" />
                </div>
              </div>
            </div>
            <div className="ds-grid">
              {MODULES.map(m => (
                <div key={m.label} className="ds-module-card" onClick={() => handleModuleClick(m.route)}>
                  <div className="ds-module-icon" style={{ background: m.iconBg }}>
                    <span style={{ color: m.iconColor, fontSize: 18 }}>{m.emoji}</span>
                  </div>
                  <span className="ds-module-label">{t(m.label, m.labelAr)}</span>
                  {editMode && <span className="ds-drag-icon">⠿</span>}
                </div>
              ))}
            </div>
          </div>

          {/* ── Announcements ────────────────────────────────────────────── */}
          <div className="ds-section">
            <div className="ds-section-row">
              <span className="ds-section-label">{t('ANNOUNCEMENTS', 'الإعلانات')}</span>
              <button className="ds-add-btn" onClick={() => setShowAnnModal(true)}>+</button>
            </div>
            {announcements.length === 0 ? (
              <div className="ds-card ds-empty-ann">
                <span style={{ fontSize: 18 }}>📣</span>
                <span className="ds-empty-text">{t('No announcements yet. Tap + to add one!', 'لا توجد إعلانات. اضغط + للإضافة!')}</span>
              </div>
            ) : (
              <div className="ds-card">
                {announcements.map((ann, i) => (
                  <div key={ann.id} className={`ds-ann-item${i < announcements.length - 1 ? ' has-border' : ''}`}>
                    <div className="ds-ann-icon">📣</div>
                    <div className="ds-ann-body">
                      <span className="ds-ann-title">{ann.title}</span>
                      {ann.content && <span className="ds-ann-content">{ann.content}</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* ── Family Events ────────────────────────────────────────────── */}
          <div className="ds-section">
            <div className="ds-section-row">
              <span className="ds-section-label">{t('FAMILY EVENTS', 'أحداث العائلة')}</span>
              <button className="ds-add-btn" onClick={() => setShowEventModal(true)}>+</button>
            </div>
            <div className="ds-events-scroll">
              {events.map(ev => (
                <div
                  key={ev.id}
                  className="ds-event-card"
                  style={{ backgroundImage: `linear-gradient(rgba(0,0,0,0.45), rgba(0,0,0,0.45)), url(${ev.imageUrl})` }}
                >
                  <span className="ds-event-title">{ev.title}</span>
                  <span className="ds-event-desc">{ev.description}</span>
                </div>
              ))}
            </div>
          </div>

          <div style={{ height: 80 }} />
        </div>
      </div>

      <BottomNavBar activeIndex={1} />

      {/* ── Announcement Modal ───────────────────────────────────────────── */}
      {showAnnModal && (
        <div className="ds-overlay" onClick={() => setShowAnnModal(false)}>
          <div className="ds-dialog" onClick={e => e.stopPropagation()}>
            <h3>{t('New Announcement', 'إعلان جديد')}</h3>
            <div className="ds-form-group">
              <input
                type="text"
                placeholder={t('Title', 'العنوان')}
                value={annTitle}
                onChange={e => setAnnTitle(e.target.value)}
              />
            </div>
            <div className="ds-form-group">
              <textarea
                rows={3}
                placeholder={t('Content', 'المحتوى')}
                value={annContent}
                onChange={e => setAnnContent(e.target.value)}
              />
            </div>
            <div className="ds-dialog-actions">
              <button className="ds-btn-text" onClick={() => setShowAnnModal(false)}>{t('Cancel', 'إلغاء')}</button>
              <button className="ds-btn-primary" onClick={addAnnouncement}>{t('Add', 'إضافة')}</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Event Modal ──────────────────────────────────────────────────── */}
      {showEventModal && (
        <div className="ds-overlay" onClick={() => setShowEventModal(false)}>
          <div className="ds-dialog" onClick={e => e.stopPropagation()}>
            <h3>{t('New Event', 'حدث جديد')}</h3>
            <div className="ds-form-group">
              <input
                type="text"
                placeholder={t('Event Title', 'عنوان الحدث')}
                value={eventTitle}
                onChange={e => setEventTitle(e.target.value)}
              />
            </div>
            <div className="ds-form-group">
              <input
                type="text"
                placeholder={t('Description', 'الوصف')}
                value={eventDesc}
                onChange={e => setEventDesc(e.target.value)}
              />
            </div>
            <div className="ds-dialog-actions">
              <button className="ds-btn-text" onClick={() => setShowEventModal(false)}>{t('Cancel', 'إلغاء')}</button>
              <button className="ds-btn-primary" onClick={addEvent}>{t('Add', 'إضافة')}</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Notification Bottom Sheet ───────────────────────────────── */}
      {showNotifs && (
        <div className="ds-overlay" onClick={() => setShowNotifs(false)}>
          <div className="ds-notif-sheet" onClick={e => e.stopPropagation()}>
            <div className="ds-notif-sheet-handle" />
            <div className="ds-notif-sheet-header">
              <span style={{ fontSize: 20 }}>🔔</span>
              <span className="ds-notif-sheet-title">{t('Notifications', 'الإشعارات')}</span>
              <button className="ds-notif-mark-all" onClick={markAllNotifsRead}>{t('Mark all read', 'قراءة الكل')}</button>
            </div>
            <div className="ds-notif-divider" />
            <div className="ds-notif-list">
              {notifList.length === 0 ? (
                <div className="ds-notif-empty">{t('No notifications yet', 'لا توجد إشعارات')}</div>
              ) : (
                notifList.map((alert, i) => {
                  const time = alert.time ? relativeTime(alert.time) : '';
                  return (
                    <div key={alert.id || i} className={`ds-notif-row ${alert.isRead ? 'read' : 'unread'}`}>
                      <div className={`ds-notif-icon ${alert.isRead ? 'read' : ''}`}>{notifIcon(alert.alertType)}</div>
                      <div className="ds-notif-body">
                        <span className={`ds-notif-msg ${alert.isRead ? '' : 'bold'}`}>{alert.message}</span>
                        <span className="ds-notif-time">{time}</span>
                      </div>
                      {!alert.isRead && (
                        <button className="ds-notif-read-btn" onClick={() => markOneNotifRead(alert)}>
                          {t('Read', 'قراءة')}
                        </button>
                      )}
                      {alert.isRead && <span className="ds-notif-done">✓</span>}
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {toast && <div className="ds-toast">{toast}</div>}
    </div>
  );
}
