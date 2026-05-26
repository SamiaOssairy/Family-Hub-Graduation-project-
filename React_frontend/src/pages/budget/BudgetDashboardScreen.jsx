// ═══════════════════════════════════════════════════════════════
// BudgetDashboardScreen — mirrors budget_dashboard_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { BarChart2, Event, RefreshCw, Plus, CheckCircle, XCircle, Bell } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import BottomNavBar from '../../components/common/BottomNavBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

// ── Color helpers (mirrors _categoryColor & _memberColors) ─────────────────
const PIE_COLORS = ['#00897B','#5BA89E','#FB8C00','#5FA09A','#7B1FA2','#E91E63'];
const MEMBER_COLORS = [
  { bg:'#E3F2FD', text:'#1565C0', border:'#90CAF9' },
  { bg:'#FFF3E0', text:'#E65100', border:'#FFCC80' },
  { bg:'#FCE4EC', text:'#C2185B', border:'#F48FB1' },
  { bg:'#D1ECEB', text:'#00352E', border:'#8CBFBB' },
];

function categoryColor(name, index) {
  const n = (name || '').toLowerCase();
  if (n.includes('grocer') || n.includes('food')) return '#00897B';
  if (n.includes('util')) return '#5BA89E';
  if (n.includes('entertain')) return '#FB8C00';
  if (n.includes('educ')) return '#5FA09A';
  if (n.includes('transport') || n.includes('travel')) return '#7B1FA2';
  if (n.includes('health') || n.includes('medical')) return '#E91E63';
  return PIE_COLORS[index % PIE_COLORS.length];
}

function initials(name = '') {
  return name.trim().split(/\s+/).slice(0, 2).map(w => w[0]?.toUpperCase() || '').join('');
}

function fmt(n) { return Number(n || 0).toLocaleString('en', { maximumFractionDigits: 0 }); }

