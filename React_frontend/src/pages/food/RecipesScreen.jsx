// ═══════════════════════════════════════════════════════════════
// Recipes Screen — mirrors recipes_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { BookOpen, Plus, RefreshCw, Trash2, Search } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const CATEGORIES = ['Breakfast','Lunch','Dinner','Dessert','Snack','Appetizer','Main Course','Side Dish','Beverage','Other'];

const CAT_COLORS = {
  Breakfast: '#FB8C00', Lunch: 'var(--color-primary)', Dinner: '#1565C0',
  Dessert: '#E91E63', Snack: '#9C27B0', Appetizer: '#00BCD4',
  'Main Course': 'var(--color-primary)', 'Side Dish': '#795548', Beverage: '#0288D1', Other: '#607D8B',
};

export default function RecipesScreen() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const toast = useToast();

  const [loading, setLoading]     = useState(true);
  const [recipes, setRecipes]     = useState([]);
  const [search, setSearch]       = useState('');
  const [catFilter, setCatFilter] = useState('All');

  // Create recipe modal
  const [showCreate, setShowCreate]  = useState(false);
  const [newName, setNewName]        = useState('');
  const [newCat, setNewCat]          = useState('Lunch');
  const [newDesc, setNewDesc]        = useState('');
  const [newServing, setNewServing]  = useState('4');
  const [newPrepTime, setNewPrepTime] = useState('');
  const [newCookTime, setNewCookTime] = useState('');
  const [saving, setSaving]          = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.getAllRecipes();
      setRecipes(r);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const filtered = recipes.filter(r => {
    const matchesSearch = !search || r.recipe_name?.toLowerCase().includes(search.toLowerCase());
    const matchesCat = catFilter === 'All' || r.category === catFilter;
    return matchesSearch && matchesCat;
  });

  async function createRecipe() {
    if (!newName.trim()) return;
    setSaving(true);
    try {
      await api.createRecipe({
        recipe_name: newName.trim(),
        category: newCat,
        description: newDesc.trim(),
        serving_size: +(newServing || 4),
        prep_time: newPrepTime ? +newPrepTime : undefined,
        cook_time: newCookTime ? +newCookTime : undefined,
      });
      setShowCreate(false);
      setNewName(''); setNewDesc(''); setNewPrepTime(''); setNewCookTime('');
      toast('Recipe created!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  async function deleteRecipe(id, name) {
    if (!window.confirm(`Delete "${name}"?`)) return;
    try {
      await api.deleteRecipe(id);
      toast(t('recipeDeleted'));
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('allRecipes')}
        actions={
          <>
            <IconBtn icon={RefreshCw} onClick={load} />
            <IconBtn icon={Plus} onClick={() => setShowCreate(true)} />
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '12px 16px 88px' }}>
          {/* Search */}
          <div style={{ position: 'relative', marginBottom: 12 }}>
            <Search size={16} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--color-text-hint)' }} />
            <input
              value={search} onChange={e => setSearch(e.target.value)}
              placeholder="Search recipes…"
              style={{
                width: '100%', padding: '10px 12px 10px 36px',
                background: 'var(--color-white)', border: '1px solid var(--color-border)',
                borderRadius: 12, fontFamily: 'var(--font-family)', fontSize: 13,
                color: 'var(--color-text-primary)', outline: 'none', boxSizing: 'border-box',
              }}
            />
          </div>

          {/* Category filter */}
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 4, marginBottom: 16 }}>
            {['All', ...CATEGORIES].map(cat => (
              <button key={cat} onClick={() => setCatFilter(cat)} style={{
                padding: '4px 12px', flexShrink: 0,
                background: catFilter === cat ? 'var(--color-primary)' : 'var(--color-white)',
                color: catFilter === cat ? '#fff' : 'var(--color-text-secondary)',
                border: catFilter === cat ? 'none' : '1px solid var(--color-border)',
                borderRadius: 20, cursor: 'pointer',
                fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
              }}>{cat}</button>
            ))}
          </div>

          {/* Recipe cards */}
          {filtered.length === 0
            ? <EmptyState icon={BookOpen} message={t('noRecipes')} />
            : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 12 }}>
                {filtered.map(recipe => {
                  const catColor = CAT_COLORS[recipe.category] || '#607D8B';
                  return (
                    <div key={recipe._id} style={{
                      background: 'var(--color-white)', borderRadius: 16,
                      border: '1px solid var(--color-border)', overflow: 'hidden',
                      boxShadow: 'var(--shadow-card)',
                    }}>
                      {/* Color strip */}
                      <div style={{ height: 4, background: catColor }} />
                      <div style={{ padding: 14 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                          <div style={{ flex: 1, cursor: 'pointer' }} onClick={() => navigate(`/recipes/${recipe._id}`)}>
                            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>
                              {recipe.recipe_name}
                            </p>
                            <span style={{
                              display: 'inline-block', marginTop: 6,
                              background: catColor + '1A', color: catColor,
                              padding: '2px 8px', borderRadius: 8,
                              fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600,
                            }}>{recipe.category}</span>
                          </div>
                          <button onClick={() => deleteRecipe(recipe._id, recipe.recipe_name)} style={{
                            background: 'none', border: 'none', cursor: 'pointer',
                            color: '#E53935', padding: 4, flexShrink: 0,
                          }}>
                            <Trash2 size={16} />
                          </button>
                        </div>
                        {recipe.description && (
                          <p style={{
                            fontFamily: 'var(--font-family)', fontSize: 11,
                            color: 'var(--color-text-secondary)', margin: '8px 0 0',
                            overflow: 'hidden', textOverflow: 'ellipsis',
                            display: '-webkit-box', WebkitLineClamp: 2,
                            WebkitBoxOrient: 'vertical',
                          }}>{recipe.description}</p>
                        )}
                        <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                          {recipe.prep_time && (
                            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)' }}>
                              🕐 {recipe.prep_time}m prep
                            </span>
                          )}
                          {recipe.cook_time && (
                            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)' }}>
                              🔥 {recipe.cook_time}m cook
                            </span>
                          )}
                          {recipe.serving_size && (
                            <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)' }}>
                              👥 {recipe.serving_size} servings
                            </span>
                          )}
                        </div>
                        <button onClick={() => navigate(`/recipes/${recipe._id}`)} style={{
                          width: '100%', marginTop: 12, padding: '8px 0',
                          background: 'var(--color-primary-surface)',
                          border: '1px solid var(--color-border)',
                          borderRadius: 8, cursor: 'pointer',
                          fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                          color: 'var(--color-primary)',
                        }}>View Recipe →</button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )
          }
        </div>
      )}

      {/* FAB */}
      <button onClick={() => setShowCreate(true)} style={{
        position: 'fixed', bottom: 24, right: 24,
        width: 56, height: 56, borderRadius: '50%',
        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
        border: 'none', cursor: 'pointer', boxShadow: 'var(--shadow-primary)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
        zIndex: 200,
      }}>
        <Plus size={28} />
      </button>

      {/* Create Recipe Modal */}
      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title={t('addRecipe')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowCreate(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Create'} disabled={saving || !newName.trim()} onClick={createRecipe} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('recipeName')} value={newName} onChange={setNewName} required />
          <SelectField
            label={t('category')}
            value={newCat} onChange={setNewCat}
            options={CATEGORIES.map(c => ({ value: c, label: c }))}
          />
          <FormField label={t('description')} value={newDesc} onChange={setNewDesc} rows={2} />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
            <FormField label={t('servingSize')} value={newServing} onChange={setNewServing} type="number" min="1" />
            <FormField label={t('prepTime')} value={newPrepTime} onChange={setNewPrepTime} type="number" min="0" />
            <FormField label={t('cookTime')} value={newCookTime} onChange={setNewCookTime} type="number" min="0" />
          </div>
        </div>
      </Modal>
    </div>
  );
}
