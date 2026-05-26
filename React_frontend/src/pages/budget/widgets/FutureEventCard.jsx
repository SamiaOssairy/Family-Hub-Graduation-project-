import { useState } from 'react';
import { Calendar, Clock, Lightbulb, Wallet } from 'lucide-react';

export default function FutureEventCard({ event, onEdit, onDelete, onOpenFunding }) {
  const [menuOpen, setMenuOpen] = useState(false);

  const estimated = +(event.estimated_cost || 0);
  const saved = +(event.saved_amount || 0);
  const progress = estimated > 0 ? Math.min(saved / estimated, 1.0) : 0.0;
  const shouldRemind = event.should_remind === true;
  const monthsUntil = event.months_until_event ?? 0;
  const suggestedSaving = +(event.suggested_saving_amount || 0);
  const isCompleted = event.is_completed === true;

  let dateStr = null;
  if (event.expected_date) {
    try {
      const d = new Date(event.expected_date);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateStr = `${String(d.getDate()).padStart(2,'0')} ${months[d.getMonth()]} ${d.getFullYear()}`;
    } catch (_) {}
  }

  const barColor = isCompleted ? '#43A047' : 'var(--color-primary)';
  const pctColor = progress >= 1.0 ? '#43A047' : 'var(--color-primary)';

  return (
    <div style={{
      marginBottom: 14,
      borderRadius: 14,
      background: '#fff',
      boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      border: shouldRemind && !isCompleted ? '2px solid #FFA726' : 'none',
      overflow: 'visible',
      position: 'relative',
    }}>
      <div style={{ padding: 16 }}>
        {/* Title row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            flex: 1,
            fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700,
            color: 'var(--color-text-primary)',
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>
            {event.name || ''}
          </span>

          {shouldRemind && !isCompleted && (
            <span style={{
              padding: '4px 8px', borderRadius: 8,
              background: '#FFE0B2',
              fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#FB8C00',
              flexShrink: 0,
            }}>
              Reminder
            </span>
          )}
          {isCompleted && (
            <span style={{
              padding: '4px 8px', borderRadius: 8,
              background: '#E8F5E9',
              fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#43A047',
              flexShrink: 0,
            }}>
              Done
            </span>
          )}

          {/* Popup menu */}
          <div style={{ position: 'relative', flexShrink: 0 }}>
            <button
              onClick={() => setMenuOpen(v => !v)}
              style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px 6px', fontSize: 20, color: '#757575', lineHeight: 1 }}
            >
              ⋮
            </button>
            {menuOpen && (
              <div style={{
                position: 'absolute', right: 0, top: '100%', zIndex: 99,
                background: '#fff', borderRadius: 8, boxShadow: '0 4px 16px rgba(0,0,0,0.15)',
                minWidth: 130, overflow: 'hidden',
              }}>
                <button
                  onClick={() => { setMenuOpen(false); onEdit && onEdit(); }}
                  style={{ display: 'block', width: '100%', textAlign: 'left', padding: '10px 16px', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-primary)' }}
                >
                  Edit
                </button>
                <button
                  onClick={() => { setMenuOpen(false); onDelete && onDelete(); }}
                  style={{ display: 'block', width: '100%', textAlign: 'left', padding: '10px 16px', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 14, color: '#E53935' }}
                >
                  Delete
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Date row */}
        {dateStr && (
          <>
            <div style={{ height: 6 }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <Calendar size={14} color="#9E9E9E" />
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#9E9E9E' }}>{dateStr}</span>
              <div style={{ width: 12 }} />
              <Clock size={14} color="#9E9E9E" />
              <span style={{
                fontFamily: 'var(--font-family)', fontSize: 13,
                color: monthsUntil <= 3 ? '#FB8C00' : '#9E9E9E',
                fontWeight: monthsUntil <= 3 ? 700 : 400,
              }}>
                {monthsUntil} months away
              </span>
            </div>
          </>
        )}

        <div style={{ height: 12 }} />

        {/* Progress bar */}
        <div style={{ borderRadius: 6, overflow: 'hidden', height: 10, background: '#EEEEEE' }}>
          <div style={{ width: `${progress * 100}%`, height: '100%', background: barColor, transition: 'width 0.3s' }} />
        </div>

        <div style={{ height: 8 }} />

        {/* Saved row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 500, fontSize: 14, color: 'var(--color-text-primary)' }}>
            Saved: {saved.toFixed(0)} / {estimated.toFixed(0)}
          </span>
          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: pctColor }}>
            {(progress * 100).toFixed(0)}%
          </span>
        </div>

        {/* Suggested saving hint */}
        {suggestedSaving > 0 && !isCompleted && (
          <>
            <div style={{ height: 10 }} />
            <div style={{
              padding: '8px 10px', borderRadius: 8,
              background: 'var(--color-background)',
              display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <Lightbulb size={18} color="var(--color-primary)" />
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 500, color: 'var(--color-primary)', flex: 1 }}>
                Suggest saving {suggestedSaving.toFixed(2)} per {event.saving_frequency || 'month'}
              </span>
            </div>
          </>
        )}

        {/* Open Funding Details button */}
        {onOpenFunding && (
          <>
            <div style={{ height: 10 }} />
            <button
              onClick={onOpenFunding}
              style={{
                width: '100%',
                padding: '10px 0',
                borderRadius: 8,
                border: '1.5px solid var(--color-primary)',
                background: 'transparent',
                cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600,
                color: 'var(--color-primary)',
              }}
            >
              <Wallet size={18} />
              Open Funding Details
            </button>
          </>
        )}
      </div>

      {/* Dismiss menu on outside click */}
      {menuOpen && (
        <div
          onClick={() => setMenuOpen(false)}
          style={{ position: 'fixed', inset: 0, zIndex: 98 }}
        />
      )}
    </div>
  );
}
