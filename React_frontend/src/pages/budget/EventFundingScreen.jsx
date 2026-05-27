// ═══════════════════════════════════════════════════════════════
// EventFundingScreen — mirrors event_funding_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

// ─────────────────────────────────────────────────────────────────
export default function EventFundingScreen() {
  const navigate = useNavigate();
  const location = useLocation();
  const toast = useToast();
  const { isParent } = useAuth();

  const { id: paramId } = useParams();
  // Get eventId from route state or params (mirrors Flutter didChangeDependencies)
  const eventId = location.state?.eventId || paramId || null;

  const [isLoading, setIsLoading] = useState(true);
  const [funding, setFunding] = useState({});
  const [members, setMembers] = useState([]);
  const [myPoints, setMyPoints] = useState(0);
  const [isAutoSaveEnabled, setIsAutoSaveEnabled] = useState(false);
  const [tabs, setTabs] = useState([]);
  const [activeTab, setActiveTab] = useState(0);

  // ── Load data (mirrors Flutter _loadData) ──────────────────────
  const loadData = useCallback(async () => {
    if (!eventId) { setIsLoading(false); return; }
    setIsLoading(true);
    try {
      const [fundingData, walletData] = await Promise.all([
        api.getEventFundingStatus(eventId),
        api.getMyWallet(),
      ]);

      let membersData = [];
      if (isParent) {
        membersData = await api.getAllMembers().catch(() => []);
      }

      const fundingMap = fundingData || {};
      const nextTabs = buildTabs(fundingMap);

      setFunding(fundingMap);
      setMyPoints(+(walletData?.total_points || 0));
      setMembers(membersData);
      setTabs(nextTabs);
    } catch (e) {
      toast(`Failed to load event funding: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  }, [eventId, isParent]);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Build tabs (mirrors Flutter _setupTabs) ─────────────────────
  function buildTabs(f) {
    const source = (f.funding_source || '').toString();
    const requiredPoints = +(f.required_points || 0);
    const result = [];
    if (source === 'budget') result.push({ id: 'budget', title: 'Family Budget' });
    if (source === 'member_contributions' || source === 'budget') result.push({ id: 'contributions', title: 'Member Contributions' });
    if (requiredPoints > 0 || source === 'points_redeem') result.push({ id: 'points', title: 'Points Redemption' });
    if (result.length === 0) result.push({ id: 'contributions', title: 'Member Contributions' });
    return result;
  }

  // ── Adjust funding goal (mirrors Flutter _adjustFundingGoal) ────
  const adjustFundingGoal = async () => {
    const estimated = +(funding.total_estimated_cost || 0);
    const input = window.prompt('Enter new estimated cost:', estimated.toFixed(0));
    if (input === null) return;
    const val = parseFloat(input);
    if (isNaN(val) || val < 0) return;
    try {
      await api.adjustEventFundingGoal(eventId, val);
      toast('Funding goal updated', 'success');
      loadData();
    } catch (e) {
      toast(`Update failed: ${e.message}`, 'error');
    }
  };

  // ── Redeem spot (mirrors Flutter _redeemSpot) ───────────────────
  const redeemSpot = async () => {
    const requiredPoints = +(funding.required_points || 0);
    if (requiredPoints <= 0) {
      toast('No points requirement found for this event', 'info');
      return;
    }
    try {
      await api.redeemEventSpot({ eventId, pointsToUse: requiredPoints });
      toast('Spot redeemed successfully', 'success');
      loadData();
    } catch (e) {
      toast(`Redeem failed: ${e.message}`, 'error');
    }
  };

  if (!eventId) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: '#F4F6F8' }}>
        <AppBar title="Event Funding" onBack={() => navigate(-1)} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 24 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, color: 'var(--color-error)' }}>Missing event ID</p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: '#F4F6F8' }}>
      <AppBar title="Event Funding" onBack={() => navigate(-1)} />

      <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', overflowY: 'auto', padding: 16 }}>
        {isLoading ? (
          <LoadingSpinner />
        ) : (
          <>
            {/* Header card */}
            <HeaderCard
              funding={funding}
              isParent={isParent}
              onAdjust={adjustFundingGoal}
            />
            <div style={{ height: 14 }} />

            {/* Tab bar */}
            {tabs.length > 0 && (
              <div style={{ background: '#fff', borderRadius: 14, overflow: 'hidden', marginBottom: 12 }}>
                <div style={{ display: 'flex' }}>
                  {tabs.map((tab, i) => (
                    <button key={tab.id} onClick={() => setActiveTab(i)} style={{
                      flex: 1, padding: '10px 4px', border: 'none', cursor: 'pointer',
                      background: 'transparent', fontFamily: 'var(--font-family)', fontSize: 12,
                      fontWeight: activeTab === i ? 600 : 400,
                      color: activeTab === i ? 'var(--color-primary)' : '#555',
                      borderBottom: `2px solid ${activeTab === i ? 'var(--color-primary)' : 'transparent'}`,
                    }}>{tab.title}</button>
                  ))}
                </div>
              </div>
            )}

            {/* Tab content */}
            {tabs.length > 0 && tabs[activeTab] && (
              <div>
                {tabs[activeTab].id === 'budget' && (
                  <BudgetTab funding={funding} isAutoSaveEnabled={isAutoSaveEnabled} setIsAutoSaveEnabled={setIsAutoSaveEnabled} />
                )}
                {tabs[activeTab].id === 'points' && (
                  <PointsTab funding={funding} myPoints={myPoints} onRedeem={redeemSpot} />
                )}
                {tabs[activeTab].id === 'contributions' && (
                  <ContributionsTab
                    funding={funding} isParent={isParent} members={members}
                    eventId={eventId} onRefresh={loadData}
                  />
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

// ── Header Card ────────────────────────────────────────────────────
function HeaderCard({ funding, isParent, onAdjust }) {
  const title = (funding.event_title || 'Event').toString();
  const eventDateRaw = funding.event_date;
  const eventDate = eventDateRaw ? new Date(eventDateRaw) : null;
  const totalCost = +(funding.total_estimated_cost || 0);
  const progressPct = +(funding.progress_percentage || 0);
  const daysRemaining = +(funding.days_remaining || 0);
  const totalContributed = +(funding.total_contributed_money || 0);

  return (
    <div style={{
      padding: 16, borderRadius: 16,
      background: 'linear-gradient(135deg, #388E3C, #66BB6A)',
    }}>
      <div style={{ display: 'flex', alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 20, fontWeight: 700, color: '#fff', margin: '0 0 4px' }}>{title}</p>
          <p style={{ fontFamily: 'var(--font-family)', color: 'rgba(255,255,255,0.7)', margin: '0 0 2px', fontSize: 13 }}>
            Date: {eventDate ? eventDate.toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' }) : '-'}
          </p>
          <p style={{ fontFamily: 'var(--font-family)', color: 'rgba(255,255,255,0.7)', margin: 0, fontSize: 13 }}>
            Estimated Cost: {totalCost.toFixed(2)} EGP
          </p>
        </div>
        {isParent && (
          <button onClick={onAdjust} style={{
            background: 'rgba(255,255,255,0.2)', border: 'none', cursor: 'pointer',
            borderRadius: 8, padding: '6px 10px', color: '#fff', fontSize: 18,
          }} title="Adjust Funding Goal">⚙️</button>
        )}
      </div>
      <div style={{ height: 12 }} />
      <div style={{ height: 10, borderRadius: 999, background: 'rgba(255,255,255,0.25)', overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${Math.min(progressPct, 100)}%`, background: '#fff', borderRadius: 999, transition: 'width 0.3s' }} />
      </div>
      <div style={{ marginTop: 10, display: 'flex', alignItems: 'center' }}>
        <span style={{ fontFamily: 'var(--font-family)', color: '#fff', fontWeight: 600, flex: 1, fontSize: 13 }}>
          {progressPct.toFixed(1)}% funded
        </span>
        <span style={{ fontFamily: 'var(--font-family)', color: 'rgba(255,255,255,0.7)', fontSize: 13 }}>
          {totalContributed.toFixed(2)} EGP raised
        </span>
      </div>
      <p style={{
        fontFamily: 'var(--font-family)', fontSize: 13, margin: '4px 0 0',
        color: daysRemaining <= 7 ? '#FFE0B2' : 'rgba(255,255,255,0.7)',
        fontWeight: daysRemaining <= 7 ? 700 : 500,
      }}>
        {daysRemaining} days remaining
      </p>
    </div>
  );
}

// ── Panel wrapper ──────────────────────────────────────────────────
function Panel({ children, style = {} }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 14, padding: 14, marginBottom: 10,
      boxShadow: '0 3px 10px rgba(0,0,0,0.08)',
      ...style,
    }}>
      {children}
    </div>
  );
}

