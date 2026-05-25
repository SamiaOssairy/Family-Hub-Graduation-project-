// ═══════════════════════════════════════════════════════════════
// Grocery List Detail Screen — mirrors grocery_list_detail_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useParams, useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Plus, X, Trash2, Check, Edit2 } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import Modal, { ModalCancelBtn, DangerBtn } from '../../components/common/Modal';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

export default function GroceryListDetailScreen() {
  const { id: listId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const toast = useToast();

  const [listTitle, setListTitle] = useState(location.state?.title || 'Grocery List');
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isEditing, setIsEditing] = useState(false);
  const [editTitleVal, setEditTitleVal] = useState('');
  const [addInput, setAddInput] = useState('');

  // Delete list confirm
  const [showDeleteList, setShowDeleteList] = useState(false);

  const addInputRef = useRef(null);
  const titleInputRef = useRef(null);

  const load = useCallback(async () => {
    if (!listId) return;
    setLoading(true);
    try {
      const data = await api.getGroceryList(listId);
      setListTitle(data.list?.title || listTitle);
      setEditTitleVal(data.list?.title || listTitle);
      setItems(data.items || []);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, [listId]);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (isEditing && titleInputRef.current) titleInputRef.current.focus();
  }, [isEditing]);

  async function addItem() {
    const name = addInput.trim();
    if (!name) return;
    try {
      await api.addGroceryItem(listId, { item_name: name });
      setAddInput('');
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function toggleItem(itemId, isChecked) {
    try {
      await api.updateGroceryItem(itemId, { is_checked: !isChecked });
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function deleteItem(itemId) {
    try {
      await api.deleteGroceryItem(itemId);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function updateTitle() {
    const newTitle = editTitleVal.trim();
    if (!newTitle || newTitle === listTitle) { setIsEditing(false); return; }
    try {
      await api.updateGroceryList(listId, { title: newTitle });
      setListTitle(newTitle);
      setIsEditing(false);
    } catch (e) { toast(e.message, 'error'); }
  }

  async function confirmDeleteList() {
    try {
      await api.deleteGroceryList(listId);
      navigate(-1);
    } catch (e) { toast(e.message, 'error'); }
  }

  const unchecked = items.filter(i => i.is_checked !== true);
  const checked = items.filter(i => i.is_checked === true);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      {/* Custom AppBar with editable title */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: 'var(--color-background)', borderBottom: '1px solid var(--color-border)',
        display: 'flex', alignItems: 'center', padding: '0 8px',
        minHeight: 56,
      }}>
        <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: 8 }}>
          ←
        </button>

        {isEditing ? (
          <input
            ref={titleInputRef}
            value={editTitleVal}
            onChange={e => setEditTitleVal(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && updateTitle()}
            style={{
              flex: 1, border: 'none', outline: 'none', padding: '4px 0',
              fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18,
              color: 'var(--color-text-primary)', background: 'transparent',
            }}
          />
        ) : (
          <div onClick={() => { setEditTitleVal(listTitle); setIsEditing(true); }}
            style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', overflow: 'hidden' }}>
            <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {listTitle}
            </span>
            <Edit2 size={16} color="var(--color-text-secondary)" />
          </div>
        )}

        {isEditing ? (
          <button onClick={updateTitle} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: 8 }}>
            <Check size={20} />
          </button>
        ) : (
          <button onClick={() => setShowDeleteList(true)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#E53935', padding: 8 }}>
            <Trash2 size={20} />
          </button>
        )}
      </div>

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 20px 40px' }}>
          {/* Add item input */}
          <div style={{ marginTop: 16 }}>
            <div style={{
              background: 'var(--color-white)', borderRadius: 14, padding: '4px 14px',
              display: 'flex', alignItems: 'center', gap: 8,
              boxShadow: '0 2px 6px rgba(0,0,0,0.04)',
            }}>
              <input
                ref={addInputRef}
                placeholder="Add an item..."
                value={addInput}
                onChange={e => setAddInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && addItem()}
                style={{
                  flex: 1, border: 'none', outline: 'none', padding: '12px 0',
                  fontFamily: 'var(--font-family)', fontSize: 14, background: 'transparent', color: 'var(--color-text-primary)',
                }}
              />
              <button onClick={addItem} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: 4 }}>
                <Plus size={28} />
              </button>
            </div>
          </div>

          <div style={{ marginTop: 16 }}>
            {items.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '50px 0' }}>
                <div style={{ fontSize: 64, marginBottom: 12, opacity: 0.3 }}>🛍️</div>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, color: '#9E9E9E', margin: 0 }}>No items in this list</p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#BDBDBD', marginTop: 6 }}>Add items using the input above</p>
              </div>
            ) : (
              <>
                {/* Unchecked items */}
                {unchecked.length > 0 && (
                  <>
                    <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600, color: '#616161', margin: '0 0 8px' }}>
                      To Buy ({unchecked.length})
                    </p>
                    {unchecked.map(item => <ItemTile key={item._id} item={item} onToggle={toggleItem} onDelete={deleteItem} />)}
                  </>
                )}

                {/* Checked items */}
                {checked.length > 0 && (
                  <>
                    <div style={{ marginTop: 20, marginBottom: 8 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600, color: '#9E9E9E', margin: 0 }}>
                        Done ({checked.length})
                      </p>
                    </div>
                    {checked.map(item => <ItemTile key={item._id} item={item} onToggle={toggleItem} onDelete={deleteItem} />)}
                  </>
                )}
              </>
            )}
          </div>
        </div>
      )}

      {/* Delete list confirm */}
      <Modal open={showDeleteList} onClose={() => setShowDeleteList(false)} title={`Delete "${listTitle}"?`}
        actions={<><ModalCancelBtn onClick={() => setShowDeleteList(false)} /><DangerBtn label="Delete" onClick={confirmDeleteList} /></>}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>
          This will permanently delete this list and all items.
        </p>
      </Modal>
    </div>
  );
}

function ItemTile({ item, onToggle, onDelete }) {
  const name = item.item_name || '';
  const itemId = item._id || '';
  const isChecked = item.is_checked === true;

  return (
    <div
      style={{
        background: 'var(--color-white)', borderRadius: 12, marginBottom: 8,
        padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 14,
        border: isChecked ? 'none' : '1px solid rgba(158,158,158,0.15)',
      }}
    >
      {/* Checkbox */}
      <button
        onClick={() => onToggle(itemId, isChecked)}
        style={{
          width: 24, height: 24, borderRadius: 12, border: `2px solid ${isChecked ? 'var(--color-primary)' : '#9E9E9E'}`,
          background: isChecked ? 'var(--color-primary)' : 'transparent',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', flexShrink: 0, padding: 0,
        }}
      >
        {isChecked && <Check size={16} color="#fff" />}
      </button>

      {/* Name */}
      <span style={{
        flex: 1, fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 500,
        color: isChecked ? '#9E9E9E' : '#00352E',
        textDecoration: isChecked ? 'line-through' : 'none',
      }}>
        {name}
      </span>

      {/* Delete */}
      <button onClick={() => onDelete(itemId)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#BDBDBD', padding: 0 }}>
        <X size={18} />
      </button>
    </div>
  );
}
