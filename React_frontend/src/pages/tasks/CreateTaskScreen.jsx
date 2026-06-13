// ═══════════════════════════════════════════════════════════════
// CreateTaskScreen — mirrors create_task_screen.dart exactly
// Creates a new task template with title, description, category,
// reward type (points/money/both), amounts, and mandatory toggle.
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Star, DollarSign, Sparkles, CheckCircle, Tag } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

// ── Reward type options ────────────────────────────────────────
const REWARD_TYPES = [
  { value: 'points', label: 'Points', icon: Star,     emoji: '⭐' },
  { value: 'money',  label: 'Money',  icon: DollarSign, emoji: '💰' },
  { value: 'both',   label: 'Both',   icon: Sparkles,   emoji: '✨' },
];

// ── Category icon helper (mirrors Flutter _categoryIcon) ──────
function categoryEmoji(title) {
  const t = (title || '').toLowerCase();
  if (t.includes('clean') || t.includes('household')) return '🧹';
  if (t.includes('cook') || t.includes('food') || t.includes('kitchen')) return '🍳';
  if (t.includes('school') || t.includes('study') || t.includes('homework') || t.includes('education')) return '📚';
  if (t.includes('shop') || t.includes('errand')) return '🛒';
  if (t.includes('sport') || t.includes('exercise') || t.includes('fitness')) return '🏋️';
  if (t.includes('garden') || t.includes('outdoor')) return '🌿';
  if (t.includes('pet') || t.includes('animal')) return '🐾';
  return '✅';
}

