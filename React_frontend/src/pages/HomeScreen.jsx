// ═══════════════════════════════════════════════════════════════════════════════
// HomeScreen — React equivalent of flutter_app/lib/pages/home.dart
// Matches Flutter HomePage exactly: header, account switcher, family members,
// stat cards, tasks teaser, AI card, events card, leaderboard, bottom nav.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import {
  getAllMembers, getCombinedBalance, getAllAssignedTasks, getMyTasks,
  getFutureEvents, getPointsRanking, getAllMemberTypes,
  createMember, deleteMember,
} from '../api/apiService';
import BottomNavBar from '../components/common/BottomNavBar';
import './HomeScreen.css';

// ── Avatar palette (matches Flutter _avatarColors / _avatarBgs) ───────────────
const AVATAR_COLORS = ['#1565C0','#6A1B9A','#AD1457','#E65100','var(--color-text-primary)','var(--color-primary)'];
const AVATAR_BGS   = ['#E3F2FD','#F3E5F5','#FCE4EC','#FFF3E0','var(--color-primary-surface)','var(--color-background)'];

function getAvatarEmoji(memberType) {
  const t = (memberType || '').toLowerCase();
  if (t === 'parent') return '👑';
  if (t.includes('child') || t.includes('kid')) return '👶';
  return '👤';
}

// ── Task helpers (matches Flutter _taskDotColor / _taskBadge) ─────────────────
function taskDotColor(status) {
  switch (status) {
    case 'approved':    return 'var(--color-primary)';
    case 'completed':   return 'var(--color-primary-light)';
    case 'in_progress': return '#1565C0';
    case 'late':        return '#FF5252';
    case 'rejected':    return '#9E9E9E';
    default:            return '#FB8C00'; // assigned
  }
}

function taskBadge(status) {
  switch (status) {
    case 'approved':    return { label: 'Approved', bg: 'var(--color-primary-surface)', fg: 'var(--color-text-primary)' };
    case 'completed':   return { label: 'Done ✓',   bg: 'var(--color-primary-surface)', fg: 'var(--color-primary)' };
    case 'in_progress': return { label: 'Active',   bg: '#E3F2FD', fg: '#1565C0' };
    case 'late':        return { label: 'Late',     bg: '#FFEBEE', fg: '#C62828' };
    case 'rejected':    return { label: 'Rejected', bg: '#F5F5F5', fg: '#9E9E9E' };
    default:            return { label: 'Pending',  bg: '#FFF3E0', fg: '#E65100' };
  }
}

// ── Event helpers ─────────────────────────────────────────────────────────────
const EVENT_ICONS  = ['✈️','🎁','🎉','🛍️','🏖️','🎂'];
const EVENT_COLORS = ['var(--color-primary-light)','#FB8C00','var(--color-primary)','#AD1457','#6A1B9A','var(--color-text-primary)'];
const MEDALS       = ['🥇','🥈','🥉'];

