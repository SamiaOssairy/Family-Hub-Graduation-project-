// ═══════════════════════════════════════════════════════════════════════════════
// FamilyMapScreen — React equivalent of flutter_app/lib/pages/family_map_screen.dart
// Location module: shows family member locations on a map with GPS tracking.
// Uses react-leaflet + OpenStreetMap (same as Flutter's flutter_map + OSM tiles)
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect, useRef, useCallback } from 'react';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useTheme } from '../context/ThemeContext';
import { useAuth } from '../context/AuthContext';
import BottomNavBar from '../components/common/BottomNavBar';
import api from '../api/apiService';
import './FamilyMapScreen.css';

// ── Fix leaflet default icon paths broken by webpack ─────────────────────────
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
  iconUrl:       require('leaflet/dist/images/marker-icon.png'),
  shadowUrl:     require('leaflet/dist/images/marker-shadow.png'),
});

// ── Cairo default center (matches Flutter's default) ─────────────────────────
const DEFAULT_CENTER = [30.0444, 31.2357];

// ── Marker color palette (matches Flutter's _markerColors) ───────────────────
const MARKER_COLORS = [
  '#1E88E5', '#E53935', '#43A047', '#FB8C00',
  '#8E24AA', 'var(--color-primary)', '#D81B60', '#6D4C41',
];
// "You" marker color
const MY_COLOR = '#1AA7EC';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
function colorForIndex(i) { return MARKER_COLORS[i % MARKER_COLORS.length]; }

function initials(name) {
  const parts = (name || 'U').trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return name.substring(0, Math.min(2, name.length)).toUpperCase();
}

function hasCoordinates(loc) {
  return typeof loc.latitude === 'number' && typeof loc.longitude === 'number';
}

function isMemberOnline(loc, isYou = false) {
  if (isYou) return true;
  if (!loc.is_sharing_enabled) return false;
  const dateStr = loc.last_updated;
  if (!dateStr) return false;
  const dt = new Date(dateStr);
  return Date.now() - dt.getTime() <= 2 * 60 * 1000; // 2 minutes
}

function relativeTime(dt) {
  const diff = Date.now() - new Date(dt).getTime();
  const secs  = Math.floor(diff / 1000);
  const mins  = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  if (secs < 60)  return 'just now';
  if (mins < 60)  return `${mins} min ago`;
  if (hours < 24) return `${hours} hr ago`;
  return new Date(dt).toLocaleDateString();
}

function alertIcon(alert) {
  switch (alert.alertType) {
    case 'sos':              return '🆘';
    case 'sharing_disabled': return '🚫';
    case 'geofence':         return '📍';
    default:                 return '📍';
  }
}

function memberPresence(loc) {
  const lu = loc.last_updated;
  if (!lu) return 'No location update yet';
  const dt = new Date(lu);
  if (isNaN(dt.getTime())) return 'No location update yet';
  const timeText = relativeTime(lu);
  return isMemberOnline(loc) ? `Online ${timeText}` : `Last update ${timeText}`;
}

// Haversine distance in metres
function distanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Create a custom Leaflet DivIcon for a family member ───────────────────────
function buildMemberIcon(initStr, color, name, isOnline) {
  const dot = isOnline ? 'var(--color-primary)' : '#9E9E9E';
  const firstWord = (name || '').split(' ')[0];
  const html = `
    <div style="display:flex;flex-direction:column;align-items:center;width:90px;">
      <div style="background:rgba(255,255,255,0.94);border-radius:18px;padding:4px 10px;
                  display:flex;align-items:center;gap:5px;white-space:nowrap;
                  box-shadow:0 1px 4px rgba(0,0,0,0.12);">
        <span style="width:7px;height:7px;border-radius:50%;background:${dot};
                     display:inline-block;flex-shrink:0;"></span>
        <span style="font-family:sans-serif;font-size:11px;font-weight:700;
                     color:#212121;">${firstWord}</span>
      </div>
      <div style="margin-top:5px;width:48px;height:48px;border-radius:50%;
                  background:linear-gradient(135deg,${color},${color}BB);
                  border:3px solid white;display:flex;align-items:center;
                  justify-content:center;box-shadow:0 4px 12px ${color}44;">
        <span style="color:white;font-weight:800;font-size:15px;">${initStr}</span>
      </div>
      <div style="width:0;height:0;border-left:6px solid transparent;
                  border-right:6px solid transparent;border-top:8px solid ${color};
                  margin-top:0;"></div>
    </div>`;
  return L.divIcon({ html, className: '', iconSize: [90, 96], iconAnchor: [45, 96] });
}

