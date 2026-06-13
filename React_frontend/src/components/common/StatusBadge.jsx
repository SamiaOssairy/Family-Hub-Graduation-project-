// StatusBadge — mirrors Flutter's _buildStatusBadge
import React from 'react';

const STATUS_MAP = {
  approved:         { dot: '#00BFA5', bg: '#E0F7F4', border: '#80CBC4', label: 'Done ✓' },
  completed:        { dot: '#1E88E5', bg: '#E3F2FD', border: '#90CAF9', label: 'Waiting ⏳' },
  pending_approval: { dot: '#1E88E5', bg: '#E3F2FD', border: '#90CAF9', label: 'Waiting' },
  in_progress:      { dot: '#1E88E5', bg: '#E3F2FD', border: '#BBDEFB', label: 'Active' },
  rejected:         { dot: '#FF5252', bg: '#FFEBEE', border: '#FFCDD2', label: 'Rejected ✕' },
  late:             { dot: '#FF5252', bg: '#FFEBEE', border: '#FFCDD2', label: 'Late' },
  assigned:         { dot: '#FB8C00', bg: '#FFF8E1', border: '#FFE082', label: 'Pending' },
  pending:          { dot: '#FB8C00', bg: '#FFF8E1', border: '#FFE082', label: 'Pending' },
  accepted:         { dot: '#00BFA5', bg: '#E0F7F4', border: '#80CBC4', label: 'Accepted' },
  cancelled:        { dot: '#9E9E9E', bg: '#F5F5F5', border: '#E0E0E0', label: 'Cancelled' },
  // Redeem lifecycle
  parent_approved:  { dot: '#00897B', bg: '#E0F2F1', border: '#80CBC4', label: 'Approved — accept it' },
  child_accepted:   { dot: '#00BFA5', bg: '#E0F7F4', border: '#80CBC4', label: 'Redeemed ✓' },
};

export default function StatusBadge({ status }) {
  const s = STATUS_MAP[status] || STATUS_MAP.assigned;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '3px 8px',
      background: s.bg, borderRadius: 8,
      border: `1px solid ${s.border}`,
    }}>
      <span style={{
        width: 6, height: 6, borderRadius: '50%',
        background: s.dot, flexShrink: 0,
      }} />
      <span style={{
        fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600,
        color: s.dot, whiteSpace: 'nowrap',
      }}>{s.label}</span>
    </span>
  );
}
