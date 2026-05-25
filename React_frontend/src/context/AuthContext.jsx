// ═══════════════════════════════════════════════════════════════════════════════
// AuthContext.jsx — Unified auth context (merged from both team members)
//
// Stores full member + family objects (from friend's auth screens)
// AND exposes flat fields (memberType, username, etc.) that food/task screens use.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // ── Core state (friend's approach: full objects) ────────────────────────────
  const [token, setToken]   = useState(() => localStorage.getItem('token') || null);
  const [member, setMember] = useState(() => {
    try { return JSON.parse(localStorage.getItem('member')) || null; } catch { return null; }
  });
  const [family, setFamily] = useState(() => {
    try { return JSON.parse(localStorage.getItem('family')) || null; } catch { return null; }
  });
  const [savedAccounts, setSavedAccounts] = useState(() => {
    try { return JSON.parse(localStorage.getItem('savedAccounts')) || []; } catch { return []; }
  });

  // ── isFirstLogin flat flag ──────────────────────────────────────────────────
  const [isFirstLogin, setIsFirstLogin] = useState(
    () => localStorage.getItem('isFirstLogin') === 'true'
  );

  // ── Derived flat fields (for food/task screens) ─────────────────────────────
  const memberType  = member?.member_type_id?.type || localStorage.getItem('memberType') || '';
  const username    = member?.username    || localStorage.getItem('username')    || '';
  const familyTitle = family?.Title || family?.title || localStorage.getItem('familyTitle') || '';
  const familyId    = family?._id   || localStorage.getItem('familyId')    || '';
  const memberId    = member?._id   || localStorage.getItem('memberId')    || '';
  const memberMail  = member?.mail  || localStorage.getItem('memberMail')  || '';
  const isParent    = memberType === 'Parent';
  const isLoggedIn  = !!token;

  // ── Persist to localStorage ─────────────────────────────────────────────────
  useEffect(() => {
    if (token) localStorage.setItem('token', token);
    else       localStorage.removeItem('token');
  }, [token]);

  useEffect(() => {
    if (member) {
      localStorage.setItem('member', JSON.stringify(member));
      // Keep legacy flat keys in sync so legacy screens still work
      localStorage.setItem('memberType',  member.member_type_id?.type || '');
      localStorage.setItem('username',    member.username    || '');
      localStorage.setItem('memberId',    member._id         || '');
      localStorage.setItem('memberMail',  member.mail        || '');
    } else {
      localStorage.removeItem('member');
    }
  }, [member]);

  useEffect(() => {
    if (family) {
      localStorage.setItem('family', JSON.stringify(family));
      // Keep legacy flat keys in sync
      localStorage.setItem('familyTitle', family.Title || family.title || '');
      localStorage.setItem('familyId',    family._id   || '');
    } else {
      localStorage.removeItem('family');
    }
  }, [family]);

  useEffect(() => {
    localStorage.setItem('savedAccounts', JSON.stringify(savedAccounts));
  }, [savedAccounts]);

  // ── login — called after successful API login ───────────────────────────────
  // Accepts EITHER:
  //   { token: tok, data: { member, family } }   ← friend's LoginScreen format
  //   (data, tkn)                                 ← legacy format (flat fields)
  const login = (responseDataOrData, legacyToken) => {
    // Friend's format: first arg is { token, data: { member, family } }
    if (legacyToken === undefined && responseDataOrData?.token && responseDataOrData?.data) {
      const { token: tok, data } = responseDataOrData;
      setToken(tok);
      setMember(data?.member || null);
      setFamily(data?.family || null);
      setIsFirstLogin(data?.member?.isFirstLogin || false);
      localStorage.setItem('isFirstLogin', data?.member?.isFirstLogin ? 'true' : 'false');

      if (data?.member && data?.family) {
        const account = {
          token: tok,
          member: data.member,
          family: data.family,
          key: `${data.family._id}_${data.member._id}`,
        };
        setSavedAccounts(prev => {
          const filtered = prev.filter(a => a.key !== account.key);
          return [account, ...filtered].slice(0, 10);
        });
      }
    } else {
      // Legacy format: login(data, token)
      const data = responseDataOrData;
      const tok  = legacyToken;
      localStorage.setItem('token',       tok);
      localStorage.setItem('memberType',  data.memberType  || '');
      localStorage.setItem('username',    data.username    || '');
      localStorage.setItem('familyTitle', data.familyTitle || '');
      localStorage.setItem('familyId',    data.familyId    || '');
      localStorage.setItem('memberId',    data.memberId    || '');
      localStorage.setItem('memberMail',  data.mail        || '');
      localStorage.setItem('isFirstLogin', data.isFirstLogin ? 'true' : 'false');
      setToken(tok);
      setIsFirstLogin(data.isFirstLogin || false);
      // Build minimal member/family objects from flat fields so derived values work
      setMember({
        _id: data.memberId || '',
        username: data.username || '',
        mail: data.mail || '',
        member_type_id: { type: data.memberType || '' },
      });
      setFamily({
        _id: data.familyId || '',
        Title: data.familyTitle || '',
      });
    }
  };

  // ── logout ──────────────────────────────────────────────────────────────────
  const logout = () => {
    setToken(null);
    setMember(null);
    setFamily(null);
    setIsFirstLogin(false);
    ['token','member','family','memberType','username','familyTitle',
     'familyId','memberId','memberMail','isFirstLogin']
      .forEach(k => localStorage.removeItem(k));
  };

  // ── clearFirstLogin ─────────────────────────────────────────────────────────
  function clearFirstLogin() {
    localStorage.setItem('isFirstLogin', 'false');
    setIsFirstLogin(false);
  }

  // ── switchAccount (friend's feature) ───────────────────────────────────────
  const switchAccount = (account) => {
    setToken(account.token);
    setMember(account.member);
    setFamily(account.family);
    localStorage.setItem('token', account.token);
  };

  const removeAccount = (key) => {
    setSavedAccounts(prev => prev.filter(a => a.key !== key));
  };

  // ── syncFromStorage — re-read all values from localStorage ─────────────────
  // Call this after a legacy screen writes to localStorage directly.
  function syncFromStorage() {
    const tkn = localStorage.getItem('token');
    setToken(tkn);
    try { setMember(JSON.parse(localStorage.getItem('member')) || null); } catch { /* noop */ }
    try { setFamily(JSON.parse(localStorage.getItem('family')) || null); } catch { /* noop */ }
    setIsFirstLogin(localStorage.getItem('isFirstLogin') === 'true');
  }

  return (
    <AuthContext.Provider value={{
      // Objects (friend's screens)
      token, member, family, savedAccounts, isLoggedIn,
      // Flat fields (food/task screens)
      memberType, username, familyTitle, familyId, memberId, memberMail,
      isFirstLogin, isParent,
      // Actions
      login, logout, clearFirstLogin, syncFromStorage,
      switchAccount, removeAccount,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
