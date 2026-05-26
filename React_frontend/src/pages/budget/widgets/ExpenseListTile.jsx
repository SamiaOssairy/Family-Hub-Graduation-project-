import { Trash2 } from 'lucide-react';

export default function ExpenseListTile({ expense, onTap, onDelete }) {
  const amount = +(expense.amount || 0);
  const isEmergency = expense.is_emergency === true;
  const hasPhoto = expense.receipt_photo_url && expense.receipt_photo_url.toString().length > 0;

  let dateStr = null;
  if (expense.expense_date) {
    try {
      const d = new Date(expense.expense_date);
      dateStr = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
    } catch (_) {}
  }

  const title = expense.description && expense.description.trim().length > 0
    ? expense.description
    : (expense.category_name || 'Expense');

  return (
    <div
      onClick={onTap}
      style={{
        marginBottom: 8,
        borderRadius: 10,
        background: '#fff',
        boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
        display: 'flex',
        alignItems: 'center',
        padding: '10px 12px',
        gap: 12,
        cursor: onTap ? 'pointer' : 'default',
      }}
    >
      {/* Leading circle icon */}
      <div style={{
        width: 44, height: 44, borderRadius: '50%', flexShrink: 0,
        background: isEmergency ? '#FFE0B2' : 'var(--color-background)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 20,
      }}>
        {isEmergency ? '🚨' : '🧾'}
      </div>

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        {/* Title row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{
            fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
            color: 'var(--color-text-primary)',
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1,
          }}>
            {title}
          </span>
          {hasPhoto && <span style={{ fontSize: 12, color: '#9E9E9E' }}>📷</span>}
        </div>

        {/* Category */}
        {expense.category_name && (
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#757575', display: 'block' }}>
            {expense.category_name}
          </span>
        )}

        {/* Date */}
        {dateStr && (
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E', display: 'block' }}>
            {dateStr}
          </span>
        )}

        {/* Emergency badge */}
        {isEmergency && (
          <span style={{
            display: 'inline-block', marginTop: 2,
            padding: '2px 6px', borderRadius: 4,
            background: '#FFE0B2',
            fontFamily: 'var(--font-family)', fontSize: 10,
            color: '#FB8C00', fontWeight: 700,
          }}>
            Emergency
          </span>
        )}
      </div>

      {/* Trailing: amount + delete */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
        <span style={{
          fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, color: '#E53935',
        }}>
          -{amount.toFixed(2)}
        </span>
        {onDelete && (
          <button
            onClick={e => { e.stopPropagation(); onDelete(); }}
            style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0, lineHeight: 1 }}
          >
            <Trash2 size={18} color="#9E9E9E" />
          </button>
        )}
      </div>
    </div>
  );
}
