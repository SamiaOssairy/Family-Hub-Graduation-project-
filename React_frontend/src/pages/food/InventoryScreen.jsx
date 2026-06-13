// ═══════════════════════════════════════════════════════════════
// Inventory Screen — mirrors inventory_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Plus, Bell, Settings, Trash2, Package } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn, DangerBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const CAT_COLORS = ['var(--color-primary)','var(--color-primary-light)','#FB8C00','var(--color-text-secondary)','#7B1FA2','#E91E63','#1565C0','#6D4C41','var(--color-text-primary)'];
const SORT_OPTIONS = [
  { value: 'name', label: 'Name' },
  { value: 'quantity', label: 'Quantity' },
  { value: 'low_stock', label: 'Low Stock First' },
  { value: 'category', label: 'Category' },
];
const INV_TYPES = ['Food','Electronics','Cleaning','Personal Care','Other'];
const UNIT_TYPES = ['weight','volume','count'];

function isLowStock(item) {
  const qty = +(item.quantity || 0);
  const thr = +(item.threshold_quantity || 0);
  return thr > 0 && qty <= thr;
}

function getCategoryName(item, categories) {
  const cat = item.item_category;
  if (cat && typeof cat === 'object') return cat.title || 'Uncategorized';
  const match = categories.find(c => c._id === cat);
  return match?.title || 'Uncategorized';
}

function getUnitName(item) {
  const u = item.unit_id;
  if (u && typeof u === 'object') return u.unit_name || '';
  return '';
}

function fmtDate(d) {
  if (!d) return null;
  try { return new Date(d).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }); }
  catch { return null; }
}

function expiryLabel(dateStr) {
  if (!dateStr) return null;
  const diff = Math.floor((new Date(dateStr) - new Date()) / 86400000);
  if (diff < 0) return `Expired ${-diff}d ago`;
  if (diff === 0) return 'Expires today';
  if (diff <= 7) return `Expires in ${diff}d`;
  return fmtDate(dateStr);
}

function expiryColor(dateStr) {
  if (!dateStr) return 'var(--color-text-hint)';
  const diff = Math.floor((new Date(dateStr) - new Date()) / 86400000);
  if (diff < 0) return '#C62828';
  if (diff <= 3) return '#E65100';
  if (diff <= 7) return '#FBC02D';
  return 'var(--color-text-hint)';
}