// ─────────────────────────────────────────────────────────────────────────────
export default function CreateTaskScreen() {
  const navigate = useNavigate();
  const toast    = useToast();

  // ── Form state ──────────────────────────────────────────────
  const [title,       setTitle]       = useState('');
  const [description, setDescription] = useState('');
  const [categoryId,  setCategoryId]  = useState('');
  const [rewardType,  setRewardType]  = useState('points');
  const [pointsAmount, setPointsAmount] = useState(10);
  const [moneyAmount,  setMoneyAmount]  = useState('');
  const [isMandatory,  setIsMandatory]  = useState(false);

  // ── Loaded data ─────────────────────────────────────────────
  const [categories,   setCategories]   = useState([]);
  const [budgetLoaded, setBudgetLoaded] = useState(false);
  const [budgetRemaining, setBudgetRemaining] = useState(0);
  const [moneyToPointsRate, setMoneyToPointsRate] = useState(10);

  // ── UI state ─────────────────────────────────────────────────
  const [submitting, setSubmitting] = useState(false);
  const [loading,    setLoading]    = useState(true);

  const usesMoney  = rewardType === 'money'  || rewardType === 'both';
  const usesPoints = rewardType === 'points' || rewardType === 'both';
  const moneyNum   = parseFloat(moneyAmount) || 0;
  const isBudgetExceeded = usesMoney && moneyNum > budgetRemaining && budgetRemaining > 0;

  // ── Load categories + budget meta on mount ───────────────────
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [cats, combined] = await Promise.all([
        api.getAllTaskCategories().catch(() => []),
        api.getCombinedBalance().catch(() => ({})),
      ]);

      setCategories(cats);
      if (cats.length > 0 && !categoryId) setCategoryId(cats[0]._id || '');

      // Extract conversion rate
      const conv = combined?.conversionRate;
      if (conv?.money_to_points_rate > 0) {
        setMoneyToPointsRate(conv.money_to_points_rate);
      }

      // Get rewards budget remaining
      try {
        const budgets = await api.getBudgets();
        const tasksRewardsBudget = (Array.isArray(budgets) ? budgets : []).find(b => {
          const name = (b.category_name || b.title || '').toLowerCase();
          return name.includes('task') || name.includes('reward');
        });
        if (tasksRewardsBudget) {
          const total   = +(tasksRewardsBudget.total_amount || tasksRewardsBudget.budget_amount || 0);
          const spent   = +(tasksRewardsBudget.spent_amount || 0);
          setBudgetRemaining(Math.max(0, total - spent));
        }
      } catch { /* budget info is optional */ }
    } catch (e) {
      toast('Failed to load data: ' + e.message, 'error');
    } finally {
      setLoading(false);
      setBudgetLoaded(true);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Submit ───────────────────────────────────────────────────
  async function handleSubmit(forceCreate = false) {
    if (!title.trim()) {
      toast('Please enter a task title', 'error'); return;
    }
    if (!categoryId) {
      toast('Please select a category', 'error'); return;
    }
    if (usesPoints && pointsAmount <= 0) {
      toast('Points reward must be greater than zero', 'error'); return;
    }
    if (usesMoney && moneyNum <= 0) {
      toast('Money reward must be greater than zero', 'error'); return;
    }

    setSubmitting(true);
    try {
      const payload = {
        title:       title.trim(),
        description: description.trim(),
        category_id: categoryId,
        is_mandatory: isMandatory,
        reward_type: rewardType,
        money_reward: usesMoney ? moneyNum : 0,
      };
      if (forceCreate) payload.force_create = true;

      const response = await api.createTask(payload);
      const status   = response?.status || '';

      if (status === 'warning' && !forceCreate) {
        // Budget warning — ask user to confirm
        const proceed = window.confirm(
          'This reward exceeds your monthly rewards budget. Continue anyway?'
        );
        if (proceed) { await handleSubmit(true); }
        return;
      }

      toast('Task created! Now assign it to a family member.', 'success');
      navigate('/task-management', { replace: true });
    } catch (e) {
      toast('Error: ' + (e?.response?.data?.message || e.message), 'error');
    } finally {
      setSubmitting(false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
        <AppBar title="Create Task" />
        <LoadingSpinner />
      </div>
    );
  }

  const moneyEqPts = moneyNum * moneyToPointsRate;
  const totalPts   = pointsAmount + moneyEqPts;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Create Task" />

      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 40px', maxWidth: 620, margin: '0 auto', width: '100%' }}>

        {/* ── Title ── */}
        <SectionLabel text="TASK TITLE" />
        <input
          value={title}
          onChange={e => setTitle(e.target.value)}
          placeholder="e.g., Clean the Kitchen"
          style={inputStyle}
        />

        {/* ── Description ── */}
        <div style={{ marginTop: 14 }}>
          <SectionLabel text="DESCRIPTION" />
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="Clean all surfaces and wash dishes..."
            rows={3}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        {/* ── Category ── */}
        <div style={{ marginTop: 14 }}>
          <SectionLabel text="CATEGORY *" />
          {categories.length === 0 ? (
            <div style={warnBoxStyle}>
              <span>No categories available. Ask a parent to create one first.</span>
            </div>
          ) : (
            <select value={categoryId} onChange={e => setCategoryId(e.target.value)} style={inputStyle}>
              {categories.map(cat => (
                <option key={cat._id} value={cat._id}>
                  {categoryEmoji(cat.title || cat.name)} {cat.title || cat.name || 'Unknown'}
                </option>
              ))}
            </select>
          )}
        </div>

        {/* ── Mandatory toggle ── */}
        <div style={{
          marginTop: 14, padding: '10px 14px',
          background: 'var(--color-white)',
          border: '1px solid var(--color-border)',
          borderRadius: 14,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{ flex: 1 }}>
            <p style={{ ...labelStyle, fontSize: 13, fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
              Mandatory Task
            </p>
            <p style={{ ...labelStyle, fontSize: 10, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
              Appears under Mandatory tab
            </p>
          </div>
          <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <div
              onClick={() => setIsMandatory(v => !v)}
              style={{
                width: 44, height: 24, borderRadius: 12,
                background: isMandatory ? 'var(--color-primary)' : 'var(--color-border)',
                position: 'relative', transition: 'background 0.2s', cursor: 'pointer',
              }}
            >
              <div style={{
                position: 'absolute', top: 3, left: isMandatory ? 23 : 3,
                width: 18, height: 18, borderRadius: '50%',
                background: '#fff', transition: 'left 0.2s',
                boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
              }} />
            </div>
          </label>
        </div>

        {/* ── Reward Type ── */}
        <div style={{ marginTop: 18 }}>
          <SectionLabel text="REWARD TYPE" />
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            {REWARD_TYPES.map(rt => {
              const active = rewardType === rt.value;
              return (
                <button
                  key={rt.value}
                  onClick={() => setRewardType(rt.value)}
                  style={{
                    flex: 1, padding: '10px 0', borderRadius: 12,
                    border: `${active ? 2 : 1}px solid ${active ? 'var(--color-primary)' : 'var(--color-border)'}`,
                    background: active ? 'var(--color-primary)' : 'var(--color-white)',
                    cursor: 'pointer', transition: 'all 0.18s',
                    boxShadow: active ? '0 2px 8px rgba(0,137,123,0.25)' : 'none',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
                  }}
                >
                  <span style={{ fontSize: 16 }}>{rt.emoji}</span>
                  <span style={{
                    fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
                    color: active ? '#fff' : 'var(--color-primary)',
                  }}>{rt.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* ── Points amount ── */}
        {usesPoints && (
          <div style={{ marginTop: 16 }}>
            <SectionLabel text="POINTS AMOUNT" />
            <div style={{ position: 'relative', marginTop: 6 }}>
              <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', fontSize: 18, zIndex: 1 }}>⭐</span>
              <input
                type="number"
                min={1}
                value={pointsAmount}
                onChange={e => setPointsAmount(Math.max(0, parseInt(e.target.value) || 0))}
                style={{ ...inputStyle, paddingLeft: 40, fontWeight: 600, fontSize: 16 }}
              />
            </div>
            <p style={{ ...labelStyle, fontSize: 11, color: 'var(--color-text-secondary)', margin: '4px 0 0 4px' }}>
              = {(pointsAmount * 0.05).toFixed(2)} EGP equivalent
            </p>
          </div>
        )}

        {/* ── Money amount ── */}
        {usesMoney && (
          <div style={{ marginTop: 16 }}>
            <SectionLabel text="MONEY AMOUNT (EGP)" />
            <div style={{ position: 'relative', marginTop: 6 }}>
              <span style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', fontSize: 18, zIndex: 1 }}>💰</span>
              <input
                type="number"
                min={0}
                step="0.01"
                value={moneyAmount}
                onChange={e => setMoneyAmount(e.target.value)}
                placeholder="0.00"
                style={{ ...inputStyle, paddingLeft: 40, fontWeight: 600, fontSize: 16 }}
              />
            </div>
            {moneyNum > 0 && (
              <p style={{ ...labelStyle, fontSize: 11, color: 'var(--color-text-secondary)', margin: '4px 0 0 4px' }}>
                = {moneyEqPts.toFixed(1)} pts equivalent
              </p>
            )}
          </div>
        )}

        {/* ── Both total ── */}
        {rewardType === 'both' && moneyNum > 0 && (
          <div style={{
            marginTop: 12, padding: 11,
            background: 'var(--color-primary-surface)',
            border: '1px solid var(--color-border)',
            borderRadius: 12,
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <span style={{ fontSize: 14 }}>✨</span>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)' }}>
              Total: {totalPts.toFixed(1)} pts equivalent
            </span>
          </div>
        )}

        {/* ── Budget status ── */}
        {usesMoney && budgetLoaded && (
          <div style={{
            marginTop: 14, padding: 12, borderRadius: 12,
            background: isBudgetExceeded ? '#FFF3E0' : 'var(--color-primary-surface)',
            border: `1px solid ${isBudgetExceeded ? '#FFCC80' : '#A5D6A7'}`,
          }}>
            {isBudgetExceeded ? (
              <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                <span style={{ fontSize: 16 }}>⚠️</span>
                <div>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#E65100', margin: 0 }}>
                    Budget Warning
                  </p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#FB8C00', margin: '2px 0 0' }}>
                    Reward exceeds remaining budget ({budgetRemaining.toFixed(2)} EGP left). You can still create.
                  </p>
                </div>
              </div>
            ) : (
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                <span style={{ fontSize: 16 }}>✅</span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-primary)' }}>
                  Budget OK — {budgetRemaining.toFixed(2)} EGP remaining
                </span>
              </div>
            )}
          </div>
        )}

        {/* ── Create button ── */}
        <button
          onClick={() => handleSubmit(false)}
          disabled={submitting || categories.length === 0}
          style={{
            marginTop: 20, width: '100%', padding: '15px 0', borderRadius: 14,
            border: 'none', cursor: submitting ? 'not-allowed' : 'pointer',
            background: submitting
              ? '#ccc'
              : 'linear-gradient(90deg, var(--color-primary), var(--color-primary-light))',
            boxShadow: submitting ? 'none' : '0 4px 12px rgba(0,137,123,0.3)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: '#fff',
            transition: 'opacity 0.2s',
          }}
        >
          {submitting ? (
            <span>Creating…</span>
          ) : (
            <>
              <CheckCircle size={20} />
              Create Task
            </>
          )}
        </button>
      </div>
    </div>
  );
}

// ── Sub-components ────────────────────────────────────────────

function SectionLabel({ text }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 6 }}>
      <div style={{ width: 3, height: 14, borderRadius: 2, background: 'var(--color-primary)', flexShrink: 0 }} />
      <span style={{
        fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700,
        color: 'var(--color-text-secondary)', letterSpacing: 0.8,
      }}>{text}</span>
    </div>
  );
}

// ── Shared styles ─────────────────────────────────────────────
const inputStyle = {
  width: '100%',
  padding: '10px 12px',
  fontFamily: 'var(--font-family)',
  fontSize: 13,
  color: 'var(--color-text-primary)',
  background: 'var(--color-white)',
  border: '1px solid var(--color-border)',
  borderRadius: 12,
  outline: 'none',
  boxSizing: 'border-box',
};

const labelStyle = {
  fontFamily: 'var(--font-family)',
};

const warnBoxStyle = {
  padding: 10,
  background: '#FFF8E1',
  borderRadius: 8,
  border: '1px solid #FFE082',
  fontFamily: 'var(--font-family)',
  fontSize: 11,
  color: '#E65100',
};
