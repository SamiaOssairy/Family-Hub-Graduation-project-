// ═══════════════════════════════════════════════════════════════
// Recipe Detail Screen — mirrors recipe_detail_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Plus, Trash2, ChefHat, ListOrdered } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

export default function RecipeDetailScreen() {
  const { id } = useParams();
  const { t } = useTranslation();
  const toast = useToast();

  const [loading, setLoading]           = useState(true);
  const [recipe, setRecipe]             = useState(null);
  const [ingredients, setIngredients]   = useState([]);
  const [steps, setSteps]               = useState([]);
  const [units, setUnits]               = useState([]);
  const [servings, setServings]         = useState(null);
  const [inventoryItems, setInventoryItems] = useState([]);

  // Add ingredient modal
  const [showIngModal, setShowIngModal] = useState(false);
  const [ingName, setIngName]           = useState('');
  const [ingQty, setIngQty]             = useState('');
  const [ingUnit, setIngUnit]           = useState('');
  const [ingNotes, setIngNotes]         = useState('');

  // Add step modal
  const [showStepModal, setShowStepModal] = useState(false);
  const [stepInst, setStepInst]           = useState('');
  const [stepDuration, setStepDuration]   = useState('');
  const [stepNum, setStepNum]             = useState('');

  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [recipeData, unitData, invItems] = await Promise.all([
        api.getRecipe(id),
        api.getAllUnits().catch(() => []),
        api.getAllFamilyItems().catch(() => []),
      ]);
      const r = recipeData?.data?.recipe || recipeData?.data || recipeData;
      setRecipe(r);
      setIngredients(recipeData?.data?.ingredients || []);
      setSteps(recipeData?.data?.steps || []);
      setUnits(unitData);
      setInventoryItems(invItems);
      if (unitData.length > 0) setIngUnit(unitData[0]._id);
      setServings(r?.serving_size || 1);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { load(); }, [load]);

  async function addIngredient() {
    if (!ingName.trim()) return;
    setSaving(true);
    try {
      await api.addRecipeIngredient(id, {
        ingredient_name: ingName.trim(),
        quantity: +ingQty || 1,
        unit_id: ingUnit || undefined,
        notes: ingNotes.trim(),
      });
      setShowIngModal(false); setIngName(''); setIngQty(''); setIngNotes('');
      toast('Ingredient added!');
      load();
    } catch (e) { toast(e.message, 'error'); } finally { setSaving(false); }
  }

  async function removeIngredient(ingId) {
    try {
      await api.removeRecipeIngredient(id, ingId);
      toast('Ingredient removed');
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function addStep() {
    if (!stepInst.trim()) return;
    setSaving(true);
    try {
      await api.addRecipeStep(id, {
        instruction: stepInst.trim(),
        step_number: +stepNum || steps.length + 1,
        duration_minutes: stepDuration ? +stepDuration : undefined,
      });
      setShowStepModal(false); setStepInst(''); setStepDuration(''); setStepNum('');
      toast('Step added!');
      load();
    } catch (e) { toast(e.message, 'error'); } finally { setSaving(false); }
  }

  async function removeStep(stepId) {
    try {
      await api.removeRecipeStep(id, stepId);
      toast('Step removed');
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  const CAT_COLORS = { Breakfast:'#FB8C00', Lunch:'#00897B', Dinner:'#1565C0', Dessert:'#E91E63', Snack:'#9C27B0', Other:'#607D8B' };
  const catColor = CAT_COLORS[recipe?.category] || '#607D8B';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={recipe?.recipe_name || 'Recipe'} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '16px 16px 32px' }}>
          {/* Recipe header card */}
          <div style={{
            background: 'var(--color-white)', borderRadius: 18,
            border: `1px solid var(--color-border)`,
            overflow: 'hidden', marginBottom: 20,
            boxShadow: 'var(--shadow-card)',
          }}>
            <div style={{ height: 6, background: catColor }} />
            <div style={{ padding: 18 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
                <div>
                  <h2 style={{ fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 20, color: 'var(--color-text-primary)', margin: 0 }}>
                    {recipe?.recipe_name}
                  </h2>
                  <span style={{
                    display: 'inline-block', marginTop: 6,
                    background: catColor + '1A', color: catColor,
                    padding: '3px 10px', borderRadius: 8,
                    fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
                  }}>{recipe?.category}</span>
                </div>
              </div>
              {recipe?.description && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-secondary)', marginTop: 10, lineHeight: 1.5 }}>
                  {recipe.description}
                </p>
              )}
              <div style={{ display: 'flex', gap: 16, marginTop: 12, flexWrap: 'wrap' }}>
                {recipe?.serving_size && <InfoChip label="Servings" value={recipe.serving_size} emoji="👥" />}
                {recipe?.prep_time && <InfoChip label="Prep" value={`${recipe.prep_time}m`} emoji="🕐" />}
                {recipe?.cook_time && <InfoChip label="Cook" value={`${recipe.cook_time}m`} emoji="🔥" />}
              </div>
            </div>
          </div>

          {/* Ingredients */}
          <SectionCard
            title={t('ingredients')}
            icon={ChefHat}
            iconColor={catColor}
            count={ingredients.length}
            onAdd={() => setShowIngModal(true)}
          >
            {ingredients.length === 0 ? (
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-hint)', textAlign: 'center', padding: '12px 0' }}>
                No ingredients yet. Add some!
              </p>
            ) : ingredients.map(ing => (
              <div key={ing._id} style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                padding: '10px 0', borderBottom: '1px solid var(--color-border-light)',
              }}>
                <div>
                  <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                    {ing.ingredient_name}
                  </p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                    {ing.quantity} {ing.unit_id?.unit_name || ''}{ing.notes ? ` — ${ing.notes}` : ''}
                  </p>
                </div>
                <button onClick={() => removeIngredient(ing._id)} style={{
                  background: 'none', border: 'none', cursor: 'pointer', color: '#E53935', padding: 4,
                }}>
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </SectionCard>

          {/* Steps */}
          <SectionCard
            title={t('steps')}
            icon={ListOrdered}
            iconColor="#FB8C00"
            count={steps.length}
            onAdd={() => setShowStepModal(true)}
          >
            {steps.length === 0 ? (
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-hint)', textAlign: 'center', padding: '12px 0' }}>
                No steps yet. Add some!
              </p>
            ) : [...steps].sort((a, b) => (a.step_number || 0) - (b.step_number || 0)).map((step, i) => (
              <div key={step._id} style={{
                display: 'flex', gap: 12, alignItems: 'flex-start',
                padding: '12px 0', borderBottom: '1px solid var(--color-border-light)',
              }}>
                <div style={{
                  width: 28, height: 28, borderRadius: '50%',
                  background: 'var(--color-primary-surface)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                }}>
                  <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 11, color: 'var(--color-primary)' }}>
                    {step.step_number || i + 1}
                  </span>
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)', margin: 0, lineHeight: 1.5 }}>
                    {step.instruction}
                  </p>
                  {step.duration_minutes && (
                    <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)', margin: '3px 0 0' }}>
                      ⏱ {step.duration_minutes} min
                    </p>
                  )}
                </div>
                <button onClick={() => removeStep(step._id)} style={{
                  background: 'none', border: 'none', cursor: 'pointer', color: '#E53935', padding: 4,
                }}>
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </SectionCard>
        </div>
      )}

      {/* Add Ingredient Modal */}
      <Modal
        open={showIngModal}
        onClose={() => setShowIngModal(false)}
        title={t('addIngredient')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowIngModal(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Add'} disabled={saving || !ingName.trim()} onClick={addIngredient} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('ingredient')} value={ingName} onChange={setIngName} required />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <FormField label={t('quantity')} value={ingQty} onChange={setIngQty} type="number" min="0" step="0.01" />
            {units.length > 0 && (
              <SelectField
                label={t('unit')}
                value={ingUnit} onChange={setIngUnit}
                options={units.map(u => ({ value: u._id, label: u.unit_name }))}
              />
            )}
          </div>
          <FormField label={t('notes')} value={ingNotes} onChange={setIngNotes} />
        </div>
      </Modal>

      {/* Add Step Modal */}
      <Modal
        open={showStepModal}
        onClose={() => setShowStepModal(false)}
        title={t('addStep')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowStepModal(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Add'} disabled={saving || !stepInst.trim()} onClick={addStep} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <FormField label="Step Number" value={stepNum} onChange={setStepNum} type="number" min="1" />
            <FormField label={t('duration')} value={stepDuration} onChange={setStepDuration} type="number" min="0" />
          </div>
          <FormField label={t('stepInstruction')} value={stepInst} onChange={setStepInst} rows={3} required />
        </div>
      </Modal>
    </div>
  );
}

function InfoChip({ label, value, emoji }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 4,
      background: 'var(--color-primary-surface)', borderRadius: 8,
      padding: '4px 10px',
    }}>
      <span style={{ fontSize: 14 }}>{emoji}</span>
      <div>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)', margin: 0 }}>{label}</p>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0 }}>{value}</p>
      </div>
    </div>
  );
}

function SectionCard({ title, icon: Icon, iconColor, count, onAdd, children }) {
  return (
    <div style={{
      background: 'var(--color-white)', borderRadius: 16,
      border: '1px solid var(--color-border)',
      padding: 16, marginBottom: 16,
      boxShadow: 'var(--shadow-card)',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 8,
            background: iconColor + '1A',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon size={18} color={iconColor} />
          </div>
          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)' }}>
            {title}
          </span>
          {count > 0 && (
            <span style={{
              background: 'var(--color-primary-surface)', color: 'var(--color-primary)',
              padding: '1px 7px', borderRadius: 10,
              fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700,
            }}>{count}</span>
          )}
        </div>
        <button onClick={onAdd} style={{
          display: 'flex', alignItems: 'center', gap: 4,
          background: 'var(--color-primary)', color: '#fff',
          border: 'none', borderRadius: 8, padding: '5px 10px',
          fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, cursor: 'pointer',
        }}>
          <Plus size={13} /> Add
        </button>
      </div>
      {children}
    </div>
  );
}
