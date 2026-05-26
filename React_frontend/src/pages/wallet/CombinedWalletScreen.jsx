// ═══════════════════════════════════════════════════════════════
// CombinedWalletScreen — mirrors combined_wallet_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { RefreshCw, ArrowUpward, ArrowDownward } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import BottomNavBar from '../../components/common/BottomNavBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

// ── Helpers ────────────────────────────────────────────────────────
function fmtDate(dateVal) {
  if (!dateVal) return 'Unknown';
  const d = new Date(dateVal);
  return `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${d.getFullYear()}`;
}

function moneyToPointsRate(balance) {
  const r = balance?.conversionRate;
  if (r && r.money_to_points_rate != null) return +(r.money_to_points_rate);
  return 10;
}

function pointsToMoneyRate(balance) {
  const r = balance?.conversionRate;
  if (r && r.points_to_money_rate != null) return +(r.points_to_money_rate);
  return 0.05;
}

function buildCombinedTransactions(pointHistory, balance) {
  const conversionRate = pointsToMoneyRate(balance);
  const list = [];

  for (const raw of (Array.isArray(pointHistory) ? pointHistory : [])) {
    if (!raw || typeof raw !== 'object') continue;
    const reason = (raw.reason_type || '').toString();
    const description = (raw.description || 'Points update').toString();
    const pointsAmount = +(raw.points_amount || 0);
    const date = raw.createdAt ? new Date(raw.createdAt) : null;

    const isPositive = pointsAmount >= 0;
    const isConversion = reason === 'conversion';

    list.push({
      kind: isConversion ? 'conversion' : 'points',
      title: description,
      amountText: `${isPositive ? '+' : '-'}${Math.abs(pointsAmount).toFixed(0)} pts`,
      isPositive,
      date,
    });

    if (isConversion) {
      const moneyEquivalent = Math.abs(pointsAmount) * conversionRate;
      const moneyPositive = pointsAmount < 0;
      list.push({
        kind: 'money',
        title: description,
        amountText: `${moneyPositive ? '+' : '-'}${moneyEquivalent.toFixed(2)} EGP`,
        isPositive: moneyPositive,
        date,
      });
    }
  }

  list.sort((a, b) => {
    const da = a.date || new Date(0);
    const db = b.date || new Date(0);
    return db - da;
  });
  return list;
}