// ── Create Budget Sheet ────────────────────────────────────────────────────
function CreateBudgetSheet({ onClose, onCreated }) {
  const toast = useToast();
  const [title, setTitle] = useState('Family Budget');
  const [total, setTotal] = useState('');
  const [periodType, setPeriodType] = useState('monthly');
  const [emergencyPct, setEmergencyPct] = useState(10);
  const [categories, setCategories] = useState([]);
  const [members, setMembers] = useState([]);
  const [catAmounts, setCatAmounts] = useState({});
  const [memberAmounts, setMemberAmounts] = useState({});
  const [loading, setLoading] = useState(false);
  const [refLoading, setRefLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const [cats, mems] = await Promise.all([
          api.getInventoryCategoriesForBudget(),
          api.getAllMembers(),
        ]);
        setCategories(cats);
        setMembers(mems);
      } catch (e) {
        toast(e.message, 'error');
      } finally {
        setRefLoading(false);
      }
    })();
  }, []);

  const submit = async () => {
    const totalNum = parseFloat(total);
    if (!totalNum || totalNum <= 0) { toast('Please enter a valid total amount', 'error'); return; }
    const endDate = periodType === 'weekly'
      ? new Date(Date.now() + 7 * 86400000)
      : periodType === 'yearly'
        ? new Date(Date.now() + 365 * 86400000)
        : new Date(Date.now() + 30 * 86400000);

    const allocations = categories
      .filter(c => parseFloat(catAmounts[c._id] || 0) > 0)
      .map(c => ({ inventory_category_id: c._id, allocated_amount: parseFloat(catAmounts[c._id]), threshold_percentage: 15 }));

    const allowances = members
      .filter(m => parseFloat(memberAmounts[m._id] || 0) > 0)
      .map(m => ({
        member_id: m._id, member_mail: m.mail, period_type: periodType,
        allowance_currency: 'money', money_amount: parseFloat(memberAmounts[m._id]),
      }));

    setLoading(true);
    try {
      await api.createBudget({
        title, period_type: periodType,
        start_date: new Date().toISOString(), end_date: endDate.toISOString(),
        total_amount: totalNum, threshold_percentage: emergencyPct,
        allocations, allowances,
      });
      toast('Budget created!', 'success');
      onCreated();
      onClose();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
    }} onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{
        background: '#fff', borderRadius: '20px 20px 0 0', padding: '20px',
        maxHeight: '90vh', overflowY: 'auto',
      }}>
        {/* Handle */}
        <div style={{ width: 40, height: 4, borderRadius: 2, background: '#ccc', margin: '0 auto 16px' }} />
        <p style={{ fontSize: 22, fontWeight: 700, marginBottom: 20, fontFamily: 'var(--font-family)' }}>Create Budget</p>

        {/* Title */}
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Budget Title"
          style={{ width: '100%', padding: '12px', borderRadius: 10, border: '1px solid #ccc',
            fontFamily: 'var(--font-family)', fontSize: 14, marginBottom: 12, boxSizing: 'border-box' }} />

        {/* Total Amount */}
        <input value={total} onChange={e => setTotal(e.target.value)} placeholder="Total Amount (EGP)"
          type="number" style={{ width: '100%', padding: '12px', borderRadius: 10, border: '1px solid #ccc',
            fontFamily: 'var(--font-family)', fontSize: 14, marginBottom: 12, boxSizing: 'border-box' }} />

        {/* Period */}
        <p style={{ fontWeight: 600, marginBottom: 8, fontFamily: 'var(--font-family)' }}>Period</p>
        <div style={{ display: 'flex', gap: 6, marginBottom: 16 }}>
          {['weekly','monthly','yearly'].map(p => (
            <button key={p} onClick={() => setPeriodType(p)} style={{
              flex: 1, padding: '10px 4px', borderRadius: 10, cursor: 'pointer', border: 'none',
              fontFamily: 'var(--font-family)', fontWeight: periodType === p ? 700 : 400,
              background: periodType === p ? 'var(--color-primary)' : '#f0f0f0',
              color: periodType === p ? '#fff' : '#333',
            }}>{p.charAt(0).toUpperCase() + p.slice(1)}</button>
          ))}
        </div>

        {/* Emergency Fund */}
        <p style={{ fontWeight: 600, marginBottom: 4, fontFamily: 'var(--font-family)' }}>Emergency Fund: {emergencyPct}%</p>
        <input type="range" min={0} max={30} value={emergencyPct} onChange={e => setEmergencyPct(+e.target.value)}
          style={{ width: '100%', accentColor: 'var(--color-primary)', marginBottom: 16 }} />

        {/* Categories */}
        {refLoading ? <p style={{ color: '#888', fontFamily: 'var(--font-family)' }}>Loading categories…</p> : (
          <>
            <p style={{ fontSize: 16, fontWeight: 700, marginBottom: 8, fontFamily: 'var(--font-family)' }}>Category Allocations</p>
            {categories.length === 0
              ? <p style={{ color: '#888', fontFamily: 'var(--font-family)', marginBottom: 12 }}>No inventory categories found. Create categories in Inventory first.</p>
              : categories.map(c => (
                <div key={c._id} style={{ display: 'flex', alignItems: 'center', marginBottom: 10 }}>
                  <div style={{ width: 16, height: 16, borderRadius: '50%', background: 'var(--color-primary)', flexShrink: 0 }} />
                  <span style={{ flex: 1, marginLeft: 10, fontFamily: 'var(--font-family)', fontSize: 14 }}>{c.title || c.name}</span>
                  <input type="number" placeholder="Amount" value={catAmounts[c._id] || ''}
                    onChange={e => setCatAmounts(prev => ({ ...prev, [c._id]: e.target.value }))}
                    style={{ width: 100, padding: '6px 8px', borderRadius: 8, border: '1px solid #ccc',
                      fontFamily: 'var(--font-family)', fontSize: 13 }} />
                </div>
              ))
            }

            {/* Member Allowances */}
            <p style={{ fontSize: 16, fontWeight: 700, marginBottom: 8, marginTop: 8, fontFamily: 'var(--font-family)' }}>Member Allowances</p>
            {members.length === 0
              ? <p style={{ color: '#888', fontFamily: 'var(--font-family)' }}>No family members found.</p>
              : members.map(m => (
                <div key={m._id} style={{ marginBottom: 12 }}>
                  <p style={{ fontWeight: 500, marginBottom: 6, fontFamily: 'var(--font-family)', fontSize: 14 }}>{m.username || m.mail}</p>
                  <input type="number" placeholder="Money allowance (EGP)" value={memberAmounts[m._id] || ''}
                    onChange={e => setMemberAmounts(prev => ({ ...prev, [m._id]: e.target.value }))}
                    style={{ width: '100%', padding: '10px', borderRadius: 8, border: '1px solid #ccc',
                      fontFamily: 'var(--font-family)', fontSize: 13, boxSizing: 'border-box' }} />
                </div>
              ))
            }
          </>
        )}

        {/* Submit */}
        <button onClick={submit} disabled={loading} style={{
          width: '100%', height: 50, borderRadius: 12, border: 'none', cursor: loading ? 'default' : 'pointer',
          background: loading ? '#ccc' : 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
          color: '#fff', fontFamily: 'var(--font-family)', fontSize: 16, fontWeight: 700,
          marginTop: 12,
        }}>
          {loading ? 'Creating…' : 'Create Budget'}
        </button>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════════════════════
