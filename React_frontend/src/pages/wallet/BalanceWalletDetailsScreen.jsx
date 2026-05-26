// ═══════════════════════════════════════════════════════════════
// BalanceWalletDetailsScreen — mirrors balance_wallet_details_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { RefreshCw } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

// ─────────────────────────────────────────────────────────────────
export default function BalanceWalletDetailsScreen() {
  const navigate = useNavigate();
  const toast = useToast();

  const [isLoading, setIsLoading] = useState(true);
  const [member, setMember] = useState({});
  const [summary, setSummary] = useState({});
  const [details, setDetails] = useState([]);
  const [selectedScope, setSelectedScope] = useState('all');

  const loadDetails = useCallback(async () => {
    setIsLoading(true);
    try {
      const data = await api.getBalanceWalletDetails();
      setMember(data.member || {});
      setSummary(data.summary || {});
      setDetails(Array.isArray(data.details) ? data.details : []);
    } catch (e) {
      toast(`Failed to load balance details: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { loadDetails(); }, [loadDetails]);

  // ── Filter (mirrors Flutter _filteredDetails getter) ───────────
  const filteredDetails = selectedScope === 'all'
    ? details
    : details.filter(d => (d.wallet_scope || '').toString() === selectedScope);

  const memberName = (member.member_name || 'Member').toString();
  const memberMail = (member.member_mail || '').toString();
  const moneySummary = summary.money_wallet || {};
  const personalSummary = summary.personal_budget || {};
  const sharedSummary = summary.shared_budget || {};

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title="Balance Details"
        onBack={() => navigate(-1)}
        actions={<IconBtn icon={RefreshCw} onClick={loadDetails} />}
      />

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', overflowY: 'auto', padding: 16 }}>
        {isLoading ? (
          <LoadingSpinner />
        ) : (
          <>
            {/* Header */}
            <Header name={memberName} mail={memberMail} />
            <div style={{ height: 16 }} />

            {/* Summary cards */}
            <SummaryCards moneySummary={moneySummary} personalSummary={personalSummary} sharedSummary={sharedSummary} />
            <div style={{ height: 16 }} />

            {/* Scope chips */}
            <ScopeChips selected={selectedScope} onSelect={setSelectedScope} />
            <div style={{ height: 12 }} />

            {/* Detail cards */}
            {filteredDetails.length === 0 ? (
              <EmptyState />
            ) : (
              filteredDetails.map((d, i) => <DetailCard key={d._id || i} detail={d} />)
            )}
          </>
        )}
      </div>
    </div>
  );
}

// ── Header ─────────────────────────────────────────────────────────
function Header({ name, mail }) {
  return (
    <div style={{
      padding: 16, borderRadius: 18,
      background: 'linear-gradient(135deg, #1B5E20, #43A047)',
      display: 'flex', alignItems: 'center', gap: 14,
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: '50%',
        background: 'rgba(255,255,255,0.24)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 28,
      }}>
        💰
      </div>
      <div>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: '#fff', margin: '0 0 2px' }}>{name}</p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'rgba(255,255,255,0.7)', margin: 0 }}>{mail}</p>
      </div>
    </div>
  );
}

// ── Summary Cards ──────────────────────────────────────────────────
function SummaryCards({ moneySummary, personalSummary, sharedSummary }) {
  const cards = [
    { title: 'Money Wallet', summary: moneySummary, color: '#1565C0' },
    { title: 'Personal Budget', summary: personalSummary, color: 'var(--color-primary)' },
    { title: 'Shared Budget', summary: sharedSummary, color: '#F57C00' },
  ];

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
      {cards.map(({ title, summary, color }) => {
        const credits = +(summary.credits || 0);
        const debits = +(summary.debits || 0);
        return (
          <div key={title} style={{
            flex: '1 1 calc(50% - 5px)', minWidth: 140,
            padding: 14, borderRadius: 16, background: '#fff',
            border: `1px solid ${color}20`,
          }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: '#555', margin: '0 0 8px' }}>
              {title}
            </p>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color, margin: 0 }}>
              {credits.toFixed(2)} in / {debits.toFixed(2)} out
            </p>
          </div>
        );
      })}
    </div>
  );
}

// ── Scope Chips ────────────────────────────────────────────────────
function ScopeChips({ selected, onSelect }) {
  const chips = [
    { label: 'All', value: 'all' },
    { label: 'Money', value: 'money_wallet' },
    { label: 'Personal', value: 'personal_budget' },
    { label: 'Shared', value: 'shared_budget' },
  ];

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      {chips.map(({ label, value }) => {
        const isSelected = selected === value;
        return (
          <button key={value} onClick={() => onSelect(value)} style={{
            padding: '6px 14px', borderRadius: 999, border: `1px solid ${isSelected ? '#1B5E20' : '#ccc'}`,
            background: isSelected ? 'rgba(27,94,32,0.14)' : '#fff', cursor: 'pointer',
            fontFamily: 'var(--font-family)', fontSize: 12,
            fontWeight: isSelected ? 700 : 500,
            color: isSelected ? '#1B5E20' : '#333',
            transition: 'all 0.15s',
          }}>
            {label}
          </button>
        );
      })}
    </div>
  );
}

// ── Detail Card ────────────────────────────────────────────────────
function DetailCard({ detail }) {
  const isCredit = detail.change_type === 'credit';
  const scope = (detail.wallet_scope || 'money_wallet').toString();
  const amount = +(detail.amount || 0);
  const title = (detail.title || 'Balance change').toString();
  const description = (detail.description || '').toString();
  const source = (detail.source_type || 'manual_adjustment').toString();
  const author = (detail.added_by_mail || detail.member_mail || '').toString();

  let dateStr = '-';
  try {
    if (detail.createdAt) {
      const d = new Date(detail.createdAt);
      dateStr = `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${d.getFullYear()}`;
    }
  } catch (_) {}

  return (
    <div style={{
      marginBottom: 10, padding: 14, borderRadius: 16, background: '#fff',
      border: `1px solid ${isCredit ? 'rgba(0,137,123,0.25)' : 'rgba(229,57,53,0.22)'}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        {/* Amount badge */}
        <div style={{
          padding: '6px 10px', borderRadius: 999,
          background: `${isCredit ? 'var(--color-primary)' : 'var(--color-error)'}1F`,
        }}>
          <span style={{
            fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 13,
            color: isCredit ? 'var(--color-primary)' : 'var(--color-error)',
          }}>
            {isCredit ? '+' : '-'}{amount.toFixed(2)}
          </span>
        </div>
        <p style={{ flex: 1, fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {title}
        </p>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#666', flexShrink: 0 }}>
          {dateStr}
        </span>
      </div>
      <div style={{ height: 8 }} />
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: '#555', margin: '0 0 4px' }}>
        {scope.replace(/_/g, ' ')}
      </p>
      {description && (
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#555', margin: '0 0 6px' }}>
          {description}
        </p>
      )}
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#888', margin: '0 0 2px' }}>
        Source: {source}
      </p>
      {author && (
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#888', margin: 0 }}>
          By: {author}
        </p>
      )}
    </div>
  );
}

// ── Empty State ─────────────────────────────────────────────────────
function EmptyState() {
  return (
    <div style={{
      padding: 24, borderRadius: 16, background: '#fff',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10,
    }}>
      <span style={{ fontSize: 42 }}>🧾</span>
      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, margin: 0 }}>No balance details yet</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#888', textAlign: 'center', margin: 0 }}>
        Balance changes will appear here once money is added or deducted.
      </p>
    </div>
  );
}
