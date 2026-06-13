// ═══════════════════════════════════════════════════════════════
// CombinedAnalyticsScreen — mirrors combined_analytics_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  PieChart, Pie, Cell, Tooltip as RechartTooltip, Legend,
  BarChart, Bar, XAxis, YAxis, CartesianGrid, ResponsiveContainer,
  Area, AreaChart,
} from 'recharts';
import {
  RefreshCw, Printer, CreditCard, Star, Gift, Heart,
  TrendingUp, AlertTriangle, BarChart2,
} from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import BottomNavBar from '../../components/common/BottomNavBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';
import './CombinedAnalyticsScreen.css';

// ── Chart colour palette (mirrors Flutter _chartColors) ─────────
const CHART_COLORS = ['var(--color-primary)', 'var(--color-primary-light)', '#5E35B1', '#F57C00', '#D81B60', '#1E88E5'];

// ── Helpers ──────────────────────────────────────────────────────
function money(v) { return Number(v || 0).toFixed(2); }
function num(v)   { return Number(v || 0).toFixed(0); }
function fmtDate(raw) {
  const d = new Date(raw);
  if (isNaN(d)) return raw || '';
  return `${String(d.getMonth()+1).padStart(2,'0')}/${String(d.getDate()).padStart(2,'0')}`;
}

// ── Sub-components ───────────────────────────────────────────────
function Panel({ title, children }) {
  return (
    <div className="ca-panel">
      <div className="ca-panel-header">
        <BarChart2 size={16} className="ca-panel-icon" />
        <span className="ca-panel-title">{title}</span>
      </div>
      <hr className="ca-panel-divider" />
      {children}
    </div>
  );
}

function OverviewCard({ title, value, Icon, color }) {
  return (
    <div className="ca-overview-card">
      <div className="ca-overview-icon" style={{ background: color + '22' }}>
        <Icon size={17} color={color} />
      </div>
      <div className="ca-overview-value">{value}</div>
      <div className="ca-overview-label">{title}</div>
    </div>
  );
}

function KV({ label, value }) {
  return (
    <div className="ca-kv">
      <span className="ca-kv-label">{label}</span>
      <span className="ca-kv-value">{value}</span>
    </div>
  );
}

function BudgetHealthBar({ title, data, color }) {
  const budget = Number(data?.budget_amount || 0);
  const spent  = Number(data?.spent_amount  || 0);
  const over   = data?.over_budget === true;
  const ratio  = budget > 0 ? Math.min(spent / budget, 1) : 0;

  return (
    <div className={`ca-health-card ${over ? 'ca-health-over' : ''}`}
         style={{ borderColor: over ? '#E53935' : color + '66' }}>
      <div className="ca-health-card-title">{title}</div>
      <div className="ca-health-spent">
        Spent: {money(spent)} / {money(budget)} EGP
      </div>
      <div className="ca-health-bar-bg">
        <div
          className="ca-health-bar-fill"
          style={{ width: `${ratio * 100}%`, background: over ? '#E53935' : color }}
        />
      </div>
      {over && (
        <div className="ca-health-over-label">
          <AlertTriangle size={14} /> Over budget
        </div>
      )}
    </div>
  );
}

