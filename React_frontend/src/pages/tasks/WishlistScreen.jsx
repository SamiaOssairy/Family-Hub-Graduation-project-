// ═══════════════════════════════════════════════════════════════
// WishlistScreen — a member's list of things they WANT.
// Each item has a points cost (required_points) + optional category.
// Shows progress toward affording each item with your current points.
// This is the "catalog of goals" — actually spending points happens on
// the separate Redeem screen.
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Gift, RefreshCw, Plus, Trash2, Edit2, Star } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useTheme } from '../../context/ThemeContext';
import * as api from '../../api/apiService';

export default function WishlistScreen() {
  const toast = useToast();
  const navigate = useNavigate();
  const { language } = useTheme();
  const t = (en, ar) => (language === 'ar' ? ar : en);

  const [loading, setLoading] = useState(true);
  const [points, setPoints] = useState(0);
  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);

  // Add/Edit modal
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [name, setName] = useState('');
  const [pointsCost, setPointsCost] = useState('');
  const [catId, setCatId] = useState('');
  const [desc, setDesc] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [wallet, list, cats] = await Promise.all([
        api.getMyWallet().catch(() => ({})),
        api.getMyWishlistItems(),
        api.getWishlistCategories().catch(() => []),
      ]);
      setPoints(wallet?.total_points || 0);
      setItems(list);
      setCategories(cats);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { load(); }, [load]);

  function openAdd() {
    setEditItem(null); setName(''); setPointsCost(''); setCatId(''); setDesc('');
    setShowModal(true);
  }
  function openEdit(item) {
    setEditItem(item);
    setName(item.item_name || '');
    setPointsCost(String(item.required_points ?? ''));
    setCatId(item.category_id?._id || item.category_id || '');
    setDesc(item.description || '');
    setShowModal(true);
  }

  async function save() {
    if (!name.trim()) { toast(t('Enter an item name', 'أدخل اسم العنصر'), 'error'); return; }
    const cost = parseInt(pointsCost, 10);
    if (!cost || cost <= 0) { toast(t('Enter how many points it costs', 'أدخل عدد النقاط المطلوبة'), 'error'); return; }
    setSaving(true);
    try {
      const payload = {
        item_name: name.trim(),
        required_points: cost,
        description: desc.trim(),
      };
      if (catId) payload.category_id = catId;
      if (editItem) {
        await api.updateWishlistItem(editItem._id, payload);
        toast(t('Item updated', 'تم تحديث العنصر'), 'success');
      } else {
        await api.addWishlistItem(payload);
        toast(t('Added to your wishlist!', 'تمت الإضافة إلى قائمة أمنياتك!'), 'success');
      }
      setShowModal(false);
      load();
    } catch (e) {
      toast(e?.response?.data?.message || e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  async function remove(itemId) {
    try {
      await api.deleteWishlistItem(itemId);
      toast(t('Removed', 'تمت الإزالة'));
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={t('My Wishlist', 'قائمة أمنياتي')} actions={<IconBtn icon={RefreshCw} onClick={load} />} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 88px' }}>
          {/* Points balance */}
          <div style={{
            margin: '12px 16px',
            background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
            borderRadius: 14, padding: '14px 18px', display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>⭐</div>
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.85)', margin: 0 }}>{t('Your points', 'نقاطك')}</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 26, fontWeight: 800, color: '#fff', margin: 0 }}>{points}</p>
            </div>
            <button onClick={() => navigate('/redeem')} style={{
              marginLeft: 'auto', padding: '8px 14px', borderRadius: 10, border: '1px solid rgba(255,255,255,0.6)',
              background: 'rgba(255,255,255,0.15)', color: '#fff', cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
            }}>🎁 {t('Redeem', 'استبدال')}</button>
          </div>

          <div style={{ padding: '0 16px' }}>
            <button onClick={openAdd} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', marginBottom: 12,
              background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 10, cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
            }}>
              <Plus size={16} /> {t('Add a wish', 'أضف أمنية')}
            </button>

            {items.length === 0 ? (
              <EmptyState icon={Gift} message={t('Your wishlist is empty — add something you want!', 'قائمة أمنياتك فارغة — أضف شيئًا تريده!')} />
            ) : (
              items.map(item => {
                const required = item.required_points || 0;
                const pct = required > 0 ? Math.min(100, (points / required) * 100) : 0;
                const canAfford = points >= required;
                const toGo = Math.max(0, required - points);
                return (
                  <div key={item._id} style={{
                    background: 'var(--color-white)', borderRadius: 16, border: '1px solid var(--color-border)',
                    padding: 14, marginBottom: 10, boxShadow: 'var(--shadow-card)',
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 10 }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>{item.item_name}</p>
                        {item.description && (
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>{item.description}</p>
                        )}
                        <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, background: 'var(--color-primary-surface)', color: 'var(--color-primary)', padding: '2px 8px', borderRadius: 8, fontSize: 11, fontWeight: 700 }}>
                            <Star size={11} /> {required} pts
                          </span>
                          {item.category_id?.title && (
                            <span style={{ background: 'var(--color-border-light)', color: 'var(--color-text-secondary)', padding: '2px 8px', borderRadius: 8, fontSize: 10 }}>{item.category_id.title}</span>
                          )}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        <button onClick={() => openEdit(item)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-text-secondary)', padding: 4 }}><Edit2 size={15} /></button>
                        <button onClick={() => remove(item._id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#E53935', padding: 4 }}><Trash2 size={15} /></button>
                      </div>
                    </div>

                    {/* Progress */}
                    <div style={{ marginTop: 10 }}>
                      <div style={{ height: 6, borderRadius: 4, background: 'var(--color-border-light)', overflow: 'hidden' }}>
                        <div style={{ height: '100%', width: `${pct}%`, background: canAfford ? 'var(--color-primary)' : 'var(--color-primary-light)', borderRadius: 4, transition: 'width 0.3s' }} />
                      </div>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600, margin: '4px 0 0', color: canAfford ? 'var(--color-primary)' : 'var(--color-text-secondary)' }}>
                        {canAfford
                          ? t('✅ Ready to redeem!', '✅ جاهز للاستبدال!')
                          : `${toGo} ${t('pts to go', 'نقطة متبقية')}`}
                      </p>
                    </div>

                    {canAfford && (
                      <button onClick={() => navigate('/redeem')} style={{
                        width: '100%', marginTop: 10, padding: '9px 0',
                        background: 'linear-gradient(90deg, var(--color-primary), var(--color-primary-light))',
                        border: 'none', borderRadius: 10, cursor: 'pointer',
                        fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, color: '#fff',
                      }}>🎁 {t('Redeem this', 'استبدل هذا')}</button>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* Add / Edit modal */}
      <Modal open={showModal} onClose={() => setShowModal(false)}
        title={editItem ? t('Edit Wish', 'تعديل الأمنية') : t('Add a Wish', 'أضف أمنية')}
        actions={<><ModalCancelBtn onClick={() => setShowModal(false)} /><ModalPrimaryBtn label={saving ? '…' : (editItem ? t('Save', 'حفظ') : t('Add', 'إضافة'))} disabled={saving || !name.trim()} onClick={save} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('What do you want?', 'ماذا تريد؟')} value={name} onChange={setName} required placeholder={t('e.g. New headphones', 'مثال: سماعات جديدة')} />
          <FormField label={t('Points needed to get it', 'النقاط اللازمة للحصول عليه')} value={pointsCost} onChange={setPointsCost} type="number" min="1" placeholder="500" />
          {categories.length > 0 && (
            <SelectField label={t('Category (optional)', 'الفئة (اختياري)')} value={catId} onChange={setCatId}
              options={[{ value: '', label: t('General', 'عام') }, ...categories.map(c => ({ value: c._id, label: c.title || c.name }))]} />
          )}
          <FormField label={t('Note (optional)', 'ملاحظة (اختياري)')} value={desc} onChange={setDesc} placeholder={t('Color, size, link…', 'اللون، المقاس، الرابط…')} />
        </div>
      </Modal>
    </div>
  );
}