// ─────────────────────────────────────────────────────────────────
export default function CombinedWalletScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const { isParent, memberId: authMemberId } = useAuth();

  const [isLoading, setIsLoading] = useState(true);
  const [members, setMembers] = useState([]);
  const [selectedMemberId, setSelectedMemberId] = useState(null);
  const [selectedMemberMail, setSelectedMemberMail] = useState(null);
  const [balance, setBalance] = useState({});
  const [transactions, setTransactions] = useState([]);
  const [conversionSheet, setConversionSheet] = useState(null); // null | 'moneyToPoints' | 'pointsToMoney'

  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      let selMemberId = selectedMemberId;
      let selMemberMail = selectedMemberMail;

      if (isParent) {
        const allMembers = await api.getAllMembers();
        setMembers(allMembers);

        const children = allMembers.filter(m => {
          const type = (m.member_type_id?.type || '').toString();
          return type !== 'Parent';
        });

        if (children.length > 0) {
          const selected = children.find(m => m._id?.toString() === selMemberId) || children[0];
          selMemberId = selected._id?.toString();
          selMemberMail = selected.mail?.toString();
          setSelectedMemberId(selMemberId);
          setSelectedMemberMail(selMemberMail);
        }
      }

      const effectiveMemberId = selMemberId || authMemberId;
      const [balanceData, pointHistory] = await Promise.all([
        api.getCombinedBalance(effectiveMemberId),
        isParent && selMemberMail
          ? api.getMemberPointHistory(selMemberMail).catch(() => [])
          : api.getMyPointHistory().catch(() => []),
      ]);

      setBalance(balanceData || {});
      setTransactions(buildCombinedTransactions(pointHistory, balanceData || {}));
    } catch (e) {
      toast(`Failed to load wallet data: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  }, [isParent, selectedMemberId, selectedMemberMail]);

  useEffect(() => { loadData(); }, []);

  const moneyBalance = +(balance.money_balance || 0);
  const pointsBalance = +(balance.points_balance || 0);
  const totalValueMoney = +(balance.total_value_in_money || 0);
  const m2p = moneyToPointsRate(balance);
  const p2m = pointsToMoneyRate(balance);

  const lifetimePointsEarned = transactions
    .filter(tx => tx.kind !== 'money' && tx.isPositive)
    .reduce((sum, tx) => sum + (parseFloat(tx.amountText?.replace(/[^0-9.]/g, '') || 0) || 0), 0);

  const lifetimeMoneySaved = transactions
    .filter(tx => tx.kind === 'money' && tx.isPositive)
    .reduce((sum, tx) => sum + (parseFloat(tx.amountText?.replace(/[^0-9.]/g, '') || 0) || 0), 0);

  const children = members.filter(m => (m.member_type_id?.type || '').toString() !== 'Parent');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title="My Wallet"
        onBack={() => navigate(-1)}
        actions={<IconBtn icon={RefreshCw} onClick={() => loadData()} />}
      />

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', overflowY: 'auto', padding: '14px 14px 80px' }}>
        {isLoading ? (
          <LoadingSpinner />
        ) : (
          <>
            {/* Child selector (parent only) */}
            {isParent && children.length > 0 && (
              <div style={{
                padding: '6px 14px', borderRadius: 14, background: '#fff',
                border: '0.8px solid var(--color-border)', marginBottom: 12,
              }}>
                <select
                  value={selectedMemberId || ''}
                  onChange={async e => {
                    const val = e.target.value;
                    const sel = children.find(m => m._id?.toString() === val);
                    setSelectedMemberId(val);
                    setSelectedMemberMail(sel?.mail?.toString() || null);
                    setIsLoading(true);
                    try {
                      const [balData, ph] = await Promise.all([
                        api.getCombinedBalance(val),
                        api.getMemberPointHistory(sel?.mail || '').catch(() => []),
                      ]);
                      setBalance(balData || {});
                      setTransactions(buildCombinedTransactions(ph, balData || {}));
                    } catch (err) {
                      toast(err.message, 'error');
                    } finally {
                      setIsLoading(false);
                    }
                  }}
                  style={{
                    width: '100%', border: 'none', background: 'transparent', outline: 'none',
                    fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)',
                    padding: '6px 0',
                  }}
                >
                  {children.map(m => (
                    <option key={m._id} value={m._id}>{m.username || m.mail || 'Member'}</option>
                  ))}
                </select>
              </div>
            )}

            {/* Money wallet card */}
            <MoneyCard
              moneyBalance={moneyBalance}
              lifetimeMoneySaved={lifetimeMoneySaved}
              onConvert={() => setConversionSheet('moneyToPoints')}
            />
            <div style={{ height: 10 }} />

            {/* Points wallet card */}
            <PointsCard
              pointsBalance={pointsBalance}
              lifetimePointsEarned={lifetimePointsEarned}
              m2p={m2p} p2m={p2m}
              onConvert={() => setConversionSheet('pointsToMoney')}
            />
            <div style={{ height: 12 }} />

            {/* Total value */}
            <div style={{
              padding: '14px 16px', borderRadius: 16, background: '#fff',
              border: '0.8px solid var(--color-border)',
              boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            }}>
              <div>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-text-secondary)', margin: '0 0 2px' }}>Total Value</p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: '#aaa', margin: 0 }}>Money + Points combined</p>
              </div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 20, fontWeight: 700, color: 'var(--color-primary)', margin: 0 }}>
                {totalValueMoney.toFixed(2)} EGP
              </p>
            </div>
            <div style={{ height: 14 }} />

            {/* Recent transactions */}
            <SectionLabel text="RECENT TRANSACTIONS" />
            <div style={{ height: 8 }} />
            <TransactionsList transactions={transactions} />
            <div style={{ height: 14 }} />

            {/* Convert panel */}
            <SectionLabel text="CONVERT" />
            <div style={{ height: 8 }} />
            <ConversionPanel
              m2p={m2p} p2m={p2m}
              onMoneyToPoints={() => setConversionSheet('moneyToPoints')}
              onPointsToMoney={() => setConversionSheet('pointsToMoney')}
            />
          </>
        )}
      </div>

      <BottomNavBar activeIndex={1} />

      {conversionSheet && (
        <ConversionSheet
          moneyToPoints={conversionSheet === 'moneyToPoints'}
          balance={balance}
          m2p={m2p} p2m={p2m}
          onClose={() => setConversionSheet(null)}
          onDone={() => { setConversionSheet(null); loadData(); }}
        />
      )}
    </div>
  );
}

// ── Section label ──────────────────────────────────────────────────
function SectionLabel({ text }) {
  return (
    <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700, letterSpacing: 0.8, color: 'var(--color-text-secondary)', margin: 0 }}>
      {text}
    </p>
  );
}

// ── Money card ─────────────────────────────────────────────────────
function MoneyCard({ moneyBalance, lifetimeMoneySaved, onConvert }) {
  return (
    <div style={{
      padding: 18, borderRadius: 18,
      background: 'linear-gradient(135deg, #00352E, #00897B)',
      boxShadow: '0 6px 16px rgba(0,137,123,0.3)',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: -20, right: -20, width: 80, height: 80, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'rgba(255,255,255,0.75)', margin: '0 0 4px' }}>💵 Money Wallet</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 26, fontWeight: 700, color: '#fff', letterSpacing: -0.5, margin: '0 0 2px' }}>
        {moneyBalance.toFixed(2)} EGP
      </p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.65)', margin: '0 0 16px' }}>
        Saved lifetime: {lifetimeMoneySaved.toFixed(2)} EGP
      </p>
      <button onClick={onConvert} style={{
        padding: '8px 14px', borderRadius: 20, border: 'none', cursor: 'pointer',
        background: 'rgba(255,255,255,0.2)',
        fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#fff',
      }}>
        Convert to Points →
      </button>
    </div>
  );
}

// ── Points card ────────────────────────────────────────────────────
function PointsCard({ pointsBalance, lifetimePointsEarned, m2p, p2m, onConvert }) {
  return (
    <div style={{
      padding: 18, borderRadius: 18,
      background: 'linear-gradient(135deg, #00838F, #5BA89E)',
      boxShadow: '0 6px 16px rgba(91,168,158,0.3)',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: -20, right: -20, width: 80, height: 80, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'rgba(255,255,255,0.75)', margin: '0 0 4px' }}>⭐ Points Wallet</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 26, fontWeight: 700, color: '#fff', letterSpacing: -0.5, margin: '0 0 2px' }}>
        {pointsBalance.toFixed(0)} pts
      </p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'rgba(255,255,255,0.65)', margin: '0 0 16px' }}>
        Rate: {m2p.toFixed(0)} EGP = 100 pts  ·  1 pt = {p2m.toFixed(2)} EGP
      </p>
      <button onClick={onConvert} style={{
        padding: '8px 14px', borderRadius: 20, border: 'none', cursor: 'pointer',
        background: 'rgba(255,255,255,0.2)',
        fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#fff',
      }}>
        Convert to Money →
      </button>
    </div>
  );
}

// ── Transactions list ──────────────────────────────────────────────
function TransactionsList({ transactions }) {
  if (transactions.length === 0) {
    return (
      <div style={{
        padding: 16, borderRadius: 16, background: '#fff',
        border: '0.8px solid var(--color-border)',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <span style={{ fontSize: 18 }}>🧾</span>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>No transactions yet</span>
      </div>
    );
  }

  const shown = transactions.slice(0, 10);

  return (
    <div style={{
      background: '#fff', borderRadius: 16, border: '0.8px solid var(--color-border)',
      boxShadow: '0 2px 8px rgba(0,0,0,0.05)', overflow: 'hidden',
    }}>
      {shown.map((tx, i) => {
        const isLast = i === shown.length - 1;
        const { kind, isPositive, amountText, title, date } = tx;

        let iconBg, iconContent;
        if (kind === 'conversion') {
          iconBg = 'var(--color-primary-surface)';
          iconContent = '⭐';
        } else if (kind === 'money') {
          iconBg = isPositive ? 'var(--color-primary-surface)' : '#FFEBEE';
          iconContent = isPositive ? '↓' : '↑';
        } else {
          iconBg = isPositive ? 'var(--color-primary-surface)' : '#FFEBEE';
          iconContent = isPositive ? '⭐' : '🎁';
        }

        return (
          <div key={i} style={{
            padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: isLast ? 'none' : '0.5px solid var(--color-border-light, #F0F0F0)',
          }}>
            <div style={{
              width: 34, height: 34, borderRadius: 10, flexShrink: 0,
              background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15,
            }}>
              {iconContent}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {title || 'Transaction'}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#aaa', margin: 0 }}>
                {fmtDate(date)}
              </p>
            </div>
            <span style={{
              fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, whiteSpace: 'nowrap',
              color: isPositive ? 'var(--color-primary)' : 'var(--color-error)',
            }}>
              {amountText}
            </span>
          </div>
        );
      })}
    </div>
  );
}

// ── Conversion panel ───────────────────────────────────────────────
function ConversionPanel({ m2p, p2m, onMoneyToPoints, onPointsToMoney }) {
  return (
    <div style={{
      padding: 14, borderRadius: 16, background: '#fff',
      border: '0.8px solid var(--color-border)',
      boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
    }}>
      <div style={{
        padding: 10, borderRadius: 10, background: 'var(--color-primary-surface)', marginBottom: 12,
      }}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-primary)', fontWeight: 600, margin: 0 }}>
          1 EGP = {m2p.toFixed(0)} pts  ·  1 pt = {p2m.toFixed(2)} EGP
        </p>
      </div>
      <div style={{ display: 'flex', gap: 10 }}>
        <button onClick={onMoneyToPoints} style={{
          flex: 1, padding: '12px 4px', borderRadius: 12, border: 'none', cursor: 'pointer',
          background: 'linear-gradient(135deg, #00352E, #00897B)',
          boxShadow: '0 3px 8px rgba(0,137,123,0.25)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          <span style={{ fontSize: 13, color: '#fff' }}>↑</span>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#fff' }}>Money → Points</span>
        </button>
        <button onClick={onPointsToMoney} style={{
          flex: 1, padding: '12px 4px', borderRadius: 12, border: 'none', cursor: 'pointer',
          background: 'linear-gradient(135deg, #00838F, #5BA89E)',
          boxShadow: '0 3px 8px rgba(91,168,158,0.25)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          <span style={{ fontSize: 13, color: '#fff' }}>↓</span>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700, color: '#fff' }}>Points → Money</span>
        </button>
      </div>
    </div>
  );
}

// ── Conversion Sheet ───────────────────────────────────────────────
function ConversionSheet({ moneyToPoints, balance, m2p, p2m, onClose, onDone }) {
  const toast = useToast();
  const moneyBalance = +(balance.money_balance || 0);
  const pointsBalance = +(balance.points_balance || 0);
  const maxValue = moneyToPoints ? moneyBalance : pointsBalance;

  const [sliderValue, setSliderValue] = useState(Math.min(maxValue > 1 ? 1 : maxValue, maxValue));
  const [isLoading, setIsLoading] = useState(false);

  const converted = moneyToPoints
    ? sliderValue * m2p
    : sliderValue * p2m;

  const confirm = async () => {
    const msg = moneyToPoints
      ? `Convert ${sliderValue.toFixed(2)} EGP to ${converted.toFixed(0)} points?`
      : `Convert ${sliderValue.toFixed(0)} points to ${converted.toFixed(2)} EGP?`;
    if (!window.confirm(msg)) return;

    setIsLoading(true);
    try {
      if (moneyToPoints) {
        await api.convertMoneyToPoints(sliderValue);
      } else {
        await api.convertPointsToMoney(sliderValue);
      }
      toast('Conversion completed successfully.', 'success');
      onDone();
    } catch (e) {
      toast(`Conversion failed: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  if (maxValue <= 0) {
    return (
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}
        onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
        <div style={{ background: '#fff', borderRadius: '20px 20px 0 0', padding: '24px 20px' }}>
          <p style={{ fontFamily: 'var(--font-family)', textAlign: 'center', color: '#666' }}>
            {moneyToPoints ? 'No money available to convert.' : 'No points available to convert.'}
          </p>
          <button onClick={onClose} style={{ width: '100%', padding: '12px', borderRadius: 12, border: 'none', background: 'var(--color-primary)', color: '#fff', fontFamily: 'var(--font-family)', cursor: 'pointer', marginTop: 12 }}>Close</button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: '#fff', borderRadius: '20px 20px 0 0', padding: '24px 20px' }}>
        {/* Handle */}
        <div style={{ width: 36, height: 4, borderRadius: 2, background: 'var(--color-border)', margin: '0 auto 16px' }} />

        <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', margin: '0 0 6px' }}>
          {moneyToPoints ? 'Convert Money to Points' : 'Convert Points to Money'}
        </p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '0 0 18px' }}>
          1 EGP = {m2p.toFixed(2)} pts  ·  1 pt = {p2m.toFixed(2)} EGP
        </p>

        {/* Result preview */}
        <div style={{
          padding: 14, borderRadius: 12,
          background: 'var(--color-primary-surface)',
          border: '1px solid var(--color-border)',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          marginBottom: 4,
        }}>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>You receive</span>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 16, fontWeight: 700, color: 'var(--color-primary)' }}>
            {moneyToPoints ? `${converted.toFixed(0)} pts` : `${converted.toFixed(2)} EGP`}
          </span>
        </div>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#aaa', textAlign: 'center', margin: '0 0 10px' }}>
          for {sliderValue.toFixed(moneyToPoints ? 2 : 0)} {moneyToPoints ? 'EGP' : 'pts'}
        </p>

        {/* Slider */}
        <input
          type="range" min={0} max={maxValue} step={maxValue / 100}
          value={sliderValue}
          onChange={e => setSliderValue(+e.target.value)}
          style={{ width: '100%', accentColor: 'var(--color-primary)', marginBottom: 14 }}
        />

        {/* Confirm button */}
        <button onClick={isLoading ? undefined : confirm} style={{
          width: '100%', height: 50, borderRadius: 13, border: 'none',
          cursor: isLoading ? 'default' : 'pointer',
          background: isLoading ? '#ccc' : 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
          boxShadow: isLoading ? 'none' : 'var(--shadow-primary)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {isLoading
            ? <div style={{ width: 22, height: 22, border: '2px solid #fff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
            : <span style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: '#fff' }}>Confirm Conversion</span>
          }
        </button>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