// ─────────────────────────────────────────────────────────────────────────────
export default function HomeScreen() {
  const navigate  = useNavigate();
  const { familyTitle, username, isParent, savedAccounts, token, logout, switchAccount } = useAuth();
  const { language } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;

  // ── Data state ────────────────────────────────────────────────────────────
  const [familyMembers, setFamilyMembers]   = useState([]);
  const [loading, setLoading]               = useState(true);
  const [walletSummary, setWalletSummary]   = useState({});
  const [walletLoading, setWalletLoading]   = useState(true);
  const [recentTasks, setRecentTasks]       = useState([]);
  const [tasksLoading, setTasksLoading]     = useState(true);
  const [futureEvents, setFutureEvents]     = useState([]);
  const [eventsLoading, setEventsLoading]   = useState(true);
  const [pointsRanking, setPointsRanking]   = useState([]);
  const [rankingLoading, setRankingLoading] = useState(true);

  // ── Modal state ───────────────────────────────────────────────────────────
  const [showAccountSwitcher, setShowAccountSwitcher] = useState(false);
  const [showLogoutDialog, setShowLogoutDialog]       = useState(false);
  const [showAddMember, setShowAddMember]             = useState(false);
  const [memberOptions, setMemberOptions]             = useState(null); // { m, i }

  // ── Add-member form ───────────────────────────────────────────────────────
  const [addForm, setAddForm]           = useState({ mail: '', username: '', birth_date: '', member_type_id: '' });
  const [memberTypes, setMemberTypes]   = useState([]);
  const [typesLoading, setTypesLoading] = useState(false);
  const [newTypeName, setNewTypeName]   = useState('');
  const [showNewType, setShowNewType]   = useState(false);
  const [addLoading, setAddLoading]     = useState(false);
  const [addError, setAddError]         = useState('');

  // ── Toast ─────────────────────────────────────────────────────────────────
  const [toast, setToast] = useState(null);
  const showToast = (msg, isError = false) => {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  };

  // ── Load all data on mount ────────────────────────────────────────────────
  useEffect(() => {
    loadMembers();
    loadWallet();
    loadTasks();
    loadEvents();
    loadRanking();
  }, []);

  async function loadMembers() {
    try   { setFamilyMembers(await getAllMembers()); }
    catch { /* silent */ }
    finally { setLoading(false); }
  }
  async function loadWallet() {
    try   { setWalletSummary(await getCombinedBalance()); }
    catch { /* silent */ }
    finally { setWalletLoading(false); }
  }
  async function loadTasks() {
    // Parents see the whole family's tasks; everyone else sees only their own.
    try   { setRecentTasks(await (isParent ? getAllAssignedTasks() : getMyTasks())); }
    catch { /* silent */ }
    finally { setTasksLoading(false); }
  }
  async function loadEvents() {
    try   { setFutureEvents(await getFutureEvents()); }
    catch { /* silent */ }
    finally { setEventsLoading(false); }
  }
  async function loadRanking() {
    try   { setPointsRanking(await getPointsRanking()); }
    catch { /* silent */ }
    finally { setRankingLoading(false); }
  }

  function getMemberName(mail) {
    const m = familyMembers.find(x => x.mail === mail);
    return m ? m.username : mail.split('@')[0];
  }

  // ── Account switching ─────────────────────────────────────────────────────
  function handleSwitchAccount(acc) {
    switchAccount(acc);
    setShowAccountSwitcher(false);
    // Reload all data after switch
    setLoading(true); setWalletLoading(true); setTasksLoading(true);
    setEventsLoading(true); setRankingLoading(true);
    loadMembers(); loadWallet(); loadTasks(); loadEvents(); loadRanking();
    showToast(t('Account switched', 'تم تبديل الحساب'));
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  function handleLogout() {
    setShowLogoutDialog(false);
    logout();
    navigate('/login', { replace: true });
  }

  // ── Open add-member dialog ────────────────────────────────────────────────
  async function openAddMember() {
    setShowAddMember(true);
    setAddForm({ mail: '', username: '', birth_date: '', member_type_id: '' });
    setAddError(''); setShowNewType(false); setNewTypeName('');
    setTypesLoading(true);
    try   { setMemberTypes(await getAllMemberTypes()); }
    catch { setMemberTypes([]); }
    finally { setTypesLoading(false); }
  }

  async function handleAddMember() {
    if (!addForm.mail.trim() || !addForm.username.trim()) {
      setAddError(t('Email and username are required', 'البريد الإلكتروني واسم المستخدم مطلوبان'));
      return;
    }
    if (!addForm.birth_date) {
      setAddError(t('Birth date is required', 'تاريخ الميلاد مطلوب'));
      return;
    }
    // Backend expects member_type as the type NAME (e.g. "Child"), like Flutter sends
    const typeName = showNewType
      ? newTypeName.trim()
      : (memberTypes.find(mt => mt._id === addForm.member_type_id)?.type || '');
    if (!typeName) {
      setAddError(t('Please select a member type', 'يرجى اختيار نوع العضو'));
      return;
    }
    setAddLoading(true); setAddError('');
    try {
      await createMember({
        mail: addForm.mail.trim().toLowerCase(),
        username: addForm.username.trim(),
        birth_date: addForm.birth_date,
        member_type: typeName,
      });
      setShowAddMember(false);
      showToast(t('Member added successfully', 'تم إضافة العضو'));
      loadMembers();
    } catch (e) {
      setAddError(e?.response?.data?.message || e?.message || t('Failed to add member', 'فشل إضافة العضو'));
    } finally {
      setAddLoading(false);
    }
  }

  async function handleDeleteMember(memberId, username) {
    if (!window.confirm(t(`Remove ${username} from the family?`, `حذف ${username} من العائلة؟`))) return;
    try {
      await deleteMember(memberId);
      setMemberOptions(null);
      showToast(t('Member removed', 'تم حذف العضو'));
      loadMembers();
    } catch (e) {
      showToast(t('Failed to remove member', 'فشل حذف العضو'), true);
    }
  }

  const moneyBalance  = Number(walletSummary?.money_balance  ?? 0);
  const pointsBalance = Number(walletSummary?.points_balance ?? 0);

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="hs-root">
      {/* ── Scrollable content ── */}
      <div className="hs-scroll">
        <div className="hs-content">

          {/* ── Header ─────────────────────────────────────────────────────── */}
          <div className="hs-header">
            <div className="hs-avatar" onClick={() => setShowAccountSwitcher(true)}>
              <span>👨‍👩‍👧‍👦</span>
            </div>
            <div className="hs-header-info">
              <span className="hs-family-title">{familyTitle || 'Family Hub'}</span>
              <span className="hs-welcome">{t(`Welcome back, ${username}`, `مرحباً ${username}`)}</span>
              {savedAccounts.length > 0 && (
                <span className="hs-active-badge">● {t('Active profile', 'الحساب النشط')}</span>
              )}
            </div>
            <button className="hs-logout-btn" onClick={() => setShowLogoutDialog(true)} title={t('Logout', 'خروج')}>
              🚪
            </button>
          </div>

          {/* ── Family Members ──────────────────────────────────────────────── */}
          <div className="hs-section">
            <span className="hs-section-label">{t('FAMILY MEMBERS', 'أفراد العائلة')}</span>
            <div className="hs-members-card">
              {loading ? (
                <div className="hs-center-pad"><div className="hs-spinner" /></div>
              ) : familyMembers.length === 0 ? (
                <div className="hs-add-first-card" onClick={openAddMember}>
                  <div className="hs-add-first-icon">👤</div>
                  <div className="hs-add-first-text">
                    <span className="hs-add-first-title">{t('Add your first member', 'أضف أول عضو في العائلة')}</span>
                    <span className="hs-add-first-sub">{t('Tap to add a family member', 'اضغط لإضافة عضو')}</span>
                  </div>
                  <span className="hs-chevron">›</span>
                </div>
              ) : (
                <div className="hs-members-wrap">
                  {familyMembers.map((m, i) => {
                    const color = AVATAR_COLORS[i % AVATAR_COLORS.length];
                    const bg    = AVATAR_BGS[i % AVATAR_BGS.length];
                    const emoji = getAvatarEmoji(m.member_type_id?.type || m.memberType?.type);
                    return (
                      <div key={m._id} className="hs-member-card" onClick={() => setMemberOptions({ m, i })}>
                        <div className="hs-member-avatar" style={{ background: bg, borderColor: color + '4D' }}>
                          <span>{emoji}</span>
                          <div className="hs-member-dot" />
                        </div>
                        <span className="hs-member-name">{m.username}</span>
                        <span className="hs-member-type" style={{ color }}>
                          {m.member_type_id?.type || m.memberType?.type || t('Member', 'عضو')}
                        </span>
                      </div>
                    );
                  })}
                  {isParent && (
                    <div className="hs-member-card" onClick={openAddMember}>
                      <div className="hs-member-avatar hs-add-avatar">
                        <span style={{ fontSize: 20, color: 'var(--color-primary)', fontWeight: 700 }}>+</span>
                      </div>
                      <span className="hs-member-name">{t('Add', 'إضافة')}</span>
                      <span className="hs-member-type" style={{ color: 'var(--color-primary)' }}>
                        {t('Member', 'عضو')}
                      </span>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* ── Stat Cards ──────────────────────────────────────────────────── */}
          <div className="hs-stat-row">
            <div className="hs-stat-card">
              <div className="hs-stat-icon" style={{ background: 'var(--color-background)' }}>💰</div>
              <div className="hs-stat-body">
                <span className="hs-stat-value">
                  {walletLoading ? '...' : `${moneyBalance.toFixed(0)} EGP`}
                </span>
                <span className="hs-stat-label">{t('Money Balance', 'رصيد المال')}</span>
                <span className="hs-stat-sub">{t('Wallet balance', 'رصيد المحفظة')}</span>
              </div>
            </div>
            <div className="hs-stat-card">
              <div className="hs-stat-icon" style={{ background: '#FFF8E1' }}>⭐</div>
              <div className="hs-stat-body">
                <span className="hs-stat-value">
                  {walletLoading ? '...' : `${pointsBalance.toFixed(0)} pts`}
                </span>
                <span className="hs-stat-label">{t('Your Points', 'نقاطك')}</span>
                <span className="hs-stat-sub">{t('Earned points', 'نقاط مكتسبة')}</span>
              </div>
            </div>
          </div>

          {/* ── Tasks Teaser ────────────────────────────────────────────────── */}
          <div className="hs-section">
            <div className="hs-section-row">
              <span className="hs-section-label">
                {isParent ? t("TODAY'S TASKS", 'مهام اليوم') : t('MY TASKS', 'مهامي')}
              </span>
              <button className="hs-see-all" onClick={() => navigate(isParent ? '/task-management' : '/tasks')}>
                {t('See all', 'عرض الكل')}
              </button>
            </div>
            <div className="hs-card">
              {tasksLoading ? (
                <div className="hs-center-pad"><div className="hs-spinner" /></div>
              ) : recentTasks.length === 0 ? (
                <div className="hs-empty-row" onClick={() => navigate(isParent ? '/task-management' : '/tasks')}>
                  <span>📋</span>
                  <span className="hs-empty-text">
                    {isParent
                      ? t('No tasks assigned yet — tap to manage', 'لا توجد مهام بعد — اضغط للإدارة')
                      : t('No tasks for you yet — tap to view', 'لا توجد مهام لك بعد — اضغط للعرض')}
                  </span>
                  <span className="hs-chevron">›</span>
                </div>
              ) : (
                recentTasks.slice(0, 3).map((task, i) => {
                  const isLast = i === Math.min(recentTasks.length, 3) - 1;
                  const title  = task.task_id?.title || t('Task', 'مهمة');
                  const mail   = task.member_mail || '';
                  const status = task.status || 'assigned';
                  const badge  = taskBadge(status);
                  return (
                    <div key={task._id || i} className={`hs-task-row${isLast ? '' : ' has-border'}`}
                      onClick={() => navigate(isParent ? '/task-management' : '/tasks')} style={{ cursor: 'pointer' }}>
                      <div className="hs-task-dot" style={{ background: taskDotColor(status) }} />
                      <div className="hs-task-info">
                        <span className="hs-task-title">{title}</span>
                        {isParent && <span className="hs-task-assignee">{getMemberName(mail)}</span>}
                      </div>
                      <div className="hs-badge" style={{ background: badge.bg, color: badge.fg }}>{badge.label}</div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* ── AI Card ─────────────────────────────────────────────────────── */}
          <div className="hs-ai-card" onClick={() => navigate('/planning-chat')}>
            <div className="hs-ai-icon-box">🤖</div>
            <div className="hs-ai-text">
              <span className="hs-ai-title">{t('Ask Family AI', 'اسأل المساعد الذكي')}</span>
              <span className="hs-ai-sub">{t('Budget, meals, tasks — ask anything', 'الميزانية، الطعام، المهام — اسأل أي شيء')}</span>
            </div>
            <span className="hs-ai-arrow">›</span>
          </div>

          {/* ── Upcoming Events ─────────────────────────────────────────────── */}
          <div className="hs-section">
            <div className="hs-section-row">
              <span className="hs-section-label">{t('UPCOMING EVENTS', 'الأحداث القادمة')}</span>
              <button className="hs-see-all" onClick={() => navigate('/dashboard')}>
                {t('See all', 'عرض الكل')}
              </button>
            </div>
            <div className="hs-card">
              {eventsLoading ? (
                <div className="hs-center-pad"><div className="hs-spinner" /></div>
              ) : futureEvents.length === 0 ? (
                <div className="hs-empty-row" onClick={() => navigate('/dashboard')}>
                  <span>📅</span>
                  <span className="hs-empty-text">{t('No upcoming events — tap to create one', 'لا توجد أحداث — اضغط لإنشاء واحد')}</span>
                  <span className="hs-chevron">›</span>
                </div>
              ) : (
                futureEvents.slice(0, 3).map((ev, i) => {
                  const isLast = i === Math.min(futureEvents.length, 3) - 1;
                  const color  = EVENT_COLORS[i % EVENT_COLORS.length];
                  const icon   = EVENT_ICONS[i % EVENT_ICONS.length];
                  const title  = ev.title || ev.name || t('Event', 'حدث');
                  const cost   = Number(ev.estimated_cost || 0);
                  const saved  = Number(ev.total_contributed_money || ev.saved_amount || 0);
                  const pct    = cost > 0 ? Math.min(100, Math.round((saved / cost) * 100)) : 0;
                  return (
                    <div key={ev._id || i} className={`hs-event-row${isLast ? '' : ' has-border'}`}>
                      <div className="hs-event-icon-box">{icon}</div>
                      <div className="hs-event-info">
                        <span className="hs-event-title">{title}</span>
                        <span className="hs-event-amount">{saved.toFixed(0)}/{cost.toFixed(0)} EGP</span>
                        <div className="hs-progress-bar">
                          <div className="hs-progress-fill" style={{ width: `${pct}%`, background: color }} />
                        </div>
                      </div>
                      <span className="hs-event-pct" style={{ color }}>{pct}%</span>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* ── Leaderboard ─────────────────────────────────────────────────── */}
          <div className="hs-section">
            <div className="hs-section-row">
              <span className="hs-section-label">{t('POINTS LEADERBOARD', 'لوحة المتصدرين')}</span>
              <button className="hs-see-all" onClick={() => navigate('/family-points')}>
                {t('Full ranking', 'الترتيب الكامل')}
              </button>
            </div>
            <div className="hs-card">
              {rankingLoading ? (
                <div className="hs-center-pad"><div className="hs-spinner" /></div>
              ) : pointsRanking.length === 0 ? (
                <div className="hs-center-pad">
                  <span className="hs-empty-text">{t('No points data yet', 'لا توجد بيانات نقاط بعد')}</span>
                </div>
              ) : (
                pointsRanking.slice(0, 3).map((m, i) => {
                  const isLast = i === Math.min(pointsRanking.length, 3) - 1;
                  const medal  = i < MEDALS.length ? MEDALS[i] : `${i + 1}.`;
                  const name   = m.username || m.mail || '?';
                  const pts    = m.total_points || 0;
                  const mail   = m.mail || '';
                  const mem    = familyMembers.find(x => x.mail === mail);
                  const emoji  = mem ? getAvatarEmoji(mem.member_type_id?.type || mem.memberType?.type) : '👤';
                  return (
                    <div key={m._id || i} className={`hs-rank-row${isLast ? '' : ' has-border'}`}>
                      <span className="hs-medal">{medal}</span>
                      <span className="hs-rank-emoji">{emoji}</span>
                      <span className="hs-rank-name">{name}</span>
                      <span className="hs-rank-pts">{pts} pts</span>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          <div style={{ height: 80 }} />
        </div>
      </div>

      {/* ── Bottom Nav ────────────────────────────────────────────────────── */}
      <BottomNavBar activeIndex={0} />

      {/* ═══════════════════════════════════════════════════════════════════
          MODALS
      ════════════════════════════════════════════════════════════════════ */}

      {/* Account Switcher Sheet */}
      {showAccountSwitcher && (
        <div className="hs-sheet-overlay" onClick={() => setShowAccountSwitcher(false)}>
          <div className="hs-sheet" onClick={e => e.stopPropagation()}>
            <div className="hs-sheet-handle" />
            <h3 className="hs-sheet-title">{t('Switch Account', 'تبديل الحساب')}</h3>
            {/* Current account */}
            <div className="hs-current-account">
              <div className="hs-ca-avatar">{(familyTitle || 'F')[0].toUpperCase()}</div>
              <div className="hs-ca-info">
                <span className="hs-ca-label">{t('Current account', 'الحساب الحالي')}</span>
                <span className="hs-ca-name">{familyTitle} ({username})</span>
              </div>
            </div>
            {savedAccounts.length === 0 ? (
              <p className="hs-no-accounts">{t('No saved accounts yet', 'لا توجد حسابات محفوظة بعد')}</p>
            ) : (
              <div className="hs-saved-list">
                {savedAccounts.map(acc => {
                  const accTitle = acc.family?.Title || acc.family?.title || '';
                  const accUser  = acc.member?.username || '';
                  const accMail  = acc.member?.mail || '';
                  const isCurrent = acc.token === token;
                  return (
                    <div
                      key={acc.key || acc.token}
                      className={`hs-acc-item${isCurrent ? ' active' : ''}`}
                      onClick={() => !isCurrent && handleSwitchAccount(acc)}
                    >
                      <div className="hs-acc-avatar">{(accUser || 'A')[0].toUpperCase()}</div>
                      <div className="hs-acc-info">
                        <span className="hs-acc-name">{accTitle} ({accUser})</span>
                        <span className="hs-acc-mail">{accMail}</span>
                      </div>
                      {isCurrent && <span className="hs-check">✓</span>}
                    </div>
                  );
                })}
              </div>
            )}
            <div className="hs-sheet-actions">
              <button className="hs-btn-outlined" onClick={() => { setShowAccountSwitcher(false); navigate('/login'); }}>
                + {t('Add New Account', 'إضافة حساب جديد')}
              </button>
              <button className="hs-btn-outlined" onClick={() => { setShowAccountSwitcher(false); navigate('/manage-accounts'); }}>
                {t('Manage Accounts', 'إدارة الحسابات')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Logout Dialog */}
      {showLogoutDialog && (
        <div className="hs-overlay" onClick={() => setShowLogoutDialog(false)}>
          <div className="hs-dialog" onClick={e => e.stopPropagation()}>
            <h3>{t('Logout options', 'خيارات تسجيل الخروج')}</h3>
            <p>{t('Choose logout scope for this device.', 'اختر نطاق تسجيل الخروج لهذا الجهاز.')}</p>
            <div className="hs-dialog-actions">
              <button className="hs-btn-text" onClick={() => setShowLogoutDialog(false)}>{t('Cancel', 'إلغاء')}</button>
              <button className="hs-btn-text" onClick={handleLogout}>{t('Logout current', 'خروج الحساب الحالي')}</button>
              <button className="hs-btn-text danger" onClick={handleLogout}>{t('Logout all', 'خروج الكل')}</button>
            </div>
          </div>
        </div>
      )}

      {/* Add Member Dialog */}
      {showAddMember && (
        <div className="hs-overlay" onClick={() => setShowAddMember(false)}>
          <div className="hs-dialog wide" onClick={e => e.stopPropagation()}>
            <div className="hs-dialog-header">
              <h3 style={{ margin: 0 }}>{t('Add New Member', 'إضافة عضو جديد')}</h3>
              <button className="hs-close-btn" onClick={() => setShowAddMember(false)}>✕</button>
            </div>
            {addError && <div className="hs-error-box">{addError}</div>}
            <div className="hs-form-group">
              <label>{t('Mail', 'البريد الإلكتروني')}</label>
              <input
                type="email"
                placeholder={t('Enter email address', 'أدخل البريد الإلكتروني')}
                value={addForm.mail}
                autoCapitalize="none"
                autoCorrect="off"
                spellCheck={false}
                onChange={e => setAddForm({ ...addForm, mail: e.target.value })}
              />
            </div>
            <div className="hs-form-group">
              <label>{t('Username', 'اسم المستخدم')}</label>
              <input
                type="text"
                placeholder={t('Enter username', 'أدخل اسم المستخدم')}
                value={addForm.username}
                onChange={e => setAddForm({ ...addForm, username: e.target.value })}
              />
            </div>
            <div className="hs-form-group">
              <label>{t('Birth Date', 'تاريخ الميلاد')}</label>
              <input
                type="date"
                value={addForm.birth_date}
                onChange={e => setAddForm({ ...addForm, birth_date: e.target.value })}
              />
            </div>
            <div className="hs-form-group">
              <label>{t('Member Type', 'نوع العضو')}</label>
              {typesLoading ? (
                <div className="hs-spinner" />
              ) : (
                <select
                  value={showNewType ? '__new__' : addForm.member_type_id}
                  onChange={e => {
                    const v = e.target.value;
                    if (v === '__new__') { setShowNewType(true); setAddForm({ ...addForm, member_type_id: '' }); }
                    else                { setShowNewType(false); setAddForm({ ...addForm, member_type_id: v }); }
                  }}
                >
                  <option value="">{t('Select type', 'اختر النوع')}</option>
                  {memberTypes.map(mt => (
                    <option key={mt._id} value={mt._id}>{mt.type}</option>
                  ))}
                  <option value="__new__">+ {t('Create new type', 'إنشاء نوع جديد')}</option>
                </select>
              )}
              {showNewType && (
                <input
                  type="text"
                  placeholder={t('Enter new type name', 'أدخل اسم النوع')}
                  value={newTypeName}
                  onChange={e => setNewTypeName(e.target.value)}
                  style={{ marginTop: 8 }}
                />
              )}
            </div>
            <div className="hs-dialog-actions">
              <button className="hs-btn-text" onClick={() => setShowAddMember(false)}>{t('Cancel', 'إلغاء')}</button>
              <button className="hs-btn-primary" onClick={handleAddMember} disabled={addLoading}>
                {addLoading ? t('Adding...', 'جارٍ الإضافة...') : t('Add Member', 'إضافة عضو')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Member Options Dialog */}
      {memberOptions && (() => {
        const { m, i } = memberOptions;
        const color = AVATAR_COLORS[i % AVATAR_COLORS.length];
        const bg    = AVATAR_BGS[i % AVATAR_BGS.length];
        const emoji = getAvatarEmoji(m.member_type_id?.type || m.memberType?.type);
        return (
          <div className="hs-overlay" onClick={() => setMemberOptions(null)}>
            <div className="hs-dialog" onClick={e => e.stopPropagation()}>
              <div className="hs-member-big-avatar" style={{ background: bg }}>
                <span>{emoji}</span>
              </div>
              <h3 className="hs-member-big-name">{m.username}</h3>
              <p className="hs-member-big-type" style={{ color }}>
                {m.member_type_id?.type || m.memberType?.type || t('Member', 'عضو')}
              </p>
              <p className="hs-member-big-mail">{m.mail}</p>
              {isParent && (
                <button
                  className="hs-btn-danger-outline"
                  onClick={() => handleDeleteMember(m._id, m.username)}
                >
                  {t('Remove Member', 'حذف العضو')}
                </button>
              )}
              <button className="hs-btn-text" style={{ display: 'block', margin: '8px auto 0' }}
                      onClick={() => setMemberOptions(null)}>
                {t('Close', 'إغلاق')}
              </button>
            </div>
          </div>
        );
      })()}

      {/* Toast */}
      {toast && <div className={`hs-toast${toast.isError ? ' error' : ''}`}>{toast.msg}</div>}
    </div>
  );
}
