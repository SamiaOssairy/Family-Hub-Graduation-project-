// BR6 - Emergency fund visual card
export default function EmergencyFundCard({ total, spent, compact = false }) {
  const remaining = Math.max(total - spent, 0);
  const progress = total > 0 ? Math.min(spent / total, 1.0) : 0.0;
  const pct = (progress * 100).toFixed(0);
  const isDepleted = remaining <= 0;

  const mainColor = isDepleted ? '#E53935' : '#FB8C00';
  const bgColor = isDepleted ? '#FFEBEE' : '#FFF3E0';
  const borderColor = isDepleted ? '#EF9A9A' : '#FFCC80';
  const labelColor = isDepleted ? '#E53935' : '#E65100';

  return (
    <div style={{
      padding: compact ? 8 : 14,
      borderRadius: 10,
      background: bgColor,
      border: `1px solid ${borderColor}`,
      display: 'flex',
      alignItems: 'center',
      gap: 8,
    }}>
      <span style={{ fontSize: compact ? 18 : 22, flexShrink: 0 }}>🚨</span>

      <div style={{ flex: 1, minWidth: 0 }}>
        <span style={{
          fontFamily: 'var(--font-family)',
          fontWeight: 600,
          fontSize: compact ? 12 : 14,
          color: labelColor,
          display: 'block',
        }}>
          Emergency Fund
        </span>
        {!compact && (
          <>
            <div style={{ height: 4 }} />
            <div style={{ borderRadius: 4, overflow: 'hidden', height: 6, background: '#EEEEEE' }}>
              <div style={{
                width: `${progress * 100}%`,
                height: '100%',
                background: mainColor,
                transition: 'width 0.3s',
              }} />
            </div>
            <div style={{ height: 4 }} />
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E' }}>
              {pct}% used
            </span>
          </>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', flexShrink: 0 }}>
        <span style={{
          fontFamily: 'var(--font-family)',
          fontWeight: 700,
          fontSize: compact ? 13 : 16,
          color: labelColor,
        }}>
          {remaining.toFixed(0)}
        </span>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: compact ? 10 : 12, color: '#9E9E9E' }}>
          remaining
        </span>
      </div>
    </div>
  );
}