export default function InventoryScreen() {
  const navigate = useNavigate();
  const toast = useToast();

  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [inventories, setInventories] = useState([]);
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [unreadAlerts, setUnreadAlerts] = useState(0);
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState('name');
  const [selInvId, setSelInvId] = useState(null);
  const [selCatId, setSelCatId] = useState(null);
  const [budgetSummary, setBudgetSummary] = useState(null);

  // Add/Edit item modal
  const [showItemModal, setShowItemModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [iForm, setIForm] = useState({ item_name: '', quantity: '', threshold_quantity: '1', unit_id: '', category_id: '', inventory_id: '', purchase_date: '', expiry_date: '' });
  const [isAdding, setIsAdding] = useState(true);
  const [savingItem, setSavingItem] = useState(false);

  // Create inventory modal
  const [showInvModal, setShowInvModal] = useState(false);
  const [newInvTitle, setNewInvTitle] = useState('');
  const [newInvType, setNewInvType] = useState('Food');
  const [savingInv, setSavingInv] = useState(false);

  // Delete item confirm
  const [deleteTarget, setDeleteTarget] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [its, cats, invs, uts, alertCount] = await Promise.all([
        api.getAllFamilyItems(),
        api.getAllInventoryCategories().catch(() => []),
        api.getAllInventories().catch(() => []),
        api.getAllUnits().catch(() => []),
        api.getUnreadAlertCount().catch(() => 0),
      ]);
      setItems(its);
      setCategories(cats);
      setInventories(invs);
      setUnits(uts);
      setUnreadAlerts(alertCount);
      // Budget summary (non-critical)
      api.getInventoryBudgetSummary({ includePeriods: true }).then(s => setBudgetSummary(s)).catch(() => {});
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Filtering
  const activeItems = selInvId
    ? items.filter(i => (i.inventory_id?._id || i.inventory_id) === selInvId)
    : items;

  const filteredItems = (() => {
    let r = [...activeItems];
    if (selCatId) r = r.filter(i => (i.item_category?._id || i.item_category) === selCatId);
    if (search) r = r.filter(i => (i.item_name || '').toLowerCase().includes(search.toLowerCase()) || getCategoryName(i, categories).toLowerCase().includes(search.toLowerCase()));
    if (sortBy === 'quantity') r.sort((a, b) => +(a.quantity||0) - +(b.quantity||0));
    else if (sortBy === 'low_stock') r.sort((a, b) => (isLowStock(a) ? 0 : 1) - (isLowStock(b) ? 0 : 1));
    else if (sortBy === 'category') r.sort((a, b) => getCategoryName(a, categories).localeCompare(getCategoryName(b, categories)));
    else r.sort((a, b) => (a.item_name || '').localeCompare(b.item_name || ''));
    return r;
  })();

  const activeCategories = (() => {
    const usedCatIds = new Set(activeItems.map(i => i.item_category?._id || i.item_category).filter(Boolean));
    return categories.filter(c => usedCatIds.has(c._id));
  })();

  const groupedItems = (() => {
    const g = {};
    filteredItems.forEach(item => {
      const n = getCategoryName(item, categories);
      if (!g[n]) g[n] = [];
      g[n].push(item);
    });
    return g;
  })();

  function openAdd() {
    setEditItem(null);
    setIsAdding(true);
    const firstInv = selInvId || (inventories.length > 0 ? inventories[0]._id : '');
    setIForm({ item_name: '', quantity: '', threshold_quantity: '1', unit_id: units[0]?._id || '', category_id: selCatId || '', inventory_id: firstInv, purchase_date: new Date().toISOString().split('T')[0], expiry_date: '' });
    setShowItemModal(true);
  }

  function openEdit(item) {
    setEditItem(item);
    setIsAdding(true);
    setIForm({
      item_name: item.item_name || '',
      quantity: '',
      threshold_quantity: String(item.threshold_quantity || '1'),
      unit_id: item.unit_id?._id || item.unit_id || '',
      category_id: item.item_category?._id || item.item_category || '',
      inventory_id: item.inventory_id?._id || item.inventory_id || '',
      purchase_date: item.purchase_date ? item.purchase_date.split('T')[0] : '',
      expiry_date: item.expiry_date ? item.expiry_date.split('T')[0] : '',
    });
    setShowItemModal(true);
  }

  async function saveItem() {
    if (!iForm.item_name.trim()) { toast('Please enter item name', 'error'); return; }
    if (!iForm.unit_id) { toast('Please select a unit', 'error'); return; }
    if (!iForm.category_id) { toast('Please select a category', 'error'); return; }
    setSavingItem(true);
    try {
      let finalQty;
      if (editItem) {
        const cur = +(editItem.quantity || 0);
        const amt = +(iForm.quantity || 0);
        finalQty = isAdding ? cur + amt : Math.max(0, cur - amt);
      } else {
        finalQty = +(iForm.quantity || 0);
      }
      const data = {
        item_name: iForm.item_name.trim(),
        quantity: finalQty,
        threshold_quantity: +(iForm.threshold_quantity || 1),
        unit_id: iForm.unit_id,
        item_category: iForm.category_id,
        // null (not undefined) so clearing a date actually clears it on the backend
        purchase_date: iForm.purchase_date || null,
        expiry_date: iForm.expiry_date || null,
      };
      if (editItem) {
        await api.updateInventoryItem(editItem._id, data);
        toast('Item updated');
      } else {
        if (!iForm.inventory_id) { toast('Please select an inventory', 'error'); return; }
        await api.addInventoryItem(iForm.inventory_id, data);
        toast('Item added');
      }
      setShowItemModal(false);
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSavingItem(false); }
  }

  async function saveInventory() {
    if (!newInvTitle.trim()) return;
    setSavingInv(true);
    try {
      await api.createInventory(newInvTitle.trim(), newInvType);
      toast('Inventory created');
      setShowInvModal(false); setNewInvTitle('');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSavingInv(false); }
  }

  async function confirmDelete() {
    if (!deleteTarget) return;
    try {
      await api.deleteInventoryItem(deleteTarget._id);
      toast(`"${deleteTarget.item_name}" deleted`);
      setDeleteTarget(null);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const lowStock = activeItems.filter(i => isLowStock(i)).length;
  const curQty = editItem ? +(editItem.quantity || 0) : 0;
  const adjQty = editItem ? (isAdding ? curQty + +(iForm.quantity || 0) : Math.max(0, curQty - +(iForm.quantity || 0))) : 0;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Inventory" actions={<>
        <div style={{ position: 'relative' }}>
          <IconBtn icon={Bell} onClick={() => navigate('/inventory-alerts')} />
          {unreadAlerts > 0 && <span style={{ position: 'absolute', top: 8, right: 8, width: 8, height: 8, borderRadius: '50%', background: '#E53935', border: '2px solid var(--color-background)' }} />}
        </div>
        <IconBtn icon={Settings} onClick={() => navigate('/inventory-categories')} />
      </>} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column' }}>
          {/* Inventory selector */}
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '8px 16px 4px', scrollbarWidth: 'none' }}>
            <InvChip label="All" count={items.length} selected={selInvId === null} icon="📦" onClick={() => setSelInvId(null)} />
            {inventories.map(inv => (
              <InvChip key={inv._id} label={inv.title || ''} count={items.filter(i => (i.inventory_id?._id || i.inventory_id) === inv._id).length}
                selected={selInvId === inv._id} icon={invIcon(inv.type)} onClick={() => setSelInvId(selInvId === inv._id ? null : inv._id)} />
            ))}
            <button onClick={() => { setNewInvTitle(''); setNewInvType('Food'); setShowInvModal(true); }} style={{
              display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0,
              padding: '8px 14px', background: 'var(--color-white)', border: '1px dashed var(--color-primary)',
              borderRadius: 14, cursor: 'pointer', color: 'var(--color-primary)', fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13,
            }}>
              <Plus size={16} /> New
            </button>
          </div>

          {/* Search */}
          <div style={{ position: 'relative', margin: '4px 16px' }}>
            <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--color-primary)' }} />
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search items..."
              style={{ width: '100%', padding: '10px 40px 10px 36px', background: 'var(--color-white)', border: '1px solid var(--color-border)', borderRadius: 14, fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)', outline: 'none', boxSizing: 'border-box' }} />
            <select value={sortBy} onChange={e => setSortBy(e.target.value)} style={{
              position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)',
              background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)',
            }}>
              {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>

          {/* Category filter */}
          {activeCategories.length > 0 && (
            <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '4px 16px', scrollbarWidth: 'none' }}>
              <CatChip label="All" count={activeItems.length} selected={!selCatId} onClick={() => setSelCatId(null)} />
              {activeCategories.map(cat => (
                <CatChip key={cat._id} label={cat.title || ''} count={activeItems.filter(i => (i.item_category?._id || i.item_category) === cat._id).length}
                  selected={selCatId === cat._id} onClick={() => setSelCatId(selCatId === cat._id ? null : cat._id)} />
              ))}
            </div>
          )}

          {/* Budget summary */}
          <BudgetSummaryBar summary={budgetSummary} />

          {/* Stats */}
          <div style={{ display: 'flex', gap: 12, padding: '4px 16px', alignItems: 'center' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'var(--color-white)', borderRadius: 20, padding: '3px 10px', fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-primary)' }}>
              📦 {activeItems.length} items
            </span>
            {lowStock > 0 && (
              <span style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'var(--color-white)', borderRadius: 20, padding: '3px 10px', fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: '#FB8C00' }}>
                ⚠️ {lowStock} low stock
              </span>
            )}
            <span style={{ marginLeft: 'auto', fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)' }}>
              {categories.length} categories
            </span>
          </div>

          {/* Items */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 88px' }}>
            {filteredItems.length === 0 ? (
              <EmptyState icon={Package} message={search ? 'No matching items' : 'No items yet — tap + to add'} />
            ) : selCatId || sortBy !== 'name' ? (
              filteredItems.map(item => <ItemTile key={item._id} item={item} categories={categories} onEdit={() => openEdit(item)} onDelete={() => setDeleteTarget(item)} />)
            ) : (
              Object.keys(groupedItems).sort().map((catName, ci) => {
                const color = CAT_COLORS[catName.charCodeAt(0) % CAT_COLORS.length];
                return (
                  <div key={catName} style={{ marginBottom: 4 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8, marginTop: 12, padding: '10px 14px', background: color + '1A', borderRadius: 12, borderLeft: `4px solid ${color}` }}>
                      <div style={{ padding: 6, background: color + '26', borderRadius: 8 }}>
                        <span style={{ fontSize: 16 }}>{catEmoji(catName)}</span>
                      </div>
                      <span style={{ flex: 1, fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)' }}>{catName}</span>
                      <span style={{ background: color + '26', color, padding: '2px 8px', borderRadius: 12, fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600 }}>
                        {groupedItems[catName].length} item{groupedItems[catName].length !== 1 ? 's' : ''}
                      </span>
                    </div>
                    {groupedItems[catName].map(item => <ItemTile key={item._id} item={item} categories={categories} onEdit={() => openEdit(item)} onDelete={() => setDeleteTarget(item)} />)}
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* FAB */}
      <button onClick={openAdd} style={{
        position: 'fixed', bottom: 24, right: 24, display: 'flex', alignItems: 'center', gap: 8,
        background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 28,
        padding: '14px 20px', cursor: 'pointer', boxShadow: 'var(--shadow-primary)', zIndex: 200,
        fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
      }}>
        <Plus size={20} /> Add Item
      </button>

      {/* Add/Edit Item Modal */}
      <Modal open={showItemModal} onClose={() => setShowItemModal(false)}
        title={editItem ? 'Edit Item' : 'Add New Item'}
        actions={<><ModalCancelBtn onClick={() => setShowItemModal(false)} /><ModalPrimaryBtn label={savingItem ? '…' : (editItem ? 'Update' : 'Add Item')} disabled={savingItem} onClick={saveItem} /></>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Item Name *" value={iForm.item_name} onChange={v => setIForm(f => ({ ...f, item_name: v }))} required />
          <SelectField label="Category *" value={iForm.category_id} onChange={v => setIForm(f => ({ ...f, category_id: v }))}
            options={[{ value: '', label: 'Select category' }, ...categories.map(c => ({ value: c._id, label: c.title || '' }))]} />

          {/* Units */}
          <div>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, marginBottom: 8, color: 'var(--color-text-primary)' }}>Unit *</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {units.map(u => (
                <button key={u._id} onClick={() => setIForm(f => ({ ...f, unit_id: f.unit_id === u._id ? '' : u._id }))} style={{
                  padding: '6px 14px', borderRadius: 20, border: 'none', cursor: 'pointer',
                  background: iForm.unit_id === u._id ? 'var(--color-primary)' : '#eee',
                  color: iForm.unit_id === u._id ? '#fff' : 'var(--color-text-primary)',
                  fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13,
                }}>{u.unit_name}</button>
              ))}
            </div>
          </div>

          {/* Quantity */}
          {editItem ? (
            <>
              <div style={{ padding: 14, borderRadius: 12, background: adjQty <= +(iForm.threshold_quantity || 1) ? '#FFEBEE' : 'var(--color-primary-surface)', border: `1px solid ${adjQty <= +(iForm.threshold_quantity || 1) ? '#EF9A9A' : 'var(--color-border)'}` }}>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#666', margin: '0 0 2px' }}>Current Stock</p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 28, fontWeight: 800, color: adjQty <= +(iForm.threshold_quantity || 1) ? '#C62828' : 'var(--color-primary)', margin: 0 }}>{adjQty % 1 === 0 ? adjQty : adjQty.toFixed(1)}</p>
              </div>
              <div style={{ display: 'flex', borderRadius: 10, overflow: 'hidden' }}>
                <button onClick={() => setIsAdding(true)} style={{ flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer', background: isAdding ? 'var(--color-primary)' : '#eee', color: isAdding ? '#fff' : '#666', fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13 }}>+ Add</button>
                <button onClick={() => setIsAdding(false)} style={{ flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer', background: !isAdding ? '#E53935' : '#eee', color: !isAdding ? '#fff' : '#666', fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13 }}>− Remove</button>
              </div>
              <FormField label={isAdding ? 'Amount to Add' : 'Amount to Remove'} value={iForm.quantity} onChange={v => setIForm(f => ({ ...f, quantity: v }))} type="number" min="0" step="0.01" />
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#666', background: '#f5f5f5', padding: '8px 12px', borderRadius: 8 }}>
                {curQty} {isAdding ? '+' : '−'} {iForm.quantity || 0} = {adjQty % 1 === 0 ? adjQty : adjQty.toFixed(1)}
              </p>
              <FormField label="Minimum Threshold" value={iForm.threshold_quantity} onChange={v => setIForm(f => ({ ...f, threshold_quantity: v }))} type="number" min="0" />
            </>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              <FormField label="Quantity" value={iForm.quantity} onChange={v => setIForm(f => ({ ...f, quantity: v }))} type="number" min="0" step="0.01" />
              <FormField label="Minimum" value={iForm.threshold_quantity} onChange={v => setIForm(f => ({ ...f, threshold_quantity: v }))} type="number" min="0" />
            </div>
          )}

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <FormField label="Purchase Date" value={iForm.purchase_date} onChange={v => setIForm(f => ({ ...f, purchase_date: v }))} type="date" />
            <FormField label="Expiry Date" value={iForm.expiry_date} onChange={v => setIForm(f => ({ ...f, expiry_date: v }))} type="date" />
          </div>

          {!editItem && (
            <SelectField label="Inventory *" value={iForm.inventory_id} onChange={v => setIForm(f => ({ ...f, inventory_id: v }))}
              options={[{ value: '', label: 'Select inventory' }, ...inventories.map(i => ({ value: i._id, label: i.title || '' }))]} />
          )}
        </div>
      </Modal>

      {/* Create Inventory Modal */}
      <Modal open={showInvModal} onClose={() => setShowInvModal(false)} title="New Inventory"
        actions={<><ModalCancelBtn onClick={() => setShowInvModal(false)} /><ModalPrimaryBtn label={savingInv ? '…' : 'Create'} disabled={savingInv || !newInvTitle.trim()} onClick={saveInventory} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Inventory Name" value={newInvTitle} onChange={setNewInvTitle} placeholder="e.g., Kitchen Pantry, Fridge" required />
          <div>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, marginBottom: 8, color: 'var(--color-text-primary)' }}>Type</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {INV_TYPES.map(type => (
                <button key={type} onClick={() => setNewInvType(type)} style={{
                  padding: '6px 12px', borderRadius: 20, border: 'none', cursor: 'pointer',
                  background: newInvType === type ? 'var(--color-primary)' : '#eee',
                  color: newInvType === type ? '#fff' : 'var(--color-text-primary)',
                  fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12,
                }}>{type}</button>
              ))}
            </div>
          </div>
        </div>
      </Modal>

      {/* Delete confirm */}
      <Modal open={!!deleteTarget} onClose={() => setDeleteTarget(null)} title="Delete Item"
        actions={<><ModalCancelBtn onClick={() => setDeleteTarget(null)} /><DangerBtn label="Delete" onClick={confirmDelete} /></>}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>
          Are you sure you want to delete &quot;{deleteTarget?.item_name}&quot;?
        </p>
      </Modal>
    </div>
  );
}

function InvChip({ label, count, selected, icon, onClick }) {
  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0,
      padding: '8px 14px', background: selected ? 'var(--color-primary)' : 'var(--color-white)',
      border: `1px solid ${selected ? 'var(--color-primary)' : 'var(--color-border)'}`,
      borderRadius: 14, cursor: 'pointer',
      boxShadow: selected ? 'var(--shadow-primary)' : 'none',
    }}>
      <span style={{ fontSize: 15 }}>{icon}</span>
      <span style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: selected ? '#fff' : 'var(--color-text-primary)' }}>{label}</span>
      <span style={{ background: selected ? 'rgba(255,255,255,0.25)' : '#eee', color: selected ? '#fff' : 'var(--color-text-secondary)', padding: '1px 6px', borderRadius: 10, fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600 }}>{count}</span>
    </button>
  );
}

function CatChip({ label, count, selected, onClick }) {
  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0,
      padding: '6px 12px', background: selected ? 'var(--color-primary)' : 'var(--color-white)',
      border: `1px solid ${selected ? 'var(--color-primary)' : 'var(--color-border)'}`, borderRadius: 20, cursor: 'pointer',
    }}>
      <span style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12, color: selected ? '#fff' : 'var(--color-text-primary)' }}>{label}</span>
      <span style={{ background: selected ? 'rgba(255,255,255,0.25)' : '#eee', color: selected ? '#fff' : 'var(--color-text-secondary)', padding: '1px 6px', borderRadius: 10, fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600 }}>{count}</span>
    </button>
  );
}