export default function BudgetDashboardScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const { isParent } = useAuth();

  const [budgets, setBudgets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [pendingLoading, setPendingLoading] = useState(false);
  const [showCreate, setShowCreate] = useState(false);

  const loadBudgets = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.getBudgets();
      setBudgets(Array.isArray(data) ? data : []);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  const loadPending = useCallback(async () => {
    if (!isParent) return;
    setPendingLoading(true);
    try {
      const data = await api.getExpenseRequests({ status: 'pending' });
      setPendingRequests(Array.isArray(data) ? data : []);
    } catch (_) {
    } finally {
      setPendingLoading(false);
    }
  }, [isParent]);

  useEffect(() => { loadBudgets(); loadPending(); }, [loadBudgets, loadPending]);

  const handleApprove = async (id) => {
    try {
      await api.approveExpenseRequest(id);
      toast('Request approved', 'success');
      loadPending();
      loadBudgets();
    } catch (e) { toast(e.message, 'error'); }
  };

  const handleReject = async (id) => {
    try {
      await api.rejectExpenseRequest(id);
      toast('Request rejected', 'info');
      loadPending();
    } catch (e) { toast(e.message, 'error'); }
  };

  // Count upcoming event reminders from budgets that have them
  const reminderCount = 0; // simplified — full implementation would check event dates

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title="Budget"
        actions={
          <>
            <IconBtn icon={BarChart2} onClick={() => navigate('/combined-analytics')} />
            <div style={{ position: 'relative' }}>
              <IconBtn icon={() => <span style={{ fontSize: 22 }}>📅</span>} onClick={() => navigate('/future-events')} badge={reminderCount > 0} />
            </div>
          </>
        }
      />

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', paddingBottom: 80 }}>
        {loading
          ? <LoadingSpinner />
          : budgets.length === 0
            ? <EmptyBudgetState onCreate={() => setShowCreate(true)} />
            : (
              <div style={{ padding: '12px 14px', overflowY: 'auto' }}>
                {budgets.map(b => (
                  <BudgetBlock key={b._id} budget={b} isParent={isParent} onAddExpense={() =>
                    navigate('/budget/add-expense', { state: { budget: b } })}
                    onAnalytics={() => navigate(`/budget/analytics/${b._id}`, { state: { budget: b } })} />
                ))}

                {isParent && (pendingLoading || pendingRequests.length > 0) && (
                  <PendingSection
                    loading={pendingLoading}
                    requests={pendingRequests}
                    onApprove={handleApprove}
                    onReject={handleReject}
                  />
                )}
              </div>
            )
        }
      </div>

      {/* FAB */}
      <button onClick={() => setShowCreate(true)} style={{
        position: 'fixed', bottom: 80, right: 20,
        width: 54, height: 54, borderRadius: '50%', border: 'none', cursor: 'pointer',
        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        boxShadow: '0 4px 12px rgba(0,137,123,0.35)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10,
      }}>
        <Plus size={26} color="#fff" />
      </button>

      <BottomNavBar activeIndex={1} />

      {showCreate && <CreateBudgetSheet onClose={() => setShowCreate(false)} onCreated={loadBudgets} />}
    </div>
  );
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function BudgetBlock({ budget, isParent, onAddExpense, onAnalytics }) {
  const categories = Array.isArray(budget.categories) ? budget.categories : [];
  const allowances = Array.isArray(budget.allowances) ? budget.allowances : [];

  return (
    <div style={{ marginBottom: 20 }}>
      <HeroCard budget={budget} />
      {categories.length > 0 && (
        <>
          <SectionLabel text="CATEGORY ALLOCATIONS" />
          <CategoryCard categories={categories} />
          <div style={{ height: 12 }} />
        </>
      )}
      {allowances.length > 0 && (
        <>
          <SectionLabel text="MEMBER ALLOWANCES" />
          <AllowancesCard allowances={allowances} />
          <div style={{ height: 12 }} />
        </>
      )}
      <ActionRow onAddExpense={onAddExpense} onAnalytics={onAnalytics} />
    </div>
  );
}

