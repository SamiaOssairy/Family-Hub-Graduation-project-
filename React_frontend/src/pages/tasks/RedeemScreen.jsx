// ═══════════════════════════════════════════════════════════════
// RedeemScreen — SPENDING points (the transaction/approval workflow).
// Member: request a redemption for an affordable wishlist item, track
// requests, accept after a parent approves. Parent: approve/reject.
// Managing the wishlist itself lives on the separate Wishlist screen.
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Gift, RefreshCw, Star } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import * as api from '../../api/apiService';

export default function RedeemScreen() {
  const toast = useToast();
  const navigate = useNavigate();
  const { isParent } = useAuth();
  const { language } = useTheme();
  const t = (en, ar) => (language === 'ar' ? ar : en);

  const [activeTab, setActiveTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [points, setPoints] = useState(0);
  const [wishlist, setWishlist] = useState([]);
  const [redemptions, setRedemptions] = useState([]);
  const [pending, setPending] = useState([]);

  // Request modal
  const [showRedeem, setShowRedeem] = useState(false);
  const [selectedItem, setSelectedItem] = useState(null);

  // Reject note modal (parent)
  const [showRejectNote, setShowRejectNote] = useState(false);
  const [rejectId, setRejectId] = useState('');
  const [rejectNote, setRejectNote] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const jobs = [
        api.getMyWallet().catch(() => ({})),
        api.getMyWishlistItems().catch(() => []),
        api.getMyRedemptions().catch(() => []),
      ];
      if (isParent) jobs.push(api.getPendingRedemptions().catch(() => []));
      const res = await Promise.all(jobs);
      setPoints(res[0]?.total_points || 0);
      setWishlist(res[1]);
      setRedemptions(res[2]);
      if (isParent) setPending(res[3] || []);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [isParent]);

  useEffect(() => { load(); }, [load]);

  // ── Member: request redemption ───────────────────────────────
  function openRedeem(item) { setSelectedItem(item); setShowRedeem(true); }

  async function requestRedeem() {
    if (!selectedItem) return;
    setSaving(true);
    try {
      await api.requestRedemption({
        wishlist_item_id: selectedItem._id,
        request_details: selectedItem.item_name,
      });
      setShowRedeem(false);
      toast(t('Redemption requested — waiting for a parent', 'تم طلب الاستبدال — في انتظار أحد الوالدين'), 'success');
      setActiveTab(1);
      load();
    } catch (e) {
      toast(e?.response?.data?.message || e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  async function cancelRedemption(id) {
    try {
      await api.cancelRedemption(id);
      toast(t('Request cancelled', 'تم إلغاء الطلب'));
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function acceptRedemption(id) {
    try {
      const resp = await api.acceptRedemption(id, true);
      const deducted = resp?.data?.redeemRequest?.point_deduction;
      toast(deducted ? `🎉 ${t('Done!', 'تم!')} −${deducted} pts` : t('Redemption completed!', 'تم الاستبدال!'), 'success');
      load();
    } catch (e) { toast(e?.response?.data?.message || e.message, 'error'); }
  }

  // ── Parent: approve / reject ─────────────────────────────────
  async function handleApprove(id, approved) {
    if (!approved) { setRejectId(id); setRejectNote(''); setShowRejectNote(true); return; }
    try {
      await api.parentApproveRedemption(id, true);
      toast(t('Approved', 'تمت الموافقة'), 'success');
      load();
    } catch (e) { toast(e?.response?.data?.message || e.message, 'error'); }
  }

  async function rejectWithNote() {
    setSaving(true);
    try {
      await api.parentApproveRedemption(rejectId, false, rejectNote);
      setShowRejectNote(false);
      toast(t('Rejected', 'تم الرفض'));
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  const card = (children, key) => (
    <div key={key} style={{
      background: 'var(--color-white)', borderRadius: 16, border: '1px solid var(--color-border)',
      padding: 14, marginBottom: 10, boxShadow: 'var(--shadow-card)',
    }}>{children}</div>
  );

  const TABS = isParent
    ? [t('Redeem', 'استبدال'), t('My Requests', 'طلباتي'), t('Pending', 'قيد الانتظار')]
    : [t('Redeem', 'استبدال'), t('My Requests', 'طلباتي')];

  const affordable = wishlist.filter(i => points >= (i.required_points || 0));
  const notYet = wishlist.filter(i => points < (i.required_points || 0));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={t('Redeem Points', 'استبدال النقاط')} actions={<IconBtn icon={RefreshCw} onClick={load} />} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 24px' }}>
          {/* Points balance */}
          <div style={{
            margin: '12px 16px',
            background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
            borderRadius: 14, padding: '14px 18px', display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>⭐</div>
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.85)', margin: 0 }}>{t('Available points', 'النقاط المتاحة')}</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 28, fontWeight: 800, color: '#fff', margin: 0 }}>{points}</p>
            </div>
            <button onClick={() => navigate('/wishlist')} style={{
              marginLeft: 'auto', padding: '8px 14px', borderRadius: 10, border: '1px solid rgba(255,255,255,0.6)',
              background: 'rgba(255,255,255,0.15)', color: '#fff', cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
            }}>⭐ {t('Wishlist', 'الأمنيات')}</button>
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', overflowX: 'auto', borderBottom: '1px solid var(--color-border)', padding: '4px 16px 0' }}>
            {TABS.map((tab, i) => (
              <button key={i} onClick={() => setActiveTab(i)} style={{
                padding: '8px 14px', flexShrink: 0, background: 'none', border: 'none',
                fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: activeTab === i ? 700 : 500,
                color: activeTab === i ? 'var(--color-primary)' : 'var(--color-text-secondary)', cursor: 'pointer',
                borderBottom: activeTab === i ? '2px solid var(--color-primary)' : '2px solid transparent',
              }}>{tab}</button>
            ))}
          </div>

          <div style={{ padding: '12px 16px' }}>
            {/* Tab 0: Redeem (pick affordable wishlist items) */}
            {activeTab === 0 && (
              wishlist.length === 0 ? (
                <EmptyState icon={Gift} message={t('Add items to your Wishlist first, then redeem them here', 'أضف عناصر إلى قائمة أمنياتك أولاً، ثم استبدلها هنا')} />
              ) : (
                <>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', marginBottom: 12 }}>
                    {t('Spend your points on a wishlist item. A parent approves before points are deducted.', 'أنفق نقاطك على عنصر من قائمة الأمنيات. يوافق أحد الوالدين قبل خصم النقاط.')}
                  </p>
                  {affordable.map(item => (
                    <div key={item._id} onClick={() => openRedeem(item)} style={{
                      background: 'var(--color-white)', borderRadius: 14, border: '1px solid var(--color-primary)',
                      padding: 14, marginBottom: 10, boxShadow: 'var(--shadow-card)', cursor: 'pointer',
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                        <div style={{ minWidth: 0 }}>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>{item.item_name}</p>
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-primary)', fontWeight: 600, marginTop: 4 }}>
                            <Star size={11} /> {item.required_points || 0} pts
                          </span>
                        </div>
                        <span style={{ background: 'var(--color-primary)', color: '#fff', padding: '6px 14px', borderRadius: 8, fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700 }}>
                          {t('Request', 'طلب')}
                        </span>
                      </div>
                    </div>
                  ))}
                  {notYet.map(item => (
                    <div key={item._id} style={{
                      background: 'var(--color-white)', borderRadius: 14, border: '1px solid var(--color-border)',
                      padding: 14, marginBottom: 10, opacity: 0.7,
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                        <div style={{ minWidth: 0 }}>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>{item.item_name}</p>
                          <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', marginTop: 4, display: 'inline-block' }}>
                            {Math.max(0, (item.required_points || 0) - points)} {t('pts to go', 'نقطة متبقية')}
                          </span>
                        </div>
                        <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)' }}>🔒 {item.required_points || 0} pts</span>
                      </div>
                    </div>
                  ))}
                </>
              )
            )}

            {/* Tab 1: My Requests */}
            {activeTab === 1 && (
              redemptions.length === 0
                ? <EmptyState icon={Gift} message={t('No redemption requests yet', 'لا توجد طلبات استبدال بعد')} />
                : redemptions.map(r => card(
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                        {r.wishlist_item_id?.item_name || r.request_details || t('Item', 'عنصر')}
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>
                        {r.point_deduction || r.points_used || 0} {t('pts', 'نقطة')}
                      </p>
                      {r.rejection_reason && r.status === 'rejected' && (
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#C62828', margin: '3px 0 0' }}>{r.rejection_reason}</p>
                      )}
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                      <StatusBadge status={r.status} />
                      {r.status === 'pending' && (
                        <button onClick={() => cancelRedemption(r._id)} style={{
                          background: 'none', border: '1px solid #E53935', color: '#E53935', borderRadius: 6,
                          padding: '3px 10px', fontFamily: 'var(--font-family)', fontSize: 10, cursor: 'pointer',
                        }}>{t('Cancel', 'إلغاء')}</button>
                      )}
                      {r.status === 'parent_approved' && (
                        <button onClick={() => acceptRedemption(r._id)} style={{
                          background: 'var(--color-primary)', border: 'none', color: '#fff', borderRadius: 6,
                          padding: '4px 12px', fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 700, cursor: 'pointer',
                        }}>✓ {t('Accept', 'قبول')}</button>
                      )}
                    </div>
                  </div>,
                  r._id,
                ))
            )}

            {/* Tab 2: Pending (parent) */}
            {activeTab === 2 && isParent && (
              pending.length === 0
                ? <EmptyState icon={Gift} message={t('No pending redemptions', 'لا توجد طلبات معلقة')} />
                : pending.map(r => {
                  const requesterMail = typeof r.requester === 'string' ? r.requester : (r.requester?.mail || '');
                  return card(
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                        <div style={{ display: 'flex', gap: 8, alignItems: 'center', minWidth: 0 }}>
                          <Avatar name={requesterMail.split('@')[0] || '?'} size={32} />
                          <div style={{ minWidth: 0 }}>
                            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                              {r.wishlist_item_id?.item_name || r.request_details || t('Item', 'عنصر')}
                            </p>
                            <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                              {requesterMail} · {r.point_deduction || r.points_used || 0} {t('pts', 'نقطة')}
                            </p>
                          </div>
                        </div>
                        <StatusBadge status={r.status} />
                      </div>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <button onClick={() => handleApprove(r._id, true)} style={{
                          flex: 1, padding: '8px 0', background: 'var(--color-primary)', border: 'none',
                          borderRadius: 8, color: '#fff', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                        }}>✓ {t('Approve', 'موافقة')}</button>
                        <button onClick={() => handleApprove(r._id, false)} style={{
                          flex: 1, padding: '8px 0', background: '#E53935', border: 'none',
                          borderRadius: 8, color: '#fff', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                        }}>✗ {t('Reject', 'رفض')}</button>
                      </div>
                    </div>,
                    r._id,
                  );
                })
            )}
          </div>
        </div>
      )}

      {/* Request confirmation */}
      <Modal open={showRedeem} onClose={() => setShowRedeem(false)} title={`🎁 ${t('Redeem', 'استبدال')}`}
        actions={<><ModalCancelBtn onClick={() => setShowRedeem(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Request', 'طلب')} disabled={saving} onClick={requestRedeem} /></>}>
        {selectedItem && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-primary)' }}>
              {t('Request', 'طلب')} <strong>{selectedItem.item_name}</strong>?
            </p>
            <div style={{ padding: 12, background: 'var(--color-primary-surface)', borderRadius: 10, border: '1px solid var(--color-border)' }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)', margin: 0 }}>
                {t('Cost', 'التكلفة')}: {selectedItem.required_points || 0} pts
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '4px 0 0' }}>
                {t('Your balance', 'رصيدك')}: {points} pts · {t('Deducted after a parent approves and you accept.', 'تُخصم بعد موافقة أحد الوالدين وقبولك.')}
              </p>
            </div>
          </div>
        )}
      </Modal>

      {/* Reject note (parent) */}
      <Modal open={showRejectNote} onClose={() => setShowRejectNote(false)} title={t('Reject Redemption', 'رفض الاستبدال')}
        actions={<><ModalCancelBtn onClick={() => setShowRejectNote(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Reject', 'رفض')} disabled={saving} onClick={rejectWithNote} /></>}>
        <FormField label={t('Reason (optional)', 'السبب (اختياري)')} value={rejectNote} onChange={setRejectNote} rows={3} />
      </Modal>
    </div>
  );
}
