import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';
import './AuthScreens.css';

// ─── Icons ───────────────────────────────────────────────────────────────────
const EmailIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
    <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/>
  </svg>
);
const LockIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
    <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/>
  </svg>
);
const EyeIcon = ({ open }) => open ? (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
  </svg>
) : (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75-1.73-4.39-6-7.5-11-7.5-1.4 0-2.74.25-3.98.7l2.16 2.16C10.74 7.13 11.35 7 12 7zM2 4.27l2.28 2.28.46.46C3.08 8.3 1.78 10.02 1 12c1.73 4.39 6 7.5 11 7.5 1.55 0 3.03-.3 4.38-.84l.42.42L19.73 22 21 20.73 3.27 3 2 4.27zM7.53 9.8l1.55 1.55c-.05.21-.08.43-.08.65 0 1.66 1.34 3 3 3 .22 0 .44-.03.65-.08l1.55 1.55c-.67.33-1.41.53-2.2.53-2.76 0-5-2.24-5-5 0-.79.2-1.53.53-2.2zm4.31-.78l3.15 3.15.02-.16c0-1.66-1.34-3-3-3l-.17.01z"/>
  </svg>
);
const FamilyIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
    <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
  </svg>
);

// ─── Saved accounts sheet (long-press the logo, like Flutter / Instagram) ─────
function SavedAccountsSheet({ accounts, onPick, onClose }) {
  return (
    <div
      style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000,
        display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div style={{ background: '#fff', borderRadius: '20px 20px 0 0', padding: '16px 20px 28px',
        maxHeight: '60vh', overflowY: 'auto' }}>
        <div style={{ width: 40, height: 4, borderRadius: 2, background: '#ccc', margin: '0 auto 14px' }} />
        <h3 style={{ margin: '0 0 14px', fontSize: 17 }}>Saved accounts</h3>
        {accounts.length === 0 ? (
          <p style={{ color: '#888', fontSize: 13 }}>
            No saved accounts yet. Accounts you log into on this device will appear here.
          </p>
        ) : accounts.map((acc) => {
          const famName = acc.family?.Title || acc.family?.title || 'Family';
          const userName = acc.member?.username || acc.member?.mail || 'Member';
          return (
            <button
              key={acc.key}
              onClick={() => onPick(acc)}
              style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%',
                padding: '10px 12px', marginBottom: 8, borderRadius: 12, cursor: 'pointer',
                border: '1px solid var(--border)', background: '#F8FDFC', textAlign: 'left' }}
            >
              <div style={{ width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
                background: 'var(--primary-surface)', display: 'flex',
                alignItems: 'center', justifyContent: 'center',
                color: 'var(--primary)', fontWeight: 700, fontSize: 16 }}>
                {userName[0]?.toUpperCase() || 'A'}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
                <span style={{ fontWeight: 600, fontSize: 14, color: 'var(--text-primary)',
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{userName}</span>
                <span style={{ fontSize: 12, color: '#888' }}>{famName} · {acc.member?.mail}</span>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─── Step 1: Enter Email ──────────────────────────────────────────────────────
function StepEmail({ onNext, onGoSignup }) {
  const [email,   setEmail]   = useState('');
  const [error,   setError]   = useState('');
  const [loading, setLoading] = useState(false);
  const [showAccounts, setShowAccounts] = useState(false);
  const { savedAccounts, switchAccount } = useAuth();
  const navigate = useNavigate();
  const pressTimer = React.useRef(null);

  // Long-press (600ms) on the logo opens the saved-accounts sheet — parity with Flutter
  const startPress = () => {
    pressTimer.current = setTimeout(() => setShowAccounts(true), 600);
  };
  const cancelPress = () => {
    if (pressTimer.current) { clearTimeout(pressTimer.current); pressTimer.current = null; }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) { setError('Please enter your email'); return; }
    setError('');
    setLoading(true);
    try {
      const families = await authAPI.getFamiliesByEmail(normalizedEmail);
      if (!families.length) { setError('No family account found for this email'); return; }
      onNext({ email: normalizedEmail, families });
    } catch (err) {
      setError(err.response?.data?.message || 'Could not find families. Check your email.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        {/* Logo — long-press to show saved accounts */}
        <div
          className="auth-logo-circle"
          onMouseDown={startPress}
          onMouseUp={cancelPress}
          onMouseLeave={cancelPress}
          onTouchStart={startPress}
          onTouchEnd={cancelPress}
          onTouchMove={cancelPress}
          onContextMenu={(e) => e.preventDefault()}
          style={{ cursor: 'pointer', WebkitTouchCallout: 'none', userSelect: 'none', WebkitUserSelect: 'none' }}
          title="Hold to show saved accounts"
        >
          <FamilyIcon />
        </div>
        {savedAccounts.length > 0 && (
          <p style={{
            textAlign: 'center', fontSize: 10.5, color: 'var(--text-hint)',
            margin: '6px 0 0', fontFamily: 'Poppins, sans-serif',
          }}>
            Hold the logo to switch account
          </p>
        )}

        <h1 className="auth-heading">Welcome Back!</h1>
        <p className="auth-subheading">Enter your email to find your family</p>

        {error && <div className="error-box">{error}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="input-wrapper">
            <span className="input-icon"><EmailIcon /></span>
            <input
              className="field-input"
              type="email"
              placeholder="Email address"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              autoFocus
            />
          </div>

          <button className="btn-primary" type="submit" disabled={loading}>
            {loading ? 'Searching...' : 'Find My Families →'}
          </button>
        </form>

        <p className="auth-switch-text">
          Don't have an account?{' '}
          <button onClick={onGoSignup}>Sign up</button>
        </p>
      </div>

      {showAccounts && (
        <SavedAccountsSheet
          accounts={savedAccounts}
          onClose={() => setShowAccounts(false)}
          onPick={(acc) => {
            switchAccount(acc);
            navigate('/home', { replace: true });
          }}
        />
      )}
    </div>
  );
}

// ─── Step 2: Pick a Family ────────────────────────────────────────────────────
function StepPickFamily({ email, families, onNext, onBack }) {
  const [selected, setSelected] = useState(null);
  const [error, setError] = useState('');

  const handleContinue = () => {
    if (!selected) { setError('Please select a family'); return; }
    onNext({ selectedFamily: selected });
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <button className="auth-back-btn" onClick={onBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/>
          </svg>
        </button>

        <div className="auth-logo-circle">
          <FamilyIcon />
        </div>

        <h1 className="auth-heading">Choose Family</h1>
        <p className="auth-subheading">{email}</p>

        {error && <div className="error-box">{error}</div>}

        <div className="family-list">
          {families.map((fam) => {
            const famId = fam.family_id || fam._id;
            const famName = fam.familyTitle || fam.Title || fam.title || 'Family';
            const isSelected = (selected?.family_id || selected?._id) === famId;
            return (
              <button
                key={famId}
                className={`family-card ${isSelected ? 'selected' : ''}`}
                onClick={() => { setSelected(fam); setError(''); }}
              >
                <div className="family-avatar">
                  {famName[0].toUpperCase()}
                </div>
                <div className="family-info">
                  <span className="family-name">{famName}</span>
                  <span className="family-email">{email}</span>
                </div>
                {isSelected && (
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="var(--primary)">
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/>
                  </svg>
                )}
              </button>
            );
          })}
        </div>

        <button className="btn-primary" onClick={handleContinue}>
          Continue →
        </button>
      </div>
    </div>
  );
}

// ─── Step 3: Enter Password ───────────────────────────────────────────────────
function StepPassword({ email, family, onBack, onSuccess }) {
  const [password,     setPassword]     = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error,        setError]        = useState('');
  const [loading,      setLoading]      = useState(false);
  const [firstLogin,   setFirstLogin]   = useState(false);
  const [resetMsg,     setResetMsg]     = useState('');
  const [resetLoading, setResetLoading] = useState(false);
  const { login } = useAuth();

  const handleForgotPassword = async () => {
    setError(''); setResetMsg(''); setResetLoading(true);
    try {
      await authAPI.forgotPassword(email);
      setResetMsg('A password reset link was sent to the family account email.');
    } catch (err) {
      setError(err.response?.data?.message || 'Could not send the reset email. Please try again.');
    } finally {
      setResetLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!password) { setError('Please enter your password'); return; }
    setError('');
    setLoading(true);
    try {
      const data = await authAPI.login({ mail: email, password, family_id: family.family_id || family._id });
      login(data);
      // First-time members log in with the family/parent password, then must set their own.
      if (data?.data?.isFirstLogin) {
        setFirstLogin(true);
      } else {
        onSuccess();
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Incorrect password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <button className="auth-back-btn" onClick={onBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/>
          </svg>
        </button>

        <div className="auth-logo-circle">
          <div className="family-initial-big">
            {(family.Title || family.title || 'F')[0].toUpperCase()}
          </div>
        </div>

        <h1 className="auth-heading">{family.familyTitle || family.Title || family.title || 'Family'}</h1>
        <p className="auth-subheading">{email}</p>

        {error && <div className="error-box">{error}</div>}
        {resetMsg && (
          <div className="error-box" style={{ background: '#EAF7F0', borderColor: '#BFE5D2', color: '#1E7D4F' }}>
            {resetMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="input-wrapper">
            <span className="input-icon"><LockIcon /></span>
            <input
              className="field-input"
              type={showPassword ? 'text' : 'password'}
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoFocus
            />
            <button
              type="button"
              className="input-suffix"
              onClick={() => setShowPassword(!showPassword)}
            >
              <EyeIcon open={showPassword} />
            </button>
          </div>

          <div style={{ textAlign: 'right', marginTop: -4 }}>
            <button
              type="button"
              onClick={handleForgotPassword}
              disabled={resetLoading}
              style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4,
                color: 'var(--primary)', fontSize: 13, fontWeight: 600,
                fontFamily: 'Poppins, sans-serif' }}
            >
              {resetLoading ? 'Sending…' : 'Forgot password?'}
            </button>
          </div>

          <button className="btn-primary" type="submit" disabled={loading}>
            {loading ? 'Logging in...' : 'Log In'}
          </button>
        </form>

        <p className="auth-switch-text" style={{ color: 'var(--text-hint)', fontSize: 12 }}>
          Your password is securely encrypted
        </p>
      </div>

      {firstLogin && <FirstLoginPasswordModal onDone={onSuccess} />}
    </div>
  );
}

// ─── First-login: force the member to set their own password ──────────────────
function FirstLoginPasswordModal({ onDone }) {
  const [pw,      setPw]      = useState('');
  const [confirm, setConfirm] = useState('');
  const [show,    setShow]    = useState(false);
  const [error,   setError]   = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    if (!pw || !confirm) { setError('Please fill in both fields'); return; }
    if (pw !== confirm)  { setError('Passwords do not match'); return; }
    setError(''); setLoading(true);
    try {
      await authAPI.setPassword({ newPassword: pw, confirmPassword: confirm });
      onDone();
    } catch (err) {
      setError(err.response?.data?.message || 'Could not set your password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 20 }}>
      <div className="auth-card" style={{ maxWidth: 400, width: '100%' }}>
        <h1 className="auth-heading">Set Your Password</h1>
        <p className="auth-subheading">Welcome! Create your own password to finish setting up your account.</p>

        {error && <div className="error-box">{error}</div>}

        <form onSubmit={submit} className="auth-form">
          <div className="input-wrapper">
            <span className="input-icon"><LockIcon /></span>
            <input
              className="field-input"
              type={show ? 'text' : 'password'}
              placeholder="New password"
              value={pw}
              onChange={(e) => setPw(e.target.value)}
              autoFocus
            />
            <button type="button" className="input-suffix" onClick={() => setShow(!show)}>
              <EyeIcon open={show} />
            </button>
          </div>

          <div className="input-wrapper">
            <span className="input-icon"><LockIcon /></span>
            <input
              className="field-input"
              type={show ? 'text' : 'password'}
              placeholder="Confirm password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
            />
          </div>

          <p className="auth-switch-text" style={{ color: 'var(--text-hint)', fontSize: 11, marginTop: 0 }}>
            At least 8 characters, with uppercase, lowercase, a number, and a special character.
          </p>

          <button className="btn-primary" type="submit" disabled={loading}>
            {loading ? 'Saving...' : 'Set Password & Continue'}
          </button>
        </form>
      </div>
    </div>
  );
}

// ─── Main LoginScreen — orchestrates the 3 steps ─────────────────────────────
export default function LoginScreen() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);          // 1 | 2 | 3
  const [email, setEmail]       = useState('');
  const [families, setFamilies] = useState([]);
  const [selectedFamily, setSelectedFamily] = useState(null);

  const goStep1 = ()  => setStep(1);
  const goStep2 = ()  => setStep(2);

  return (
    <>
      {step === 1 && (
        <StepEmail
          onNext={({ email: e, families: f }) => {
            setEmail(e);
            setFamilies(f);
            // if only one family, skip picker
            if (f.length === 1) { setSelectedFamily(f[0]); setStep(3); }
            else setStep(2);
          }}
          onGoSignup={() => navigate('/signup')}
        />
      )}

      {step === 2 && (
        <StepPickFamily
          email={email}
          families={families}
          onBack={goStep1}
          onNext={({ selectedFamily: sf }) => {
            setSelectedFamily(sf);
            setStep(3);
          }}
        />
      )}

      {step === 3 && (
        <StepPassword
          email={email}
          family={selectedFamily}
          onBack={families.length > 1 ? goStep2 : goStep1}
          onSuccess={() => navigate('/home', { replace: true })}
        />
      )}
    </>
  );
}
