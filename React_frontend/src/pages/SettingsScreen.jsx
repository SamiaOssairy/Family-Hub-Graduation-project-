// ═══════════════════════════════════════════════════════════════════════════════
// SettingsScreen — React equivalent of flutter_app/lib/pages/setting.dart
// Sections: Profile card, My Account, Family Settings (parent), Preferences,
//           Support, Danger Zone, Logout button.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { PALETTES } from '../context/ThemeContext';
import {
  getAllMembers, getCombinedBalance, setConversionRate,
  getMyLocation, toggleLocationSharing, setPassword, deactivateAccount,
} from '../api/apiService';
import BottomNavBar from '../components/common/BottomNavBar';
import './SettingsScreen.css';

// ─────────────────────────────────────────────────────────────────────────────
export default function SettingsScreen() {
  const navigate  = useNavigate();
  const { familyTitle, username, memberId, isParent, savedAccounts, token, logout, logoutAll, switchAccount, removeAccount, member } = useAuth();
  const { theme, language, toggleTheme, toggleLanguage, palette, setPalette } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;
  const isDark = theme === 'dark';

  // ── State ─────────────────────────────────────────────────────────────────
  const [familyMembers,         setFamilyMembers]         = useState([]);
  const [membersLoading,        setMembersLoading]         = useState(true);
  const [locationSharing,       setLocationSharing]        = useState(true);
  const [updatingLocation,      setUpdatingLocation]       = useState(false);
  const [notificationsEnabled,  setNotificationsEnabled]   = useState(
    () => localStorage.getItem('notifications_enabled') !== 'false'
  );
  const [moneyToPointsRate,     setMoneyToPointsRate]      = useState(10);
  const [pointsToMoneyRate,     setPointsToMoneyRate]      = useState(0.05);
  const [currentUsername,       setCurrentUsername]        = useState(username || '');

  // ── Modal state ───────────────────────────────────────────────────────────
  const [showEditProfile,       setShowEditProfile]        = useState(false);
  const [showMembers,           setShowMembers]            = useState(false);
  const [showConversion,        setShowConversion]         = useState(false);
  const [showLanguage,          setShowLanguage]           = useState(false);
  const [showSwitchProfile,     setShowSwitchProfile]      = useState(false);
  const [showChangePassword,    setShowChangePassword]     = useState(false);
  const [showDeactivate,        setShowDeactivate]         = useState(false);
  const [showLogout,            setShowLogout]             = useState(false);

  // Edit profile form
  const [editUsername, setEditUsername] = useState(username || '');

  // Change password form
  const [pwCurrent,   setPwCurrent]   = useState('');
  const [pwNew,       setPwNew]       = useState('');
  const [pwConfirm,   setPwConfirm]   = useState('');
  const [pwLoading,   setPwLoading]   = useState(false);
  const [pwShowC,     setPwShowC]     = useState(false);
  const [pwShowN,     setPwShowN]     = useState(false);
  const [pwShowConf,  setPwShowConf]  = useState(false);

  // Deactivate form
  const [deacEmail,   setDeacEmail]   = useState('');
  const [deacPass,    setDeacPass]    = useState('');
  const [deacLoading, setDeacLoading] = useState(false);

  // Conversion rate form
  const [m2p, setM2p] = useState('');
  const [p2m, setP2m] = useState('');
  const [convLoading, setConvLoading] = useState(false);

  // Toast
  const [toast, setToast] = useState(null);
  const showToast = (msg, isError = false) => {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  };

  // ── Load data on mount ─────────────────────────────────────────────────────
  useEffect(() => {
    loadMembers();
    loadLocationSharing();
    loadConversionRate();
  }, []);

  async function loadMembers() {
    try   { setFamilyMembers(await getAllMembers()); }
    catch { /* silent */ }
    finally { setMembersLoading(false); }
  }

  async function loadLocationSharing() {
    try {
      const res = await getMyLocation();
      const loc = res?.data?.location;
      if (loc) setLocationSharing(loc.is_sharing_enabled ?? true);
    } catch { /* silent */ }
  }

  async function loadConversionRate() {
    try {
      const data = await getCombinedBalance();
      const rate = data?.conversionRate;
      if (rate) {
        setMoneyToPointsRate(rate.money_to_points_rate ?? 10);
        setPointsToMoneyRate(rate.points_to_money_rate ?? 0.05);
      }
    } catch { /* silent */ }
  }

  // ── Toggle location sharing ────────────────────────────────────────────────
  async function handleToggleLocation(value) {
    if (updatingLocation) return;
    const prev = locationSharing;
    setLocationSharing(value);
    setUpdatingLocation(true);
    try {
      await toggleLocationSharing(value);
      showToast(value
        ? t('Location sharing enabled', 'تم تفعيل مشاركة الموقع')
        : t('Location sharing disabled', 'تم إيقاف مشاركة الموقع'));
    } catch (e) {
      setLocationSharing(prev);
      showToast(e?.response?.data?.message || t('Failed to update', 'فشل التحديث'), true);
    } finally {
      setUpdatingLocation(false);
    }
  }

  // ── Toggle notifications ───────────────────────────────────────────────────
  function handleToggleNotifications(value) {
    localStorage.setItem('notifications_enabled', String(value));
    setNotificationsEnabled(value);
    showToast(value
      ? t('Notifications enabled', 'تم تفعيل الإشعارات')
      : t('Notifications disabled', 'تم إيقاف الإشعارات'));
  }

  // ── Save username ──────────────────────────────────────────────────────────
  function handleSaveProfile() {
    if (!editUsername.trim()) return;
    localStorage.setItem('username', editUsername.trim());
    setCurrentUsername(editUsername.trim());
    setShowEditProfile(false);
    showToast(t('Profile updated', 'تم تحديث الملف الشخصي'));
  }

  // ── Change password ────────────────────────────────────────────────────────
  async function handleChangePassword() {
    if (!pwCurrent || !pwNew) {
      showToast(t('Fill all fields', 'يرجى ملء جميع الحقول'), true); return;
    }
    if (pwNew !== pwConfirm) {
      showToast(t('Passwords do not match', 'كلمتا المرور غير متطابقتين'), true); return;
    }
    setPwLoading(true);
    try {
      await setPassword({ currentPassword: pwCurrent, newPassword: pwNew, confirmPassword: pwConfirm });
      setShowChangePassword(false);
      setPwCurrent(''); setPwNew(''); setPwConfirm('');
      showToast(t('Password changed!', 'تم تغيير كلمة المرور!'));
    } catch (e) {
      showToast(e?.response?.data?.message || t('Failed to change password', 'فشل تغيير كلمة المرور'), true);
    } finally {
      setPwLoading(false);
    }
  }

  // ── Save conversion rate ───────────────────────────────────────────────────
  async function handleSaveConversion() {
    const m2pNum = parseFloat(m2p);
    const p2mNum = parseFloat(p2m);
    if (isNaN(m2pNum) || isNaN(p2mNum) || m2pNum <= 0 || p2mNum <= 0) {
      showToast(t('Enter valid positive numbers', 'أدخل أرقاماً موجبة صحيحة'), true); return;
    }
    setConvLoading(true);
    try {
      await setConversionRate({ moneyToPointsRate: m2pNum, pointsToMoneyRate: p2mNum / 100 });
      setMoneyToPointsRate(m2pNum); setPointsToMoneyRate(p2mNum / 100);
      setShowConversion(false);
      showToast(t('Rates updated', 'تم تحديث الأسعار'));
    } catch (e) {
      showToast(e?.response?.data?.message || t('Failed to update rates', 'فشل تحديث الأسعار'), true);
    } finally {
      setConvLoading(false);
    }
  }

  // ── Deactivate account ────────────────────────────────────────────────────
  async function handleDeactivate() {
    if (!deacEmail.trim() || !deacPass) return;
    setDeacLoading(true);
    try {
      await deactivateAccount(deacEmail.trim(), deacPass);
      setShowDeactivate(false);
      logout();
      navigate('/login', { replace: true });
    } catch (e) {
      showToast(e?.response?.data?.message || t('Failed to deactivate', 'فشل تعطيل الحساب'), true);
    } finally {
      setDeacLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  function handleLogout() {
    setShowLogout(false);
    logout();
    navigate('/login', { replace: true });
  }

  function handleLogoutAll() {
    setShowLogout(false);
    logoutAll();
    navigate('/login', { replace: true });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  const getAvatarEmoji = (memberType) => {
    const t2 = (memberType || '').toLowerCase();
    if (t2 === 'parent') return '👑';
    if (t2.includes('child') || t2.includes('kid')) return '👶';
    return '👤';
  };

  const familyInitial = (familyTitle || 'F')[0].toUpperCase();
  const displayUsername = currentUsername || username || '';

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="ss-root">
      <div className="ss-scroll">
        <div className="ss-content">

          {/* ── Profile Card ──────────────────────────────────────────────── */}
          <div className="ss-profile-card">
            <div className="ss-profile-avatar" onClick={() => { setEditUsername(displayUsername); setShowEditProfile(true); }}>
              <span className="ss-profile-initial">{familyInitial}</span>
              <div className="ss-profile-edit-badge">✏️</div>
            </div>
            <div className="ss-profile-info">
              <span className="ss-profile-family">
                {familyTitle ? `${familyTitle} ${t('Family', 'عائلة')}` : t('Family', 'العائلة')}
              </span>
              {displayUsername && (
                <span className="ss-profile-username">@{displayUsername}</span>
              )}
              <div className="ss-profile-badge">
                {isParent ? `👑 ${t('Parent', 'أحد الوالدين')}` : `👤 ${t('Member', 'عضو')}`}
              </div>
            </div>
          </div>

          {/* ── My Account ────────────────────────────────────────────────── */}
          <SettingsSection label={t('MY ACCOUNT', 'حسابي')}>
            <SettingsRow
              icon="👤" iconBg="var(--color-primary-surface)" iconColor="var(--color-primary)"
              title={t('Edit Profile', 'تعديل الملف الشخصي')}
              subtitle={displayUsername || undefined}
              onTap={() => { setEditUsername(displayUsername); setShowEditProfile(true); }}
            />
            <SettingsRow
              icon="👨‍👩‍👧‍👦" iconBg="var(--color-background)" iconColor="var(--color-primary)"
              title={t('Family Members', 'أفراد العائلة')}
              subtitle={membersLoading ? undefined : `${familyMembers.length} ${t('members', 'أعضاء')}`}
              onTap={() => setShowMembers(true)}
            />
            <SettingsRow
              icon="🔒" iconBg="#FFF8E1" iconColor="#F9A825"
              title={t('Change Password', 'تغيير كلمة المرور')}
              onTap={() => { setPwCurrent(''); setPwNew(''); setPwConfirm(''); setShowChangePassword(true); }}
            />
            <SettingsRow
              icon="🔄" iconBg="#E3F2FD" iconColor="#1565C0"
              title={t('Manage Accounts', 'إدارة الحسابات')}
              subtitle={`${savedAccounts.length} ${t('saved', 'محفوظ')}`}
              onTap={() => navigate('/manage-accounts')}
            />
          </SettingsSection>

          {/* ── Family Settings (Parent only) ─────────────────────────────── */}
          {isParent && (
            <SettingsSection label={t('FAMILY SETTINGS', 'إعدادات العائلة')}>
              <SettingsRow
                icon="💱" iconBg="var(--color-background)" iconColor="var(--color-primary)"
                title={t('Conversion Rates', 'أسعار التحويل')}
                subtitle={`1 EGP = ${moneyToPointsRate.toFixed(0)} pts  •  100 pts = ${(pointsToMoneyRate * 100).toFixed(0)} EGP`}
                onTap={() => { setM2p(String(Math.round(moneyToPointsRate))); setP2m(String(Math.round(pointsToMoneyRate * 100))); setShowConversion(true); }}
              />
            </SettingsSection>
          )}

          {/* ── Preferences ───────────────────────────────────────────────── */}
          <SettingsSection label={t('PREFERENCES', 'التفضيلات')}>
            <SettingsToggleRow
              icon="🔔" iconBg="#FFF3E0" iconColor="#E65100"
              title={t('Notifications', 'الإشعارات')}
              subtitle={notificationsEnabled ? t('Enabled', 'مفعّل') : t('Disabled', 'معطّل')}
              value={notificationsEnabled}
              onChanged={handleToggleNotifications}
            />
            <SettingsRow
              icon="🌐" iconBg="var(--color-primary-surface)" iconColor="var(--color-primary)"
              title={t('Language', 'اللغة')}
              trailing={
                <div className="ss-lang-badge">
                  {language === 'ar' ? 'عر' : 'EN'}
                </div>
              }
              onTap={() => setShowLanguage(true)}
            />
            <SettingsToggleRow
              icon={isDark ? '🌙' : '☀️'}
              iconBg={isDark ? '#1A1A2E' : 'var(--color-primary-surface)'}
              iconColor={isDark ? '#FFFFFF' : 'var(--color-primary)'}
              title={t('Dark Mode', 'الوضع الداكن')}
              subtitle={isDark ? t('On', 'مفعّل') : t('Off', 'معطّل')}
              value={isDark}
              onChanged={toggleTheme}
            />
            <ColorThemePicker palette={palette} setPalette={setPalette} t={t} />
            <SettingsToggleRow
              icon="📍" iconBg="var(--color-primary-surface)" iconColor="var(--color-primary)"
              title={updatingLocation
                ? t('Location Sharing (updating…)', 'مشاركة الموقع (جارٍ التحديث…)')
                : t('Location Sharing', 'مشاركة الموقع')}
              subtitle={locationSharing
                ? t('Visible to family', 'مرئي للعائلة')
                : t('Hidden from map', 'مخفي عن الخريطة')}
              value={locationSharing}
              onChanged={handleToggleLocation}
              disabled={updatingLocation}
            />
          </SettingsSection>

          {/* ── Support ───────────────────────────────────────────────────── */}
          <SettingsSection label={t('SUPPORT', 'الدعم')}>
            <SettingsRow
              icon="❓" iconBg="#E0F7FA" iconColor="#00838F"
              title={t('Help Center', 'مركز المساعدة')}
              onTap={() => showToast(t('Coming soon', 'قريباً'))}
            />
            <SettingsRow
              icon="✉️" iconBg="#FCE4EC" iconColor="#AD1457"
              title={t('Contact Us', 'تواصل معنا')}
              onTap={() => showToast(t('Coming soon', 'قريباً'))}
            />
            <SettingsRow
              icon="ℹ️" iconBg="var(--color-primary-surface)" iconColor="var(--color-primary)"
              title={t('About Family Hub', 'عن فاميلي هب')}
              onTap={() => showToast(t('Coming soon', 'قريباً'))}
            />
          </SettingsSection>

          {/* ── Danger Zone ───────────────────────────────────────────────── */}
          <div className="ss-danger-card" onClick={() => setShowDeactivate(true)}>
            <div className="ss-danger-icon">🚫</div>
            <div className="ss-danger-text">
              <span className="ss-danger-title">{t('Deactivate Family Account', 'تعطيل حساب العائلة')}</span>
              <span className="ss-danger-sub">{t('Cannot be undone', 'لا يمكن التراجع')}</span>
            </div>
            <span className="ss-danger-chevron">›</span>
          </div>

          {/* ── Logout Button ─────────────────────────────────────────────── */}
          <button className="ss-logout-btn" onClick={() => setShowLogout(true)}>
            🚪 {t('Logout Options', 'خيارات تسجيل الخروج')}
          </button>

          <p className="ss-version">Family Hub v1.0.0</p>
          <div style={{ height: 80 }} />
        </div>
      </div>

      <BottomNavBar activeIndex={4} />

      {/* ═══════════════════════════════════════════════════════════════════
          MODALS
      ════════════════════════════════════════════════════════════════════ */}

      {/* Edit Profile */}
      {showEditProfile && (
        <Overlay onClose={() => setShowEditProfile(false)}>
          <h3>{t('Edit Profile', 'تعديل الملف الشخصي')}</h3>
          <div className="ss-form-group">
            <label>{t('Username', 'اسم المستخدم')}</label>
            <input type="text" value={editUsername} onChange={e => setEditUsername(e.target.value)} />
          </div>
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowEditProfile(false)}>{t('Cancel', 'إلغاء')}</button>
            <button className="ss-btn-primary" onClick={handleSaveProfile}>{t('Save', 'حفظ')}</button>
          </div>
        </Overlay>
      )}

      {/* Family Members Sheet */}
      {showMembers && (
        <div className="ss-sheet-overlay" onClick={() => setShowMembers(false)}>
          <div className="ss-sheet" onClick={e => e.stopPropagation()}>
            <div className="ss-sheet-handle" />
            <div className="ss-sheet-header">
              <h3 className="ss-sheet-title">{t('Family Members', 'أفراد العائلة')}</h3>
              {isParent && (
                <button className="ss-btn-text" onClick={() => { setShowMembers(false); navigate('/home'); }}>
                  👤 {t('Add', 'إضافة')}
                </button>
              )}
            </div>
            <div className="ss-divider" />
            {membersLoading ? (
              <div className="ss-center"><div className="ss-spinner" /></div>
            ) : familyMembers.length === 0 ? (
              <div className="ss-center">
                <span className="ss-empty-text">{t('No members found', 'لا يوجد أعضاء')}</span>
              </div>
            ) : (
              <div className="ss-member-list">
                {familyMembers.map((m, i) => (
                  <React.Fragment key={m._id}>
                    {i > 0 && <div className="ss-divider" />}
                    <div className="ss-member-row">
                      <div className="ss-member-avatar">
                        {getAvatarEmoji(m.member_type_id?.type || m.memberType?.type)}
                      </div>
                      <div className="ss-member-info">
                        <span className="ss-member-name">{m.username}</span>
                        <span className="ss-member-type">{m.member_type_id?.type || m.memberType?.type || t('Member', 'عضو')}</span>
                      </div>
                      <span className="ss-member-mail">{m.mail}</span>
                    </div>
                  </React.Fragment>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Change Password */}
      {showChangePassword && (
        <Overlay onClose={() => setShowChangePassword(false)}>
          <div className="ss-dialog-header">
            <h3 style={{ margin: 0 }}>{t('Change Password', 'تغيير كلمة المرور')}</h3>
            <button className="ss-close-btn" onClick={() => setShowChangePassword(false)}>✕</button>
          </div>
          <PwField label={t('Current Password', 'كلمة المرور الحالية')} value={pwCurrent} onChange={setPwCurrent} show={pwShowC} onToggle={() => setPwShowC(v => !v)} />
          <PwField label={t('New Password', 'كلمة المرور الجديدة')}     value={pwNew}     onChange={setPwNew}     show={pwShowN} onToggle={() => setPwShowN(v => !v)} />
          <PwField label={t('Confirm Password', 'تأكيد كلمة المرور')}   value={pwConfirm} onChange={setPwConfirm} show={pwShowConf} onToggle={() => setPwShowConf(v => !v)} />
          <button className="ss-btn-full-primary" onClick={handleChangePassword} disabled={pwLoading}>
            {pwLoading ? t('Updating...', 'جارٍ التحديث...') : t('Update Password', 'تحديث كلمة المرور')}
          </button>
        </Overlay>
      )}

      {/* Conversion Rates */}
      {showConversion && (
        <Overlay onClose={() => setShowConversion(false)}>
          <h3>{t('Conversion Rates', 'أسعار التحويل')}</h3>
          <div className="ss-rate-info">
            {t(
              `Current: 1 EGP = ${moneyToPointsRate.toFixed(0)} pts  |  100 pts = ${(pointsToMoneyRate * 100).toFixed(0)} EGP`,
              `حالياً: 1 جنيه = ${moneyToPointsRate.toFixed(0)} نقطة  |  100 نقطة = ${(pointsToMoneyRate * 100).toFixed(0)} جنيه`
            )}
          </div>
          <div className="ss-form-group">
            <label>{t('Points per 1 EGP', 'نقاط لكل جنيه')} ({t('Default: 10', 'الافتراضي: 10')})</label>
            <input type="number" value={m2p} onChange={e => setM2p(e.target.value)} min="1" />
          </div>
          <div className="ss-form-group">
            <label>{t('EGP per 100 pts', 'جنيه لكل 100 نقطة')} ({t('Default: 5', 'الافتراضي: 5')})</label>
            <input type="number" value={p2m} onChange={e => setP2m(e.target.value)} min="1" />
          </div>
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowConversion(false)}>{t('Cancel', 'إلغاء')}</button>
            <button className="ss-btn-primary" onClick={handleSaveConversion} disabled={convLoading}>
              {convLoading ? t('Saving...', 'حفظ...') : t('Save', 'حفظ')}
            </button>
          </div>
        </Overlay>
      )}

      {/* Language */}
      {showLanguage && (
        <Overlay onClose={() => setShowLanguage(false)}>
          <h3>{t('Select Language', 'اختر اللغة')}</h3>
          <div className="ss-lang-option" onClick={() => { if (language !== 'en') toggleLanguage(); setShowLanguage(false); }}>
            <span>{t('English', 'الإنجليزية')}</span>
            {language === 'en' && <span className="ss-check">✓</span>}
          </div>
          <div className="ss-lang-option" onClick={() => { if (language !== 'ar') toggleLanguage(); setShowLanguage(false); }}>
            <span>{t('Arabic', 'العربية')}</span>
            {language === 'ar' && <span className="ss-check">✓</span>}
          </div>
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowLanguage(false)}>{t('Cancel', 'إلغاء')}</button>
          </div>
        </Overlay>
      )}

      {/* Switch Profile */}
      {showSwitchProfile && (
        <Overlay onClose={() => setShowSwitchProfile(false)}>
          <h3>{t('Switch Profile', 'تبديل الحساب')}</h3>
          {savedAccounts.length === 0 ? (
            <p className="ss-empty-text">{t('No saved profiles.', 'لا توجد حسابات محفوظة.')}</p>
          ) : (
            <div className="ss-profile-list">
              {savedAccounts.map(acc => {
                const accTitle = acc.family?.Title || acc.family?.title || '';
                const accUser  = acc.member?.username || '';
                const accMail  = acc.member?.mail || '';
                const accKey   = acc.key || acc.token;
                const isActive = acc.token === token;
                return (
                  <div
                    key={accKey}
                    className={`ss-profile-item${isActive ? ' active' : ''}`}
                    onClick={() => {
                      if (!isActive) { switchAccount(acc); setShowSwitchProfile(false); showToast(t('Profile switched', 'تم تبديل الحساب')); }
                    }}
                  >
                    <div className="ss-profile-item-body">
                      <div className="ss-profile-item-name">{accTitle} ({accUser})</div>
                      <div className="ss-profile-item-mail">{accMail}</div>
                    </div>
                    <div className="ss-profile-item-actions">
                      {isActive && <span className="ss-check">✓</span>}
                      <button
                        className="ss-profile-remove-btn"
                        title={t('Remove', 'حذف')}
                        onClick={e => {
                          e.stopPropagation();
                          removeAccount(accKey);
                          if (isActive && savedAccounts.length <= 1) { setShowSwitchProfile(false); handleLogout(); }
                        }}
                      >✕</button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowSwitchProfile(false)}>{t('Close', 'إغلاق')}</button>
          </div>
        </Overlay>
      )}

      {/* Deactivate */}
      {showDeactivate && (
        <Overlay onClose={() => setShowDeactivate(false)}>
          <div className="ss-danger-header">
            ⚠️ <h3 style={{ margin: 0, color: '#E53935' }}>{t('Deactivate Account', 'تعطيل الحساب')}</h3>
          </div>
          <div className="ss-danger-warning">
            {t(
              'This will deactivate the entire family account. All members will be logged out.',
              'سيتم تعطيل حساب العائلة بالكامل وتسجيل خروج جميع الأعضاء.'
            )}
          </div>
          <div className="ss-form-group">
            <label>{t('Email', 'البريد الإلكتروني')}</label>
            <input type="email" value={deacEmail} onChange={e => setDeacEmail(e.target.value)} />
          </div>
          <div className="ss-form-group">
            <label>{t('Password', 'كلمة المرور')}</label>
            <input type="password" value={deacPass} onChange={e => setDeacPass(e.target.value)} />
          </div>
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowDeactivate(false)}>{t('Cancel', 'إلغاء')}</button>
            <button className="ss-btn-danger" onClick={handleDeactivate} disabled={deacLoading}>
              {deacLoading ? t('Deactivating...', 'جارٍ التعطيل...') : t('Deactivate', 'تعطيل')}
            </button>
          </div>
        </Overlay>
      )}

      {/* Logout */}
      {showLogout && (
        <Overlay onClose={() => setShowLogout(false)}>
          <h3>{t('Logout options', 'خيارات تسجيل الخروج')}</h3>
          <p className="ss-dialog-sub">{t('Choose whether to logout this profile only or all saved profiles.', 'اختر تسجيل خروج الحساب الحالي فقط أو كل الحسابات.')}</p>
          <div className="ss-dialog-actions">
            <button className="ss-btn-text" onClick={() => setShowLogout(false)}>{t('Cancel', 'إلغاء')}</button>
            <button className="ss-btn-text" onClick={handleLogout}>{t('Logout current', 'خروج الحساب الحالي')}</button>
            <button className="ss-btn-text danger" onClick={handleLogoutAll}>{t('Logout all', 'خروج الكل')}</button>
          </div>
        </Overlay>
      )}

      {/* Toast */}
      {toast && <div className={`ss-toast${toast.isError ? ' error' : ''}`}>{toast.msg}</div>}
    </div>
  );
}

/* ── Sub-components ──────────────────────────────────────────────────────── */

function Overlay({ children, onClose }) {
  return (
    <div className="ss-overlay" onClick={onClose}>
      <div className="ss-dialog" onClick={e => e.stopPropagation()}>
        {children}
      </div>
    </div>
  );
}

function SettingsSection({ label, children }) {
  return (
    <div className="ss-section">
      <span className="ss-section-label">{label}</span>
      <div className="ss-section-card">
        {React.Children.map(children, (child, i) => (
          <>
            {child}
            {i < React.Children.count(children) - 1 && (
              <div className="ss-row-divider" />
            )}
          </>
        ))}
      </div>
    </div>
  );
}

function SettingsRow({ icon, iconBg, iconColor, title, subtitle, trailing, onTap }) {
  return (
    <div className="ss-row" onClick={onTap}>
      <div className="ss-row-icon" style={{ background: iconBg }}>
        <span style={{ color: iconColor }}>{icon}</span>
      </div>
      <div className="ss-row-body">
        <span className="ss-row-title">{title}</span>
        {subtitle && <span className="ss-row-sub">{subtitle}</span>}
      </div>
      {trailing || <span className="ss-chevron">›</span>}
    </div>
  );
}

function SettingsToggleRow({ icon, iconBg, iconColor, title, subtitle, value, onChanged, disabled }) {
  return (
    <div className="ss-row">
      <div className="ss-row-icon" style={{ background: iconBg }}>
        <span style={{ color: iconColor }}>{icon}</span>
      </div>
      <div className="ss-row-body">
        <span className="ss-row-title">{title}</span>
        {subtitle && <span className="ss-row-sub">{subtitle}</span>}
      </div>
      <div
        className={`ss-toggle${value ? ' on' : ''}${disabled ? ' disabled' : ''}`}
        onClick={() => !disabled && onChanged(!value)}
      >
        <div className="ss-toggle-knob" />
      </div>
    </div>
  );
}

function ColorThemePicker({ palette, setPalette, t }) {
  return (
    <div className="ss-row ss-color-picker-row">
      <div className="ss-row-icon" style={{ background: 'var(--color-primary-surface)' }}>
        <span>🎨</span>
      </div>
      <div className="ss-row-body">
        <span className="ss-row-title">{t('Color Theme', 'لون التطبيق')}</span>
        <div className="ss-palette-dots">
          {PALETTES.map(p => {
            const isSelected = palette?.id === p.id;
            return (
              <button
                key={p.id}
                className={`ss-palette-dot${isSelected ? ' selected' : ''}`}
                style={{ background: p.seed, boxShadow: isSelected ? `0 0 0 3px ${p.seed}55` : undefined }}
                title={p.displayName}
                onClick={() => setPalette(p.id)}
              >
                {isSelected && <span className="ss-palette-check">✓</span>}
              </button>
            );
          })}
        </div>
      </div>
      <span className="ss-row-sub" style={{ fontSize: 11, color: 'var(--color-primary)', fontWeight: 600 }}>
        {palette?.displayName || ''}
      </span>
    </div>
  );
}

function PwField({ label, value, onChange, show, onToggle }) {
  return (
    <div className="ss-form-group">
      <label>{label}</label>
      <div className="ss-pw-wrapper">
        <input type={show ? 'text' : 'password'} value={value} onChange={e => onChange(e.target.value)} />
        <button type="button" className="ss-pw-toggle" onClick={onToggle}>
          {show ? '🙈' : '👁️'}
        </button>
      </div>
    </div>
  );
}
