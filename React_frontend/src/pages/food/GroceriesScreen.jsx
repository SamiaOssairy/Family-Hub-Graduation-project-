// ═══════════════════════════════════════════════════════════════
// Groceries Screen — mirrors groceries_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ShoppingCart, Plus, CheckCircle, List } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

export default function GroceriesScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const navigate = useNavigate();

  const [groceryLists, setGroceryLists] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Create modal
  const [showCreate, setShowCreate] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const lists = await api.getAllGroceryLists();
      setGroceryLists(Array.isArray(lists) ? lists : []);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const filtered = searchQuery
    ? groceryLists.filter(l => (l.title || '').toLowerCase().includes(searchQuery.toLowerCase()))
    : groceryLists;

  async function createList() {
    if (!newTitle.trim()) return;
    setCreating(true);
    try {
      await api.createGroceryList({ title: newTitle.trim() });
      setShowCreate(false);
      setNewTitle('');
      toast('List created');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setCreating(false); }
  }

  async function deleteList(listId, title, e) {
    e.preventDefault();
    e.stopPropagation();
    if (!window.confirm(`Delete "${title}"? This will permanently delete this list and all its items.`)) return;
    try {
      await api.deleteGroceryList(listId);
      toast(`"${title}" deleted`);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const totalChecked = groceryLists.reduce((s, l) => s + ((l.checked_items || 0)), 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Grocery Lists" />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 100px' }}>
          {/* Search bar */}
          <div style={{ padding: '12px 20px 0' }}>
            <div style={{ background: 'var(--color-white)', borderRadius: 14, padding: '0 14px', display: 'flex', alignItems: 'center', gap: 8, boxShadow: 'var(--shadow-card)' }}>
              <span style={{ color: '#9E9E9E', fontSize: 18 }}>🔍</span>
              <input
                placeholder="Search grocery lists..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{
                  flex: 1, border: 'none', outline: 'none', padding: '12px 0',
                  fontFamily: 'var(--font-family)', fontSize: 13, background: 'transparent', color: 'var(--color-text-primary)',
                }}
              />
            </div>
          </div>

          {/* Summary chips */}
          <div style={{ display: 'flex', gap: 12, padding: '8px 24px' }}>
            <SummaryChip icon={<List size={14} color="var(--color-primary)" />} label={`${groceryLists.length} lists`} />
            <SummaryChip icon={<CheckCircle size={14} color="var(--color-primary)" />} label={`${totalChecked} done`} />
          </div>

          {/* List */}
          {filtered.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 16px' }}>
              <div style={{ fontSize: 64, marginBottom: 12, opacity: 0.3 }}>🛒</div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, color: '#9E9E9E', margin: 0 }}>
                {searchQuery ? 'No matching lists' : 'No grocery lists yet'}
              </p>
              {!searchQuery && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#BDBDBD', marginTop: 8 }}>
                  Tap + to create your first list
                </p>
              )}
            </div>
          ) : (
            <div style={{ padding: '4px 20px' }}>
              {filtered.map(list => (
                <ListCard
                  key={list._id}
                  list={list}
                  onClick={() => navigate(`/grocery-list-detail/${list._id}`, { state: { title: list.title } })}
                  onLongPress={e => deleteList(list._id, list.title || 'Untitled', e)}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {/* FAB */}
      <button onClick={() => { setNewTitle(''); setShowCreate(true); }} style={{
        position: 'fixed', bottom: 24, right: 24,
        background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 28,
        padding: '14px 20px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
        fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
        boxShadow: '0 4px 14px rgba(0,137,123,0.4)',
      }}>
        <Plus size={18} /> New List
      </button>

      {/* Create Modal */}
      <Modal open={showCreate} onClose={() => setShowCreate(false)} title="Create New List"
        actions={<>
          <ModalCancelBtn onClick={() => setShowCreate(false)} />
          <ModalPrimaryBtn label={creating ? '…' : 'Create'} disabled={creating || !newTitle.trim()} onClick={createList} />
        </>}
      >
        <FormField label="List Name" value={newTitle} onChange={setNewTitle} placeholder="e.g., Weekly Shopping" autoFocus />
      </Modal>
    </div>
  );
}

function SummaryChip({ icon, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'var(--color-white)', borderRadius: 20, padding: '4px 10px' }}>
      {icon}
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>{label}</span>
    </div>
  );
}

function ListCard({ list, onClick, onLongPress }) {
  const title = list.title || 'Untitled';
  const totalItems = list.total_items || 0;
  const checkedItems = list.checked_items || 0;
  const progress = totalItems > 0 ? checkedItems / totalItems : 0;
  const isComplete = totalItems > 0 && checkedItems === totalItems;

  return (
    <div
      onClick={onClick}
      onContextMenu={onLongPress}
      style={{
        background: 'var(--color-white)', borderRadius: 14, marginBottom: 12,
        padding: 16, cursor: 'pointer',
        boxShadow: '0 2px 6px rgba(0,0,0,0.04)',
        border: isComplete ? '1px solid #4CAF5033' : 'none',
        display: 'flex', alignItems: 'center', gap: 14,
      }}
    >
      {/* Icon */}
      <div style={{
        padding: 10, borderRadius: 12, flexShrink: 0,
        background: isComplete ? '#4CAF501A' : 'var(--color-background)',
      }}>
        {isComplete
          ? <CheckCircle size={24} color="#4CAF50" />
          : <List size={24} color="var(--color-primary)" />}
      </div>

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 15, color: '#1A1A1A', margin: 0 }}>{title}</p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#9E9E9E', margin: '4px 0 0' }}>
          {totalItems === 0 ? 'Empty list' : `${totalItems} items · ${checkedItems} done`}
        </p>
        {totalItems > 0 && (
          <div style={{ marginTop: 6, height: 4, background: '#E0E0E0', borderRadius: 4, overflow: 'hidden' }}>
            <div style={{
              height: '100%', borderRadius: 4,
              width: `${progress * 100}%`,
              background: isComplete ? '#4CAF50' : 'var(--color-primary)',
              transition: 'width 0.3s',
            }} />
          </div>
        )}
      </div>

      <span style={{ color: '#9E9E9E', fontSize: 20 }}>›</span>
    </div>
  );
}
