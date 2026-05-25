// ═══════════════════════════════════════════════════════════════
// Meal Suggestions Screen — mirrors meal_suggestions_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { Sparkles, Trash2, CalendarDays } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import Modal, { ModalCancelBtn, DangerBtn } from '../../components/common/Modal';
import { useToast } from '../../components/common/Toast';
import { useNavigate } from 'react-router-dom';
import * as api from '../../api/apiService';

const MEAL_TYPE_OPTIONS = [
  { label: 'Breakfast', emoji: '🌅', color: '#FB8C00', subtitle: 'Morning recipes' },
  { label: 'Lunch',     emoji: '☀️', color: '#00897B', subtitle: 'Midday meals' },
  { label: 'Dinner',    emoji: '🌙', color: '#1565C0', subtitle: 'Evening dishes' },
  { label: 'Snack',     emoji: '🍿', color: '#E91E63', subtitle: 'Light bites' },
  { label: 'Any',       emoji: '✨', color: '#7B1FA2', subtitle: 'All categories' },
];

export default function MealSuggestionsScreen() {
  const toast = useToast();
  const navigate = useNavigate();

  const [suggestions, setSuggestions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [lastMealType, setLastMealType] = useState(null);
  const [showPicker, setShowPicker] = useState(false);
  const [pickerSelected, setPickerSelected] = useState('Any');
  const [showClearConfirm, setShowClearConfirm] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const s = await api.getMealSuggestions();
      setSuggestions(s);
      if (s.length > 0) setLastMealType(s[0].meal_type || null);
    } catch (e) { toast(e.message, 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function generate(mealType) {
    setGenerating(true); setLastMealType(mealType); setShowPicker(false);
    try {
      const result = await api.generateMealSuggestions(mealType);
      const raw = result?.data?.suggestions || result?.suggestions || [];
      setSuggestions(Array.isArray(raw) ? raw : []);
      toast(`Generated ${(Array.isArray(raw) ? raw : []).length} suggestions for ${mealType === 'Any' ? 'all categories' : mealType}!`);
    } catch (e) { toast(e.message, 'error'); }
    finally { setGenerating(false); }
  }

  async function clearAll() {
    try {
      await api.clearMealSuggestions();
      setSuggestions([]); setLastMealType(null); setShowClearConfirm(false);
    } catch (e) { toast(e.message, 'error'); }
  }

  const opt = (type) => MEAL_TYPE_OPTIONS.find(o => o.label === type) || MEAL_TYPE_OPTIONS[MEAL_TYPE_OPTIONS.length - 1];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title="Meal Suggestions"
        actions={suggestions.length > 0 && <IconBtn icon={Trash2} onClick={() => setShowClearConfirm(true)} />}
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '8px 16px 32px' }}>

          {/* Generate button */}
          <button onClick={() => { setPickerSelected(lastMealType || 'Any'); setShowPicker(true); }}
            disabled={generating}
            style={{
              width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
              background: generating ? '#5BA89E' : 'var(--color-primary)',
              color: '#fff', border: 'none', borderRadius: 14, padding: '14px 20px',
              fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, cursor: generating ? 'not-allowed' : 'pointer',
              marginBottom: 12,
            }}>
            <Sparkles size={20} />
            {generating ? 'Generating…' : 'Generate Smart Suggestions'}
          </button>

          {/* Last type chip */}
          {lastMealType && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 6,
                padding: '5px 12px', borderRadius: 20,
                background: opt(lastMealType).color + '1F',
                border: `1px solid ${opt(lastMealType).color}4D`,
                fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: opt(lastMealType).color,
              }}>
                {opt(lastMealType).emoji} {lastMealType} suggestions
              </span>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-hint)' }}>
                {suggestions.length} found
              </span>
            </div>
          )}

          {/* Suggestions list or empty state */}
          {suggestions.length === 0 ? (
            <EmptyMealState onQuickGen={(t) => generate(t)} />
          ) : (
            suggestions.map((s, i) => <SuggestionCard key={i} s={s} navigate={navigate} />)
          )}
        </div>
      )}

      {/* Meal type picker modal */}
      {showPicker && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', zIndex: 300, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
          onClick={() => setShowPicker(false)}>
          <div style={{ background: 'var(--color-white)', borderRadius: '24px 24px 0 0', width: '100%', maxWidth: 600, padding: '12px 20px 32px' }}
            onClick={e => e.stopPropagation()}>
            <div style={{ width: 40, height: 4, background: '#ccc', borderRadius: 2, margin: '0 auto 20px' }} />
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: 'var(--color-text-primary)', textAlign: 'center', margin: 0 }}>
              What meal are you planning?
            </p>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-secondary)', textAlign: 'center', margin: '6px 0 20px' }}>
              We'll suggest recipes that match your inventory
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 }}>
              {MEAL_TYPE_OPTIONS.map(option => {
                const sel = pickerSelected === option.label;
                return (
                  <button key={option.label} onClick={() => setPickerSelected(option.label)} style={{
                    display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px',
                    background: sel ? option.color + '26' : '#f5f5f5',
                    border: `2px solid ${sel ? option.color : 'transparent'}`,
                    borderRadius: 14, cursor: 'pointer',
                  }}>
                    <span style={{ fontSize: 20 }}>{option.emoji}</span>
                    <div style={{ textAlign: 'left' }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: sel ? option.color : 'var(--color-text-primary)', margin: 0 }}>
                        {option.label}
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#999', margin: 0 }}>{option.subtitle}</p>
                    </div>
                  </button>
                );
              })}
            </div>
            <button onClick={() => generate(pickerSelected)} style={{
              width: '100%', background: 'var(--color-primary)', color: '#fff',
              border: 'none', borderRadius: 14, padding: '14px 0', cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            }}>
              <Sparkles size={18} /> Find Suggestions
            </button>
          </div>
        </div>
      )}

      {/* Clear confirm */}
      <Modal open={showClearConfirm} onClose={() => setShowClearConfirm(false)} title="Clear Suggestions"
        actions={<><ModalCancelBtn onClick={() => setShowClearConfirm(false)} /><DangerBtn label="Clear" onClick={clearAll} /></>}>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)' }}>Remove all current suggestions?</p>
      </Modal>
    </div>
  );
}