// "You" marker icon
function buildYouIcon(initStr) {
  const html = `
    <div style="display:flex;flex-direction:column;align-items:center;width:90px;">
      <div style="background:rgba(255,255,255,0.94);border-radius:18px;padding:4px 10px;
                  box-shadow:0 1px 4px rgba(0,0,0,0.12);">
        <span style="font-family:sans-serif;font-size:11px;font-weight:800;color:#212121;">You</span>
      </div>
      <div style="margin-top:5px;width:54px;height:54px;border-radius:50%;
                  background:linear-gradient(135deg,#1AA7EC,#4FC3A1);
                  border:3px solid white;display:flex;align-items:center;
                  justify-content:center;box-shadow:0 4px 12px #1AA7EC44;">
        <span style="color:white;font-weight:800;font-size:17px;">${initStr}</span>
      </div>
      <div style="width:0;height:0;border-left:7px solid transparent;
                  border-right:7px solid transparent;border-top:10px solid #1AA7EC;
                  margin-top:0;"></div>
    </div>`;
  return L.divIcon({ html, className: '', iconSize: [90, 104], iconAnchor: [45, 104] });
}

// ── MapController — inner component to imperatively control the map ───────────
function MapMover({ target }) {
  const map = useMap();
  useEffect(() => {
    if (target) map.setView(target, 15, { animate: true });
  }, [map, target]);
  return null;
}

