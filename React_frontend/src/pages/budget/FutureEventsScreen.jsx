// ═══════════════════════════════════════════════════════════════
// FutureEventsScreen — mirrors future_events_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { RefreshCw, Plus } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import BottomNavBar from '../../components/common/BottomNavBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

// ── Color / icon palette (mirrors Flutter _eventBg, _eventColors, _eventEmojis) ──
const EVENT_BG = [
  'var(--color-primary-surface)', '#FFF8E1', 'var(--color-background)',
  '#E3F2FD', '#FCE4EC', '#F3E5F5',
];
const EVENT_COLORS = ['#00897B', '#FB8C00', '#43A047', '#1565C0', '#E91E63', '#7B1FA2'];
const EVENT_EMOJIS = ['✈️', '🛍️', '🎒', '🎉', '🏖️', '🎓'];

// ─────────────────────────────────────────────────────────────────
export default function FutureEventsScreen() {
  const navigate = useNavigate();
  const toast = useToast();

  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showSheet, setShowSheet] = useState(false);
  const [editingEvent, setEditingEvent] = useState(null);

  const fetchEvents = useCallback(async () => {
    setLoading(true);
    try {
      const raw = await api.getFutureEvents();
      const normalized = (Array.isArray(raw) ? raw : []).map(e => ({
        ...e,
        name: e.title || e.name || '',
        expected_date: e.event_date || e.expected_date || '',
        estimated_cost: e.estimated_cost || 0,
        saved_amount: e.total_contributed_money || e.saved_amount || 0,
      }));
      setEvents(normalized);
    } catch (e) {
      toast(`Error loading events: ${e.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchEvents(); }, [fetchEvents]);

  const handleDelete = async (eventId) => {
    if (!window.confirm('Are you sure you want to delete this future event?')) return;
    try {
      await api.deleteFutureEvent(eventId);
      toast('Event deleted', 'info');
      fetchEvents();
    } catch (e) {
      toast(e.message, 'error');
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title="Family Events"
        onBack={() => navigate(-1)}
        actions={<IconBtn icon={RefreshCw} onClick={fetchEvents} />}
      />

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', overflowY: 'auto', padding: '14px 14px 100px' }}>
        {loading ? (
          <LoadingSpinner />
        ) : events.length === 0 ? (
          <EmptyState onAdd={() => { setEditingEvent(null); setShowSheet(true); }} />
        ) : (
          events.map((event, i) => (
            <EventCard
              key={event._id || i}
              event={event}
              index={i}
              onEdit={() => { setEditingEvent(event); setShowSheet(true); }}
              onDelete={() => handleDelete(event._id)}
              onFund={() => navigate('/event-funding', { state: { eventId: event._id } })}
            />
          ))
        )}
      </div>

      {/* FAB */}
      <button onClick={() => { setEditingEvent(null); setShowSheet(true); }} style={{
        position: 'fixed', bottom: 80, right: 20,
        width: 54, height: 54, borderRadius: '50%', border: 'none', cursor: 'pointer',
        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        boxShadow: '0 4px 12px rgba(0,137,123,0.35)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10,
      }}>
        <Plus size={26} color="#fff" />
      </button>

      <BottomNavBar activeIndex={1} />

      {showSheet && (
        <EventSheet
          existing={editingEvent}
          onClose={() => setShowSheet(false)}
          onSaved={fetchEvents}
        />
      )}
    </div>
  );
}

// ── Event Card ────────────────────────────────────────────────────
function EventCard({ event, index, onEdit, onDelete, onFund }) {
  const name = event.name || 'Event';
  const expectedDate = event.expected_date || '';
  const estimatedCost = +(event.estimated_cost || 0);
  const savedAmount = +(event.saved_amount || 0);
  const progress = estimatedCost > 0 ? Math.min(savedAmount / estimatedCost, 1) : 0;
  const isFunded = progress >= 1;
  const remaining = estimatedCost - savedAmount;

  const iconBg = EVENT_BG[index % EVENT_BG.length];
  const iconColor = EVENT_COLORS[index % EVENT_COLORS.length];
  const emoji = EVENT_EMOJIS[index % EVENT_EMOJIS.length];

  let dateLabel = expectedDate;
  try {
    if (expectedDate) {
      dateLabel = new Date(expectedDate).toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
    }
  } catch (_) {}

  return (
    <div style={{
      marginBottom: 12, padding: 14, borderRadius: 18, background: '#fff',
      border: `${isFunded ? 1.5 : 0.8}px solid ${isFunded ? '#A5D6A7' : 'var(--color-border)'}`,
      boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
    }}>
      {/* Header row */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 42, height: 42, borderRadius: 13, background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 }}>
          {emoji}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {name}
          </p>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
            Expected: {dateLabel}
          </p>
        </div>
        {isFunded ? (
          <div style={{ padding: '4px 8px', borderRadius: 8, background: 'var(--color-background)' }}>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700, color: 'var(--color-primary)' }}>✓ Funded</span>
          </div>
        ) : (
          <div style={{ display: 'flex', gap: 6 }}>
            <button onClick={onEdit} style={{
              width: 28, height: 28, borderRadius: 8, border: 'none', cursor: 'pointer',
              background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13,
            }}>✏️</button>
            <button onClick={onDelete} style={{
              width: 28, height: 28, borderRadius: 8, border: 'none', cursor: 'pointer',
              background: 'var(--color-error-surface, #FFEBEE)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13,
            }}>🗑️</button>
          </div>
        )}
      </div>

      {/* Progress */}
      <div style={{ marginTop: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 5 }}>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)' }}>
            Target: {estimatedCost.toFixed(0)} EGP
          </span>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 700, color: isFunded ? '#43A047' : iconColor }}>
            {(progress * 100).toFixed(0)}% saved
          </span>
        </div>
        <div style={{ height: 5, borderRadius: 4, background: isFunded ? '#C8E6C9' : 'var(--color-border-light, #E0E0E0)', overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${progress * 100}%`, background: isFunded ? '#43A047' : iconColor, borderRadius: 4, transition: 'width 0.3s' }} />
        </div>
        <p style={{
          fontFamily: 'var(--font-family)', fontSize: 9, margin: '5px 0 0',
          color: isFunded ? '#43A047' : 'var(--color-text-secondary)',
          fontWeight: isFunded ? 600 : 400,
        }}>
          {isFunded
            ? `${savedAmount.toFixed(0)} / ${estimatedCost.toFixed(0)} EGP — Fully funded! 🎉`
            : `Saved: ${savedAmount.toFixed(0)} EGP  ·  Remaining: ${remaining.toFixed(0)} EGP`}
        </p>
      </div>

      {/* Action buttons (only when not funded) */}
      {!isFunded && (
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <button onClick={onFund} style={{
            flex: 1, padding: '8px', borderRadius: 10, border: 'none', cursor: 'pointer',
            background: 'var(--color-primary-surface)',
            fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600, color: 'var(--color-primary)',
          }}>
            Contribute 💰
          </button>
          <button onClick={onFund} style={{
            flex: 1, padding: '8px', borderRadius: 10, border: 'none', cursor: 'pointer',
            background: 'var(--color-primary-surface)',
            fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600, color: 'var(--color-primary)',
          }}>
            Use Points ⭐
          </button>
        </div>
      )}
    </div>
  );
}

