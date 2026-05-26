// ═══════════════════════════════════════════════════════════════
// BudgetAnalyticsScreen — mirrors budget_analytics_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useLocation, useNavigate } from 'react-router-dom';
import { PieChart, Pie, Cell, Tooltip, LineChart, Line, XAxis, YAxis, CartesianGrid, ResponsiveContainer } from 'recharts';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

// ── Colors (mirrors Flutter _pieColors) ────────────────────────
const PIE_COLORS = ['#00897B', '#5BA89E', '#FB8C00', '#5FA09A', '#7B1FA2', '#E91E63'];

// ── Category icons (mirrors Flutter catIcons) ──────────────────
const CAT_ICONS = {
  groceries: '🛒', food: '🛒', utilities: '💡',
  entertainment: '🎬', education: '📚', transport: '🚗', healthcare: '🏥',
};

function getCatIcon(category) {
  const lower = (category || '').toLowerCase();
  for (const [key, icon] of Object.entries(CAT_ICONS)) {
    if (lower.includes(key)) return icon;
  }
  return '💰';
}

function fmt(n) { return Number(n || 0).toLocaleString('en', { maximumFractionDigits: 0 }); }

function formatDate(dateStr) {
  if (!dateStr) return 'Unknown date';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' }) +
    ', ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
}

// ─────────────────────────────────────────────────────────────────
export default function BudgetAnalyticsScreen() {
  const { id: budgetId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const toast = useToast();

  const budget = location.state?.budget || {};
  const budgetTitle = budget.title || 'Budget Analytics';

  let dateRange = '';
  try {
    if (budget.start_date && budget.end_date) {
      const s = new Date(budget.start_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      const e = new Date(budget.end_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
      dateRange = `${s} – ${e}`;
    }
  } catch (_) {}

  const [activeTab, setActiveTab] = useState(0); // 0=Overview, 1=Trend, 2=Expenses
  const [analytics, setAnalytics] = useState(null);
  const [expenses, setExpenses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [touchedIndex, setTouchedIndex] = useState(-1);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [analyticsData, expensesData] = await Promise.all([
        api.getBudgetAnalytics(budgetId),
        api.getExpensesByBudget(budgetId).catch(() => []),
      ]);
      setAnalytics(analyticsData);
      setExpenses(Array.isArray(expensesData) ? expensesData : []);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [budgetId]);

  useEffect(() => { loadData(); }, [loadData]);

  const tabs = ['Overview', 'Trend', 'Expenses'];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      {/* AppBar with title + date range */}
      <div style={{
        background: 'var(--color-background)', borderBottom: '0.5px solid var(--color-border)',
        position: 'sticky', top: 0, zIndex: 100,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '10px 14px', gap: 8 }}>
          <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: 'var(--color-primary)' }}>
            ←
          </button>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {budgetTitle}
            </p>
            {dateRange && (
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                {dateRange}
              </p>
            )}
          </div>
        </div>

        {/* Tab bar */}
        <div style={{ display: 'flex', borderTop: '0.5px solid var(--color-border)' }}>
          {tabs.map((tab, i) => (
            <button key={tab} onClick={() => setActiveTab(i)} style={{
              flex: 1, padding: '10px 4px', border: 'none', cursor: 'pointer', background: 'transparent',
              fontFamily: 'var(--font-family)', fontWeight: activeTab === i ? 600 : 400, fontSize: 12,
              color: activeTab === i ? 'var(--color-primary)' : 'var(--color-text-secondary)',
              borderBottom: `2px solid ${activeTab === i ? 'var(--color-primary)' : 'transparent'}`,
            }}>{tab}</button>
          ))}
        </div>
      </div>

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', overflowY: 'auto' }}>
        {loading || !analytics
          ? <LoadingSpinner />
          : activeTab === 0
            ? <OverviewTab analytics={analytics} touchedIndex={touchedIndex} setTouchedIndex={setTouchedIndex} />
            : activeTab === 1
              ? <TrendTab analytics={analytics} />
              : <ExpensesTab expenses={expenses} />
        }
      </div>
    </div>
  );
}