function InfoRow({ label, value }) {
  return (
    <div style={{ display: 'flex', padding: '2px 0' }}>
      <span style={{ flex: 1, fontFamily: 'var(--font-family)', color: '#666', fontSize: 13 }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13 }}>{value}</span>
    </div>
  );
}

// ── Budget Tab ─────────────────────────────────────────────────────
function BudgetTab({ funding, isAutoSaveEnabled, setIsAutoSaveEnabled }) {
  const toast = useToast();
  const monthly = +(funding.monthly_savings_needed || 0);
  const remaining = +(funding.remaining_needed || 0);
  const rewardsBudget = funding.rewards_budget_remaining;

  return (
    <Panel>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, fontWeight: 700, margin: '0 0 10px' }}>Savings Plan</p>
      <InfoRow label="Remaining needed" value={`${remaining.toFixed(2)} EGP`} />
      <InfoRow label="Monthly savings needed" value={`${monthly.toFixed(2)} EGP / month`} />
      {rewardsBudget != null && (
        <InfoRow label="Rewards budget remaining" value={`${(+rewardsBudget).toFixed(2)} EGP`} />
      )}
      <div style={{ height: 12 }} />
      <button
        onClick={() => {
          setIsAutoSaveEnabled(v => !v);
          toast(isAutoSaveEnabled ? 'Auto-Save disabled' : 'Auto-Save enabled (UI toggle)', 'info');
        }}
        style={{
          width: '100%', padding: '12px', borderRadius: 8, border: 'none', cursor: 'pointer',
          background: 'var(--color-primary)', color: '#fff',
          fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}
      >
        <span>{isAutoSaveEnabled ? '✅' : '💰'}</span>
        {isAutoSaveEnabled ? 'Auto-Save Enabled' : 'Set Auto-Save'}
      </button>
    </Panel>
  );
}