// ── Empty State ───────────────────────────────────────────────────
function EmptyState({ onAdd }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 32, minHeight: 300 }}>
      <div style={{ width: 80, height: 80, borderRadius: 24, background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 16 }}>
        <span style={{ fontSize: 40 }}>📅</span>
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', margin: '0 0 8px', textAlign: 'center' }}>
        No events planned yet
      </p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', textAlign: 'center', margin: '0 0 24px' }}>
        Plan for Eid, tuition, back-to-school<br />and get saving reminders.
      </p>
      <button onClick={onAdd} style={{
        padding: '13px 24px', borderRadius: 14, border: 'none', cursor: 'pointer',
        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        boxShadow: 'var(--shadow-primary)',
        fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 700, color: '#fff',
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <Plus size={16} /> Add First Event
      </button>
    </div>
  );
}

// ── Event Sheet (create/edit bottom sheet) ────────────────────────
function EventSheet({ existing, onClose, onSaved }) {
  const toast = useToast();
  const [name, setName] = useState(existing?.name || '');
  const [cost, setCost] = useState(existing ? String(existing.estimated_cost) : '');
  const [saved, setSaved] = useState(existing ? String(existing.saved_amount) : '0');
  const [date, setDate] = useState(() => {
    if (existing?.expected_date) {
      try { return new Date(existing.expected_date).toISOString().split('T')[0]; } catch (_) {}
    }
    const d = new Date(); d.setDate(d.getDate() + 90);
    return d.toISOString().split('T')[0];
  });
  const [reminderMonths, setReminderMonths] = useState(existing?.reminder_months_before || 3);
  const [frequency, setFrequency] = useState(existing?.saving_frequency || 'monthly');
  const [isLoading, setIsLoading] = useState(false);

  const submit = async () => {
    if (!name.trim()) { toast('Please enter an event name', 'error'); return; }
    const costNum = parseFloat(cost);
    if (!costNum) { toast('Please enter a valid estimated cost', 'error'); return; }

    setIsLoading(true);
    try {
      const payload = {
        name: name.trim(),
        expected_date: new Date(date).toISOString(),
        estimated_cost: costNum,
        saved_amount: parseFloat(saved) || 0,
        reminder_months_before: reminderMonths,
        saving_frequency: frequency,
      };
      if (existing) {
        await api.updateFutureEvent(existing._id, payload);
      } else {
        await api.createFutureEvent(payload);
      }
      toast(existing ? 'Event updated!' : 'Event created!', 'success');
      onSaved();
      onClose();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const inputStyle = {
    width: '100%', padding: '12px', borderRadius: 10,
    border: '1px solid var(--color-border)', outline: 'none',
    fontFamily: 'var(--font-family)', fontSize: 14, boxSizing: 'border-box',
    marginBottom: 12,
  };

  return (
    <div
      style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div style={{ background: '#fff', borderRadius: '20px 20px 0 0', padding: 20, maxHeight: '90vh', overflowY: 'auto' }}>
        {/* Handle */}
        <div style={{ width: 36, height: 4, borderRadius: 2, background: 'var(--color-border)', margin: '0 auto 14px' }} />
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', margin: '0 0 18px' }}>
          {existing ? 'Edit Event' : 'New Future Event'}
        </p>

        <input value={name} onChange={e => setName(e.target.value)} placeholder="Event Name (e.g. Eid)" style={inputStyle} />
        <input value={cost} onChange={e => setCost(e.target.value)} placeholder="Estimated Cost (EGP)" type="number" style={inputStyle} />
        <input value={saved} onChange={e => setSaved(e.target.value)} placeholder="Already Saved (EGP)" type="number" style={inputStyle} />

        {/* Date */}
        <div
          style={{ padding: 14, borderRadius: 10, background: 'var(--color-background)', border: '1px solid var(--color-border)', marginBottom: 14, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10 }}
        >
          <span>📅</span>
          <span style={{ flex: 1, fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)' }}>
            {new Date(date).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}
          </span>
          <input
            type="date" value={date} onChange={e => setDate(e.target.value)}
            min={new Date().toISOString().split('T')[0]}
            style={{ position: 'absolute', opacity: 0, width: 30, height: 30, cursor: 'pointer' }}
          />
          <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>▼</span>
        </div>

        {/* Reminder slider */}
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 4px' }}>
          Remind me {reminderMonths} month{reminderMonths > 1 ? 's' : ''} before
        </p>
        <input
          type="range" min={1} max={12} value={reminderMonths}
          onChange={e => setReminderMonths(+e.target.value)}
          style={{ width: '100%', accentColor: 'var(--color-primary)', marginBottom: 14 }}
        />

        {/* Saving frequency */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 22, flexWrap: 'wrap' }}>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-text-primary)' }}>
            Saving frequency:
          </span>
          {['weekly', 'monthly'].map(f => (
            <button key={f} onClick={() => setFrequency(f)} style={{
              padding: '7px 14px', borderRadius: 20, border: 'none', cursor: 'pointer',
              background: frequency === f ? 'var(--color-primary)' : 'var(--color-primary-surface)',
              fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
              color: frequency === f ? '#fff' : 'var(--color-primary)',
              transition: 'background 0.18s',
            }}>
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>

        {/* Submit */}
        <button onClick={isLoading ? undefined : submit} style={{
          width: '100%', height: 50, borderRadius: 13, border: 'none',
          cursor: isLoading ? 'default' : 'pointer',
          background: isLoading ? 'var(--color-border)' : 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
          boxShadow: isLoading ? 'none' : 'var(--shadow-primary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {isLoading ? (
            <div style={{ width: 22, height: 22, border: '2px solid #fff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
          ) : (
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: '#fff' }}>
              {existing ? 'Update Event' : 'Save Event'}
            </span>
          )}
        </button>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
