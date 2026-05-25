// ═══════════════════════════════════════════════════════════════
// Receipts Screen — mirrors receipts_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, Settings, X, Camera, Search, RefreshCw, ChevronDown } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

function fmtDate(dateStr) {
  if (!dateStr) return '';
  try { return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return String(dateStr); }
}

function toNum(v) { return typeof v === 'number' ? v : (parseFloat(String(v)) || 0); }

export default function ReceiptsScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [receipts, setReceipts] = useState([]);
  const [inventories, setInventories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isScanning, setIsScanning] = useState(false);

  // Add/Edit dialog
  const [showDialog, setShowDialog] = useState(false);
  const [editReceipt, setEditReceipt] = useState(null);

  // Scan source picker
  const [showScanPicker, setShowScanPicker] = useState(false);

  // Scan preview dialog
  const [scanData, setScanData] = useState(null);
  const [scanImageBase64, setScanImageBase64] = useState(null);

  const fileInputRef = useRef(null);
  const scanFileInputRef = useRef(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [recs, invs] = await Promise.all([
        api.getAllReceipts(),
        api.getAllInventories().catch(() => []),
      ]);
      setReceipts(Array.isArray(recs) ? recs : []);
      setInventories(Array.isArray(invs) ? invs : []);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const filtered = searchQuery
    ? receipts.filter(r => {
        const store = (r.store_name || '').toLowerCase();
        const notes = (r.notes || '').toLowerCase();
        return store.includes(searchQuery.toLowerCase()) || notes.includes(searchQuery.toLowerCase());
      })
    : receipts;

  const grandTotal = receipts.reduce((s, r) => s + toNum(r.total_amount), 0);

  async function deleteReceipt(id) {
    if (!window.confirm('Are you sure you want to delete this receipt?')) return;
    try {
      await api.deleteReceipt(id);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  function handleScanFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setIsScanning(true);
    const reader = new FileReader();
    reader.onload = async ev => {
      const base64 = ev.target.result; // data:image/...;base64,...
      const byteStr = base64.split(',')[1];
      const bytes = Uint8Array.from(atob(byteStr), c => c.charCodeAt(0));
      try {
        const scanned = await api.scanReceipt(bytes);
        setScanImageBase64(base64);
        setScanData(scanned);
      } catch (ex) { toast('Scan failed: ' + ex.message, 'error'); }
      finally { setIsScanning(false); }
    };
    reader.readAsDataURL(file);
    e.target.value = '';
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Receipts" />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '0 0 100px' }}>
          {receipts.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '80px 16px' }}>
              <div style={{ fontSize: 64, marginBottom: 12, opacity: 0.3 }}>🧾</div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, color: '#9E9E9E', margin: 0 }}>No receipts yet</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#BDBDBD', marginTop: 4 }}>Tap + to add your first receipt</p>
            </div>
          ) : (
            <>
              {/* Search bar */}
              <div style={{ padding: '16px 20px 0' }}>
                <div style={{ background: 'var(--color-white)', borderRadius: 12, padding: '0 14px', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Search size={18} color="var(--color-primary)" />
                  <input
                    placeholder="Search by store name..."
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    style={{
                      flex: 1, border: 'none', outline: 'none', padding: '14px 0',
                      fontFamily: 'var(--font-family)', fontSize: 13, background: 'transparent', color: 'var(--color-text-primary)',
                    }}
                  />
                </div>
              </div>

              {/* Count + total */}
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 20px 0' }}>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#9E9E9E' }}>
                  {filtered.length} receipt{filtered.length !== 1 ? 's' : ''}
                </span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)' }}>
                  Total: EGP {grandTotal.toFixed(2)}
                </span>
              </div>

              {/* Receipt list */}
              <div style={{ padding: '12px 20px' }}>
                {filtered.length === 0 ? (
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: '#9E9E9E', textAlign: 'center', marginTop: 40 }}>
                    {searchQuery ? 'No receipts match your search' : 'No receipts yet'}
                  </p>
                ) : (
                  filtered.map(r => (
                    <ReceiptCard
                      key={r._id}
                      receipt={r}
                      onEdit={() => { setEditReceipt(r); setShowDialog(true); }}
                      onDelete={() => deleteReceipt(r._id)}
                    />
                  ))
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* FABs */}
      <div style={{ position: 'fixed', bottom: 24, right: 24, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 12 }}>
        {isScanning && (
          <div style={{ background: '#1A237E', borderRadius: 20, padding: '8px 14px', display: 'flex', alignItems: 'center', gap: 8 }}>
            <RefreshCw size={14} color="#fff" style={{ animation: 'spin 1s linear infinite' }} />
            <span style={{ fontFamily: 'var(--font-family)', color: '#fff', fontSize: 12 }}>Scanning receipt…</span>
          </div>
        )}
        <button
          onClick={() => scanFileInputRef.current?.click()}
          disabled={isScanning}
          title="Scan receipt with AI"
          style={{
            width: 44, height: 44, borderRadius: 22, background: '#1A237E', border: 'none',
            cursor: isScanning ? 'not-allowed' : 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(0,0,0,0.3)', opacity: isScanning ? 0.6 : 1,
          }}>
          <Camera size={20} color="#fff" />
        </button>
        <button
          onClick={() => { setEditReceipt(null); setShowDialog(true); }}
          title="Add receipt manually"
          style={{
            width: 56, height: 56, borderRadius: 28, background: 'var(--color-primary)', border: 'none',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 4px 14px rgba(0,137,123,0.4)',
          }}>
          <Plus size={28} color="#fff" />
        </button>
      </div>

      {/* Hidden file input for scanning */}
      <input ref={scanFileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleScanFile} />

      {/* Add/Edit dialog */}
      {showDialog && (
        <ReceiptDialog
          receipt={editReceipt}
          onClose={() => { setShowDialog(false); setEditReceipt(null); }}
          onSaved={() => { setShowDialog(false); setEditReceipt(null); load(); }}
          toast={toast}
        />
      )}

      {/* Scan preview dialog */}
      {scanData && (
        <ScanPreviewDialog
          scanned={scanData}
          imageBase64={scanImageBase64}
          inventories={inventories}
          onClose={() => { setScanData(null); setScanImageBase64(null); }}
          onSaved={() => { setScanData(null); setScanImageBase64(null); load(); }}
          toast={toast}
        />
      )}

      <style>{`@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

function ReceiptCard({ receipt, onEdit, onDelete }) {
  const store = receipt.store_name || 'Unknown Store';
  const amount = toNum(receipt.total_amount);
  const subtotal = toNum(receipt.subtotal);
  const taxes = toNum(receipt.taxes);
  const date = receipt.purchase_date || receipt.createdAt || '';
  const items = receipt.items || [];
  const photoUrl = receipt.receipt_photo_url;
  const formattedDate = fmtDate(date);

  return (
    <div style={{ background: 'var(--color-white)', borderRadius: 16, marginBottom: 20, border: '1px solid var(--color-border)', overflow: 'hidden' }}>
      {/* Green header */}
      <div style={{ background: '#E8F5E9', padding: '12px 8px 12px 16px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ flex: 1 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-primary)', margin: 0 }}>Store: {store}</p>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#616161', margin: '2px 0 0' }}>Date: {formattedDate}</p>
        </div>
        <button onClick={onEdit} style={{ background: 'rgba(255,255,255,0.5)', border: 'none', borderRadius: 8, padding: 6, cursor: 'pointer' }}>
          <Settings size={20} color="#616161" />
        </button>
        <button onClick={onDelete} style={{ background: 'rgba(255,255,255,0.5)', border: 'none', borderRadius: 8, padding: 6, cursor: 'pointer' }}>
          <X size={20} color="#616161" />
        </button>
      </div>

      {/* Photo */}
      {photoUrl && (
        <div style={{ width: '100%', height: 180, overflow: 'hidden', position: 'relative', cursor: 'pointer' }}
          onClick={() => window.open(photoUrl, '_blank')}>
          <img src={photoUrl} alt="receipt" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          <div style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.54)', borderRadius: 6, padding: '4px 8px', display: 'flex', alignItems: 'center', gap: 4 }}>
            <Camera size={14} color="#fff" />
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#fff' }}>Tap to view</span>
          </div>
        </div>
      )}

      {/* Line items */}
      {items.length > 0 && (
        <div style={{ padding: '12px 16px 8px' }}>
          {items.map((item, i) => {
            const unit = item.unit || '';
            return (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#00352E' }}>
                  {item.quantity || 1} {unit ? unit + ' ' : ''}{item.name || ''}
                </span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 500, color: '#1A1A1A' }}>
                  EGP {toNum(item.price).toFixed(2)}
                </span>
              </div>
            );
          })}
        </div>
      )}

      {/* Payment summary */}
      <div style={{ padding: `${items.length > 0 ? 4 : 12}px 16px 16px` }}>
        {items.length > 0 && (
          <>
            <hr style={{ border: 'none', borderTop: '1px solid #E0E0E0', margin: '8px 0' }} />
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: '#1A1A1A', margin: '0 0 6px' }}>Payment Summary</p>
            <SummaryRow label="Subtotal" value={`EGP ${subtotal.toFixed(2)}`} bold={false} />
            <SummaryRow label="Taxes" value={`EGP ${taxes.toFixed(2)}`} bold={false} />
            <div style={{ height: 4 }} />
          </>
        )}
        <SummaryRow label="Total amount" value={`EGP ${amount.toFixed(2)}`} bold={true} />
      </div>
    </div>
  );
}

function SummaryRow({ label, value, bold }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '2px 0' }}>
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: bold ? 700 : 400, color: bold ? '#1A1A1A' : '#9E9E9E' }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: bold ? 700 : 500, color: bold ? '#1A1A1A' : '#616161' }}>{value}</span>
    </div>
  );
}

// ── Add/Edit Receipt Dialog ───────────────────────────────────
function ReceiptDialog({ receipt, onClose, onSaved, toast }) {
  const isEdit = !!receipt;
  const [store, setStore] = useState(receipt?.store_name || '');
  const [subtotal, setSubtotal] = useState(String(receipt?.subtotal || '0'));
  const [taxes, setTaxes] = useState(String(receipt?.taxes || '0'));
  const [notes, setNotes] = useState(receipt?.notes || '');
  const [purchaseDate, setPurchaseDate] = useState(
    receipt?.purchase_date ? receipt.purchase_date.split('T')[0] : new Date().toISOString().split('T')[0]
  );
  const [photo, setPhoto] = useState(receipt?.receipt_photo_url || null);
  const [lineItems, setLineItems] = useState(
    receipt?.items ? receipt.items.map(i => ({ ...i, price: String(i.price || '') })) : []
  );
  const [saving, setSaving] = useState(false);
  const photoInputRef = useRef(null);

  const sub = parseFloat(subtotal) || 0;
  const tax = parseFloat(taxes) || 0;
  const total = sub + tax;

  function addLineItem() {
    setLineItems(prev => [...prev, { name: '', quantity: '1', unit: '', price: '0' }]);
  }

  function updateItem(idx, field, val) {
    setLineItems(prev => prev.map((it, i) => i === idx ? { ...it, [field]: val } : it));
  }

  function removeItem(idx) {
    setLineItems(prev => prev.filter((_, i) => i !== idx));
  }

  function handlePhotoChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = ev => setPhoto(ev.target.result);
    reader.readAsDataURL(file);
    e.target.value = '';
  }

  async function save() {
    if (!store.trim()) { toast('Please enter store name', 'error'); return; }
    setSaving(true);
    try {
      const body = {
        store_name: store.trim(),
        total_amount: total,
        subtotal: sub,
        taxes: tax,
        notes: notes.trim(),
        receipt_photo_url: photo,
        purchase_date: new Date(purchaseDate).toISOString(),
        items: lineItems.filter(i => (i.name || '').trim()).map(i => ({
          name: i.name,
          quantity: i.quantity || '1',
          unit: i.unit || '',
          price: parseFloat(i.price) || 0,
        })),
      };
      if (isEdit) await api.updateReceipt(receipt._id, body);
      else await api.createReceipt(body);
      onSaved();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
      <div style={{ background: '#fff', borderRadius: 20, width: '100%', maxWidth: 450, maxHeight: '88vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Header */}
        <div style={{ background: 'var(--color-primary)', padding: '16px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: '#fff' }}>
            {isEdit ? 'Edit Receipt' : 'Add Receipt'}
          </span>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#fff', padding: 0 }}>
            <X size={22} />
          </button>
        </div>

        {/* Body */}
        <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
          <DialogLabel text="Store Name" />
          <DialogInput value={store} onChange={setStore} placeholder="e.g. Oscar, Carrefour" />

          <div style={{ height: 14 }} />
          <DialogLabel text="Receipt Photo (optional)" />
          {photo ? (
            <div style={{ position: 'relative', borderRadius: 10, overflow: 'hidden', marginBottom: 4 }}>
              <img src={photo} alt="receipt" style={{ width: '100%', height: 150, objectFit: 'cover' }} />
              <button onClick={() => setPhoto(null)} style={{ position: 'absolute', top: 6, right: 6, background: '#E53935', border: 'none', borderRadius: '50%', width: 24, height: 24, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <X size={14} color="#fff" />
              </button>
            </div>
          ) : (
            <div onClick={() => photoInputRef.current?.click()} style={{ border: '1px solid #E0E0E0', borderRadius: 10, background: '#F5F5F5', padding: '24px 0', textAlign: 'center', cursor: 'pointer', marginBottom: 4 }}>
              <span style={{ fontSize: 32 }}>📷</span>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#9E9E9E', margin: '8px 0 0' }}>Tap to add receipt photo</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#BDBDBD', margin: '2px 0 0' }}>Choose from gallery</p>
            </div>
          )}
          <input ref={photoInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handlePhotoChange} />

          <div style={{ height: 14 }} />
          <DialogLabel text="Purchase Date" />
          <input type="date" value={purchaseDate} onChange={e => setPurchaseDate(e.target.value)} style={{
            width: '100%', padding: '12px 14px', border: '1px solid #E0E0E0', borderRadius: 10,
            fontFamily: 'var(--font-family)', fontSize: 13, outline: 'none', background: '#fff', boxSizing: 'border-box',
          }} />

          <div style={{ height: 18 }} />
          {/* Line Items */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: '#00352E' }}>Items</span>
            <button onClick={addLineItem} style={{ background: 'var(--color-primary-surface)', border: '1px solid var(--color-border)', borderRadius: 8, padding: '4px 10px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}>
              <Plus size={14} color="var(--color-primary)" />
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-primary)', fontWeight: 500 }}>Add Item</span>
            </button>
          </div>
          {lineItems.length === 0 ? (
            <div style={{ background: '#F5F5F5', borderRadius: 10, padding: 14, textAlign: 'center' }}>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#9E9E9E' }}>No items added yet. Tap "Add Item" above.</span>
            </div>
          ) : (
            lineItems.map((item, idx) => (
              <LineItemRow key={idx} item={item} idx={idx} onChange={updateItem} onRemove={removeItem} />
            ))
          )}

          <div style={{ height: 16 }} />
          {/* Payment summary */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <DialogLabel text="Subtotal (EGP)" />
              <DialogInput value={subtotal} onChange={setSubtotal} placeholder="0.00" type="number" />
            </div>
            <div>
              <DialogLabel text="Taxes (EGP)" />
              <DialogInput value={taxes} onChange={setTaxes} placeholder="0.00" type="number" />
            </div>
          </div>
          <div style={{ height: 10 }} />
          <div style={{ background: '#E8F5E9', borderRadius: 10, padding: 12, display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14 }}>Total amount</span>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-primary)' }}>EGP {total.toFixed(2)}</span>
          </div>

          <div style={{ height: 14 }} />
          <DialogLabel text="Notes (optional)" />
          <textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder="Optional notes" rows={2} style={{
            width: '100%', padding: '10px 14px', border: '1px solid #E0E0E0', borderRadius: 10,
            fontFamily: 'var(--font-family)', fontSize: 13, resize: 'vertical', outline: 'none', boxSizing: 'border-box',
          }} />

          <div style={{ height: 18 }} />
          <button onClick={save} disabled={saving} style={{
            width: '100%', padding: '14px 0', background: 'var(--color-primary)', color: '#fff', border: 'none',
            borderRadius: 10, cursor: saving ? 'not-allowed' : 'pointer',
            fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 16,
          }}>
            {saving ? '…' : isEdit ? 'Save Changes' : 'Add Receipt'}
          </button>
        </div>
      </div>
    </div>
  );
}

function DialogLabel({ text }) {
  return <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, margin: '0 0 6px' }}>{text}</p>;
}

function DialogInput({ value, onChange, placeholder, type = 'text' }) {
  return (
    <input type={type} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} style={{
      width: '100%', padding: '10px 14px', border: '1px solid #E0E0E0', borderRadius: 10,
      fontFamily: 'var(--font-family)', fontSize: 13, outline: 'none', boxSizing: 'border-box',
    }} />
  );
}

function LineItemRow({ item, idx, onChange, onRemove }) {
  return (
    <div style={{ background: '#F5F5F5', borderRadius: 10, padding: 10, marginBottom: 8, display: 'flex', gap: 6, alignItems: 'center' }}>
      <input value={item.name || ''} onChange={e => onChange(idx, 'name', e.target.value)} placeholder="Item name" style={{ flex: 3, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px 10px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <input value={item.quantity || ''} onChange={e => onChange(idx, 'quantity', e.target.value)} placeholder="Qty" type="number" style={{ flex: 1, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <input value={item.price || ''} onChange={e => onChange(idx, 'price', e.target.value)} placeholder="EGP" type="number" style={{ flex: 2, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <button onClick={() => onRemove(idx)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#EF9A9A', padding: '0 4px' }}>
        <X size={18} />
      </button>
    </div>
  );
}

// ── Scan Preview Dialog ───────────────────────────────────────
function ScanPreviewDialog({ scanned, imageBase64, inventories, onClose, onSaved, toast }) {
  const [store, setStore] = useState(scanned.store_name || '');
  const [subtotal, setSubtotal] = useState(String(scanned.subtotal || '0'));
  const [taxes, setTaxes] = useState(String(scanned.taxes || '0'));
  const [purchaseDate, setPurchaseDate] = useState(
    scanned.purchase_date ? new Date(scanned.purchase_date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0]
  );
  const [items, setItems] = useState(
    (scanned.items || []).map(i => ({ ...i, price: String(i.price || '0'), quantity: String(i.quantity || '1'), addToInventory: true }))
  );
  const [addToInventory, setAddToInventory] = useState(inventories.length > 0);
  const [selectedInventoryId, setSelectedInventoryId] = useState(inventories[0]?._id || '');
  const [saving, setSaving] = useState(false);

  const sub = parseFloat(subtotal) || 0;
  const tax = parseFloat(taxes) || 0;
  const total = (sub + tax) || toNum(scanned.total_amount);

  function toggleItem(idx) {
    setItems(prev => prev.map((it, i) => i === idx ? { ...it, addToInventory: !it.addToInventory } : it));
  }

  function toggleAll() {
    const allOn = items.every(i => i.addToInventory);
    setItems(prev => prev.map(it => ({ ...it, addToInventory: !allOn })));
  }

  function updateItem(idx, field, val) {
    setItems(prev => prev.map((it, i) => i === idx ? { ...it, [field]: val } : it));
  }

  function removeItem(idx) {
    setItems(prev => prev.filter((_, i) => i !== idx));
  }

  async function confirm() {
    setSaving(true);
    try {
      const body = {
        store_name: store.trim() || 'Unknown Store',
        total_amount: total,
        subtotal: sub,
        taxes: tax,
        purchase_date: new Date(purchaseDate).toISOString(),
        receipt_photo_url: imageBase64,
        items: items.filter(i => (i.name || '').trim()).map(i => ({
          name: i.name, quantity: i.quantity || '1', unit: i.unit || '', price: parseFloat(i.price) || 0,
        })),
      };
      await api.createReceipt(body);

      // Add checked items to inventory
      if (addToInventory && selectedInventoryId) {
        const checked = items.filter(i => i.addToInventory && (i.name || '').trim());
        for (const item of checked) {
          try {
            await api.addInventoryItem(selectedInventoryId, {
              item_name: item.name,
              quantity: parseFloat(item.quantity) || 1,
            });
          } catch (_) { /* skip individual failures */ }
        }
        const checkedCount = checked.length;
        toast(`Receipt saved & ${checkedCount} item${checkedCount !== 1 ? 's' : ''} added to inventory!`);
      } else {
        toast('Receipt saved successfully!');
      }
      onSaved();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 300, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
      <div style={{ background: '#fff', borderRadius: 20, width: '100%', maxWidth: 480, maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Gradient header */}
        <div style={{ background: 'linear-gradient(135deg, #1A237E, #26A69A)', padding: '16px 20px', display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <span style={{ fontSize: 20 }}>📄</span>
          <div style={{ flex: 1 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: '#fff', margin: 0 }}>Scanned Receipt</p>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'rgba(255,255,255,0.7)', margin: '2px 0 0' }}>Review & confirm before saving</p>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#fff', padding: 0 }}>
            <X size={22} />
          </button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
          {/* Scanned image */}
          {imageBase64 && (
            <img src={imageBase64} alt="scanned" style={{ width: '100%', height: 130, objectFit: 'cover', borderRadius: 12, marginBottom: 12 }} />
          )}

          {/* AI badge */}
          <div style={{ background: 'var(--color-primary-surface)', borderRadius: 10, padding: 10, display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            <span>✨</span>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-primary)' }}>
              AI detected {items.length} item{items.length !== 1 ? 's' : ''}. Edit or remove before saving.
            </span>
          </div>

          <DialogLabel text="Store Name" />
          <DialogInput value={store} onChange={setStore} placeholder="Store name" />

          <div style={{ height: 14 }} />
          <DialogLabel text="Purchase Date" />
          <input type="date" value={purchaseDate} onChange={e => setPurchaseDate(e.target.value)} style={{
            width: '100%', padding: '12px 14px', border: '1px solid #E0E0E0', borderRadius: 10,
            fontFamily: 'var(--font-family)', fontSize: 13, outline: 'none', background: '#fff', boxSizing: 'border-box',
          }} />

          <div style={{ height: 18 }} />
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: '#00352E' }}>Items ({items.length})</span>
            {items.length > 0 && (
              <button onClick={toggleAll} style={{ background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-primary)' }}>
                {items.every(i => i.addToInventory) ? 'Deselect all' : 'Select all'}
              </button>
            )}
          </div>

          {items.length === 0 ? (
            <div style={{ background: '#F5F5F5', borderRadius: 10, padding: 14, textAlign: 'center' }}>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#9E9E9E' }}>No items detected</span>
            </div>
          ) : (
            items.map((item, idx) => (
              <ScanItemRow key={idx} item={item} idx={idx} onChange={updateItem} onRemove={removeItem} onToggle={toggleItem} />
            ))
          )}

          <div style={{ height: 14 }} />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div><DialogLabel text="Subtotal (EGP)" /><DialogInput value={subtotal} onChange={setSubtotal} placeholder="0.00" type="number" /></div>
            <div><DialogLabel text="Taxes (EGP)" /><DialogInput value={taxes} onChange={setTaxes} placeholder="0.00" type="number" /></div>
          </div>
          <div style={{ height: 10 }} />
          <div style={{ background: '#E8F5E9', borderRadius: 10, padding: 12, display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14 }}>Total</span>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-primary)' }}>EGP {total.toFixed(2)}</span>
          </div>

          {/* Add to inventory */}
          {inventories.length > 0 && (
            <>
              <hr style={{ border: 'none', borderTop: '1px solid #E0E0E0', margin: '18px 0 8px' }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: '#00352E', margin: 0 }}>Add to Inventory</p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E', margin: '2px 0 0' }}>Checked items will be added to your selected inventory</p>
                </div>
                <input type="checkbox" checked={addToInventory} onChange={e => setAddToInventory(e.target.checked)} style={{ width: 20, height: 20, accentColor: 'var(--color-primary)', cursor: 'pointer' }} />
              </div>
              {addToInventory && (
                <>
                  <div style={{ height: 10 }} />
                  <select value={selectedInventoryId} onChange={e => setSelectedInventoryId(e.target.value)} style={{
                    width: '100%', padding: '12px 14px', border: '1px solid #E0E0E0', borderRadius: 10,
                    fontFamily: 'var(--font-family)', fontSize: 13, outline: 'none', background: '#fff',
                  }}>
                    {inventories.map(inv => (
                      <option key={inv._id} value={inv._id}>{inv.title || 'Inventory'}</option>
                    ))}
                  </select>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#9E9E9E', marginTop: 6 }}>
                    ✓ Check the items above you want to add
                  </p>
                </>
              )}
            </>
          )}

          <div style={{ height: 20 }} />
          <button onClick={confirm} disabled={saving} style={{
            width: '100%', padding: '14px 0', background: 'var(--color-primary)', color: '#fff', border: 'none',
            borderRadius: 10, cursor: saving ? 'not-allowed' : 'pointer',
            fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 16,
          }}>
            {saving ? '…' : 'Confirm & Save'}
          </button>
        </div>
      </div>
    </div>
  );
}

function ScanItemRow({ item, idx, onChange, onRemove, onToggle }) {
  const isChecked = item.addToInventory !== false;
  return (
    <div style={{
      background: isChecked ? 'var(--color-primary-surface)' : '#F5F5F5',
      border: `1px solid ${isChecked ? 'var(--color-border)' : '#E0E0E0'}`,
      borderRadius: 10, padding: 10, marginBottom: 8, display: 'flex', gap: 6, alignItems: 'center',
    }}>
      {/* Checkbox */}
      <button onClick={() => onToggle(idx)} style={{
        width: 22, height: 22, borderRadius: 5,
        background: isChecked ? 'var(--color-primary)' : '#fff',
        border: `1px solid ${isChecked ? 'var(--color-primary)' : '#9E9E9E'}`,
        cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, padding: 0,
      }}>
        {isChecked && <span style={{ fontSize: 12, color: '#fff' }}>✓</span>}
      </button>
      <input value={item.name || ''} onChange={e => onChange(idx, 'name', e.target.value)} placeholder="Item name" style={{ flex: 3, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px 10px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <input value={item.quantity || ''} onChange={e => onChange(idx, 'quantity', e.target.value)} placeholder="Qty" type="number" style={{ flex: 1, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <input value={item.price || ''} onChange={e => onChange(idx, 'price', e.target.value)} placeholder="EGP" type="number" style={{ flex: 2, border: '1px solid #E0E0E0', borderRadius: 8, padding: '8px', fontFamily: 'var(--font-family)', fontSize: 12, outline: 'none', background: '#fff' }} />
      <button onClick={() => onRemove(idx)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#EF9A9A', padding: '0 4px' }}>
        <X size={18} />
      </button>
    </div>
  );
}
