// ═══════════════════════════════════════════════════════════════
// Leftovers Screen — mirrors leftovers_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Archive, Plus, AlertTriangle, Clock, MoreVertical } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn, DangerBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

function daysUntil(dateStr) {
  if (!dateStr) return 999;
  return Math.floor((new Date(dateStr) - new Date()) / 86400000);
}

function expiryColor(days) {
  if (days < 0) return '#E53935';
  if (days === 0) return '#FF5722';
  if (days <= 2) return '#FF9800';
  if (days <= 5) return '#FFC107';
  return 'var(--color-primary)';
}

function expiryText(days) {
  if (days < 0) return `Expired ${-days} day${-days === 1 ? '' : 's'} ago`;
  if (days === 0) return 'Expires today!';
  return `Expires in ${days} day${days === 1 ? '' : 's'}`;
}

function expiryProgress(lo) {
  const created = lo.createdAt || lo.created_at;
  const expiry = lo.expiry_date;
  if (!created || !expiry) return 1;
  const start = new Date(created).getTime();
  const end = new Date(expiry).getTime();
  const now = Date.now();
  const total = (end - start) / 3600000;
  if (total <= 0) return 1;
  return Math.min(1, Math.max(0, (now - start) / 3600000 / total));
}

const TABS = ['All', 'Expiring', 'Expired'];