function EmptyMealState({ onQuickGen }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '40px 20px' }}>
      <div style={{ padding: 28, background: 'var(--color-primary-surface)', borderRadius: '50%', marginBottom: 20 }}>
        <span style={{ fontSize: 52 }}>🍽️</span>
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: 'var(--color-text-primary)', margin: 0 }}>No Suggestions Yet</p>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: '#999', textAlign: 'center', lineHeight: 1.6, margin: '10px 0 28px', maxWidth: 300 }}>
        Tap "Generate Smart Suggestions" to choose a meal type and get recipe ideas based on what's in your inventory and leftovers.
      </p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
        {MEAL_TYPE_OPTIONS.map(opt => (
          <button key={opt.label} onClick={() => onQuickGen(opt.label)} style={{
            display: 'flex', alignItems: 'center', gap: 6, padding: '8px 14px',
            background: opt.color + '1A', border: `1px solid ${opt.color}4D`,
            borderRadius: 20, cursor: 'pointer',
            fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: opt.color,
          }}>
            {opt.emoji} {opt.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function SuggestionCard({ s, navigate }) {
  const recipeObj = s.recipe_id;
  const recipeName = recipeObj?.recipe_name || recipeObj?.title || 'Unnamed Recipe';
  const recipeCategory = recipeObj?.category || '';
  const matchPct = +(s.match_percentage || 0);
  const mealType = s.meal_type || recipeCategory;
  const usesExpiring = s.uses_expiring_items === true;
  const usesLeftovers = s.uses_leftovers === true;
  const missingRaw = s.missing_ingredients || [];
  const availableRaw = s.available_ingredients || [];

  const MEAL_TYPE_OPTIONS = [
    { label: 'Breakfast', emoji: '🌅', color: '#FB8C00' },
    { label: 'Lunch',     emoji: '☀️', color: '#00897B' },
    { label: 'Dinner',    emoji: '🌙', color: '#1565C0' },
    { label: 'Snack',     emoji: '🍿', color: '#E91E63' },
    { label: 'Any',       emoji: '✨', color: '#7B1FA2' },
  ];
  const opt = MEAL_TYPE_OPTIONS.find(o => o.label === mealType) || MEAL_TYPE_OPTIONS[MEAL_TYPE_OPTIONS.length - 1];
  const matchColor = matchPct >= 80 ? '#00897B' : matchPct >= 50 ? '#FB8C00' : '#E53935';

  return (
    <div style={{
      background: 'var(--color-white)', borderRadius: 18,
      marginBottom: 14, boxShadow: 'var(--shadow-card)', overflow: 'hidden',
    }}>
      {/* Banner */}
      <div style={{ padding: '14px 16px', background: `linear-gradient(135deg, ${opt.color}26, ${opt.color}0D)` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ padding: 10, background: opt.color + '26', borderRadius: 12, flexShrink: 0 }}>
            <span style={{ fontSize: 22 }}>{opt.emoji}</span>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-text-primary)', margin: 0 }}>{recipeName}</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 4 }}>
              {mealType && (
                <span style={{ background: opt.color + '26', color: opt.color, padding: '2px 8px', borderRadius: 6, fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600 }}>
                  {mealType}
                </span>
              )}
              {usesExpiring && (
                <span style={{ background: '#FFEBEE', color: '#E53935', padding: '2px 6px', borderRadius: 6, fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600 }}>
                  ⚡ Expiring
                </span>
              )}
              {usesLeftovers && (
                <span style={{ background: '#FFF3E0', color: '#FB8C00', padding: '2px 6px', borderRadius: 6, fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600 }}>
                  ♻️ Leftovers
                </span>
              )}
            </div>
          </div>
          {/* Match ring */}
          <div style={{ width: 54, height: 54, flexShrink: 0, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="54" height="54" style={{ position: 'absolute', top: 0, left: 0, transform: 'rotate(-90deg)' }}>
              <circle cx="27" cy="27" r="22" fill="none" stroke={matchColor + '26'} strokeWidth="5" />
              <circle cx="27" cy="27" r="22" fill="none" stroke={matchColor} strokeWidth="5"
                strokeDasharray={`${2 * Math.PI * 22}`}
                strokeDashoffset={`${2 * Math.PI * 22 * (1 - matchPct / 100)}`}
                strokeLinecap="round"
              />
            </svg>
            <div style={{ textAlign: 'center', zIndex: 1 }}>
              <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 11, color: matchColor, margin: 0 }}>{Math.round(matchPct)}%</p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 7, color: '#999', margin: 0 }}>match</p>
            </div>
          </div>
        </div>
      </div>

      {/* Body */}
      <div style={{ padding: '12px 16px 16px' }}>
        {availableRaw.length > 0 && (
          <>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: '#00897B', marginBottom: 6 }}>✅ Available in your kitchen</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 10 }}>
              {availableRaw.map((name, i) => (
                <span key={i} style={{ background: 'var(--color-primary-surface)', color: 'var(--color-primary)', padding: '4px 8px', borderRadius: 8, fontFamily: 'var(--font-family)', fontSize: 11 }}>
                  ✓ {name}
                </span>
              ))}
            </div>
          </>
        )}
        {missingRaw.length > 0 && (
          <>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: '#E53935', marginBottom: 6 }}>❌ Still needed</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 10 }}>
              {missingRaw.map((ing, i) => {
                const name = typeof ing === 'string' ? ing : (ing.ingredient_name || ing.name || '?');
                const qty = typeof ing === 'object' ? ing.quantity : null;
                const unit = typeof ing === 'object' ? (ing.unit_name || '') : '';
                const label = qty != null ? `${name} (${qty}${unit ? ' ' + unit : ''})` : name;
                return (
                  <span key={i} style={{ background: '#FFEBEE', color: '#E53935', padding: '4px 8px', borderRadius: 8, fontFamily: 'var(--font-family)', fontSize: 11 }}>
                    🛒 {label}
                  </span>
                );
              })}
            </div>
          </>
        )}
        {availableRaw.length === 0 && missingRaw.length === 0 && (
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: '#00897B', fontWeight: 500, marginBottom: 10 }}>All ingredients ready!</p>
        )}

        <button onClick={() => navigate('/meals')} style={{
          width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          background: 'none', border: '1px solid var(--color-primary)', borderRadius: 10, padding: '10px 0', cursor: 'pointer',
          fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-primary)',
        }}>
          <CalendarDays size={15} /> Plan This Meal
        </button>
      </div>
    </div>
  );
}
