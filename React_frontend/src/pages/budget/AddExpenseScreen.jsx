// ═══════════════════════════════════════════════════════════════
// AddExpenseScreen — mirrors add_expense_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useRef } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Calendar } from 'lucide-react';
import AppBar from '../../components/common/AppBar';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

// ── Helpers ────────────────────────────────────────────────────
function parseColor(hex) {
  if (!hex) return 'var(--color-primary)';
  const h = hex.replace('#', '');
  if (h.length === 6) return `#${h}`;
  return 'var(--color-primary)';
}

function Label({ text }) {
  return (
    <p style={{
      fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 700,
      letterSpacing: 0.8, color: 'var(--color-text-secondary)', margin: '0 0 6px',
    }}>{text}</p>
  );
}

function FieldContainer({ children }) {
  return (
    <div style={{
      padding: '12px', borderRadius: 11,
      border: '1px solid var(--color-border)',
      background: 'var(--color-background)',
    }}>
      {children}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════
export default function AddExpenseScreen() {
  const navigate = useNavigate();
  const location = useLocation();
  const toast = useToast();
  const { isParent } = useAuth();

  // Receive budget object from navigation state (mirrors Flutter's widget.budget)
  const budget = location.state?.budget || {};

  // ── State (mirrors Flutter state) ─────────────────────────────
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState('');
  const [expenseScope, setExpenseScope] = useState('shared');
  const [expenseDate, setExpenseDate] = useState(new Date().toISOString().split('T')[0]);
  const [isEmergency, setIsEmergency] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [receiptFile, setReceiptFile] = useState(null);
  const [receiptPreview, setReceiptPreview] = useState(null);
  const fileInputRef = useRef(null);

  // ── Derived state (mirrors Flutter _categories getter) ──────────
  const rawCategories = Array.isArray(budget.categories) ? budget.categories : [];
  const seen = new Set();
  const categories = [];
  for (const cat of rawCategories) {
    const catId = (cat._id || cat.category_id || '').toString().trim();
    if (!catId || seen.has(catId)) continue;
    seen.add(catId);
    categories.push({ ...cat, _id: catId, category_id: catId });
  }

  const emergencyTotal = +(budget.emergency_fund_amount || 0);
  const emergencySpent = +(budget.emergency_fund_spent || 0);
  const emergencyRemaining = emergencyTotal - emergencySpent;

  // ── Logic (mirrors Flutter _submit) ─────────────────────────────
  const submit = async () => {
    const amountNum = parseFloat(amount);
    if (!amountNum || amountNum <= 0) {
      toast('Please enter a valid amount', 'error');
      return;
    }
    if (expenseScope === 'shared' && !selectedCategoryId) {
      toast('Please select a category', 'error');
      return;
    }

    const title = description.trim()
      ? description.trim()
      : `${expenseScope === 'personal' ? 'Personal' : 'Shared'} expense`;

    const catObj = categories.find(c => c._id === selectedCategoryId);
    const categoryName = catObj ? (catObj.name || catObj.title || 'General') : 'General';

    setIsLoading(true);
    try {
      if (!isParent && expenseScope === 'shared') {
        // Child submitting shared expense → request
        await api.submitExpenseRequest({
          budget_id: budget._id,
          budget_category_id: selectedCategoryId || undefined,
          amount: amountNum,
          description: description.trim(),
          title,
        });
        toast('Request submitted! Waiting for parent approval.', 'info');
        navigate(-1);
      } else {
        await api.createExpense({
          budget_id: budget._id,
          budget_category_id: selectedCategoryId || undefined,
          amount: amountNum,
          expense_date: new Date(expenseDate).toISOString(),
          description: description.trim(),
          source_module: 'manual',
          expense_scope: expenseScope,
          title,
          category: categoryName,
          is_emergency: isEmergency,
        });
        toast('Expense added!', 'success');
        navigate(-1);
      }
    } catch (e) {
      toast(e.message || 'Failed to save expense', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      setReceiptFile(file);
      setReceiptPreview(URL.createObjectURL(file));
    }
  };

  // ── Format date for display ──────────────────────────────────────
  const formatDate = (dateStr) => {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Add Expense" onBack={() => navigate(-1)} />

      <div style={{
        flex: 1, maxWidth: 700, margin: '0 auto', width: '100%',
        padding: '18px 16px 32px', overflowY: 'auto',
      }}>

        {/* ── Amount ───────────────────────────────────────────────── */}
        <Label text="AMOUNT" />
        <div style={{
          padding: '12px 14px', borderRadius: 12,
          border: '2px solid var(--color-primary)',
          background: 'var(--color-background)',
          display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16,
        }}>
          <span style={{
            fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700,
            color: 'var(--color-primary)',
          }}>EGP</span>
          <input
            type="number"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder="0.00"
            style={{
              flex: 1, border: 'none', background: 'transparent', outline: 'none',
              fontFamily: 'var(--font-family)', fontSize: 20, fontWeight: 700,
              color: 'var(--color-text-primary)',
            }}
          />
        </div>

        {/* ── Expense Type ─────────────────────────────────────────── */}
        <Label text="EXPENSE TYPE" />
        <div style={{
          display: 'flex', padding: 3, borderRadius: 11,
          border: '0.8px solid var(--color-border)',
          background: '#fff', marginBottom: 16,
        }}>
          {['shared', 'personal'].map(scope => {
            const isActive = expenseScope === scope;
            return (
              <button
                key={scope}
                onClick={() => setExpenseScope(scope)}
                style={{
                  flex: 1, padding: '10px 4px', borderRadius: 9, border: 'none', cursor: 'pointer',
                  background: isActive ? 'var(--color-primary)' : 'transparent',
                  transition: 'background 0.2s',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1,
                }}
              >
                <span style={{
                  fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                  color: isActive ? '#fff' : 'var(--color-text-secondary)',
                }}>
                  {scope === 'shared' ? 'Shared' : 'Personal'}
                </span>
                <span style={{
                  fontFamily: 'var(--font-family)', fontSize: 9,
                  color: isActive ? 'rgba(255,255,255,0.75)' : 'var(--color-text-hint, #aaa)',
                }}>
                  {scope === 'shared' ? 'Family budget' : 'Member wallet'}
                </span>
              </button>
            );
          })}
        </div>

        {/* ── Category ──────────────────────────────────────────────── */}
        <Label text={expenseScope === 'shared' ? 'CATEGORY' : 'CATEGORY (OPTIONAL)'} />
        <FieldContainer>
          <select
            value={selectedCategoryId}
            onChange={e => setSelectedCategoryId(e.target.value)}
            style={{
              width: '100%', border: 'none', background: 'transparent', outline: 'none',
              fontFamily: 'var(--font-family)', fontSize: 12,
              color: selectedCategoryId ? 'var(--color-text-primary)' : 'var(--color-text-hint, #aaa)',
            }}
          >
            <option value="">
              {expenseScope === 'shared' ? 'Select category' : 'Optional'}
            </option>
            {categories.map(cat => (
              <option key={cat._id} value={cat._id}>
                {cat.name || cat.title || 'Category'}
              </option>
            ))}
          </select>
        </FieldContainer>
        <div style={{ height: 16 }} />

        {/* ── Date ─────────────────────────────────────────────────── */}
        <Label text="DATE" />
        <FieldContainer>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{
              fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)', flex: 1,
            }}>
              {formatDate(expenseDate)}
            </span>
            <Calendar size={18} color="var(--color-text-secondary)" />
            <input
              type="date"
              value={expenseDate}
              max={new Date().toISOString().split('T')[0]}
              onChange={e => setExpenseDate(e.target.value)}
              style={{
                position: 'absolute', opacity: 0, width: 30, height: 30, cursor: 'pointer',
              }}
            />
          </div>
        </FieldContainer>
        <div style={{ height: 16 }} />

        {/* ── Description ──────────────────────────────────────────── */}
        <Label text="DESCRIPTION (OPTIONAL)" />
        <div style={{
          minHeight: 70, borderRadius: 11,
          border: '1px solid var(--color-border)',
          background: 'var(--color-background)',
          padding: '10px 12px',
        }}>
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="Add a note..."
            rows={3}
            style={{
              width: '100%', border: 'none', background: 'transparent', outline: 'none', resize: 'none',
              fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-primary)',
              boxSizing: 'border-box',
            }}
          />
        </div>
        <div style={{ height: 16 }} />

        {/* ── Receipt Photo ─────────────────────────────────────────── */}
        <Label text="RECEIPT PHOTO (OPTIONAL)" />
        <div
          onClick={() => fileInputRef.current?.click()}
          style={{
            height: receiptPreview ? 160 : 72, borderRadius: 11, cursor: 'pointer',
            border: `1px solid ${receiptPreview ? 'var(--color-primary)' : 'var(--color-border)'}`,
            background: '#fff', overflow: 'hidden',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
        >
          {receiptPreview ? (
            <img src={receiptPreview} alt="receipt" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{
                width: 34, height: 34, borderRadius: 10,
                background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <span style={{ fontSize: 18 }}>📷</span>
              </div>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)' }}>
                Tap to add receipt photo
              </span>
            </div>
          )}
        </div>
        <input ref={fileInputRef} type="file" accept="image/*" onChange={handleFileChange} style={{ display: 'none' }} />
        <div style={{ height: 16 }} />

        {/* ── Emergency Fund Toggle ─────────────────────────────────── */}
        <div style={{
          padding: '12px 14px', borderRadius: 11,
          border: `1px solid ${isEmergency ? 'var(--color-primary)' : 'var(--color-border)'}`,
          background: '#fff', display: 'flex', alignItems: 'center', gap: 12,
          marginBottom: 28,
        }}>
          <div style={{
            width: 34, height: 34, borderRadius: 10,
            background: '#FFF8E1', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <span style={{ fontSize: 17 }}>⚡</span>
          </div>
          <div style={{ flex: 1 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
              Emergency Fund
            </p>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
              {isEmergency
                ? `Remaining: ${emergencyRemaining.toFixed(2)} EGP`
                : 'Deduct from category budget'}
            </p>
          </div>
          <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <div
              onClick={() => setIsEmergency(v => !v)}
              style={{
                width: 40, height: 22, borderRadius: 11, cursor: 'pointer', transition: 'background 0.2s',
                background: isEmergency ? 'var(--color-primary)' : '#ccc', position: 'relative',
              }}
            >
              <div style={{
                position: 'absolute', top: 2, left: isEmergency ? 20 : 2, width: 18, height: 18,
                borderRadius: '50%', background: '#fff', transition: 'left 0.2s',
                boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
              }} />
            </div>
          </label>
        </div>

        {/* ── Save Button ───────────────────────────────────────────── */}
        <button
          onClick={isLoading ? undefined : submit}
          style={{
            width: '100%', height: 52, borderRadius: 13, border: 'none',
            cursor: isLoading ? 'default' : 'pointer',
            background: isLoading ? 'var(--color-border)' : 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
            boxShadow: isLoading ? 'none' : 'var(--shadow-primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'background 0.2s',
          }}
        >
          {isLoading ? (
            <div style={{ width: 22, height: 22, border: '2px solid #fff', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
          ) : (
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 700, color: '#fff' }}>
              Save Expense
            </span>
          )}
        </button>
      </div>

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
