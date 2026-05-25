// ═══════════════════════════════════════════════════════════════
// Inventory Categories Screen — mirrors inventory_categories_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronRight, MoreVertical, Plus, FolderOpen } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import Modal, { ModalCancelBtn, ModalPrimaryBtn, DangerBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const CAT_COLORS = [
  '#00897B', '#26A69A', '#FB8C00', '#607D8B',
  '#7B1FA2', '#E91E63', '#1565C0', '#6D4C41', '#00352E',
];

function getCategoryIcon(title) {
  const t = (title || '').toLowerCase();
  if (t.includes('fruit') || t.includes('vegetable') || t.includes('produce')) return '🥦';
  if (t.includes('dairy') || t.includes('milk') || t.includes('cheese')) return '🧀';
  if (t.includes('meat') || t.includes('chicken') || t.includes('beef')) return '🍗';
  if (t.includes('bread') || t.includes('bake') || t.includes('grain')) return '🍞';
  if (t.includes('drink') || t.includes('beverage') || t.includes('juice')) return '🥤';
  if (t.includes('snack') || t.includes('chip') || t.includes('candy')) return '🍪';
  if (t.includes('spice') || t.includes('herb') || t.includes('season')) return '🌿';
  if (t.includes('frozen')) return '🧊';
  if (t.includes('can') || t.includes('tin')) return '🥫';
  if (t.includes('clean') || t.includes('detergent')) return '🧹';
  if (t.includes('personal') || t.includes('hygiene')) return '🧴';
  if (t.includes('electronic')) return '📱';
  return '📦';
}

function buildCategoryPath(cat, flatCategories) {
  const parts = [cat.title || ''];
  let current = cat;
  let guard = 0;
  while (current.parent_category_id && guard < 10) {
    guard++;
    const parentId = current.parent_category_id?._id || current.parent_category_id;
    const parent = flatCategories.find(c => c._id === parentId);
    if (!parent) break;
    parts.unshift(parent.title || '');
    current = parent;
  }
  return parts.join(' > ');
}

function collectDescendantIds(node, ids = new Set()) {
  const id = node._id?.toString();
  if (id) ids.add(id);
  const children = node.children || [];
  children.forEach(c => collectDescendantIds(c, ids));
  return ids;
}

function countDescendants(node) {
  const children = node.children || [];
  return children.reduce((sum, c) => sum + 1 + countDescendants(c), 0);
}

function nodeMatchesSearch(node, q) {
  if (!q) return true;
  const title = (node.title || '').toLowerCase();
  if (title.includes(q.toLowerCase())) return true;
  return (node.children || []).some(c => nodeMatchesSearch(c, q));
}

function nodeHasUsedCategory(node, usedIds) {
  if (usedIds.has(node._id?.toString() || '')) return true;
  return (node.children || []).some(c => nodeHasUsedCategory(c, usedIds));
}