// ── Points Tab ─────────────────────────────────────────────────────
function PointsTab({ funding, myPoints, onRedeem }) {
  const cost = +(funding.required_points || 0);
  const redeemedRaw = funding.members_redeemed_spots;
  const redeemed = Array.isArray(redeemedRaw)
    ? redeemedRaw.map(r => (r instanceof Object ? r : {}))
    : [];

  return (
    <>
      <Panel>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, fontWeight: 700, margin: '0 0 8px' }}>Buy Your Spot</p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, margin: '0 0 4px' }}>Cost: {cost.toFixed(0)} Points</p>
        <p style={{ fontFamily: 'var(--font-family)', color: '#666', margin: '0 0 12px', fontSize: 13 }}>Current points balance: {myPoints}</p>
        <button
          onClick={myPoints >= cost ? onRedeem : undefined}
          disabled={myPoints < cost}
          style={{
            width: '100%', padding: '12px', borderRadius: 8, border: 'none',
            cursor: myPoints >= cost ? 'pointer' : 'not-allowed',
            background: myPoints >= cost ? 'var(--color-primary)' : '#ccc',
            color: '#fff', fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
          }}
        >
          Redeem Spot
        </button>
      </Panel>
      <Panel>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, margin: '0 0 8px' }}>Members Who Redeemed Spots</p>
        {redeemed.length === 0 ? (
          <p style={{ fontFamily: 'var(--font-family)', color: '#666', fontSize: 13 }}>No spots redeemed yet.</p>
        ) : redeemed.map((r, i) => {
          const mail = (r.member_mail || 'Member').toString();
          const pointsUsed = +(r.points_used || 0);
          const redeemedAt = r.redeemed_at ? new Date(r.redeemed_at) : null;
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '8px 0', borderBottom: i < redeemed.length - 1 ? '0.5px solid var(--color-border)' : 'none' }}>
              <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--color-background)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, color: 'var(--color-primary)' }}>
                👤
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, margin: '0 0 2px', fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{mail}</p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#666', margin: 0 }}>
                  {redeemedAt ? redeemedAt.toLocaleDateString('en-US', { day: '2-digit', month: 'short' }) + ', ' + redeemedAt.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : 'Unknown date'}
                </p>
              </div>
              <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 13 }}>{pointsUsed.toFixed(0)} pts</span>
            </div>
          );
        })}
      </Panel>
    </>
  );
}