function ItemTile({ item, categories, onEdit, onDelete }) {
  const lowStk = isLowStock(item);
  const expDate = item.expiry_date;
  const purDate = item.purchase_date;
  const expLabel = expiryLabel(expDate);
  const expColor = expiryColor(expDate);
  const isExpired = expDate && new Date(expDate) < new Date();
  const expiringSoon = expDate && !isExpired && Math.floor((new Date(expDate) - new Date()) / 86400000) <= 3;
  const unitName = getUnitName(item);
  const catName = getCategoryName(item, categories);
  const invName = item.inventory_id?.title || '';

  return (
    <div onClick={onEdit} style={{
      marginBottom: 8, padding: '12px 14px',
      background: isExpired ? '#FFEBEE' : expiringSoon ? '#FFF3E0' : 'var(--color-white)',
      borderRadius: 12,
      borderLeft: `3.5px solid ${isExpired ? '#E53935' : lowStk ? '#FB8C00' : 'var(--color-primary)'}`,
      boxShadow: '0 1px 4px rgba(0,0,0,0.03)', cursor: 'pointer', display: 'flex', alignItems: 'center',
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, color: 'var(--color-text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {item.item_name}
        </p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 4 }}>
          <InfoBadge text={catName} color="var(--color-primary)" bg="var(--color-primary-surface)" />
          {invName && <InfoBadge text={invName} color="#999" bg="#f5f5f5" />}
          {purDate && <InfoBadge text={`Bought ${fmtDate(purDate)}`} color="#1976D2" bg="#E3F2FD" />}
          {expLabel && <InfoBadge text={expLabel} color={expColor} bg={isExpired ? '#FFCDD2' : expiringSoon ? '#FFE0B2' : '#f5f5f5'} />}
        </div>
      </div>
      <div style={{ textAlign: 'right', marginLeft: 12 }}>
        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 18, color: lowStk ? '#FB8C00' : 'var(--color-text-primary)', margin: 0 }}>
          {item.quantity} {unitName && <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--color-text-hint)' }}>{unitName}</span>}
        </p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)', margin: 0 }}>min: {item.threshold_quantity || 0}</p>
      </div>
      <button onClick={e => { e.stopPropagation(); onDelete(); }} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#bbb', padding: '4px', marginLeft: 4 }}>
        <Trash2 size={18} />
      </button>
    </div>
  );
}

