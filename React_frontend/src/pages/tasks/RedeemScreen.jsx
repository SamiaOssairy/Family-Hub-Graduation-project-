// ═══════════════════════════════════════════════════════════════
// Redeem Screen — mirrors redeem_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Gift, RefreshCw, Plus, Trash2 } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

const TABS = ['My Wishlist', 'Redeem', 'My Redemptions', 'Pending (Parent)'];

export default function RedeemScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const { isParent } = useAuth();

  const [activeTab, setActiveTab]     = useState(0);
  const [loading, setLoading]         = useState(true);
  const [wallet, setWallet]           = useState(null);
  const [wishlist, setWishlist]       = useState([]);
  const [redemptions, setRedemptions] = useState([]);
  const [pending, setPending]         = useState([]);

  // Add wishlist item modal
  const [showAddWish, setShowAddWish] = useState(false);
  const [wishName, setWishName]       = useState('');
  const [wishDesc, setWishDesc]       = useState('');
  const [wishPrice, setWishPrice]     = useState('');

  // Redeem modal
  const [showRedeem, setShowRedeem]   = useState(false);
  const [selectedItem, setSelectedItem] = useState(null);

  // Reject note modal
  const [showRejectNote, setShowRejectNote] = useState(false);
  const [rejectId, setRejectId]       = useState('');
  const [rejectNote, setRejectNote]   = useState('');
  const [saving, setSaving]           = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const tasks = [
        api.getMyWallet(),
        api.getMyWishlistItems(),
        api.getMyRedemptions(),
      ];
      if (isParent) tasks.push(api.getPendingRedemptions());
      const results = await Promise.all(tasks);
      setWallet(results[0]);
      setWishlist(results[1]);
      setRedemptions(results[2]);
      if (isParent && results[3]) setPending(results[3]);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [isParent]);

  useEffect(() => { load(); }, [load]);

  // ── Add wishlist item ─────────────────────────────────────────
  async function addWishlistItem() {
    if (!wishName.trim()) return;
    setSaving(true);
    try {
      await api.addWishlistItem({
        item_name: wishName.trim(),
        description: wishDesc.trim(),
        estimated_price: wishPrice ? +wishPrice : 0,
      });
      setShowAddWish(false);
      setWishName(''); setWishDesc(''); setWishPrice('');
      toast('Wishlist item added!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Delete wishlist item ──────────────────────────────────────
  async function deleteWishItem(itemId) {
    try {
      await api.deleteWishlistItem(itemId);
      toast('Item removed');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  // ── Request redemption ────────────────────────────────────────
  function openRedeem(item) {
    setSelectedItem(item);
    setShowRedeem(true);
  }

  async function requestRedeem() {
    if (!selectedItem) return;
    setSaving(true);
    try {
      await api.requestRedemption({ wishlist_item_id: selectedItem._id });
      setShowRedeem(false);
      toast(t('redemptionRequested'));
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Cancel redemption ─────────────────────────────────────────
  async function cancelRedemption(id) {
    try {
      await api.cancelRedemption(id);
      toast('Redemption cancelled');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  // ── Parent: approve/reject ─────────────────────────────────────
  async function handleApprove(id, approved) {
    if (!approved) { setRejectId(id); setRejectNote(''); setShowRejectNote(true); return; }
    try {
      await api.parentApproveRedemption(id, true);
      toast('Approved!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  async function rejectWithNote() {
    setSaving(true);
    try {
      await api.parentApproveRedemption(rejectId, false, rejectNote);
      setShowRejectNote(false);
      toast('Rejected');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  const card = (children) => (
    <div style={{
      background: 'var(--color-white)', borderRadius: 16,
      border: '1px solid var(--color-border)',
      padding: 14, marginBottom: 10,
      boxShadow: 'var(--shadow-card)',
    }}>{children}</div>
  );

  const tabLabels = isParent
    ? ['Wishlist', 'Redemptions', 'Pending']
    : ['My Wishlist', 'Redeem', 'My Redemptions'];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('redeemPoints')}
        actions={<IconBtn icon={RefreshCw} onClick={load} />}
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 24px' }}>
          {/* Points summary */}
          <div style={{
            margin: '12px 16px',
            background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
            borderRadius: 14, padding: '14px 18px',
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: '50%',
              background: 'rgba(255,255,255,0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 22,
            }}>⭐</div>
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.8)', margin: 0 }}>Available Points</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 28, fontWeight: 800, color: '#fff', margin: 0 }}>
                {wallet?.total_points || 0}
              </p>
            </div>
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', overflowX: 'auto', borderBottom: '1px solid var(--color-border)', padding: '4px 16px 0' }}>
            {[t('myWishlist'), 'Redeem', t('myRedemptions'), ...(isParent ? [t('pendingRedemptions')] : [])].map((tab, i) => (
              <button key={i} onClick={() => setActiveTab(i)} style={{
                padding: '8px 14px', flexShrink: 0,
                background: 'none', border: 'none',
                fontFamily: 'var(--font-family)', fontSize: 12,
                fontWeight: activeTab === i ? 700 : 500,
                color: activeTab === i ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                cursor: 'pointer',
                borderBottom: activeTab === i ? '2px solid var(--color-primary)' : '2px solid transparent',
              }}>{tab}</button>
            ))}
          </div>

          <div style={{ padding: '12px 16px' }}>
            {/* Tab 0: My Wishlist */}
            {activeTab === 0 && (
              <>
                <button onClick={() => setShowAddWish(true)} style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  padding: '10px 16px', marginBottom: 12,
                  background: 'var(--color-primary)', color: '#fff',
                  border: 'none', borderRadius: 10, cursor: 'pointer',
                  fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                }}>
                  <Plus size={16} /> Add to Wishlist
                </button>
                {wishlist.length === 0
                  ? <EmptyState icon={Gift} message={t('noWishlistItems')} />
                  : wishlist.map(item => card(
                    <div key={item._id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 10 }}>
                      <div style={{ flex: 1 }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>
                          {item.item_name}
                        </p>
                        {item.description && (
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>
                            {item.description}
                          </p>
                        )}
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)', margin: '6px 0 0' }}>
                          {t('estimatedPrice')}: {item.estimated_price || 0} EGP
                        </p>
                      </div>
                      <button onClick={() => deleteWishItem(item._id)} style={{
                        background: 'none', border: 'none', cursor: 'pointer',
                        color: '#E53935', padding: 4,
                      }}>
                        <Trash2 size={16} />
                      </button>
                    </div>
                  ))
                }
              </>
            )}

            {/* Tab 1: Redeem */}
            {activeTab === 1 && (
              <>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', marginBottom: 12 }}>
                  Select a wishlist item to redeem with your points:
                </p>
                {wishlist.filter(i => !i.is_funded).length === 0
                  ? <EmptyState icon={Gift} message="No items to redeem. Add items to your wishlist first." />
                  : wishlist.filter(i => !i.is_funded).map(item => (
                    <div key={item._id} onClick={() => openRedeem(item)} style={{
                      background: 'var(--color-white)', borderRadius: 14,
                      border: '1px solid var(--color-border)',
                      padding: 14, marginBottom: 10,
                      boxShadow: 'var(--shadow-card)', cursor: 'pointer',
                      transition: 'box-shadow 0.2s',
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>
                          {item.item_name}
                        </p>
                        <span style={{
                          background: 'var(--color-primary)', color: '#fff',
                          padding: '4px 12px', borderRadius: 8,
                          fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
                        }}>{t('redeemNow')}</span>
                      </div>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '4px 0 0' }}>
                        ~{item.estimated_price || 0} EGP
                      </p>
                    </div>
                  ))
                }
              </>
            )}

            {/* Tab 2: My Redemptions */}
            {activeTab === 2 && (
              redemptions.length === 0
                ? <EmptyState icon={Gift} message="No redemptions yet" />
                : redemptions.map(r => card(
                  <div key={r._id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                    <div style={{ flex: 1 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                        {r.wishlist_item_id?.item_name || 'Item'}
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>
                        {r.points_used || 0} pts used
                      </p>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                      <StatusBadge status={r.status} />
                      {r.status === 'pending' && (
                        <button onClick={() => cancelRedemption(r._id)} style={{
                          background: 'none', border: '1px solid #E53935',
                          color: '#E53935', borderRadius: 6, padding: '2px 8px',
                          fontFamily: 'var(--font-family)', fontSize: 10, cursor: 'pointer',
                        }}>Cancel</button>
                      )}
                    </div>
                  </div>
                ))
            )}

            {/* Tab 3: Pending (Parent) */}
            {activeTab === 3 && isParent && (
              pending.length === 0
                ? <EmptyState icon={Gift} message="No pending redemptions" />
                : pending.map(r => card(
                  <div key={r._id}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <Avatar name={r.member_mail?.split('@')[0] || '?'} size={32} />
                        <div>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                            {r.wishlist_item_id?.item_name || 'Item'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                            {r.member_mail} · {r.points_used || 0} pts
                          </p>
                        </div>
                      </div>
                      <StatusBadge status={r.status} />
                    </div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button onClick={() => handleApprove(r._id, true)} style={{
                        flex: 1, padding: '8px 0',
                        background: 'var(--color-primary)', border: 'none',
                        borderRadius: 8, color: '#fff', cursor: 'pointer',
                        fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                      }}>✓ Approve</button>
                      <button onClick={() => handleApprove(r._id, false)} style={{
                        flex: 1, padding: '8px 0',
                        background: '#E53935', border: 'none',
                        borderRadius: 8, color: '#fff', cursor: 'pointer',
                        fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                      }}>✗ Reject</button>
                    </div>
                  </div>
                ))
            )}
          </div>
        </div>
      )}

      {/* Add Wishlist Item Modal */}
      <Modal
        open={showAddWish}
        onClose={() => setShowAddWish(false)}
        title="Add Wishlist Item"
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowAddWish(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Add'} disabled={saving || !wishName.trim()} onClick={addWishlistItem} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Item Name" value={wishName} onChange={setWishName} required />
          <FormField label="Description" value={wishDesc} onChange={setWishDesc} />
          <FormField label="Estimated Price (EGP)" value={wishPrice} onChange={setWishPrice} type="number" min="0" step="0.01" />
        </div>
      </Modal>

      {/* Redeem Confirmation */}
      <Modal
        open={showRedeem}
        onClose={() => setShowRedeem(false)}
        title="🎁 Redeem Item"
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowRedeem(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Request Redemption'} disabled={saving} onClick={requestRedeem} />
          </>
        }
      >
        {selectedItem && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-primary)' }}>
              Request redemption for <strong>{selectedItem.item_name}</strong>?
            </p>
            <div style={{
              padding: 12, background: 'var(--color-primary-surface)',
              borderRadius: 10, border: '1px solid var(--color-border)',
            }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)', margin: 0 }}>
                Estimated: {selectedItem.estimated_price || 0} EGP
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '4px 0 0' }}>
                Your balance: {wallet?.total_points || 0} pts
              </p>
            </div>
          </div>
        )}
      </Modal>

      {/* Reject Note Modal */}
      <Modal
        open={showRejectNote}
        onClose={() => setShowRejectNote(false)}
        title="Reject Redemption"
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowRejectNote(false)} />
            <button onClick={rejectWithNote} disabled={saving} style={{
              padding: '8px 20px', background: '#E53935', border: 'none',
              borderRadius: 10, color: '#fff', cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 600,
            }}>{saving ? '…' : 'Reject'}</button>
          </>
        }
      >
        <FormField label="Rejection Reason (optional)" value={rejectNote} onChange={setRejectNote} rows={3} />
      </Modal>
    </div>
  );
}