// ── Contributions Tab ──────────────────────────────────────────────
function ContributionsTab({ funding, isParent, members, eventId, onRefresh }) {
  const toast = useToast();
  const [showSheet, setShowSheet] = useState(false);
  const [sheetMember, setSheetMember] = useState(null);
  const [markPaidRow, setMarkPaidRow] = useState(null);

  const breakdownRaw = funding.breakdown_by_member;
  const rows = Array.isArray(breakdownRaw)
    ? breakdownRaw.map(e => (e instanceof Object ? e : {}))
    : [];

  const handleMarkPaid = async (row, amount, type) => {
    try {
      await api.markEventContributionPaid(eventId, {
        memberId: (row.member_id || '').toString(),
        contributionType: type,
        amount,
      });
      toast('Marked as paid', 'success');
      setMarkPaidRow(null);
      onRefresh();
    } catch (e) {
      toast(`Could not mark paid: ${e.message}`, 'error');
    }
  };

  return (
    <>
      {isParent && (
        <button onClick={() => { setSheetMember(null); setShowSheet(true); }} style={{
          width: '100%', padding: '12px', borderRadius: 8, border: 'none', cursor: 'pointer',
          background: 'var(--color-primary)', color: '#fff',
          fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, marginBottom: 10,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          + Add Contribution
        </button>
      )}

      {rows.length === 0 ? (
        <Panel><p style={{ fontFamily: 'var(--font-family)', color: '#666', fontSize: 13 }}>No contributions yet.</p></Panel>
      ) : (
        rows.map((row, i) => {
          const promisedMoney = +(row.amount_promised || 0);
          const paidMoney = +(row.amount_paid || 0);
          const promisedPoints = +(row.points_promised || 0);
          const paidPoints = +(row.points_paid || 0);
          const totalTarget = promisedMoney + paidMoney + promisedPoints + paidPoints;
          const done = paidMoney + paidPoints;
          const progress = totalTarget <= 0 ? 0 : Math.min(done / totalTarget, 1);

          return (
            <Panel key={i}>
              <div style={{ display: 'flex', alignItems: 'center', marginBottom: 6 }}>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, flex: 1 }}>
                  {(row.member_name || 'Member').toString()}
                </span>
                <button onClick={() => { setSheetMember(row); setShowSheet(true); }} style={{
                  padding: '6px 14px', borderRadius: 8, border: '1px solid var(--color-border)',
                  background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 12,
                }}>Contribute</button>
              </div>
              <InfoRow label="Promised amount" value={`${promisedMoney.toFixed(2)} EGP`} />
              <InfoRow label="Paid amount" value={`${paidMoney.toFixed(2)} EGP`} />
              <InfoRow label="Promised points" value={`${promisedPoints.toFixed(0)} pts`} />
              <InfoRow label="Paid points" value={`${paidPoints.toFixed(0)} pts`} />
              <div style={{ height: 8, borderRadius: 999, background: '#eee', overflow: 'hidden', margin: '8px 0 6px' }}>
                <div style={{ height: '100%', width: `${progress * 100}%`, background: 'var(--color-primary)', borderRadius: 999, transition: 'width 0.3s' }} />
              </div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#666', margin: 0 }}>
                Progress: {(progress * 100).toFixed(0)}%
              </p>
              {isParent && (promisedMoney > 0 || promisedPoints > 0) && (
                <button onClick={() => setMarkPaidRow(row)} style={{
                  display: 'block', marginTop: 6, padding: '6px 12px', borderRadius: 8,
                  border: 'none', background: 'var(--color-primary-surface)', cursor: 'pointer',
                  fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-primary)', fontWeight: 600,
                }}>
                  ✓ Mark as Paid
                </button>
              )}
            </Panel>
          );
        })
      )}

      {showSheet && (
        <ContributeSheet
          member={sheetMember}
          members={members}
          isParent={isParent}
          eventId={eventId}
          onClose={() => setShowSheet(false)}
          onSaved={() => { setShowSheet(false); onRefresh(); }}
        />
      )}

      {markPaidRow && (
        <MarkPaidDialog
          row={markPaidRow}
          onClose={() => setMarkPaidRow(null)}
          onConfirm={handleMarkPaid}
        />
      )}
    </>
  );
}

