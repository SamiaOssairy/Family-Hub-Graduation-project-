// BR4 - Visual indicator for budget limit
export default function BudgetProgressIndicator({ spent, total, isOverBudget, showLabel = true }) {
  const progress = total > 0 ? Math.min(spent / total, 1.0) : 0.0;
  const pct = (progress * 100).toFixed(0);

  let barColor;
  if (isOverBudget || progress >= 1.0) {
    barColor = '#E53935';
  } else if (progress >= 0.8) {
    barColor = '#FB8C00';
  } else {
    barColor = 'var(--color-primary)';
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <div style={{ borderRadius: 6, overflow: 'hidden', height: 10, background: '#EEEEEE' }}>
        <div style={{ width: `${progress * 100}%`, height: '100%', background: barColor, transition: 'width 0.3s' }} />
      </div>
      {showLabel && (
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: barColor, fontWeight: 600 }}>
            {pct}% used
          </span>
          {isOverBudget && (
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#E53935', fontWeight: 700 }}>
              OVER BUDGET
            </span>
          )}
        </div>
      )}
    </div>
  );
}
