// ═══════════════════════════════════════════════════════════════
// ManageAccountsPage — mirrors manage_accounts_page.dart
// Shows saved accounts from localStorage, allows switching and
// removing accounts (no backend calls needed — all via AuthContext).
// ═══════════════════════════════════════════════════════════════
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeftRight, Trash2, CheckCircle } from 'lucide-react';
import AppBar from '../components/common/AppBar';
import { useAuth } from '../context/AuthContext';

// ── Avatar helper ─────────────────────────────────────────────
function AccountAvatar({ name }) {
  const letter = (name || 'A')[0].toUpperCase();
  return (
    <div style={{
      width: 42, height: 42, borderRadius: '50%',
      background: 'var(--color-primary-surface)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexShrink: 0,
    }}>
      <span style={{
        fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700,
        color: 'var(--color-primary)',
      }}>{letter}</span>
    </div>
  );
}

// ── Confirm Dialog ────────────────────────────────────────────
function ConfirmDialog({ open, title, message, onConfirm, onCancel }) {
  if (!open) return null;
  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 1000,
      background: 'rgba(0,0,0,0.4)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 24,
    }}>
      <div style={{
        background: 'var(--color-white)',
        borderRadius: 18, padding: 24,
        maxWidth: 380, width: '100%',
        boxShadow: '0 8px 32px rgba(0,0,0,0.18)',
      }}>
        <h3 style={{ fontFamily: 'var(--font-family)', fontWeight: 700, margin: '0 0 8px', color: 'var(--color-text-primary)' }}>
          {title}
        </h3>
        <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-secondary)', margin: '0 0 20px' }}>
          {message}
        </p>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button
            onClick={onCancel}
            style={{
              padding: '9px 18px', borderRadius: 10,
              border: '1px solid var(--color-border)',
              background: 'none', cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 13,
              color: 'var(--color-text-secondary)',
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            style={{
              padding: '9px 18px', borderRadius: 10,
              border: 'none', background: '#E53935',
              cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 13,
              fontWeight: 600, color: '#fff',
            }}
          >
            Remove
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
export default function ManageAccountsPage() {
  const navigate = useNavigate();
  const { savedAccounts, token, switchAccount, removeAccount } = useAuth();

  // Find which account is currently active by matching token
  const activeKey = savedAccounts.find(a => a.token === token)?.key || '';

  // Dialog state
  const [confirmKey,     setConfirmKey]     = useState(null);
  const [confirmTitle,   setConfirmTitle]   = useState('');
  const [confirmMessage, setConfirmMessage] = useState('');

  // ── Switch account ───────────────────────────────────────────
  function handleSwitch(account) {
    if (account.key === activeKey) return;
    switchAccount(account);
    navigate('/home');
  }

  // ── Remove account ───────────────────────────────────────────
  function askRemove(account) {
    const familyTitle = account.family?.Title || account.family?.title || 'Family';
    const username    = account.member?.username || 'Member';
    setConfirmKey(account.key);
    setConfirmTitle('Remove account?');
    setConfirmMessage(`Remove ${familyTitle} (${username}) from this device?`);
  }

  function handleConfirmRemove() {
    if (confirmKey) removeAccount(confirmKey);
    setConfirmKey(null);
  }

  // ─────────────────────────────────────────────────────────────
  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title="Manage Accounts" />

      <div style={{ flex: 1, padding: 16, maxWidth: 600, margin: '0 auto', width: '100%' }}>
        {savedAccounts.length === 0 ? (
          <div style={{
            textAlign: 'center', marginTop: 60,
            fontFamily: 'var(--font-family)', color: 'var(--color-text-secondary)',
          }}>
            No saved accounts
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {savedAccounts.map((account, idx) => {
              const familyTitle = account.family?.Title || account.family?.title || 'Family';
              const username    = account.member?.username || 'Member';
              const mail        = account.member?.mail || '';
              const isActive    = account.key === activeKey;

              return (
                <div
                  key={account.key || idx}
                  style={{
                    background: 'var(--color-white)',
                    borderRadius: 14,
                    border: `${isActive ? 2 : 1}px solid ${isActive ? 'var(--color-primary)' : 'var(--color-border)'}`,
                    padding: '12px 14px',
                    display: 'flex', alignItems: 'center', gap: 12,
                    boxShadow: 'var(--shadow-card)',
                  }}
                >
                  {/* Avatar */}
                  <AccountAvatar name={username} />

                  {/* Info */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{
                      fontFamily: 'var(--font-family)', fontWeight: 600,
                      fontSize: 13, color: 'var(--color-text-primary)',
                      margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>
                      {familyTitle} ({username})
                    </p>
                    <p style={{
                      fontFamily: 'var(--font-family)', fontSize: 11,
                      color: 'var(--color-text-secondary)', margin: '2px 0 0',
                      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>
                      {mail}
                    </p>
                  </div>

                  {/* Active checkmark */}
                  {isActive && (
                    <CheckCircle size={20} color="var(--color-primary)" style={{ flexShrink: 0 }} />
                  )}

                  {/* Switch button */}
                  <button
                    onClick={() => handleSwitch(account)}
                    disabled={isActive}
                    title={isActive ? 'Already active' : 'Switch account'}
                    style={{
                      background: 'none', border: 'none',
                      width: 36, height: 36, borderRadius: '50%',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      cursor: isActive ? 'default' : 'pointer',
                      color: isActive ? 'var(--color-border)' : 'var(--color-primary)',
                      flexShrink: 0,
                    }}
                  >
                    <ArrowLeftRight size={18} />
                  </button>

                  {/* Remove button */}
                  <button
                    onClick={() => askRemove(account)}
                    title="Remove account"
                    style={{
                      background: 'none', border: 'none',
                      width: 36, height: 36, borderRadius: '50%',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      cursor: 'pointer', color: '#E53935', flexShrink: 0,
                    }}
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Remove confirm dialog */}
      <ConfirmDialog
        open={!!confirmKey}
        title={confirmTitle}
        message={confirmMessage}
        onConfirm={handleConfirmRemove}
        onCancel={() => setConfirmKey(null)}
      />
    </div>
  );
}