export default function LeftoversScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [leftovers, setLeftovers] = useState([]);
  const [categories, setCategories] = useState([]);
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState(0);

  // Add/Edit modal
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [form, setForm] = useState({ item_name: '', quantity: '', unit_id: '', category_id: '', expiry_date: '' });
  const [saving, setSaving] = useState(false);

  // Delete confirm
  const [deleteItem, setDeleteItem] = useState(null);
  const [menuOpen, setMenuOpen] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [lo, cats, uts] = await Promise.all([
        api.getAllLeftovers(),
        api.getAllInventoryCategories().catch(() => []),
        api.getAllUnits().catch(() => []),
      ]);
      setLeftovers(lo);
      setCategories(cats);
      setUnits(uts);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const expiringSoon = leftovers.filter(lo => { const d = daysUntil(lo.expiry_date); return d >= 0 && d <= 3; });
  const expired = leftovers.filter(lo => daysUntil(lo.expiry_date) < 0);
  const lists = [leftovers, expiringSoon, expired];

  function openAdd() {
    setEditItem(null);
    setForm({ item_name: '', quantity: '', unit_id: units[0]?._id || '', category_id: '', expiry_date: '' });
    setShowModal(true);
  }

  function openEdit(lo) {
    setEditItem(lo);
    setForm({
      item_name: lo.item_name || '',
      quantity: String(lo.quantity || ''),
      unit_id: lo.unit_id?._id || lo.unit_id || '',
      category_id: lo.category_id?._id || lo.category_id || '',
      expiry_date: lo.expiry_date ? lo.expiry_date.split('T')[0] : '',
    });
    setShowModal(true);
    setMenuOpen(null);
  }

  async function save() {
    if (!form.item_name.trim()) return;
    const body = {
      item_name: form.item_name.trim(),
      quantity: parseFloat(form.quantity) || 0,
    };
    if (form.unit_id) body.unit_id = form.unit_id;
    if (form.category_id) body.category_id = form.category_id;
    if (form.expiry_date) body.expiry_date = new Date(form.expiry_date).toISOString();
    setSaving(true);
    try {
      if (editItem) await api.updateLeftover(editItem._id, body);
      else await api.addLeftover(body);
      setShowModal(false);
      toast(editItem ? 'Leftover updated!' : 'Leftover added!');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function confirmDelete() {
    if (!deleteItem) return;
    try {
      await api.deleteLeftover(deleteItem._id);
      toast('Leftover deleted');
      setDeleteItem(null);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const items = lists[activeTab] || [];
  const tabCounts = lists.map(l => l.length);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}
      onClick={() => setMenuOpen(null)}>
      <AppBar title="Leftover Tracker" />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '12px 16px 32px' }}>
          {/* Tabs */}
          <div style={{ display: 'flex', background: 'var(--color-white)', borderRadius: 12, padding: 4, marginBottom: 14, boxShadow: 'var(--shadow-card)' }}>
            {TABS.map((tab, i) => (
              <button key={tab} onClick={() => setActiveTab(i)} style={{
                flex: 1, padding: '8px 0', border: 'none', cursor: 'pointer',
                background: activeTab === i ? 'var(--color-primary)' : 'none',
                borderRadius: 10, color: activeTab === i ? '#fff' : 'var(--color-text-secondary)',
                fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, transition: 'all 0.15s',
              }}>
                {tab} ({tabCounts[i]})
              </button>
            ))}
          </div>

          {/* Add button */}
          <button onClick={openAdd} style={{
            width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 12,
            padding: '14px 0', cursor: 'pointer', marginBottom: 14,
            fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
          }}>
            <Plus size={20} /> Add Leftover
          </button>

          {items.length === 0 ? (
            <EmptyState icon={Archive} message="No leftovers here" />
          ) : (
            items.map(lo => {
              const days = daysUntil(lo.expiry_date);
              const color = expiryColor(days);
              const progress = expiryProgress(lo);
              const unitName = lo.unit_id?.unit_name || '';
              const catName = lo.category_id?.title || '';
              const isExp = days < 0;

              return (
                <div key={lo._id} style={{
                  background: 'var(--color-white)', borderRadius: 16, marginBottom: 12,
                  borderLeft: `4px solid ${color}`,
                  boxShadow: 'var(--shadow-card)', padding: 16,
                }} onClick={e => e.stopPropagation()}>
                  <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
                    <div style={{ padding: 10, background: color + '1A', borderRadius: 12, flexShrink: 0 }}>
                      {isExp ? <AlertTriangle size={24} color={color} /> : <Clock size={24} color={color} />}
                    </div>
                    <div style={{ flex: 1 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)', margin: 0 }}>
                        {lo.item_name || 'Unknown'}
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 600, color: 'var(--color-primary)', margin: '2px 0 0' }}>
                        {lo.quantity} {unitName}
                      </p>
                    </div>
                    {/* Context menu */}
                    <div style={{ position: 'relative', flexShrink: 0 }}>
                      <button onClick={e => { e.stopPropagation(); setMenuOpen(menuOpen === lo._id ? null : lo._id); }} style={{
                        background: 'none', border: 'none', cursor: 'pointer', color: '#999', padding: 4,
                      }}>
                        <MoreVertical size={18} />
                      </button>
                      {menuOpen === lo._id && (
                        <div style={{
                          position: 'absolute', right: 0, top: '100%', background: 'var(--color-white)',
                          border: '1px solid var(--color-border)', borderRadius: 10, zIndex: 100,
                          boxShadow: 'var(--shadow-card)', minWidth: 120, overflow: 'hidden',
                        }}>
                          <button onClick={() => openEdit(lo)} style={{ width: '100%', padding: '10px 14px', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left', fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)' }}>Edit</button>
                          <button onClick={() => { setDeleteItem(lo); setMenuOpen(null); }} style={{ width: '100%', padding: '10px 14px', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left', fontFamily: 'var(--font-family)', fontSize: 13, color: '#E53935' }}>Delete</button>
                        </div>
                      )}
                    </div>
                  </div>

                  <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 10 }}>
                    <Clock size={14} color={color} />
                    <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color }}>{expiryText(days)}</span>
                    {catName && (
                      <span style={{ background: '#EDE7F6', color: '#7B1FA2', padding: '2px 8px', borderRadius: 6, fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 500 }}>
                        {catName}
                      </span>
                    )}
                  </div>

                  {lo.expiry_date && (
                    <div style={{ marginTop: 8, height: 4, background: '#eee', borderRadius: 4, overflow: 'hidden' }}>
                      <div style={{ height: '100%', width: `${progress * 100}%`, background: color, borderRadius: 4 }} />
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Add/Edit Modal */}
      <Modal open={showModal} onClose={() => setShowModal(false)}
        title={editItem ? 'Edit Leftover' : 'Add Leftover'}
        actions={<>
          <ModalCancelBtn onClick={() => setShowModal(false)} />
          <ModalPrimaryBtn label={saving ? '…' : (editItem ? 'Save' : 'Add')} disabled={saving || !form.item_name.trim()} onClick={save} />
        </>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Item Name" value={form.item_name} onChange={v => setForm(f => ({ ...f, item_name: v }))} required />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <FormField label="Quantity" value={form.quantity} onChange={v => setForm(f => ({ ...f, quantity: v }))} type="number" min="0" step="0.01" />
            {units.length > 0 && (
              <SelectField label="Unit" value={form.unit_id} onChange={v => setForm(f => ({ ...f, unit_id: v }))}
                options={units.map(u => ({ value: u._id, label: u.unit_name }))} />
            )}
          </div>
          <SelectField label="Category (optional)" value={form.category_id} onChange={v => setForm(f => ({ ...f, category_id: v }))}
            options={[{ value: '', label: 'No category' }, ...categories.map(c => ({ value: c._id, label: c.title || c.name || '' }))]} />
          <FormField label="Expiry Date" value={form.expiry_date} onChange={v => setForm(f => ({ ...f, expiry_date: v }))} type="date" />
        </div>
      </Modal>

      {/* Delete confirm */}
      <Modal open={!!deleteItem} onClose={() => setDeleteItem(null)} title="Delete Leftover"
        actions={<><ModalCancelBtn onClick={() => setDeleteItem(null)} /><DangerBtn label="Delete" onClick={confirmDelete} /></>}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>
          Are you sure you want to delete this leftover?
        </p>
      </Modal>
    </div>
  );
}