function HeroCard({ budget }) {
  const total = +(budget.total_amount || 0);
  const spent = +(budget.total_spent ?? budget.spent_amount ?? 0);
  const remaining = +(budget.remaining_amount ?? (total - spent));
  const emergencyTotal = +(budget.emergency_fund_amount || 0);
  const isOverBudget = budget.is_over_budget === true;
  const periodType = budget.period_type || 'monthly';
  const title = budget.title || 'Budget';
  const progress = total > 0 ? Math.min(spent / total, 1) : 0;

  const periodLabel = { weekly: 'Weekly', monthly: 'Monthly', yearly: 'Yearly' }[periodType] || 'Custom';

  return (
    <div style={{
      padding: 16, borderRadius: 18,
      background: 'linear-gradient(135deg, #00352E, #5BA89E)',
      boxShadow: '0 6px 16px rgba(0,137,123,0.30)',
      marginBottom: 12, position: 'relative', overflow: 'hidden',
    }}>
      {/* Decorative circle */}
      <div style={{
        position: 'absolute', top: -20, right: -20, width: 80, height: 80,
        borderRadius: '50%', background: 'rgba(255,255,255,0.07)',
      }} />
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 2 }}>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.7)' }}>
          {periodLabel} Budget
        </span>
        <span style={{ flex: 1 }} />
        {isOverBudget && (
          <span style={{
            padding: '3px 8px', borderRadius: 8, background: 'rgba(255,0,0,0.25)',
            fontFamily: 'var(--font-family)', fontSize: 9, color: '#fff', fontWeight: 700,
          }}>Over Budget</span>
        )}
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'rgba(255,255,255,0.85)', margin: '2px 0 4px', fontWeight: 500 }}>{title}</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 26, fontWeight: 700, color: '#fff', margin: '0 0 6px', letterSpacing: -0.5 }}>
        {fmt(total)} EGP
      </p>
      <div style={{ display: 'flex', marginBottom: 8 }}>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.7)' }}>Spent: </span>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#fff', fontWeight: 600, marginLeft: 2 }}>{fmt(spent)} EGP</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.7)' }}>Left: </span>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#fff', fontWeight: 600, marginLeft: 2 }}>{fmt(remaining)} EGP</span>
      </div>
      {/* Progress bar */}
      <div style={{ height: 5, borderRadius: 3, background: 'rgba(255,255,255,0.2)', overflow: 'hidden', marginBottom: 5 }}>
        <div style={{
          height: '100%', borderRadius: 3,
          width: `${progress * 100}%`,
          background: isOverBudget ? '#ff5252' : '#fff',
          transition: 'width 0.3s',
        }} />
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'rgba(255,255,255,0.7)', margin: 0 }}>
        {(progress * 100).toFixed(0)}% used
        {emergencyTotal > 0 ? ` · Emergency: ${fmt(emergencyTotal)} EGP` : ''}
      </p>
    </div>
  );
}