// ── Overview Tab ────────────────────────────────────────────────
function OverviewTab({ analytics, touchedIndex, setTouchedIndex }) {
  const pieData = Array.isArray(analytics.pie_chart_data) ? analytics.pie_chart_data : [];
  const totalSpent = +(analytics.total_spent || 0);
  const totalBudget = +(analytics.total_budget || 0);
  const totalRemaining = +(analytics.total_remaining || 0);
  const spentPct = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0;

  const overCategories = pieData.filter(d => {
    const spent = +(d.spent_amount || 0);
    const alloc = +(d.allocated_amount || 0);
    return alloc > 0 && spent / alloc > 0.8;
  });

  // For the donut center label
  const CustomCenter = ({ cx, cy }) => (
    <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle">
      <tspan x={cx} dy="-6" fontSize={12} fontWeight={700} fill="var(--color-text-primary)">{spentPct.toFixed(0)}%</tspan>
      <tspan x={cx} dy="16" fontSize={9} fill="var(--color-text-secondary)">spent</tspan>
    </text>
  );

  return (
    <div style={{ padding: '14px 14px 90px' }}>
      {/* 3 summary cards */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
        {[
          { label: 'Spent', value: totalSpent, color: 'var(--color-error)' },
          { label: 'Left', value: totalRemaining, color: 'var(--color-primary)' },
          { label: 'Total', value: totalBudget, color: 'var(--color-text-primary)' },
        ].map(({ label, value, color }) => (
          <div key={label} style={{
            flex: 1, padding: '10px 6px', borderRadius: 12, background: '#fff',
            border: '0.8px solid var(--color-border)', textAlign: 'center',
            boxShadow: '0 1px 6px rgba(0,0,0,0.04)',
          }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 700, color, margin: '0 0 2px' }}>
              {fmt(value)}
            </p>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 8, color: 'var(--color-text-secondary)', margin: 0 }}>
              {label}
            </p>
          </div>
        ))}
      </div>

      {/* Over-budget warnings */}
      {overCategories.map((d, i) => {
        const spent = +(d.spent_amount || 0);
        const alloc = +(d.allocated_amount || 0);
        const pct = alloc > 0 ? (spent / alloc * 100) : 0;
        return (
          <div key={i} style={{
            padding: '8px 12px', borderRadius: 10, marginBottom: 6,
            background: '#FFEBEE', border: '1px solid #FFCDD2',
            display: 'flex', alignItems: 'flex-start', gap: 8,
          }}>
            <span style={{ fontSize: 16 }}>⚠️</span>
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 700, color: '#C62828', margin: 0 }}>
                {d.category_name || ''} overspent!
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: '#E57373', margin: 0 }}>
                {fmt(spent)} EGP of {fmt(alloc)} EGP used ({pct.toFixed(0)}%)
              </p>
            </div>
          </div>
        );
      })}

      {pieData.length === 0 ? (
        <div style={{ padding: '40px 0', textAlign: 'center' }}>
          <p style={{ fontFamily: 'var(--font-family)', color: 'var(--color-text-secondary)' }}>No expenses yet</p>
        </div>
      ) : (
        <>
          {/* Pie chart card */}
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: 'var(--color-text-secondary)', letterSpacing: 0.8, margin: '0 0 6px' }}>
            SPENDING BY CATEGORY
          </p>
          <div style={{
            background: '#fff', borderRadius: 16, border: '1px solid var(--color-border)',
            padding: 14, marginBottom: 12,
            boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
            display: 'flex', gap: 14, alignItems: 'center',
          }}>
            {/* Donut */}
            <div style={{ position: 'relative', width: 100, height: 100, flexShrink: 0 }}>
              <PieChart width={100} height={100}>
                <Pie
                  data={pieData}
                  dataKey="spent_amount"
                  cx={50} cy={50}
                  innerRadius={30} outerRadius={45}
                  paddingAngle={2}
                  onMouseEnter={(_, i) => setTouchedIndex(i)}
                  onMouseLeave={() => setTouchedIndex(-1)}
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]}
                      opacity={touchedIndex === -1 || touchedIndex === i ? 1 : 0.7}
                    />
                  ))}
                </Pie>
              </PieChart>
              {/* Center text */}
              <div style={{
                position: 'absolute', top: '50%', left: '50%',
                transform: 'translate(-50%,-50%)', textAlign: 'center', pointerEvents: 'none',
              }}>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0 }}>{spentPct.toFixed(0)}%</p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 8, color: 'var(--color-text-secondary)', margin: 0 }}>spent</p>
              </div>
            </div>

            {/* Legend */}
            <div style={{ flex: 1, minWidth: 0 }}>
              {pieData.map((d, i) => {
                const spent = +(d.spent_amount || 0);
                const alloc = +(d.allocated_amount || 0);
                const isOver = alloc > 0 && spent / alloc > 0.8;
                return (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 5 }}>
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: PIE_COLORS[i % PIE_COLORS.length], flexShrink: 0 }} />
                    <span style={{ flex: 1, fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {d.category_name || ''}
                    </span>
                    <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700, color: isOver ? '#E65100' : 'var(--color-text-primary)', whiteSpace: 'nowrap' }}>
                      {fmt(spent)} EGP{isOver ? ' ⚠️' : ''}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Category breakdown list */}
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: 'var(--color-text-secondary)', letterSpacing: 0.8, margin: '0 0 6px' }}>
            CATEGORY BREAKDOWN
          </p>
          {pieData.map((d, i) => {
            const spent = +(d.spent_amount || 0);
            const alloc = +(d.allocated_amount || 0);
            const pct = parseFloat(d.percentage) || 0;
            const isOver = alloc > 0 && spent / alloc > 0.8;
            return (
              <div key={i} style={{
                padding: 12, borderRadius: 12, marginBottom: 8, background: '#fff',
                border: `${isOver ? 1.5 : 0.8}px solid ${isOver ? '#FFCDD2' : 'var(--color-border)'}`,
                boxShadow: '0 1px 6px rgba(0,0,0,0.04)',
                display: 'flex', alignItems: 'center', gap: 10,
              }}>
                <div style={{ width: 12, height: 12, borderRadius: '50%', background: PIE_COLORS[i % PIE_COLORS.length], flexShrink: 0 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {d.category_name || ''}
                  </p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)', margin: 0 }}>
                    {d.expense_count || 0} transactions
                  </p>
                </div>
                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: isOver ? 'var(--color-error)' : 'var(--color-text-primary)', margin: '0 0 2px' }}>
                    {fmt(spent)} EGP
                  </p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)', margin: 0 }}>
                    {pct.toFixed(1)}% · of {fmt(alloc)}
                  </p>
                </div>
              </div>
            );
          })}
        </>
      )}
    </div>
  );
}

