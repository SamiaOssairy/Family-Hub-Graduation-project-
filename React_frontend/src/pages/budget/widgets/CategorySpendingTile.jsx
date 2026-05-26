export default function CategorySpendingTile({ categoryName, allocated, spent, color, compact = false }) {
  const progress = allocated > 0 ? Math.min(spent / allocated, 1.0) : 0.0;
  const isOver = spent > allocated;
  const remaining = allocated - spent;

  return (
    <div style={{ paddingBottom: 8 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ width: 12, height: 12, borderRadius: '50%', background: color, flexShrink: 0 }} />
        <span style={{
          flex: 1,
          fontFamily: 'var(--font-family)',
          fontSize: compact ? 13 : 14,
          fontWeight: 500,
          color: 'var(--color-text-primary)',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>
          {categoryName}
        </span>
        <span style={{
          fontFamily: 'var(--font-family)',
          fontSize: 12,
          fontWeight: 500,
          color: isOver ? '#E53935' : '#9E9E9E',
          flexShrink: 0,
        }}>
          {isOver
            ? `-${(spent - allocated).toFixed(0)} over`
            : `${remaining.toFixed(0)} left`}
        </span>
      </div>

      <div style={{ height: 4 }} />

      <div style={{ borderRadius: 4, overflow: 'hidden', height: compact ? 6 : 8, background: '#EEEEEE' }}>
        <div style={{
          width: `${progress * 100}%`,
          height: '100%',
          background: isOver ? '#E53935' : color,
          transition: 'width 0.3s',
        }} />
      </div>

      {!compact && (
        <div style={{ marginTop: 4 }}>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E' }}>
            {spent.toFixed(2)} of {allocated.toFixed(2)}
          </span>
        </div>
      )}
    </div>
  );
}
