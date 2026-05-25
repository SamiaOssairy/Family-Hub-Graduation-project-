// ═══════════════════════════════════════════════════════════════
// Inventory Alerts Screen — mirrors inventory_alerts_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import {
  TrendingDown, ShoppingCart, Clock, AlertTriangle, Bell, RefreshCw, Trash2,
} from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const FILTER_TYPES = [
  { key: 'all', label: 'All', icon: Bell },
  { key: 'low_stock', label: 'Low Stock', icon: TrendingDown },
  { key: 'out_of_stock', label: 'Out of Stock', icon: ShoppingCart },
  { key: 'expiring_soon', label: 'Expiring', icon: Clock },
  { key: 'expired', label: 'Expired', icon: AlertTriangle },
];

function alertColor(type) {
  switch (type) {
    case 'low_stock': return '#FB8C00';
    case 'out_of_stock': return '#E53935';
    case 'expiring_soon': return '#F9A825';
    case 'expired': return '#C62828';
    default: return '#00897B';
  }
}

function alertLabel(type) {
  switch (type) {
    case 'low_stock': return 'Low Stock';
    case 'out_of_stock': return 'Out of Stock';
    case 'expiring_soon': return 'Expiring Soon';
    case 'expired': return 'Expired';
    default: return 'Alert';
  }
}

function alertIconEl(type, size = 22) {
  const color = alertColor(type);
  switch (type) {
    case 'low_stock': return <TrendingDown size={size} color={color} />;
    case 'out_of_stock': return <ShoppingCart size={size} color={color} />;
    case 'expiring_soon': return <Clock size={size} color={color} />;
    case 'expired': return <AlertTriangle size={size} color={color} />;
    default: return <Bell size={size} color={color} />;
  }
}

function timeAgo(dateStr) {
  if (!dateStr) return '';
  try {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  } catch { return ''; }
}

function fmtDate(dateStr) {
  if (!dateStr) return '';
  try { return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return dateStr; }
}

function daysUntil(dateStr) {
  if (!dateStr) return 9999;
  return Math.floor((new Date(dateStr) - Date.now()) / 86400000);
}