// ── Contribute Sheet ───────────────────────────────────────────────
function ContributeSheet({ member, members, isParent, eventId, onClose, onSaved }) {
  const toast = useToast();
  const [amount, setAmount] = useState('');
  const [contributionType, setContributionType] = useState('money');
  const [paymentMode, setPaymentMode] = useState('pay_now');
  const [selectedMemberId, setSelectedMemberId] = useState(member?.member_id || '');
  const [isLoading, setIsLoading] = useState(false);

  const submit = async () => {
    const amountNum = parseFloat(amount);
    if (!amountNum || amountNum <= 0) { toast('Please enter a valid amount', 'error'); return; }
    if (isParent && !selectedMemberId) { toast('Please select a member', 'error'); return; }
    setIsLoading(true);
    try {
      await api.contributeToEvent(eventId, {
        contributionType, amount: amountNum, paymentMode,
        memberId: selectedMemberId || undefined,
        manualEntry: isParent && paymentMode === 'pay_now',
      });
      toast('Contribution saved', 'success');
      onSaved();
    } catch (e) {
      toast(`Contribution failed: ${e.message}`, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const chipStyle = (active) => ({
    padding: '6px 14px', borderRadius: 999, border: 'none', cursor: 'pointer',
    background: active ? 'var(--color-primary)' : 'var(--color-primary-surface)',
    color: active ? '#fff' : 'var(--color-primary)',
    fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12,
  });

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: '#fff', borderRadius: '24px 24px 0 0', padding: 20, maxHeight: '85vh', overflowY: 'auto' }}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, margin: '0 0 14px' }}>
          {member ? `Contribute for ${member.member_name || 'Member'}` : 'Add Contribution'}
        </p>

        {isParent && (
          <>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, margin: '0 0 8px' }}>Member</p>
            <select value={selectedMemberId} onChange={e => setSelectedMemberId(e.target.value)}
              style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--color-border)', fontFamily: 'var(--font-family)', fontSize: 14, marginBottom: 12, boxSizing: 'border-box' }}>
              <option value="">Select member</option>
              {members.map(m => (
                <option key={m._id} value={m._id}>{m.username || m.mail || 'Member'}</option>
              ))}
            </select>
          </>
        )}

        <input value={amount} onChange={e => setAmount(e.target.value)} type="number" placeholder="Amount"
          style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--color-border)', fontFamily: 'var(--font-family)', fontSize: 14, marginBottom: 12, boxSizing: 'border-box', outline: 'none' }} />

        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, margin: '0 0 8px' }}>Use points instead?</p>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
          <button style={chipStyle(contributionType === 'money')} onClick={() => setContributionType('money')}>Money</button>
          <button style={chipStyle(contributionType === 'points')} onClick={() => setContributionType('points')}>Points</button>
        </div>

        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, margin: '0 0 8px' }}>Contribution Mode</p>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
          <button style={chipStyle(paymentMode === 'pay_now')} onClick={() => setPaymentMode('pay_now')}>Pay now</button>
          <button style={chipStyle(paymentMode === 'promise')} onClick={() => setPaymentMode('promise')}>Promise to pay later</button>
        </div>

        <button onClick={isLoading ? undefined : submit} style={{
          width: '100%', padding: '14px', borderRadius: 8, border: 'none',
          cursor: isLoading ? 'default' : 'pointer',
          background: isLoading ? '#ccc' : 'var(--color-primary)', color: '#fff',
          fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {isLoading ? <div style={{ width: 20, height: 20, border: '2px solid #fff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} /> : 'Save Contribution'}
        </button>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

// ── Mark Paid Dialog ───────────────────────────────────────────────
function MarkPaidDialog({ row, onClose, onConfirm }) {
  const [amount, setAmount] = useState('');
  const [type, setType] = useState('money');

  const chipStyle = (active) => ({
    padding: '6px 14px', borderRadius: 999, border: 'none', cursor: 'pointer',
    background: active ? 'var(--color-primary)' : 'var(--color-primary-surface)',
    color: active ? '#fff' : 'var(--color-primary)',
    fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12,
  });

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: '#fff', borderRadius: 16, padding: 20, width: '100%', maxWidth: 380 }}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, fontWeight: 700, margin: '0 0 10px' }}>Mark as Paid</p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, margin: '0 0 10px', color: '#555' }}>
          Member: {row.member_name || 'Member'}
        </p>
        <input value={amount} onChange={e => setAmount(e.target.value)} type="number" placeholder="Amount to mark paid"
          style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--color-border)', fontFamily: 'var(--font-family)', fontSize: 14, marginBottom: 10, boxSizing: 'border-box', outline: 'none' }} />
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          <button style={chipStyle(type === 'money')} onClick={() => setType('money')}>Money</button>
          <button style={chipStyle(type === 'points')} onClick={() => setType('points')}>Points</button>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px', borderRadius: 8, border: '1px solid var(--color-border)', background: 'transparent', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 13 }}>
            Cancel
          </button>
          <button onClick={() => {
            const amountNum = parseFloat(amount);
            if (!amountNum || amountNum <= 0) return;
            onConfirm(row, amountNum, type);
          }} style={{ flex: 1, padding: '10px', borderRadius: 8, border: 'none', background: 'var(--color-primary)', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 13, color: '#fff', fontWeight: 600 }}>
            Confirm
          </button>
        </div>
      </div>
    </div>
  );
}