// ── RecenterButton — inner component that uses map context ────────────────────
function RecenterControl({ center }) {
  const map = useMap();
  return (
    <button
      className="fm-fab fm-fab-white"
      title="My location"
      onClick={() => map.setView(center, 15, { animate: true })}
    >
      🎯
    </button>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main component
// ─────────────────────────────────────────────────────────────────────────────
export default function FamilyMapScreen() {
  const { language } = useTheme();
  const { username: authUsername } = useAuth();
  const t = (en, ar) => language === 'ar' ? ar : en;

  const [familyLocations, setFamilyLocations] = useState([]);
  const [myPosition,      setMyPosition]      = useState(null);   // [lat, lng]
  const [myMail,          setMyMail]          = useState(null);
  const [myUsername,      setMyUsername]      = useState(authUsername || 'You');
  const [isSharingEnabled, setIsSharingEnabled] = useState(true);
  const [loading,         setLoading]         = useState(true);
  const [error,           setError]           = useState(null);
  const [selectedMember,  setSelectedMember]  = useState(null);
  const [unreadAlerts,    setUnreadAlerts]     = useState(0);
  const [showAlerts,      setShowAlerts]       = useState(false);
  const [alertsList,      setAlertsList]       = useState([]);
  const [showSosDialog,   setShowSosDialog]    = useState(false);
  const [mapMoveTarget,   setMapMoveTarget]    = useState(null);   // for RecenterControl
  const [toast,           setToast]            = useState(null);

  // Sync-throttle refs
  const lastSyncAt        = useRef(null);
  const lastSyncedPos     = useRef(null);
  const syncingRef        = useRef(false);
  const refreshTimerRef   = useRef(null);
  const mapCenterRef      = useRef(DEFAULT_CENTER);

  // ── Toast helper ─────────────────────────────────────────────────────────
  function showToast(msg, isError = false) {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  }

  // ── GPS location sync ────────────────────────────────────────────────────
  const syncMyLocation = useCallback(async () => {
    if (syncingRef.current) return;
    if (!navigator.geolocation) return;
    syncingRef.current = true;
    try {
      const pos = await new Promise((resolve, reject) =>
        navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 8000 })
      );
      const newLat = pos.coords.latitude;
      const newLng = pos.coords.longitude;
      setMyPosition([newLat, newLng]);

      const now = Date.now();
      const last = lastSyncAt.current;
      const lp   = lastSyncedPos.current;
      const intervalPassed = !last || now - last >= 45000;
      const movedEnough    = !lp || distanceMeters(lp[0], lp[1], newLat, newLng) >= 20;

      if (isSharingEnabled && (intervalPassed || movedEnough)) {
        await api.post('/location/update', { latitude: newLat, longitude: newLng });
        lastSyncAt.current      = now;
        lastSyncedPos.current   = [newLat, newLng];
      }
    } catch { /* GPS unavailable or denied — silent */ }
    finally { syncingRef.current = false; }
  }, [isSharingEnabled]);

  // ── Load all data ────────────────────────────────────────────────────────
  const loadData = useCallback(async (silent = false) => {
    if (!silent) { setLoading(true); setError(null); }
    try {
      // Get my location settings
      try {
        const myRes = await api.get('/location/me');
        const locData = myRes.data?.data?.location;
        if (locData) {
          setIsSharingEnabled(locData.is_sharing_enabled ?? true);
          setMyMail(locData.member_mail || null);
        }
      } catch { /* silent */ }

      // Sync GPS
      await syncMyLocation();

      // Parallel: family locations + location alert count (location only)
      const [famRes, alertCountRes] = await Promise.allSettled([
        api.get('/location/family'),
        api.get('/location/alerts/unread-count'),
      ]);

      let locations = [];
      if (famRes.status === 'fulfilled') {
        locations = famRes.value.data?.data?.locations || [];
      }

      let unread = 0;
      if (alertCountRes.status === 'fulfilled') {
        unread = alertCountRes.value.data?.data?.count || 0;
      }

      // Filter out self
      const filtered = myMail
        ? locations.filter(l => l.member_mail !== myMail)
        : locations;

      setFamilyLocations(filtered);
      setUnreadAlerts(unread);
      setLoading(false);
      setError(null);
    } catch (e) {
      if (!silent) {
        setError(e?.response?.data?.message || 'Failed to load location data');
        setLoading(false);
      }
    }
  }, [syncMyLocation, myMail]);

  // ── Initial load + 20s auto-refresh ──────────────────────────────────────
  useEffect(() => {
    loadData();
    refreshTimerRef.current = setInterval(() => loadData(true), 20000);
    return () => {
      clearInterval(refreshTimerRef.current);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Compute map center ────────────────────────────────────────────────────
  function mapCenter() {
    if (myPosition) return myPosition;
    const valid = familyLocations.filter(hasCoordinates);
    if (valid.length === 0) return DEFAULT_CENTER;
    const lat = valid.reduce((s, l) => s + l.latitude,  0) / valid.length;
    const lng = valid.reduce((s, l) => s + l.longitude, 0) / valid.length;
    return [lat, lng];
  }
  const center = mapCenter();
  mapCenterRef.current = center;

  // ── Sharing toggle ────────────────────────────────────────────────────────
  async function toggleSharing() {
    const newVal = !isSharingEnabled;
    try {
      await api.patch('/location/toggle', { is_sharing_enabled: newVal });
      setIsSharingEnabled(newVal);
      showToast(newVal ? 'Location sharing enabled' : 'Location sharing disabled');
    } catch (e) {
      showToast('Error: ' + (e?.response?.data?.message || 'Failed to toggle'), true);
    }
  }

  // ── Directions ────────────────────────────────────────────────────────────
  function openDirections(loc) {
    if (!hasCoordinates(loc)) {
      showToast('This member has no saved location yet.', true);
      return;
    }
    const dest = `${loc.latitude},${loc.longitude}`;
    const origin = myPosition ? `${myPosition[0]},${myPosition[1]}` : '';
    const url = origin
      ? `https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${dest}&travelmode=driving`
      : `https://www.google.com/maps/dir/?api=1&destination=${dest}&travelmode=driving`;
    window.open(url, '_blank');
  }

  // ── SOS ──────────────────────────────────────────────────────────────────
  async function sendSOS() {
    setShowSosDialog(false);
    try {
      await api.post('/location/alerts', {
        alert_type: 'sos',
        message:    'Emergency SOS! I need help!',
      });
      showToast('SOS alert sent to all family members!');
    } catch (e) {
      showToast('Failed to send SOS: ' + (e?.response?.data?.message || 'Error'), true);
    }
  }

  // ── Unified notification center (location + inventory) ─────────────────────
  async function openAlerts() {
    setShowAlerts(true);

    try {
      const locRes = await api.get('/location/alerts');
      const alerts = (locRes.data?.data?.alerts || []).map(a => ({
        id: a._id || '',
        source: 'location',
        alertType: a.alert_type || '',
        message: a.message || 'Location alert',
        isRead: a.is_read === true,
        time: a.created_at || a.createdAt || null,
      }));
      alerts.sort((x, y) => {
        const tx = x.time ? new Date(x.time).getTime() : 0;
        const ty = y.time ? new Date(y.time).getTime() : 0;
        return ty - tx;
      });
      setAlertsList(alerts);
    } catch {
      setAlertsList([]);
    }
  }

  async function markAllRead() {
    try {
      await api.patch('/location/alerts/read-all');
      setUnreadAlerts(0);
      setAlertsList(prev => prev.map(a => ({ ...a, isRead: true })));
    } catch { /* silent */ }
  }

  async function markOneRead(alert) {
    try {
      await api.patch(`/location/alerts/${alert.id}/read`);
      setUnreadAlerts(prev => Math.max(0, prev - 1));
      setAlertsList(prev => prev.map(a => (a.id === alert.id ? { ...a, isRead: true } : a)));
    } catch { /* silent */ }
  }

  // ──────────────────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="fm-root fm-center">
        <div className="fm-spinner" />
        <BottomNavBar activeIndex={3} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="fm-root fm-center fm-error-wrap">
        <div className="fm-error-content">
          <span className="fm-error-icon">📍</span>
          <p className="fm-error-msg">{error}</p>
          <button className="fm-retry-btn" onClick={() => loadData()}>Retry</button>
        </div>
        <BottomNavBar activeIndex={3} />
      </div>
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="fm-root">

      {/* ── Map ───────────────────────────────────────────────────────────── */}
      <div className="fm-map-wrap">
        <MapContainer
          center={center}
          zoom={familyLocations.length === 0 ? 15 : 13}
          style={{ width: '100%', height: '100%' }}
          onClick={() => setSelectedMember(null)}
          zoomControl={false}
        >
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='© <a href="https://openstreetmap.org/copyright">OpenStreetMap</a>'
          />
          {/* Recenter imperative control */}
          {mapMoveTarget && <MapMover target={mapMoveTarget} />}

          {/* "You" marker */}
          {myPosition && (
            <Marker
              position={myPosition}
              icon={buildYouIcon(initials(myUsername))}
              eventHandlers={{ click: () => setSelectedMember({
                member_username: myUsername,
                member_type: 'You',
                member_mail: myMail || '',
                last_updated: new Date().toISOString(),
                _isYou: true,
              })}}
            />
          )}

          {/* Family member markers */}
          {familyLocations.filter(hasCoordinates).map((loc, i) => (
            <Marker
              key={loc._id || i}
              position={[loc.latitude, loc.longitude]}
              icon={buildMemberIcon(
                initials(loc.member_username || 'U'),
                isMemberOnline(loc) ? colorForIndex(i) : '#9E9E9E',
                loc.member_username || 'Unknown',
                isMemberOnline(loc),
              )}
              eventHandlers={{ click: () => setSelectedMember(loc) }}
            />
          ))}
        </MapContainer>

        {/* ── Top header bar ────────────────────────────────────────────── */}
        <div className="fm-top-bar">
          <div className="fm-top-bar-icon">🗺️</div>
          <div className="fm-top-bar-text">
            <span className="fm-top-bar-title">Family Map</span>
            <span className="fm-top-bar-sub">
              {myPosition == null
                ? 'Waiting for your location'
                : `You + ${familyLocations.length} family members`}
            </span>
          </div>
          <div style={{ flex: 1 }} />
          {/* Notification bell */}
          <button className="fm-notif-btn" onClick={openAlerts}>
            🔔
            {unreadAlerts > 0 && (
              <span className="fm-notif-badge">{unreadAlerts > 99 ? '99+' : unreadAlerts}</span>
            )}
          </button>
          <div className="fm-live-pill">
            {familyLocations.length + (myPosition ? 1 : 0)} live
          </div>
        </div>

        {/* ── "You" badge (top-left below header) ───────────────────────── */}
        {myPosition && (
          <div className="fm-you-badge">
            <div className="fm-you-avatar">
              <span>{initials(myUsername)}</span>
            </div>
            <div className="fm-you-info">
              <span className="fm-you-name">You</span>
              <span className="fm-you-sub">
                {isSharingEnabled ? 'Live now' : 'Visible only to you'}
              </span>
            </div>
          </div>
        )}

        {/* ── Right FAB column ──────────────────────────────────────────── */}
        <div className="fm-fab-col">
          <button
            className={`fm-fab ${isSharingEnabled ? 'fm-fab-primary' : 'fm-fab-grey'}`}
            title={isSharingEnabled ? 'Stop sharing' : 'Start sharing'}
            onClick={toggleSharing}
          >
            {isSharingEnabled ? '📍' : '🚫'}
          </button>
          <button
            className="fm-fab fm-fab-white"
            title="Recenter"
            onClick={() => setMapMoveTarget([...center, Date.now()])}
          >
            🎯
          </button>
          <button
            className="fm-fab fm-fab-sos"
            title="SOS"
            onClick={() => setShowSosDialog(true)}
          >
            SOS
          </button>
        </div>

        {/* ── Detail card (tapped member) ───────────────────────────────── */}
        {selectedMember && (
          <div className={`fm-detail-card ${familyLocations.length > 0 ? 'above-chips' : ''}`}>
            <div className="fm-detail-inner">
              {(() => {
                const loc  = selectedMember;
                const name = loc.member_username || 'Unknown';
                const type = loc.member_type || 'Member';
                const mail = loc.member_mail || '';
                const isYou = !!loc._isYou;
                const idx  = familyLocations.findIndex(l => l.member_mail === loc.member_mail);
                const col  = isYou ? MY_COLOR : colorForIndex(idx >= 0 ? idx : 0);
                const online = isMemberOnline(loc, isYou);
                return (
                  <>
                    <div className="fm-detail-avatar" style={{ background: `linear-gradient(135deg,${col},${col}BB)` }}>
                      <span>{initials(name)}</span>
                    </div>
                    <div className="fm-detail-body">
                      <span className="fm-detail-name">{name}</span>
                      <div className="fm-detail-row">
                        <span className={`fm-online-dot ${online ? 'on' : 'off'}`} />
                        <span className="fm-detail-status">{online ? 'Online' : 'Offline'}</span>
                        <span className="fm-detail-type">{type}</span>
                      </div>
                      <span className="fm-detail-mail">{mail}</span>
                      <span className="fm-detail-time">⏱ {memberPresence(loc)}</span>
                      {!isYou && (
                        <button
                          className="fm-directions-btn"
                          onClick={() => openDirections(loc)}
                          disabled={!hasCoordinates(loc)}
                        >
                          🗺 Directions
                        </button>
                      )}
                    </div>
                    <button className="fm-detail-close" onClick={() => setSelectedMember(null)}>✕</button>
                  </>
                );
              })()}
            </div>
          </div>
        )}

        {/* ── Bottom member chips carousel ──────────────────────────────── */}
        {familyLocations.length > 0 && (
          <div className="fm-chips-strip">
            <div className="fm-chips-scroll">
              {familyLocations.map((loc, i) => {
                const name = loc.member_username || 'Unknown';
                const col  = isMemberOnline(loc) ? colorForIndex(i) : '#9E9E9E';
                const isSel = selectedMember?.member_mail === loc.member_mail;
                return (
                  <button
                    key={loc._id || i}
                    className={`fm-chip ${isSel ? 'fm-chip-selected' : ''}`}
                    onClick={() => {
                      if (hasCoordinates(loc)) {
                        setMapMoveTarget([loc.latitude, loc.longitude, Date.now()]);
                      }
                      setSelectedMember(loc);
                    }}
                  >
                    <div
                      className="fm-chip-avatar"
                      style={{
                        background: `linear-gradient(135deg,${col},${col}BB)`,
                        boxShadow: isSel ? `0 2px 10px ${col}66` : 'none',
                        border: `3px solid ${isSel ? 'white' : 'transparent'}`,
                      }}
                    >
                      <span>{initials(name)}</span>
                    </div>
                    <div className="fm-chip-row">
                      <span className={`fm-chip-dot ${isMemberOnline(loc) ? 'on' : 'off'}`} />
                      <span className="fm-chip-name">{name.split(' ')[0]}</span>
                    </div>
                    <span className="fm-chip-time">{memberPresence(loc)}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* ── Alerts Bottom Sheet ───────────────────────────────────────────── */}
      {showAlerts && (
        <div className="fm-sheet-overlay" onClick={() => setShowAlerts(false)}>
          <div className="fm-sheet" onClick={e => e.stopPropagation()}>
            <div className="fm-sheet-handle" />
            <div className="fm-sheet-header">
              <span className="fm-sheet-icon">🔔</span>
              <span className="fm-sheet-title">Notifications</span>
              <button className="fm-sheet-mark-all" onClick={markAllRead}>Mark all read</button>
            </div>
            <div className="fm-sheet-divider" />
            <div className="fm-sheet-list">
              {alertsList.length === 0 ? (
                <div className="fm-sheet-empty">No notifications yet</div>
              ) : (
                alertsList.map((alert, i) => {
                  const time = alert.time ? relativeTime(alert.time) : '';
                  return (
                    <div key={alert.id || i} className={`fm-alert-row ${alert.isRead ? 'read' : 'unread'}`}>
                      <div className={`fm-alert-icon ${alert.isRead ? 'read' : ''}`}>{alertIcon(alert)}</div>
                      <div className="fm-alert-body">
                        <span className={`fm-alert-msg ${alert.isRead ? '' : 'bold'}`}>{alert.message}</span>
                        <span className="fm-alert-time">
                          Location{time ? ` · ${time}` : ''}
                        </span>
                      </div>
                      {!alert.isRead && (
                        <button className="fm-alert-read-btn" onClick={() => markOneRead(alert)}>
                          Read
                        </button>
                      )}
                      {alert.isRead && <span className="fm-alert-done">✓</span>}
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── SOS Confirmation Dialog ───────────────────────────────────────── */}
      {showSosDialog && (
        <div className="fm-dialog-overlay" onClick={() => setShowSosDialog(false)}>
          <div className="fm-dialog" onClick={e => e.stopPropagation()}>
            <div className="fm-dialog-title-row">
              <span>⚠️</span>
              <span className="fm-dialog-title">Send SOS Alert</span>
            </div>
            <p className="fm-dialog-body">
              This will send an emergency alert to all family members with your current location. Continue?
            </p>
            <div className="fm-dialog-actions">
              <button className="fm-dialog-cancel" onClick={() => setShowSosDialog(false)}>Cancel</button>
              <button className="fm-dialog-sos" onClick={sendSOS}>Send SOS</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Toast ─────────────────────────────────────────────────────────── */}
      {toast && (
        <div className={`fm-toast ${toast.isError ? 'error' : ''}`}>{toast.msg}</div>
      )}

      <BottomNavBar activeIndex={3} />
    </div>
  );
}
