// ═══════════════════════════════════════════════════════════════
// Meals Screen — mirrors meals_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { UtensilsCrossed, Plus, ChevronLeft, ChevronRight, Calendar, Trash2, Edit2, Eye, BookOpen } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn, DangerBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const MEAL_TYPE_ORDER = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

const MEAL_TYPE_META = {
  Breakfast: { emoji: '🌅', color: '#FF9800', bg: '#FFF3E0' },
  Lunch:     { emoji: '☀️', color: 'var(--color-primary)', bg: 'var(--color-primary-surface)' },
  Dinner:    { emoji: '🌙', color: '#2196F3', bg: '#E3F2FD' },
  Snack:     { emoji: '🍿', color: '#E91E63', bg: '#FCE4EC' },
};

function formatDateLabel(date) {
  const today = new Date(); today.setHours(0,0,0,0);
  const d = new Date(date); d.setHours(0,0,0,0);
  const diff = Math.round((d - today) / 86400000);
  if (diff === 0) return 'Today';
  if (diff === -1) return 'Yesterday';
  if (diff === 1) return 'Tomorrow';
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

function toDateStr(date) {
  return date.toISOString().split('T')[0];
}

export default function MealsScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [selectedDate, setSelectedDate] = useState(new Date());
  const [meals, setMeals] = useState([]);
  const [inventoryItems, setInventoryItems] = useState([]);
  const [loading, setLoading] = useState(true);

  // Add/Edit meal modal
  const [showAddModal, setShowAddModal] = useState(false);
  const [editMeal, setEditMeal] = useState(null);
  const [mealName, setMealName] = useState('');
  const [mealType, setMealType] = useState('Breakfast');
  const [servings, setServings] = useState(1);
  const [saving, setSaving] = useState(false);

  // Delete modal
  const [deleteMeal, setDeleteMeal] = useState(null);

  // Detail sheet
  const [detailMeal, setDetailMeal] = useState(null);
  const [detailItems, setDetailItems] = useState([]);
  const [detailLoading, setDetailLoading] = useState(false);
  const [showDetail, setShowDetail] = useState(false);

  // Add item to meal modal
  const [showAddItemModal, setShowAddItemModal] = useState(false);
  const [addItemMeal, setAddItemMeal] = useState(null);
  const [itemMode, setItemMode] = useState('inventory'); // 'inventory' | 'custom'
  const [selectedItemId, setSelectedItemId] = useState('');
  const [itemQty, setItemQty] = useState('1');
  const [customName, setCustomName] = useState('');
  const [customUnit, setCustomUnit] = useState('');
  const [savingItem, setSavingItem] = useState(false);

  const loadMeals = useCallback(async (date) => {
    const d = date || selectedDate;
    setLoading(true);
    try {
      const meals = await api.getMeals({ date: toDateStr(d) });
      setMeals(meals);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, [selectedDate]);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [ms, items] = await Promise.all([
        api.getMeals({ date: toDateStr(selectedDate) }),
        api.getAllFamilyItems().catch(() => []),
      ]);
      setMeals(ms);
      setInventoryItems(items);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, [selectedDate]);

  useEffect(() => { loadData(); }, []);

  function goToPrevDay() {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() - 1);
    setSelectedDate(d);
    loadMeals(d);
  }

  function goToNextDay() {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + 1);
    setSelectedDate(d);
    loadMeals(d);
  }

  function openAdd() {
    setEditMeal(null); setMealName(''); setMealType('Breakfast'); setServings(1);
    setShowAddModal(true);
  }

  function openEdit(meal) {
    setEditMeal(meal); setMealName(meal.meal_name || ''); setMealType(meal.meal_type || 'Breakfast');
    setServings(meal.servings && meal.servings > 0 ? meal.servings : 1);
    setShowAddModal(true);
  }

  async function saveMeal() {
    if (!mealName.trim()) return;
    setSaving(true);
    try {
      if (editMeal) {
        await api.updateMeal(editMeal._id, { meal_name: mealName.trim(), meal_type: mealType, servings });
      } else {
        await api.createMeal({ meal_name: mealName.trim(), meal_date: toDateStr(selectedDate), meal_type: mealType, servings });
      }
      setShowAddModal(false);
      toast(editMeal ? 'Meal updated!' : 'Meal added!');
      loadMeals();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function confirmDelete() {
    if (!deleteMeal) return;
    try {
      await api.deleteMeal(deleteMeal._id);
      toast('Meal deleted');
      setDeleteMeal(null);
      loadMeals();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function openDetail(meal) {
    setDetailLoading(true);
    setShowDetail(true);
    try {
      const d = await api.getMeal(meal._id);
      setDetailMeal(d.meal || {});
      setDetailItems(d.mealItems || []);
    } catch (e) { toast(e.message, 'error'); }
    finally { setDetailLoading(false); }
  }

  async function refreshDetail() {
    if (!detailMeal?._id) return;
    try {
      const d = await api.getMeal(detailMeal._id);
      setDetailMeal(d.meal || {});
      setDetailItems(d.mealItems || []);
    } catch (_) {}
  }

  async function removeItem(itemId) {
    try {
      await api.removeMealItem(detailMeal._id, itemId);
      await refreshDetail();
      loadMeals();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function prepareMeal() {
    try {
      const result = await api.prepareMealFromRecipe(detailMeal._id);
      if (result.status === 'partial') {
        const missing = result.data?.missing || [];
        toast('Missing: ' + missing.map(m => m.ingredient_name).join(', '), 'warning');
      } else {
        toast('All ingredients deducted from inventory!');
        await refreshDetail();
        loadMeals();
      }
    } catch (e) { toast(e.message, 'error'); }
  }

  function openAddItem(meal) {
    setAddItemMeal(meal); setItemMode('inventory');
    setSelectedItemId(''); setItemQty('1'); setCustomName(''); setCustomUnit('');
    setShowAddItemModal(true);
  }

  async function saveItem() {
    const qty = parseFloat(itemQty);
    if (!qty || qty <= 0) { toast('Quantity must be > 0', 'error'); return; }

    let payload;
    if (itemMode === 'inventory') {
      if (!selectedItemId) { toast('Please select an item', 'error'); return; }
      const item = inventoryItems.find(i => i._id === selectedItemId);
      const unitId = item?.unit_id?._id || item?.unit_id || undefined;
      payload = { inventory_item_id: selectedItemId, unit_id: unitId, quantity_used: qty };
    } else {
      if (!customName.trim()) { toast('Please enter an item name', 'error'); return; }
      payload = { custom_name: customName.trim(), custom_unit: customUnit.trim() || undefined, quantity_used: qty };
    }

    setSavingItem(true);
    try {
      await api.addMealItem(addItemMeal._id, payload);
      setShowAddItemModal(false);
      const items = await api.getAllFamilyItems().catch(() => []);
      setInventoryItems(items);
      openDetail(addItemMeal);
    } catch (e) { toast(e.message, 'error'); }
    finally { setSavingItem(false); }
  }

  function groupByType() {
    const groups = {};
    MEAL_TYPE_ORDER.forEach(t => { groups[t] = []; });
    meals.forEach(m => {
      const type = m.meal_type || 'Snack';
      if (groups[type]) groups[type].push(m);
      else groups['Snack'].push(m);
    });
    return groups;
  }

  const grouped = groupByType();
  const mealType2 = detailMeal?.meal_type || 'Lunch';
  const detailAccent = MEAL_TYPE_META[mealType2]?.color || 'var(--color-primary)';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Meal Planner" />

      {/* Date selector */}
      <div style={{
        margin: '12px 16px 4px',
        padding: '6px 8px',
        background: 'var(--color-white)',
        borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        boxShadow: 'var(--shadow-card)',
      }}>
        <button onClick={goToPrevDay} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: 8 }}>
          <ChevronLeft size={22} />
        </button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Calendar size={18} color="var(--color-primary)" />
          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 16, color: 'var(--color-text-primary)' }}>
            {formatDateLabel(selectedDate)}
          </span>
          <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-hint)' }}>
            {selectedDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
          </span>
        </div>
        <button onClick={goToNextDay} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-primary)', padding: 8 }}>
          <ChevronRight size={22} />
        </button>
      </div>

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '8px 16px 88px' }}>
          {meals.length === 0 ? (
            <EmptyState icon={UtensilsCrossed} message="No meals planned — tap + to add" />
          ) : (
            MEAL_TYPE_ORDER.filter(type => grouped[type]?.length > 0).map(type => {
              const meta = MEAL_TYPE_META[type];
              return (
                <div key={type} style={{ marginBottom: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0' }}>
                    <span style={{ fontSize: 18 }}>{meta.emoji}</span>
                    <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: meta.color }}>{type}</span>
                    <span style={{
                      background: meta.bg, color: meta.color,
                      padding: '1px 8px', borderRadius: 10,
                      fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                    }}>{grouped[type].length}</span>
                  </div>
                  {grouped[type].map(meal => (
                    <MealCard key={meal._id} meal={meal} meta={meta}
                      onView={() => openDetail(meal)}
                      onEdit={() => openEdit(meal)}
                      onDelete={() => setDeleteMeal(meal)}
                    />
                  ))}
                </div>
              );
            })
          )}
        </div>
      )}

      {/* FAB */}
      <button onClick={openAdd} style={{
        position: 'fixed', bottom: 24, right: 24, width: 56, height: 56,
        borderRadius: 16, background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        border: 'none', cursor: 'pointer', boxShadow: 'var(--shadow-primary)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', zIndex: 200,
      }}>
        <Plus size={28} />
      </button>

      {/* Add / Edit Meal Modal */}
      <Modal open={showAddModal} onClose={() => setShowAddModal(false)}
        title={editMeal ? 'Edit Meal' : 'Add Meal'}
        actions={<>
          <ModalCancelBtn onClick={() => setShowAddModal(false)} />
          <ModalPrimaryBtn label={saving ? '…' : (editMeal ? 'Save' : 'Add')} disabled={saving || !mealName.trim()} onClick={saveMeal} />
        </>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label="Meal Name" value={mealName} onChange={setMealName} required />
          <div>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, marginBottom: 8, color: 'var(--color-text-primary)' }}>Meal Type</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {MEAL_TYPE_ORDER.map(type => {
                const meta = MEAL_TYPE_META[type];
                const sel = mealType === type;
                return (
                  <button key={type} onClick={() => setMealType(type)} style={{
                    display: 'flex', alignItems: 'center', gap: 6,
                    background: sel ? meta.color : meta.bg,
                    color: sel ? '#fff' : 'var(--color-text-primary)',
                    border: `2px solid ${sel ? meta.color : 'transparent'}`,
                    borderRadius: 20, padding: '6px 14px', cursor: 'pointer',
                    fontFamily: 'var(--font-family)', fontWeight: sel ? 600 : 400, fontSize: 13,
                  }}>
                    <span>{meta.emoji}</span> {type}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Servings / number of people */}
          <div>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, marginBottom: 8, color: 'var(--color-text-primary)' }}>
              How many people can eat this?
            </p>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <button type="button" onClick={() => setServings(s => Math.max(1, s - 1))} style={{
                width: 40, height: 40, borderRadius: 12, border: '2px solid var(--color-border)',
                background: 'var(--color-white)', cursor: 'pointer', fontSize: 20, fontWeight: 700,
                color: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>−</button>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 90, justifyContent: 'center' }}>
                <span style={{ fontSize: 18 }}>👥</span>
                <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 20, color: 'var(--color-text-primary)' }}>{servings}</span>
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-secondary)' }}>
                  {servings === 1 ? 'person' : 'people'}
                </span>
              </div>
              <button type="button" onClick={() => setServings(s => Math.min(50, s + 1))} style={{
                width: 40, height: 40, borderRadius: 12, border: '2px solid var(--color-border)',
                background: 'var(--color-white)', cursor: 'pointer', fontSize: 20, fontWeight: 700,
                color: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>+</button>
            </div>
          </div>
        </div>
      </Modal>

      {/* Delete Confirm Modal */}
      <Modal open={!!deleteMeal} onClose={() => setDeleteMeal(null)} title="Delete Meal"
        actions={<>
          <ModalCancelBtn onClick={() => setDeleteMeal(null)} />
          <DangerBtn label="Delete" onClick={confirmDelete} />
        </>}
      >
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>
          Delete &quot;{deleteMeal?.meal_name}&quot;? All ingredients used will be restored to inventory.
        </p>
      </Modal>

      {/* Meal Detail Sheet */}
      {showDetail && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', zIndex: 300,
          display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
        }} onClick={() => setShowDetail(false)}>
          <div style={{
            background: 'var(--color-white)', borderRadius: '24px 24px 0 0',
            width: '100%', maxWidth: 700, maxHeight: '90vh', display: 'flex', flexDirection: 'column',
          }} onClick={e => e.stopPropagation()}>
            {/* Handle */}
            <div style={{ width: 40, height: 4, background: '#ccc', borderRadius: 2, margin: '12px auto 0' }} />

            {/* Header */}
            {detailMeal && (
              <div style={{ padding: '16px 20px 0', display: 'flex', alignItems: 'center', gap: 14 }}>
                <div style={{
                  padding: 10, background: MEAL_TYPE_META[detailMeal.meal_type]?.bg || 'var(--color-primary-surface)',
                  borderRadius: 12,
                }}>
                  <span style={{ fontSize: 24 }}>{MEAL_TYPE_META[detailMeal.meal_type]?.emoji || '🍽️'}</span>
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: 'var(--color-text-primary)', margin: 0 }}>
                    {detailMeal.meal_name}
                  </p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                    {detailMeal.meal_type} · {formatDateLabel(selectedDate)}
                    {detailMeal.servings ? ` · 👥 ${detailMeal.servings} ${detailMeal.servings === 1 ? 'person' : 'people'}` : ''}
                  </p>
                </div>
                <button onClick={() => setShowDetail(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#999' }}>✕</button>
              </div>
            )}
            <div style={{ height: 1, background: 'var(--color-border-light)', margin: '12px 0 0' }} />

            {/* Body */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px' }}>
              {detailLoading ? <LoadingSpinner /> : (
                <>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                    <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)', margin: 0 }}>
                      Ingredients Used
                    </p>
                    <button onClick={() => { setShowDetail(false); openAddItem(detailMeal); }} style={{
                      display: 'flex', alignItems: 'center', gap: 4, background: 'none', border: 'none',
                      cursor: 'pointer', color: detailAccent, fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13,
                    }}>
                      <Plus size={16} /> Add
                    </button>
                  </div>

                  {detailItems.length === 0 ? (
                    <div style={{ padding: 24, background: '#f9f9f9', borderRadius: 12, textAlign: 'center' }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: '#999', margin: 0 }}>No ingredients added yet</p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#bbb', margin: '4px 0 0' }}>Tap "Add" to use items from inventory</p>
                    </div>
                  ) : (
                    detailItems.map(item => {
                      const invItem = item.inventory_item_id;
                      const unit = item.unit_id;
                      const isCustom = !invItem;
                      const itemName = invItem?.item_name || item.custom_name || 'Unknown';
                      const unitName = unit?.unit_name || item.custom_unit || '';
                      return (
                        <div key={item._id} style={{
                          display: 'flex', alignItems: 'center', gap: 12,
                          marginBottom: 8, padding: '10px 14px',
                          background: '#f9f9f9', borderRadius: 12, border: '1px solid #eee',
                        }}>
                          <div style={{ padding: 8, background: detailAccent + '1A', borderRadius: 8 }}>
                            <span style={{ fontSize: 16 }}>{isCustom ? '📝' : '📦'}</span>
                          </div>
                          <div style={{ flex: 1 }}>
                            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                              {itemName}
                              {isCustom && (
                                <span style={{
                                  marginLeft: 6, fontSize: 10, fontWeight: 600, color: '#9C6700',
                                  background: '#FFF3CD', borderRadius: 6, padding: '1px 6px', verticalAlign: 'middle',
                                }}>not in inventory</span>
                              )}
                            </p>
                            <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>{item.quantity_used} {unitName}</p>
                          </div>
                          <button onClick={() => removeItem(item._id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#E53935' }}>
                            <Trash2 size={18} />
                          </button>
                        </div>
                      );
                    })
                  )}

                  {/* Linked recipe */}
                  {detailMeal?.recipe_id && (
                    <div style={{
                      marginTop: 20, padding: 14, background: '#FFF8E1',
                      borderRadius: 12, border: '1px solid #FFE082',
                      display: 'flex', alignItems: 'center', gap: 12,
                    }}>
                      <BookOpen size={24} color="#F57F17" />
                      <div style={{ flex: 1 }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>Linked Recipe</p>
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#E65100', margin: 0 }}>
                          {detailMeal.recipe_id?.recipe_name || 'Recipe'}
                        </p>
                      </div>
                      <button onClick={prepareMeal} style={{
                        background: '#F57F17', color: '#fff', border: 'none',
                        borderRadius: 8, padding: '6px 12px', cursor: 'pointer',
                        fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                      }}>Prepare</button>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Add Item Modal */}
      <Modal open={showAddItemModal} onClose={() => setShowAddItemModal(false)}
        title="Add Item"
        actions={<>
          <ModalCancelBtn onClick={() => setShowAddItemModal(false)} />
          <ModalPrimaryBtn
            label={savingItem ? '…' : 'Add'}
            disabled={savingItem || (itemMode === 'inventory' ? !selectedItemId : !customName.trim())}
            onClick={saveItem}
          />
        </>}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* Mode toggle: inventory vs new item */}
          <div style={{ display: 'flex', gap: 8, background: 'var(--color-primary-surface)', padding: 4, borderRadius: 12 }}>
            {[
              { key: 'inventory', label: '📦 From Inventory' },
              { key: 'custom', label: '📝 New Item' },
            ].map(opt => {
              const sel = itemMode === opt.key;
              return (
                <button key={opt.key} type="button" onClick={() => setItemMode(opt.key)} style={{
                  flex: 1, padding: '8px 10px', borderRadius: 9, border: 'none', cursor: 'pointer',
                  background: sel ? 'var(--color-primary)' : 'transparent',
                  color: sel ? '#fff' : 'var(--color-text-secondary)',
                  fontFamily: 'var(--font-family)', fontWeight: sel ? 600 : 500, fontSize: 13,
                }}>{opt.label}</button>
              );
            })}
          </div>

          {itemMode === 'inventory' ? (
            <>
              <SelectField
                label="Select from Inventory"
                value={selectedItemId} onChange={setSelectedItemId}
                options={[
                  { value: '', label: 'Choose an item' },
                  ...inventoryItems.map(i => {
                    const unit = i.unit_id;
                    const uName = unit?.unit_name || '';
                    return { value: i._id, label: `${i.item_name} (${i.quantity} ${uName})` };
                  }),
                ]}
              />
              <FormField label="Quantity to use" value={itemQty} onChange={setItemQty} type="number" min="0.01" step="0.01" />
              {selectedItemId && (() => {
                const it = inventoryItems.find(i => i._id === selectedItemId);
                if (!it) return null;
                const uName = it.unit_id?.unit_name || '';
                return (
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>
                    Available: {it.quantity} {uName}
                  </p>
                );
              })()}
            </>
          ) : (
            <>
              <FormField label="Item Name" value={customName} onChange={setCustomName} placeholder="e.g. Salt, Olive oil" required />
              <div style={{ display: 'flex', gap: 10 }}>
                <div style={{ flex: 1 }}>
                  <FormField label="Quantity" value={itemQty} onChange={setItemQty} type="number" min="0.01" step="0.01" />
                </div>
                <div style={{ flex: 1 }}>
                  <FormField label="Unit (optional)" value={customUnit} onChange={setCustomUnit} placeholder="cups, pcs…" />
                </div>
              </div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>
                This item isn't tracked in inventory, so nothing will be deducted.
              </p>
            </>
          )}
        </div>
      </Modal>
    </div>
  );
}

function MealCard({ meal, meta, onView, onEdit, onDelete }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handler(e) { if (ref.current && !ref.current.contains(e.target)) setMenuOpen(false); }
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const recipeName = meal.recipe_id?.recipe_name;

  return (
    <div onClick={onView} style={{
      marginBottom: 10, padding: 14,
      background: 'var(--color-white)', borderRadius: 14,
      borderLeft: `4px solid ${meta.color}`,
      boxShadow: 'var(--shadow-card)', display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer',
    }}>
      <div style={{ padding: 10, background: meta.bg, borderRadius: 12, flexShrink: 0 }}>
        <span style={{ fontSize: 22 }}>{meta.emoji}</span>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 15, color: 'var(--color-text-primary)', margin: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{meal.meal_name || 'Untitled'}</span>
          {meal.servings > 0 && (
            <span style={{
              flexShrink: 0, fontSize: 11, fontWeight: 600, color: meta.color, background: meta.bg,
              borderRadius: 10, padding: '1px 8px', display: 'inline-flex', alignItems: 'center', gap: 3,
            }}>👥 {meal.servings}</span>
          )}
        </p>
        {recipeName && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#E65100', margin: '2px 0 0' }}>
            📖 {recipeName}
          </p>
        )}
        {meal.created_by && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)', margin: 0 }}>
            by {meal.created_by}
          </p>
        )}
      </div>

      <div ref={ref} style={{ position: 'relative' }} onClick={e => e.stopPropagation()}>
        <button onClick={() => setMenuOpen(!menuOpen)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#999', padding: 4 }}>
          ⋮
        </button>
        {menuOpen && (
          <div style={{
            position: 'absolute', right: 0, top: '100%', background: 'var(--color-white)',
            border: '1px solid var(--color-border)', borderRadius: 10, zIndex: 100,
            boxShadow: 'var(--shadow-card)', minWidth: 140, overflow: 'hidden',
          }}>
            {[
              { icon: Eye, label: 'View Details', action: onView },
              { icon: Edit2, label: 'Edit', action: onEdit },
              { icon: Trash2, label: 'Delete', action: onDelete, red: true },
            ].map(item => (
              <button key={item.label} onClick={() => { setMenuOpen(false); item.action(); }} style={{
                width: '100%', display: 'flex', alignItems: 'center', gap: 8, padding: '10px 14px',
                background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left',
                color: item.red ? '#E53935' : 'var(--color-text-primary)',
                fontFamily: 'var(--font-family)', fontSize: 13,
              }}>
                <item.icon size={16} /> {item.label}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