function CategoryCard({ categories }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 18, border: '0.8px solid var(--color-border)',
      boxShadow: 'var(--shadow-card)',
    }}>
      {categories.map((cat, i) => {
        const name = cat.name || cat.title || 'Category';
        const allocated = +(cat.allocated_amount || 0);
        const spent = +(cat.spent_amount || 0);
        const progress = allocated > 0 ? Math.min(spent / allocated, 1) : 0;
        const isWarn = progress >= 0.8;
        const color = categoryColor(name, i);
        const isLast = i === categories.length - 1;

        return (
          <div key={cat._id || i} style={{
            padding: '10px 14px',
            borderBottom: isLast ? 'none' : '0.5px solid var(--color-border-light)',
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <div style={{ width: 9, height: 9, borderRadius: '50%', background: color, flexShrink: 0 }} />
            <div style={{ flex: 1 }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 4px' }}>{name}</p>
              <div style={{ height: 4, borderRadius: 2, background: 'var(--color-border-light)', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${progress * 100}%`, background: isWarn ? '#FB8C00' : color, borderRadius: 2 }} />
              </div>
            </div>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: isWarn ? '#E65100' : 'var(--color-text-secondary)', whiteSpace: 'nowrap' }}>
              {fmt(spent)}/{fmt(allocated)}
            </span>
            {isWarn && <span style={{ fontSize: 11 }}>⚠️</span>}
          </div>
        );
      })}
    </div>
  );
}

function AllowancesCard({ allowances }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 18, border: '0.8px solid var(--color-border)',
      boxShadow: 'var(--shadow-card)',
    }}>
      {allowances.map((al, i) => {
        const name = al.member_name || al.member_mail || 'Member';
        const money = +(al.money_amount || 0);
        const spent = +(al.spent_amount || 0);
        const progress = money > 0 ? Math.min(spent / money, 1) : 0;
        const isWarn = progress >= 0.85;
        const colors = MEMBER_COLORS[i % MEMBER_COLORS.length];
        const init = initials(name);
        const isLast = i === allowances.length - 1;

        return (
          <div key={al.member_id || i} style={{
            padding: '10px 14px',
            borderBottom: isLast ? 'none' : '0.5px solid var(--color-border-light)',
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
              background: colors.bg, border: `1.5px solid ${colors.border}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: colors.text }}>{init}</span>
            </div>
            <div style={{ flex: 1 }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 4px' }}>{name}</p>
              <div style={{ height: 4, borderRadius: 2, background: 'var(--color-border-light)', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${progress * 100}%`, background: isWarn ? 'var(--color-error)' : colors.text, borderRadius: 2 }} />
              </div>
            </div>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: isWarn ? 'var(--color-error)' : 'var(--color-text-secondary)', whiteSpace: 'nowrap' }}>
              {fmt(spent)}/{fmt(money)}
            </span>
            {isWarn && <span style={{ fontSize: 11 }}>⚠️</span>}
          </div>
        );
      })}
    </div>
  );
}

function PendingSection({ loading, requests, onApprove, onReject }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <SectionLabel text="EXPENSE REQUESTS" />
        {requests.length > 0 && (
          <span style={{
            padding: '2px 7px', borderRadius: 8,
            background: 'var(--color-error)', color: '#fff',
            fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700,
          }}>{requests.length}</span>
        )}
      </div>
      {loading
        ? <div style={{ padding: 16, textAlign: 'center' }}>
            <div style={{ display: 'inline-block', width: 24, height: 24, border: '2px solid var(--color-primary)', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
          </div>
        : requests.length === 0
          ? (
            <div style={{ background: '#fff', borderRadius: 18, border: '0.8px solid var(--color-border)', padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
              <CheckCircle size={18} color="var(--color-primary)" />
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>No pending expense requests</span>
            </div>
          )
          : (
            <div style={{ background: '#fff', borderRadius: 18, border: '0.8px solid var(--color-border)', boxShadow: 'var(--shadow-card)' }}>
              {requests.map((req, i) => {
                const id = req._id || '';
                const memberName = req.member_name || req.member_mail || 'Member';
                const amount = +(req.amount || 0);
                const title = req.title || req.description || 'Expense';
                const category = req.category_name || req.category || '';
                const colors = MEMBER_COLORS[i % MEMBER_COLORS.length];
                const init = initials(memberName);
                const isLast = i === requests.length - 1;

                return (
                  <div key={id || i} style={{
                    padding: '11px 14px',
                    borderBottom: isLast ? 'none' : '0.5px solid var(--color-border-light)',
                    display: 'flex', alignItems: 'center', gap: 10,
                  }}>
                    <div style={{
                      width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
                      background: colors.bg, border: `1.5px solid ${colors.border}`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <span style={{ fontSize: 10, fontWeight: 700, color: colors.text }}>{init}</span>
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-primary)', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {title} · {fmt(amount)} EGP
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                        {memberName}{category ? ` · ${category}` : ''}
                      </p>
                    </div>
                    {/* Approve */}
                    <button onClick={() => onApprove(id)} style={{
                      width: 30, height: 30, borderRadius: 9, border: 'none', cursor: 'pointer',
                      background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <span style={{ color: 'var(--color-primary)', fontWeight: 900, fontSize: 16 }}>✓</span>
                    </button>
                    {/* Reject */}
                    <button onClick={() => onReject(id)} style={{
                      width: 30, height: 30, borderRadius: 9, border: 'none', cursor: 'pointer',
                      background: 'var(--color-error-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <span style={{ color: 'var(--color-error)', fontWeight: 900, fontSize: 14 }}>✕</span>
                    </button>
                  </div>
                );
              })}
            </div>
          )
      }
    </div>
  );
}

function ActionRow({ onAddExpense, onAnalytics }) {
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <button onClick={onAddExpense} style={{
        flex: 1, padding: '11px', borderRadius: 12, cursor: 'pointer',
        border: '1px solid var(--color-primary)', background: 'transparent',
        fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-primary)', fontWeight: 600,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        <Plus size={16} /> Add Expense
      </button>
      <button onClick={onAnalytics} style={{
        flex: 1, padding: '11px', borderRadius: 12, cursor: 'pointer',
        border: 'none', background: 'var(--color-primary)',
        fontFamily: 'var(--font-family)', fontSize: 12, color: '#fff', fontWeight: 600,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        <BarChart2 size={16} /> Analytics
      </button>
    </div>
  );
}

function EmptyBudgetState({ onCreate }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 32, flex: 1 }}>
      <div style={{ width: 80, height: 80, borderRadius: 24, background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 16 }}>
        <span style={{ fontSize: 40 }}>💼</span>
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', margin: '0 0 8px' }}>No budgets yet</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', textAlign: 'center', margin: '0 0 24px' }}>
        Create a budget to start tracking your family spending.
      </p>
      <button onClick={onCreate} style={{
        padding: '12px 24px', borderRadius: 14, border: 'none', cursor: 'pointer',
        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        boxShadow: 'var(--shadow-primary)',
        fontFamily: 'var(--font-family)', fontSize: 13, color: '#fff', fontWeight: 700,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <Plus size={16} /> Create Budget
      </button>
    </div>
  );
}

function SectionLabel({ text }) {
  return (
    <p style={{
      fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700, letterSpacing: 0.8,
      color: 'var(--color-text-secondary)', margin: '0 0 6px',
    }}>{text}</p>
  );
}