// ── Main Component ───────────────────────────────────────────────
export default function CombinedAnalyticsScreen() {
  const navigate  = useNavigate();
  const toast     = useToast();

  const [loading,    setLoading]    = useState(true);
  const [analytics,  setAnalytics]  = useState({});
  const [memberMap,  setMemberMap]  = useState({});   // memberId → combined balance
  const [period,     setPeriod]     = useState('Month');

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [analyticsData, members] = await Promise.all([
        api.getCombinedAnalytics(),
        api.getAllMembers(),
      ]);

      const children = members.filter(m => {
        const t = m.member_type_id;
        return typeof t === 'object' ? t?.type !== 'Parent' : true;
      });

      const balances = await Promise.all(
        children.map(async m => {
          try {
            const bal = await api.getCombinedBalance(m._id);
            return [m._id, bal];
          } catch {
            return [m._id, {}];
          }
        })
      );

      setAnalytics(analyticsData);
      setMemberMap(Object.fromEntries(balances));
    } catch (e) {
      toast.error('Failed to load analytics');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => { loadData(); }, [loadData]);

  const handlePrint = () => window.print();

  // ── Data extraction ──────────────────────────────────────────
  const overview      = analytics.overview                    || {};
  const monthly       = analytics.monthly_summary_for_parents || {};
  const personalBudg  = analytics.personal_budget_summary     || {};
  const memberSums    = Array.isArray(analytics.member_summaries) ? analytics.member_summaries : [];
  const budgetHealth  = analytics.budget_health               || {};
  const alerts        = Array.isArray(analytics.alerts)       ? analytics.alerts : [];
  const charts        = analytics.charts                      || {};

  const pieData   = (charts.spending_by_category              || []).map((d,i) => ({
    name: d.category || 'Category', value: Number(d.amount || 0), color: CHART_COLORS[i % CHART_COLORS.length],
  }));
  const barData   = (charts.points_earned_vs_redeemed_by_member || []).map(d => ({
    name: (d.member_name || 'Member').slice(0, 8),
    earned:   Number(d.points_earned   || 0),
    redeemed: Number(d.points_redeemed || 0),
  }));
  const lineData  = (charts.rewards_spending_over_time || []).map(d => ({
    date:   fmtDate(d.date),
    amount: Number(d.amount || 0),
  }));

  // ── Render ───────────────────────────────────────────────────
  return (
    <div className="ca-root">
      <AppBar
        title="Analytics"
        onBack={() => navigate(-1)}
        actions={[
          <IconBtn key="refresh" icon={RefreshCw} onClick={loadData} tooltip="Refresh" />,
          <IconBtn key="print"   icon={Printer}   onClick={handlePrint} tooltip="Print / Export" />,
        ]}
      />

      {loading ? (
        <LoadingSpinner />
      ) : (
        <div className="ca-body">
          {/* ── Period tabs ─────────────────────────────── */}
          <div className="ca-period-tabs">
            {['Week', 'Month', 'Year'].map(p => (
              <button
                key={p}
                className={`ca-period-tab ${period === p ? 'ca-period-tab--active' : ''}`}
                onClick={() => setPeriod(p)}
              >
                {p}
              </button>
            ))}
          </div>

          {/* ── Overview cards ──────────────────────────── */}
          <div className="ca-overview-grid">
            <OverviewCard
              title="Total Family Spending"
              value={`${money(overview.total_family_spending)} EGP`}
              Icon={CreditCard}
              color="#B71C1C"
            />
            <OverviewCard
              title="Total Points Earned"
              value={num(overview.total_points_earned)}
              Icon={Star}
              color="#EF6C00"
            />
            <OverviewCard
              title="Total Points Redeemed"
              value={num(overview.total_points_redeemed)}
              Icon={Gift}
              color="#1565C0"
            />
            <OverviewCard
              title="Money as Allowance / Rewards"
              value={`${money(overview.total_money_given_as_allowance_rewards)} EGP`}
              Icon={Heart}
              color="var(--color-primary)"
            />
          </div>

          {/* ── Charts ──────────────────────────────────── */}
          <Panel title="Charts">
            {/* Pie — spending by category */}
            <div className="ca-chart-label">
              <TrendingUp size={14} /> Spending by Category
            </div>
            {pieData.length === 0 ? (
              <div className="ca-empty-chart">No spending data yet</div>
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <PieChart>
                  <Pie data={pieData} dataKey="value" nameKey="name"
                       cx="50%" cy="50%" outerRadius={80} innerRadius={36} paddingAngle={2}
                       label={({ name, percent }) => `${(percent*100).toFixed(0)}%`}
                       labelLine={false}>
                    {pieData.map((entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ))}
                  </Pie>
                  <RechartTooltip formatter={(v) => [`${money(v)} EGP`, 'Amount']} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
            )}

            <div className="ca-chart-gap" />

            {/* Bar — points earned vs redeemed per member */}
            <div className="ca-chart-label">
              <TrendingUp size={14} /> Points Earned vs Redeemed per Member
            </div>
            {barData.length === 0 ? (
              <div className="ca-empty-chart">No points activity yet</div>
            ) : (
              <>
                <div className="ca-bar-legend">
                  <span><span className="ca-legend-dot" style={{background:'var(--color-primary)'}} /> Earned</span>
                  <span><span className="ca-legend-dot" style={{background:'#EF6C00'}} /> Redeemed</span>
                </div>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart data={barData} barCategoryGap="30%" barGap={3}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e0e0e0" />
                    <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                    <YAxis tick={{ fontSize: 10 }} width={36} />
                    <RechartTooltip />
                    <Bar dataKey="earned"   name="Earned"   fill="var(--color-primary)" radius={[3,3,0,0]} />
                    <Bar dataKey="redeemed" name="Redeemed" fill="#EF6C00" radius={[3,3,0,0]} />
                  </BarChart>
                </ResponsiveContainer>
              </>
            )}

            <div className="ca-chart-gap" />

            {/* Line — rewards spending over time */}
            <div className="ca-chart-label">
              <TrendingUp size={14} /> Money Spent on Rewards over Time
            </div>
            {lineData.length === 0 ? (
              <div className="ca-empty-chart">No rewards spending yet</div>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={lineData}>
                  <defs>
                    <linearGradient id="rewardsGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#1565C0" stopOpacity={0.15} />
                      <stop offset="95%" stopColor="#1565C0" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e0e0e0" />
                  <XAxis dataKey="date" tick={{ fontSize: 10 }} interval="preserveStartEnd" />
                  <YAxis tick={{ fontSize: 10 }} width={40} />
                  <RechartTooltip formatter={(v) => [`${money(v)} EGP`, 'Amount']} />
                  <Area type="monotone" dataKey="amount" name="Amount (EGP)"
                        stroke="#1565C0" strokeWidth={3}
                        fill="url(#rewardsGrad)" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </Panel>

          {/* ── Member summary cards ─────────────────────── */}
          <Panel title="Member Summary Cards">
            {memberSums.length === 0 ? (
              <div className="ca-empty-inline">No child member summaries found</div>
            ) : (
              memberSums.map(s => {
                const id      = (s.member_id || '').toString();
                const bal     = memberMap[id] || {};
                const saved   = Number(bal.money_balance ?? s.current_money_saved ?? 0);
                return (
                  <div key={id} className="ca-member-card">
                    <div className="ca-member-name">{s.member_name || 'Member'}</div>
                    <KV label="Money received (allowance + rewards)"    value={`${money(s.money_received)} EGP`} />
                    <KV label="Personal budget"                         value={`${money(s.personal_budget_amount)} EGP`} />
                    <KV label="Personal budget spent"                   value={`${money(s.personal_budget_spent)} EGP`} />
                    <KV label="Personal budget remaining"               value={`${money(s.personal_budget_remaining)} EGP`} />
                    <KV label="Points earned"                           value={num(s.points_earned)} />
                    <KV label="Points redeemed"                         value={num(s.points_redeemed)} />
                    <KV label="Current money saved"                     value={`${money(saved)} EGP`} />
                  </div>
                );
              })
            )}
          </Panel>

          {/* ── Budget health ────────────────────────────── */}
          <Panel title="Budget Health Indicators">
            <BudgetHealthBar title="Rewards category"         data={budgetHealth.rewards}         color="#6A1B9A" />
            <BudgetHealthBar title="Allowances category"      data={budgetHealth.allowances}      color="var(--color-primary)" />
            <BudgetHealthBar title="Personal budget tracker"  data={budgetHealth.personal_budget} color="#1565C0" />
            {alerts.map((alert, i) => (
              <div key={i} className="ca-alert">
                <AlertTriangle size={16} className="ca-alert-icon" />
                <span>{alert}</span>
              </div>
            ))}
          </Panel>

          {/* ── Monthly summary / Export ─────────────────── */}
          <Panel title="Monthly Summary">
            <KV label="Month"                              value={monthly.month || '—'} />
            <KV label="Money spent this month"             value={`${money(monthly.money_spent_this_month)} EGP`} />
            <KV label="Personal money spent this month"    value={`${money(monthly.personal_money_spent_this_month)} EGP`} />
            <KV label="Points earned this month"           value={num(monthly.points_earned_this_month)} />
            <KV label="Points redeemed this month"         value={num(monthly.points_redeemed_this_month)} />
            <KV label="Tracked personal budget"            value={`${money(personalBudg.total_budget_amount)} EGP`} />
            <KV label="Tracked spent"                      value={`${money(personalBudg.total_spent_amount)} EGP`} />
            <KV label="Tracked remaining"                  value={`${money(personalBudg.total_remaining_amount)} EGP`} />
            <KV label="Expenses tracked this month"        value={num(personalBudg.tracked_expenses)} />
            <button className="ca-print-btn" onClick={handlePrint}>
              <Printer size={16} /> Print / Export Report
            </button>
          </Panel>
        </div>
      )}

      <BottomNavBar />
    </div>
  );
}