export default function InventoryCategoriesScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [treeCategories, setTreeCategories] = useState([]);
  const [flatCategories, setFlatCategories] = useState([]);
  const [inventories, setInventories] = useState([]);
  const [allItems, setAllItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedInventoryId, setSelectedInventoryId] = useState(null);
  const [expandedIds, setExpandedIds] = useState(new Set());

  // Add/Edit modal
  const [showModal, setShowModal] = useState(false);
  const [editNode, setEditNode] = useState(null);
  const [modalTitle, setModalTitle] = useState('');
  const [modalDesc, setModalDesc] = useState('');
  const [modalParentId, setModalParentId] = useState('');
  const [modalExcludeIds, setModalExcludeIds] = useState(new Set());
  const [saving, setSaving] = useState(false);

  // Sub-category modal
  const [showSubModal, setShowSubModal] = useState(false);
  const [subParent, setSubParent] = useState(null);
  const [subTitle, setSubTitle] = useState('');
  const [subDesc, setSubDesc] = useState('');

  // Delete confirm
  const [deleteNode, setDeleteNode] = useState(null);

  // Popup menu
  const [menuOpen, setMenuOpen] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [tree, flat, invs, items] = await Promise.all([
        api.getAllInventoryCategories({ tree: true }).catch(() => []),
        api.getAllInventoryCategories({ tree: false }).catch(() => []),
        api.getAllInventories().catch(() => []),
        api.getAllFamilyItems().catch(() => []),
      ]);
      setTreeCategories(tree);
      setFlatCategories(flat);
      setInventories(invs);
      setAllItems(items);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const usedCategoryIds = (() => {
    const items = selectedInventoryId == null
      ? allItems
      : allItems.filter(item => {
          const inv = item.inventory_id;
          if (inv && typeof inv === 'object') return inv._id === selectedInventoryId;
          return inv === selectedInventoryId;
        });
    const ids = new Set();
    items.forEach(item => {
      const cat = item.item_category;
      if (cat && typeof cat === 'object' && cat._id) ids.add(cat._id);
      else if (typeof cat === 'string') ids.add(cat);
    });
    return ids;
  })();

  function expandAll() {
    const ids = new Set();
    flatCategories.forEach(c => { if (c._id) ids.add(c._id.toString()); });
    setExpandedIds(ids);
  }
  function collapseAll() { setExpandedIds(new Set()); }

  function toggleExpand(id) {
    setExpandedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  function openAdd() {
    setEditNode(null);
    setModalTitle(''); setModalDesc(''); setModalParentId('');
    setModalExcludeIds(new Set());
    setShowModal(true);
  }

  function openEdit(node) {
    setEditNode(node);
    setModalTitle(node.title || '');
    setModalDesc(node.description || '');
    const parentRef = node.parent_category_id;
    const parentId = parentRef?._id || parentRef || '';
    setModalParentId(parentId);
    setModalExcludeIds(collectDescendantIds(node));
    setShowModal(true);
    setMenuOpen(null);
  }

  function openAddSub(node) {
    setSubParent(node);
    setSubTitle(''); setSubDesc('');
    setShowSubModal(true);
    setMenuOpen(null);
  }

  async function saveCategory() {
    if (!modalTitle.trim()) return;
    setSaving(true);
    try {
      const body = {
        title: modalTitle.trim(),
        description: modalDesc.trim(),
        parent_category_id: modalParentId || null,
      };
      if (editNode) await api.updateInventoryCategory(editNode._id, body);
      else await api.createInventoryCategory(body);
      setShowModal(false);
      toast(editNode ? 'Category updated' : 'Category created');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function saveSubcategory() {
    if (!subTitle.trim() || !subParent) return;
    setSaving(true);
    try {
      await api.createInventoryCategory({
        title: subTitle.trim(),
        description: subDesc.trim(),
        parent_category_id: subParent._id,
      });
      // Auto-expand parent so new child is visible
      setExpandedIds(prev => {
        const next = new Set(prev);
        next.add(subParent._id.toString());
        return next;
      });
      setShowSubModal(false);
      toast('Subcategory created');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function confirmDelete() {
    if (!deleteNode) return;
    const children = deleteNode.children || [];
    if (children.length > 0) {
      toast(`Cannot delete "${deleteNode.title}" because it has ${children.length} subcategor${children.length === 1 ? 'y' : 'ies'}. Remove them first.`, 'error');
      setDeleteNode(null);
      return;
    }
    try {
      await api.deleteInventoryCategory(deleteNode._id);
      toast(`"${deleteNode.title}" deleted`);
      setDeleteNode(null);
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const visibleRoots = treeCategories.filter(node => {
    if (!nodeMatchesSearch(node, searchQuery)) return false;
    if (selectedInventoryId != null) return nodeHasUsedCategory(node, usedCategoryIds);
    return true;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}
      onClick={() => setMenuOpen(null)}>
      <AppBar title="Categories" actions={
        <>
          <button onClick={expandAll} title="Expand all" style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: '4px 8px', fontFamily: 'var(--font-family)', fontSize: 12 }}>⊞ All</button>
          <button onClick={collapseAll} title="Collapse all" style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: '4px 8px', fontFamily: 'var(--font-family)', fontSize: 12 }}>⊟ All</button>
        </>
      } />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 100px' }}>
          {/* Inventory selector */}
          {inventories.length > 0 && (
            <div style={{ overflowX: 'auto', display: 'flex', gap: 8, padding: '8px 16px', scrollbarWidth: 'none' }}>
              <InvChip label="All Inventories" selected={selectedInventoryId == null} onClick={() => setSelectedInventoryId(null)} />
              {inventories.map(inv => (
                <InvChip key={inv._id} label={inv.title || ''} selected={selectedInventoryId === inv._id}
                  onClick={() => setSelectedInventoryId(selectedInventoryId === inv._id ? null : inv._id)} />
              ))}
            </div>
          )}

          {/* Search bar */}
          <div style={{ padding: '4px 20px 8px' }}>
            <div style={{ background: 'var(--color-white)', borderRadius: 14, padding: '0 14px', display: 'flex', alignItems: 'center', gap: 8, boxShadow: 'var(--shadow-card)' }}>
              <span style={{ color: '#9E9E9E', fontSize: 18 }}>🔍</span>
              <input
                placeholder="Search categories..."
                value={searchQuery}
                onChange={e => {
                  const val = e.target.value;
                  setSearchQuery(val);
                  if (val) {
                    const ids = new Set();
                    flatCategories.forEach(c => { if (c._id) ids.add(c._id.toString()); });
                    setExpandedIds(ids);
                  }
                }}
                style={{
                  flex: 1, border: 'none', outline: 'none', padding: '12px 0',
                  fontFamily: 'var(--font-family)', fontSize: 13, background: 'transparent', color: 'var(--color-text-primary)',
                }}
              />
            </div>
          </div>

          {/* Stats bar */}
          <div style={{ display: 'flex', gap: 12, padding: '4px 24px 8px' }}>
            <StatChip icon="📁" label={`${treeCategories.length} root`} />
            <StatChip icon="🌳" label={`${flatCategories.length} total`} />
          </div>

          {/* Tree */}
          {visibleRoots.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 16px' }}>
              <div style={{ fontSize: 64, marginBottom: 12, opacity: 0.3 }}>📂</div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 16, color: '#9E9E9E', margin: 0 }}>
                {searchQuery ? 'No matching categories' : 'No categories yet'}
              </p>
              {!searchQuery && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#BDBDBD', marginTop: 8 }}>
                  Tap + to create your first category
                </p>
              )}
            </div>
          ) : (
            <div style={{ padding: '4px 16px' }}>
              {visibleRoots.map((node, i) => (
                <TreeNode
                  key={node._id}
                  node={node}
                  depth={0}
                  colorIndex={i}
                  expandedIds={expandedIds}
                  toggleExpand={toggleExpand}
                  searchQuery={searchQuery}
                  menuOpen={menuOpen}
                  setMenuOpen={setMenuOpen}
                  onEdit={openEdit}
                  onAddSub={openAddSub}
                  onDelete={n => { setDeleteNode(n); setMenuOpen(null); }}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {/* FAB */}
      <button onClick={openAdd} style={{
        position: 'fixed', bottom: 24, right: 24,
        background: 'var(--color-primary)', color: '#fff', border: 'none', borderRadius: 28,
        padding: '14px 20px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
        fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14,
        boxShadow: '0 4px 14px rgba(0,137,123,0.4)',
      }}>
        <Plus size={18} /> Add Category
      </button>

      {/* Add/Edit Modal */}
      <Modal open={showModal} onClose={() => setShowModal(false)}
        title={editNode ? 'Edit Category' : 'Add Category'}
        actions={<>
          <ModalCancelBtn onClick={() => setShowModal(false)} />
          <ModalPrimaryBtn label={saving ? '…' : (editNode ? 'Save' : 'Add')} disabled={saving || !modalTitle.trim()} onClick={saveCategory} />
        </>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Category Name *" value={modalTitle} onChange={setModalTitle} placeholder="e.g., Dairy, Leafy Greens" required />
          <SelectField
            label="Parent Category"
            value={modalParentId}
            onChange={setModalParentId}
            options={[
              { value: '', label: 'None (root level)' },
              ...flatCategories
                .filter(c => !modalExcludeIds.has(c._id?.toString()))
                .map(c => ({ value: c._id, label: buildCategoryPath(c, flatCategories) }))
            ]}
          />
          <FormField label="Description (optional)" value={modalDesc} onChange={setModalDesc} rows={2} />
        </div>
      </Modal>

      {/* Add Subcategory Modal */}
      <Modal open={showSubModal} onClose={() => setShowSubModal(false)}
        title="Add Subcategory"
        actions={<>
          <ModalCancelBtn onClick={() => setShowSubModal(false)} />
          <ModalPrimaryBtn label={saving ? '…' : 'Add'} disabled={saving || !subTitle.trim()} onClick={saveSubcategory} />
        </>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {subParent && (
            <div style={{ background: 'var(--color-primary-surface)', borderRadius: 8, padding: '8px 12px', display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ color: 'var(--color-primary)', fontSize: 16 }}>↳</span>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>
                Under: {buildCategoryPath(subParent, flatCategories)}
              </span>
            </div>
          )}
          <FormField label="Subcategory Name *" value={subTitle} onChange={setSubTitle} required />
          <FormField label="Description (optional)" value={subDesc} onChange={setSubDesc} rows={2} />
        </div>
      </Modal>

      {/* Delete confirm */}
      <Modal open={!!deleteNode} onClose={() => setDeleteNode(null)} title="Delete Category"
        actions={<><ModalCancelBtn onClick={() => setDeleteNode(null)} /><DangerBtn label="Delete" onClick={confirmDelete} /></>}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>
          Are you sure you want to delete "{deleteNode?.title}"?
        </p>
      </Modal>
    </div>
  );
}

function InvChip({ label, selected, onClick }) {
  return (
    <button onClick={onClick} style={{
      flexShrink: 0, padding: '8px 14px', border: `1px solid ${selected ? 'var(--color-primary)' : '#E0E0E0'}`,
      borderRadius: 14, background: selected ? 'var(--color-primary)' : 'var(--color-white)',
      color: selected ? '#fff' : 'var(--color-text-primary)',
      fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12, cursor: 'pointer',
    }}>
      {label}
    </button>
  );
}

function StatChip({ icon, label }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 4,
      background: 'var(--color-white)', borderRadius: 20, padding: '4px 10px',
    }}>
      <span style={{ fontSize: 14 }}>{icon}</span>
      <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>{label}</span>
    </div>
  );
}

function TreeNode({ node, depth, colorIndex, expandedIds, toggleExpand, searchQuery, menuOpen, setMenuOpen, onEdit, onAddSub, onDelete }) {
  const id = node._id?.toString() || '';
  const title = node.title || '';
  const desc = node.description || '';
  const children = node.children || [];
  const hasChildren = children.length > 0;
  const isExpanded = expandedIds.has(id);
  const icon = getCategoryIcon(title);
  const color = CAT_COLORS[colorIndex % CAT_COLORS.length];
  const totalDescendants = countDescendants(node);

  const visibleChildren = children.filter(c => nodeMatchesSearch(c, searchQuery));

  return (
    <div>
      {/* Node tile */}
      <div
        onClick={e => { e.stopPropagation(); if (hasChildren) toggleExpand(id); }}
        style={{
          marginLeft: depth * 20, marginBottom: 8,
          background: 'var(--color-white)',
          borderRadius: 14,
          borderLeft: depth === 0 ? `4px solid ${color}` : 'none',
          boxShadow: depth === 0 ? `0 2px 8px ${color}14, var(--shadow-card)` : 'var(--shadow-card)',
          cursor: hasChildren ? 'pointer' : 'default',
          padding: '10px 12px',
          display: 'flex', alignItems: 'center', gap: 6,
        }}
        onClick={e => { e.stopPropagation(); }}
      >
        {/* Expand toggle */}
        {hasChildren ? (
          <div
            onClick={e => { e.stopPropagation(); toggleExpand(id); }}
            style={{
              cursor: 'pointer',
              transform: isExpanded ? 'rotate(90deg)' : 'rotate(0deg)',
              transition: 'transform 0.2s',
              color: 'var(--color-text-secondary)', flexShrink: 0,
            }}>
            <ChevronRight size={22} />
          </div>
        ) : (
          <div style={{ width: 22, flexShrink: 0 }} />
        )}

        {/* Category icon */}
        <div style={{
          padding: 8, borderRadius: 10, flexShrink: 0,
          background: depth === 0 ? color + '1F' : 'var(--color-primary-surface)',
        }}>
          <span style={{ fontSize: 18 }}>{icon}</span>
        </div>

        {/* Title + meta */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <p style={{
            fontFamily: 'var(--font-family)', fontWeight: 600, margin: 0,
            fontSize: depth === 0 ? 15 : 14, color: '#00352E',
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>{title}</p>
          {desc && (
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)', margin: '1px 0 0', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{desc}</p>
          )}
          {hasChildren && (
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)', margin: '2px 0 0' }}>
              {children.length} subcategor{children.length === 1 ? 'y' : 'ies'}
              {totalDescendants > children.length ? ` (${totalDescendants} total)` : ''}
            </p>
          )}
        </div>

        {/* Depth badge */}
        {depth > 0 && (
          <div style={{ background: 'var(--color-primary-surface)', borderRadius: 8, padding: '2px 6px', marginRight: 4, flexShrink: 0 }}>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)' }}>L{depth + 1}</span>
          </div>
        )}

        {/* Popup menu */}
        <div style={{ position: 'relative', flexShrink: 0 }} onClick={e => e.stopPropagation()}>
          <button onClick={e => { e.stopPropagation(); setMenuOpen(menuOpen === id ? null : id); }}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#9E9E9E', padding: 4 }}>
            <MoreVertical size={18} />
          </button>
          {menuOpen === id && (
            <div style={{
              position: 'absolute', right: 0, top: '100%', background: 'var(--color-white)',
              border: '1px solid var(--color-border)', borderRadius: 10, zIndex: 100,
              boxShadow: 'var(--shadow-card)', minWidth: 150, overflow: 'hidden',
            }}>
              <button onClick={() => onEdit(node)} style={menuBtnStyle('#00897B')}>✏️ Edit</button>
              <button onClick={() => onAddSub(node)} style={menuBtnStyle('#26A69A')}>➕ Add Subcategory</button>
              <button onClick={() => onDelete(node)} style={menuBtnStyle('#E53935')}>🗑️ Delete</button>
            </div>
          )}
        </div>
      </div>

      {/* Children */}
      {isExpanded && hasChildren && visibleChildren.map((child, ci) => (
        <TreeNode
          key={child._id}
          node={child}
          depth={depth + 1}
          colorIndex={colorIndex}
          expandedIds={expandedIds}
          toggleExpand={toggleExpand}
          searchQuery={searchQuery}
          menuOpen={menuOpen}
          setMenuOpen={setMenuOpen}
          onEdit={onEdit}
          onAddSub={onAddSub}
          onDelete={onDelete}
        />
      ))}
    </div>
  );
}

function menuBtnStyle(color) {
  return {
    width: '100%', padding: '10px 14px', background: 'none', border: 'none', cursor: 'pointer',
    textAlign: 'left', fontFamily: 'var(--font-family)', fontSize: 13, color,
    display: 'block',
  };
}