// ── Trend Tab ───────────────────────────────────────────────────
function TrendTab({ analytics }) {
  const trend = Array.isArray(analytics.daily_trend_data) ? analytics.daily_trend_data : [];

  if (trend.length === 0) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 300 }}>
        <p style={{ fontFamily: 'var(--font-family)', color: 'var(--color-text-secondary)' }}>No spending data yet</p>
      </div>
    );
  }

  const chartData = trend.map((d, i) => ({
    name: typeof d._id === 'string' && d._id.length >= 5 ? d._id.slice(5) : `${i}`,
    value: +(d.daily_spent || 0),
  }));

  return (
    <div style={{ padding: '14px 14px 90px' }}>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, color: 'var(--color-text-primary)', margin: '0 0 14px' }}>
        Daily Spending Trend
      </p>
      <div style={{
        background: '#fff', borderRadius: 16, border: '1px solid var(--color-border)',
        padding: 14, boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
      }}>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={chartData} margin={{ top: 8, right: 8, left: -10, bottom: 0 }}>
            <CartesianGrid strokeDasharray="" stroke="var(--color-primary-surface)" horizontal vertical={false} />
            <XAxis dataKey="name" tick={{ fontFamily: 'var(--font-family)', fontSize: 9, fill: 'var(--color-text-secondary)' }}
              interval={2} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontFamily: 'var(--font-family)', fontSize: 9, fill: 'var(--color-text-secondary)' }}
              axisLine={false} tickLine={false} />
            <Tooltip
              contentStyle={{ fontFamily: 'var(--font-family)', fontSize: 11, borderRadius: 8, border: '1px solid var(--color-border)' }}
              formatter={v => [`${fmt(v)} EGP`, 'Spent']}
            />
            <Line
              type="monotone" dataKey="value" stroke="var(--color-primary)"
              strokeWidth={2.5} dot={false}
              fill="rgba(0,137,123,0.10)"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

// ── Expenses Tab ────────────────────────────────────────────────
function ExpensesTab({ expenses }) {
  if (expenses.length === 0) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 300 }}>
        <p style={{ fontFamily: 'var(--font-family)', color: 'var(--color-text-secondary)', textAlign: 'center' }}>
          No expenses found for this budget period
        </p>
      </div>
    );
  }

  return (
    <div style={{ padding: '14px 14px 90px' }}>
      {expenses.map((expense, i) => {
        const amount = +(expense.amount || 0);
        const title = expense.title || expense.category || 'Expense';
        const category = expense.category || 'Uncategorized';
        const memberMail = expense.member_mail || '';
        const source = expense.expense_source || expense.expense_scope || 'budget';
        const description = expense.description || '';
        const icon = getCatIcon(category);

        return (
          <div key={expense._id || i} style={{
            padding: 12, borderRadius: 12, marginBottom: 8, background: '#fff',
            border: '0.8px solid var(--color-border)',
            boxShadow: '0 1px 6px rgba(0,0,0,0.04)',
            display: 'flex', alignItems: 'flex-start', gap: 10,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10, flexShrink: 0,
              background: 'var(--color-primary-surface)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16,
            }}>
              {icon}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 3px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {title}
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexWrap: 'wrap' }}>
                <span style={{
                  padding: '2px 6px', borderRadius: 6,
                  background: 'var(--color-primary-surface)',
                  fontFamily: 'var(--font-family)', fontSize: 8, fontWeight: 600, color: 'var(--color-dark, #00352E)',
                }}>
                  {category}
                </span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 8, color: 'var(--color-text-secondary)' }}>
                  • {source}
                </span>
              </div>
              {memberMail && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 8, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                  {memberMail}
                </p>
              )}
              {description && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-primary)', margin: '2px 0 0', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {description}
                </p>
              )}
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 8, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                {formatDate(expense.expense_date)}
              </p>
            </div>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: 'var(--color-error)', whiteSpace: 'nowrap', flexShrink: 0 }}>
              -{fmt(amount)} EGP
            </span>
          </div>
        );
      })}
    </div>
  );
}