export default function InventoryAlertsScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filterType, setFilterType] = useState('all');
  const [generating, setGenerating] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.getInventoryAlertsPersisted();
      setAlerts(Array.isArray(data) ? data : []);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function generateAlerts() {
    setGenerating(true);
    try {
      await api.generateInventoryAlerts();
      await load();
      toast('Alerts refreshed!');
    } catch (e) { toast(e.message, 'error'); }
    finally { setGenerating(false); }
  }

  async function markAllRead() {
    try {
      await api.markAllAlertsAsRead();
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function markAsRead(id) {
    try {
      await api.markAlertAsRead(id);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function deleteAlert(id) {
    try {
      await api.deleteAlert(id);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const filtered = filterType === 'all' ? alerts : alerts.filter(a => a.alert_type === filterType);
  const unread = filtered.filter(a => a.is_read !== true);
  const read = filtered.filter(a => a.is_read === true);
  const unreadCount = alerts.filter(a => a.is_read !== true).length;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Inventory Alerts" actions={
        unreadCount > 0 ? (
          <button onClick={markAllRead} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)',
          }}>Read All</button>
        ) : null
      } />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '0 0 32px' }}>
          {/* Generate button */}
          <div style={{ padding: '16px 20px 0' }}>
            <button onClick={generateAlerts} disabled={generating} style={{
              width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
              background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 12,
              padding: '14px 0', cursor: generating ? 'not-allowed' : 'pointer',
              fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, opacity: generating ? 0.7 : 1,
            }}>
              <RefreshCw size={18} style={{ animation: generating ? 'spin 1s linear infinite' : 'none' }} />
              {generating ? 'Scanning…' : 'Scan Inventory for Alerts'}
            </button>
          </div>

          {/* Filter chips */}
          <div style={{ overflowX: 'auto', display: 'flex', gap: 8, padding: '10px 20px', scrollbarWidth: 'none' }}>
            {FILTER_TYPES.map(({ key, label }) => {
              const count = key === 'all' ? alerts.length : alerts.filter(a => a.alert_type === key).length;
              const selected = filterType === key;
              return (
                <button key={key} onClick={() => setFilterType(key)} style={{
                  flexShrink: 0, padding: '6px 12px', borderRadius: 20, cursor: 'pointer',
                  background: selected ? 'var(--color-primary)' : 'var(--color-white)',
                  border: `1px solid ${selected ? 'var(--color-primary)' : '#E0E0E0'}`,
                  color: selected ? '#fff' : '#616161',
                  fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 11,
                }}>
                  {label} ({count})
                </button>
              );
            })}
          </div>

          {/* Alert list */}
          {filtered.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 20px' }}>
              <div style={{ width: 96, height: 96, borderRadius: 48, background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 20px' }}>
                <Bell size={48} color="var(--color-primary)" />
              </div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: '#00352E', margin: 0 }}>
                {filterType !== 'all' ? `No ${alertLabel(filterType)} alerts` : 'No Alerts'}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#9E9E9E', marginTop: 8 }}>
                {filterType !== 'all'
                  ? 'Try a different filter or scan inventory'
                  : 'Tap "Scan Inventory" to check for low stock and expiring items'}
              </p>
            </div>
          ) : (
            <div style={{ padding: '0 20px' }}>
              {unread.length > 0 && (
                <>
                  <SectionHeader title="New" count={unread.length} />
                  {unread.map(a => <AlertCard key={a._id} alert={a} onMarkRead={markAsRead} onDelete={deleteAlert} />)}
                  <div style={{ height: 16 }} />
                </>
              )}
              {read.length > 0 && (
                <>
                  <SectionHeader title="Read" count={read.length} />
                  {read.map(a => <AlertCard key={a._id} alert={a} onMarkRead={markAsRead} onDelete={deleteAlert} />)}
                </>
              )}
            </div>
          )}
        </div>
      )}

      <style>{`@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

function SectionHeader({ title, count }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: '#9E9E9E' }}>
        {title} ({count})
      </span>
      <div style={{ flex: 1, height: 1, background: '#E0E0E0' }} />
    </div>
  );
}

function AlertCard({ alert, onMarkRead, onDelete }) {
  const type = alert.alert_type;
  const message = alert.alert_message || alert.message || '';
  const isRead = alert.is_read === true;
  const id = alert._id || '';
  const color = alertColor(type);
  const label = alertLabel(type);
  const createdAt = alert.createdAt || '';

  const item = alert.inventory_item_id;
  const itemName = item && typeof item === 'object' ? (item.item_name || '') : '';
  const itemQty = item && typeof item === 'object' ? item.quantity : null;
  const itemThreshold = item && typeof item === 'object' ? item.threshold_quantity : null;
  const unitName = item && typeof item === 'object' && item.unit_id && typeof item.unit_id === 'object'
    ? (item.unit_id.unit_name || '') : '';
  const expiryRaw = item && typeof item === 'object' ? (item.expiry_date || '') : '';
  const categoryName = item && typeof item === 'object' && item.item_category && typeof item.item_category === 'object'
    ? (item.item_category.title || '') : '';

  const expiryDisplay = expiryRaw ? fmtDate(expiryRaw) : '';
  const daysLeft = expiryRaw ? daysUntil(expiryRaw) : 9999;
  const timeStr = timeAgo(createdAt);

  return (
    <div
      onClick={() => !isRead && onMarkRead(id)}
      style={{
        marginBottom: 10, background: 'var(--color-white)', borderRadius: 14,
        border: isRead ? 'none' : `1.5px solid ${color}4D`,
        boxShadow: isRead ? '0 2px 8px rgba(0,0,0,0.02)' : '0 2px 8px rgba(0,0,0,0.05)',
        padding: 14, cursor: isRead ? 'default' : 'pointer',
        display: 'flex', gap: 12, alignItems: 'flex-start',
      }}
    >
      {/* Icon */}
      <div style={{
        padding: 10, borderRadius: 12, flexShrink: 0,
        background: color + '1A',
      }}>
        {alertIconEl(type, 22)}
      </div>

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        {/* Type badge + time */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{
            background: color + '1A', borderRadius: 6, padding: '2px 8px',
          }}>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600, color }}>{label}</span>
          </div>
          {timeStr && (
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#9E9E9E' }}>{timeStr}</span>
          )}
        </div>

        {/* Item name */}
        {itemName && (
          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: '#00352E', margin: '0 0 2px' }}>{itemName}</p>
        )}

        {/* Category */}
        {categoryName && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E', margin: '0 0 8px' }}>{categoryName}</p>
        )}

        {/* Type-specific detail rows */}
        {type === 'expired' && expiryDisplay && (
          <DetailRow icon="📅" text={`Expired on ${expiryDisplay}`} color={color} />
        )}
        {type === 'expiring_soon' && expiryDisplay && (
          <DetailRow icon="⏱️" text={
            daysLeft === 0 ? 'Expires today!' :
            daysLeft === 1 ? `Expires tomorrow · ${expiryDisplay}` :
            `Expires in ${daysLeft} days · ${expiryDisplay}`
          } color={color} />
        )}
        {(type === 'low_stock' || type === 'out_of_stock') && itemQty != null && (
          <>
            <DetailRow icon="📦" text={`Current stock: ${itemQty}${unitName ? ' ' + unitName : ''}`} color={color} />
            {itemThreshold != null && (
              <DetailRow icon="🚩" text={`Minimum threshold: ${itemThreshold}${unitName ? ' ' + unitName : ''}`} color="#9E9E9E" />
            )}
          </>
        )}

        {/* Fallback message */}
        {!itemName && message && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#00352E', margin: '4px 0 0', fontWeight: isRead ? 400 : 500 }}>
            {message}
          </p>
        )}

        {!isRead && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#BDBDBD', margin: '6px 0 0' }}>
            Tap to mark as read
          </p>
        )}
      </div>

      {/* Right side: unread dot + delete */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        {!isRead && (
          <div style={{ width: 8, height: 8, borderRadius: 4, background: color, marginTop: 4 }} />
        )}
        <button onClick={e => { e.stopPropagation(); onDelete(id); }} style={{
          background: 'none', border: 'none', cursor: 'pointer', color: '#BDBDBD', padding: 2,
        }}>
          <Trash2 size={14} />
        </button>
      </div>
    </div>
  );
}

function DetailRow({ icon, text, color }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 5, marginBottom: 4 }}>
      <span style={{ fontSize: 12, flexShrink: 0 }}>{icon}</span>
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 500, color }}>{text}</span>
    </div>
  );
}