function InfoBadge({ text, color, bg }) {
  return (
    <span style={{ background: bg, color, padding: '2px 6px', borderRadius: 6, fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 500 }}>
      {text}
    </span>
  );
}

function BudgetSummaryBar({ summary }) {
  const periodBudget = summary?.data?.period_budget;
  const cats = summary?.data?.categories || [];
  if (!periodBudget || cats.length === 0) return null;
  return (
    <div style={{ margin: '4px 16px', padding: 14, borderRadius: 18, border: '1px solid var(--color-border)', background: 'linear-gradient(135deg, var(--color-white), var(--color-primary-surface))' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
        <div style={{ padding: 8, background: 'var(--color-primary-surface)', borderRadius: 12 }}>💰</div>
        <div style={{ flex: 1 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>{periodBudget.title}</p>
        </div>
        <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, color: 'var(--color-primary)' }}>
          {periodBudget.remaining_amount} / {periodBudget.total_amount}
        </span>
      </div>
      <div style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
        {cats.map((entry, i) => (
          <div key={i} style={{ flexShrink: 0, width: 140, padding: '8px 10px', background: 'var(--color-white)', borderRadius: 12, border: '1px solid var(--color-border-light)' }}>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 11, color: 'var(--color-text-primary)', margin: '0 0 4px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {entry.inventory_category_title || 'Category'}
            </p>
            {[['Allocated', entry.allocated_amount], ['Spent', entry.spent_amount], ['Remaining', entry.remaining_amount]].map(([l, v]) => (
              <div key={l} style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-hint)' }}>{l}</span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: 'var(--color-text-primary)' }}>{v}</span>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

function invIcon(type) {
  switch (type) {
    case 'Food': return '🍽️';
    case 'Electronics': return '📱';
    case 'Cleaning': return '🧹';
    case 'Personal Care': return '🧴';
    default: return '📦';
  }
}

function catEmoji(name) {
  const n = name.toLowerCase();
  if (n.includes('dairy') || n.includes('milk') || n.includes('cheese')) return '🥛';
  if (n.includes('vegetable') || n.includes('veg')) return '🥦';
  if (n.includes('fruit')) return '🍎';
  if (n.includes('meat') || n.includes('chicken') || n.includes('beef')) return '🥩';
  if (n.includes('grain') || n.includes('bread') || n.includes('rice') || n.includes('pasta')) return '🌾';
  if (n.includes('spice') || n.includes('herb')) return '🌿';
  if (n.includes('drink') || n.includes('beverage')) return '🥤';
  if (n.includes('snack') || n.includes('chip')) return '🍿';
  if (n.includes('frozen')) return '🧊';
  return '🏷️';
}
