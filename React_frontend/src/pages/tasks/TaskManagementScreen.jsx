// ═══════════════════════════════════════════════════════════════════════════════
// TaskManagementScreen — PARENT-ONLY management hub.
// Tabs: All Tasks · Approvals (two gates) · Templates · History.
// Non-parents get a "Parents only" screen.
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, RefreshCw, ClipboardList, Users, CheckCircle, History as HistoryIcon, ShieldOff, Clock } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import * as api from '../../api/apiService';

const FINISHED = ['approved', 'rejected', 'late'];

export default function TaskManagementScreen() {
  const toast = useToast();
  const navigate = useNavigate();
  const { isParent } = useAuth();
  const { language } = useTheme();
  const t = (en, ar) => (language === 'ar' ? ar : en);

  const TABS = [
    { label: t('All Tasks', 'كل المهام'), icon: Users },
    { label: t('Approvals', 'الموافقات'), icon: CheckCircle },
    { label: t('Templates', 'القوالب'), icon: ClipboardList },
    { label: t('History', 'السجل'), icon: HistoryIcon },
  ];

  const [activeTab, setActiveTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [templates, setTemplates] = useState([]);
  const [pendingAssign, setPendingAssign] = useState([]);
  const [waitingApproval, setWaitingApproval] = useState([]);
  const [allAssigned, setAllAssigned] = useState([]);
  const [members, setMembers] = useState([]);
  const [categories, setCategories] = useState([]);
  const [allFilter, setAllFilter] = useState('active'); // active | waiting | all

  // Create template modal
  const [showCreate, setShowCreate] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newCatId, setNewCatId] = useState('');
  const [newRewardType, setNewRewardType] = useState('points');
  const [newMoneyReward, setNewMoneyReward] = useState('');
  const [saving, setSaving] = useState(false);

  // Assign modal
  const [showAssign, setShowAssign] = useState(false);
  const [assignTaskId, setAssignTaskId] = useState('');
  const [assignTaskTitle, setAssignTaskTitle] = useState('');
  const [assignMemberMail, setAssignMemberMail] = useState('');
  const [assignPoints, setAssignPoints] = useState('10');
  const [assignPenalty, setAssignPenalty] = useState('0');
  const [assignDeadline, setAssignDeadline] = useState('');

  // Penalty modal
  const [showPenalty, setShowPenalty] = useState(false);
  const [penaltyTaskId, setPenaltyTaskId] = useState('');
  const [penaltyPoints, setPenaltyPoints] = useState('5');
  const [penaltyNotes, setPenaltyNotes] = useState('');

  // Reject notes modal
  const [showRejectNotes, setShowRejectNotes] = useState(false);
  const [rejectTaskId, setRejectTaskId] = useState('');
  const [rejectNotes, setRejectNotes] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [tmpl, pend, waiting, assigned, mems, cats] = await Promise.all([
        api.getAllTasks(),
        api.getPendingAssignments().catch(() => []),
        api.getTasksWaitingApproval().catch(() => []),
        api.getAllAssignedTasks(),
        api.getAllMembers(),
        api.getAllTaskCategories(),
      ]);
      setTemplates(tmpl);
      setPendingAssign(pend);
      setWaitingApproval(waiting);
      setAllAssigned(assigned);
      setMembers(mems);
      setCategories(cats);
      if (cats.length > 0) setNewCatId(cats[0]._id);
      if (mems.length > 0) setAssignMemberMail(mems[0].mail || '');
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { if (isParent) load(); else setLoading(false); }, [isParent, load]);

  // ── Actions ──────────────────────────────────────────────────
  async function createTask() {
    if (!newTitle.trim() || !newCatId) return;
    setSaving(true);
    try {
      await api.createTask({
        title: newTitle.trim(),
        description: newDesc.trim(),
        category_id: newCatId,
        is_mandatory: false,
        reward_type: newRewardType,
        money_reward: newRewardType !== 'points' ? +(newMoneyReward || 0) : 0,
      });
      setShowCreate(false);
      setNewTitle(''); setNewDesc(''); setNewMoneyReward('');
      toast(t('Template created!', 'تم إنشاء القالب!'), 'success');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function deleteTemplate(taskId) {
    try {
      await api.deleteTask(taskId);
      toast(t('Template deleted', 'تم حذف القالب'));
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  function openAssign(tmpl) {
    setAssignTaskId(tmpl._id);
    setAssignTaskTitle(tmpl.title || '');
    setAssignPoints('10'); setAssignPenalty('0'); setAssignDeadline('');
    setShowAssign(true);
  }

  async function assignTask() {
    if (!assignTaskId || !assignMemberMail) return;
    setSaving(true);
    try {
      await api.assignTask({
        task_id: assignTaskId,
        member_mail: assignMemberMail,
        assigned_points: +(assignPoints || 10),
        penalty_points: +(assignPenalty || 0),
        deadline: assignDeadline
          ? new Date(assignDeadline).toISOString()
          : new Date(Date.now() + 7 * 864e5).toISOString(),
        priority: 0,
      });
      setShowAssign(false);
      toast(t('Task assigned!', 'تم إسناد المهمة!'), 'success');
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  async function handleAssignDecision(id, approved) {
    try {
      await api.approveTaskAssignment(id, approved);
      toast(approved ? t('Assignment approved', 'تمت الموافقة على الإسناد') : t('Assignment rejected', 'تم رفض الإسناد'));
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function approveCompletion(id, approved) {
    if (!approved) { setRejectTaskId(id); setRejectNotes(''); setShowRejectNotes(true); return; }
    try {
      await api.approveTaskCompletion(id, true);
      toast(t('Approved — reward released!', 'تمت الموافقة — تم منح المكافأة!'), 'success');
      load();
    } catch (e) { toast(e.message, 'error'); }
  }

  async function rejectWithNotes() {
    setSaving(true);
    try {
      await api.approveTaskCompletion(rejectTaskId, false, rejectNotes);
      setShowRejectNotes(false);
      toast(t('Sent back for redo', 'تمت الإعادة للتصحيح'));
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  function openPenalty(id) {
    setPenaltyTaskId(id); setPenaltyPoints('5'); setPenaltyNotes('');
    setShowPenalty(true);
  }

  async function submitPenalty() {
    setSaving(true);
    try {
      await api.applyPenalty(penaltyTaskId, +(penaltyPoints || 5), penaltyNotes);
      setShowPenalty(false);
      toast(t('Penalty applied', 'تم تطبيق الخصم'));
      load();
    } catch (e) { toast(e.message, 'error'); }
    finally { setSaving(false); }
  }

  // ── Guard: parents only ──────────────────────────────────────
  if (!isParent) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
        <AppBar title={t('Task Management', 'إدارة المهام')} />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 24px', textAlign: 'center' }}>
          <div style={{ width: 80, height: 80, borderRadius: 20, background: 'var(--color-primary-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 20 }}>
            <ShieldOff size={40} color="var(--color-text-hint)" />
          </div>
          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 18, color: 'var(--color-text-primary)', margin: '0 0 8px' }}>
            {t('Parents Only', 'للوالدين فقط')}
          </p>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, color: 'var(--color-text-secondary)', margin: '0 0 20px', maxWidth: 280, lineHeight: 1.5 }}>
            {t('Task management is handled by parents. You can see your own tasks on the Tasks screen.', 'إدارة المهام يقوم بها الوالدان. يمكنك رؤية مهامك في شاشة المهام.')}
          </p>
          <button onClick={() => navigate('/tasks')} style={{
            padding: '11px 22px', borderRadius: 12, border: 'none', cursor: 'pointer',
            background: 'var(--color-primary)', color: '#fff',
            fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 600,
          }}>{t('Go to My Tasks', 'الذهاب إلى مهامي')}</button>
        </div>
      </div>
    );
  }

  // ── Shared card shell ────────────────────────────────────────
  const card = (children, key, style = {}) => (
    <div key={key} style={{
      background: 'var(--color-white)', borderRadius: 16, border: '1px solid var(--color-border)',
      padding: 14, marginBottom: 10, boxShadow: 'var(--shadow-card)', ...style,
    }}>{children}</div>
  );
  const actionBtn = (label, onClick, color = 'var(--color-primary)', secondary = false) => (
    <button onClick={onClick} style={{
      padding: '6px 12px', borderRadius: 8,
      fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, cursor: 'pointer',
      background: secondary ? 'transparent' : color, color: secondary ? color : '#fff',
      border: secondary ? `1px solid ${color}` : 'none',
    }}>{label}</button>
  );

  const memberRow = (item, right) => (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginBottom: 8 }}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', minWidth: 0 }}>
        <Avatar name={item.member_mail?.split('@')[0] || '?'} size={32} />
        <div style={{ minWidth: 0 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {item.task_id?.title || 'Unknown Task'}
          </p>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
            {item.member_mail}
          </p>
        </div>
      </div>
      {right}
    </div>
  );

  // ── Derived lists ────────────────────────────────────────────
  const activeAssigned = allAssigned.filter(x => ['assigned', 'in_progress'].includes(x.status));
  const finishedAssigned = allAssigned.filter(x => FINISHED.includes(x.status));
  const allFiltered =
    allFilter === 'active' ? activeAssigned
    : allFilter === 'waiting' ? allAssigned.filter(x => x.status === 'completed')
    : allAssigned;

  const counts = [activeAssigned.length, pendingAssign.length + waitingApproval.length, templates.length, finishedAssigned.length];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('Task Management', 'إدارة المهام')}
        actions={
          <>
            <IconBtn icon={RefreshCw} onClick={load} />
            <IconBtn icon={Plus} onClick={() => setShowCreate(true)} />
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '0 0 24px' }}>
          {/* Tabs */}
          <div style={{ display: 'flex', overflowX: 'auto', padding: '8px 12px 0', borderBottom: '1px solid var(--color-border)' }}>
            {TABS.map((tab, i) => (
              <button key={i} onClick={() => setActiveTab(i)} style={{
                padding: '9px 14px', flexShrink: 0, background: 'none', border: 'none',
                display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer',
                fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: activeTab === i ? 700 : 500,
                color: activeTab === i ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                borderBottom: activeTab === i ? '2px solid var(--color-primary)' : '2px solid transparent',
              }}>
                <tab.icon size={15} />
                {tab.label}
                {counts[i] > 0 && (
                  <span style={{
                    padding: '1px 6px', background: i === 1 ? '#FFEBEE' : 'var(--color-primary-surface)',
                    color: i === 1 ? '#E53935' : 'var(--color-primary)', borderRadius: 10, fontSize: 9, fontWeight: 700,
                  }}>{counts[i]}</span>
                )}
              </button>
            ))}
          </div>

          <div style={{ padding: '12px 16px' }}>
            {/* ── Tab 0: All Tasks ── */}
            {activeTab === 0 && (
              <>
                <div style={{ display: 'flex', gap: 6, marginBottom: 12 }}>
                  {[
                    { k: 'active', label: t('Active', 'نشطة') },
                    { k: 'waiting', label: t('Submitted', 'مُرسلة') },
                    { k: 'all', label: t('All', 'الكل') },
                  ].map(f => (
                    <button key={f.k} onClick={() => setAllFilter(f.k)} style={{
                      padding: '5px 12px', borderRadius: 20, cursor: 'pointer',
                      border: `1px solid ${allFilter === f.k ? 'var(--color-primary)' : 'var(--color-border)'}`,
                      background: allFilter === f.k ? 'var(--color-primary)' : 'var(--color-white)',
                      color: allFilter === f.k ? '#fff' : 'var(--color-text-secondary)',
                      fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
                    }}>{f.label}</button>
                  ))}
                </div>
                {allFiltered.length === 0
                  ? <EmptyState icon={Users} message={t('No tasks here', 'لا توجد مهام هنا')} />
                  : allFiltered.map(item => card(
                    <>
                      {memberRow(item, <StatusBadge status={item.status} />)}
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', paddingLeft: 40 }}>
                        <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-primary)', fontWeight: 600 }}>
                          ⭐ {item.assigned_points || 0} pts
                        </span>
                        {item.penalty_points > 0 && (
                          <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#E53935', fontWeight: 600 }}>
                            ⚠️ −{item.penalty_points} {t('if late', 'إذا تأخر')}
                          </span>
                        )}
                        {item.deadline && (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)' }}>
                            <Clock size={10} /> {new Date(item.deadline).toLocaleDateString()}
                          </span>
                        )}
                        {['assigned', 'in_progress'].includes(item.status) && (
                          <button onClick={() => openPenalty(item._id)} style={{
                            marginLeft: 'auto', padding: '4px 10px', borderRadius: 8, border: '1px solid #FB8C00',
                            background: 'transparent', color: '#FB8C00', cursor: 'pointer',
                            fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600,
                          }}>⚑ {t('Penalty', 'خصم')}</button>
                        )}
                      </div>
                    </>,
                    item._id,
                  ))
                }
              </>
            )}

            {/* ── Tab 1: Approvals (two gates) ── */}
            {activeTab === 1 && (
              <>
                {/* Gate 1: assignment requests */}
                <SectionTitle
                  emoji="🕓" color="#8E24AA"
                  title={t('Assignment Requests', 'طلبات الإسناد')}
                  desc={t('A member assigned a task — approve before it starts', 'أسند أحد الأفراد مهمة — وافق قبل أن تبدأ')}
                  count={pendingAssign.length}
                />
                {pendingAssign.length === 0
                  ? <MutedEmpty text={t('No assignment requests', 'لا توجد طلبات إسناد')} />
                  : pendingAssign.map(item => card(
                    <>
                      {memberRow(item, <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)' }}>{item.assigned_points || 0} pts</span>)}
                      <div style={{ display: 'flex', gap: 8 }}>
                        {actionBtn('✓ ' + t('Approve', 'موافقة'), () => handleAssignDecision(item._id, true))}
                        {actionBtn('✗ ' + t('Reject', 'رفض'), () => handleAssignDecision(item._id, false), '#E53935')}
                      </div>
                    </>,
                    item._id,
                  ))
                }

                {/* Gate 2: completed work review */}
                <div style={{ marginTop: 22 }}>
                  <SectionTitle
                    emoji="✅" color="#1E88E5"
                    title={t('Completed — Review', 'مكتملة — مراجعة')}
                    desc={t('Finished work — approve to release the reward', 'عمل منتهٍ — وافق لمنح المكافأة')}
                    count={waitingApproval.length}
                  />
                  {waitingApproval.length === 0
                    ? <MutedEmpty text={t('Nothing waiting for review', 'لا يوجد شيء للمراجعة')} />
                    : waitingApproval.map(item => card(
                      <>
                        {memberRow(item, <StatusBadge status={item.status} />)}
                        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                          {actionBtn('✓ ' + t('Approve & Reward', 'موافقة ومكافأة'), () => approveCompletion(item._id, true))}
                          {actionBtn('↩ ' + t('Redo', 'إعادة'), () => approveCompletion(item._id, false), '#E53935', true)}
                          {actionBtn('⚑ ' + t('Penalty', 'خصم'), () => openPenalty(item._id), '#FB8C00', true)}
                        </div>
                      </>,
                      item._id,
                    ))
                  }
                </div>
              </>
            )}

            {/* ── Tab 2: Templates ── */}
            {activeTab === 2 && (
              templates.length === 0
                ? <EmptyState icon={ClipboardList} message={t('No templates yet — tap + to create one', 'لا توجد قوالب — اضغط + لإنشاء واحد')} />
                : templates.map(tmpl => card(
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>{tmpl.title}</p>
                      {tmpl.description && (
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>{tmpl.description}</p>
                      )}
                      <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
                        <span style={{ background: 'var(--color-primary-surface)', color: 'var(--color-primary)', padding: '2px 8px', borderRadius: 8, fontSize: 10, fontWeight: 600 }}>
                          {tmpl.reward_type === 'points' ? '⭐ Points' : tmpl.reward_type === 'money' ? '💰 Money' : '⭐💰 Both'}
                        </span>
                        {tmpl.category_id?.title && (
                          <span style={{ background: 'var(--color-border-light)', color: 'var(--color-text-secondary)', padding: '2px 8px', borderRadius: 8, fontSize: 10 }}>{tmpl.category_id.title}</span>
                        )}
                      </div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flexShrink: 0 }}>
                      {actionBtn(t('Assign', 'إسناد'), () => openAssign(tmpl), 'var(--color-primary)')}
                      {actionBtn(t('Delete', 'حذف'), () => deleteTemplate(tmpl._id), '#E53935', true)}
                    </div>
                  </div>,
                  tmpl._id,
                ))
            )}

            {/* ── Tab 3: History ── */}
            {activeTab === 3 && (
              finishedAssigned.length === 0
                ? <EmptyState icon={HistoryIcon} message={t('No finished tasks yet', 'لا توجد مهام منتهية بعد')} />
                : finishedAssigned.map(item => card(
                  memberRow(item, (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <StatusBadge status={item.status} />
                    </div>
                  )),
                  item._id,
                  { marginBottom: 8 },
                ))
            )}
          </div>
        </div>
      )}

      {/* Create Template Modal */}
      <Modal open={showCreate} onClose={() => setShowCreate(false)} title={t('Create Template', 'إنشاء قالب')}
        actions={<><ModalCancelBtn onClick={() => setShowCreate(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Create', 'إنشاء')} disabled={saving || !newTitle.trim()} onClick={createTask} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('Task Name', 'اسم المهمة')} value={newTitle} onChange={setNewTitle} required />
          <FormField label={t('Description', 'الوصف')} value={newDesc} onChange={setNewDesc} />
          {categories.length > 0 && (
            <SelectField label={t('Category', 'الفئة')} value={newCatId} onChange={setNewCatId}
              options={categories.map(c => ({ value: c._id, label: c.title || c.name }))} required />
          )}
          <SelectField label={t('Reward Type', 'نوع المكافأة')} value={newRewardType} onChange={setNewRewardType}
            options={[{ value: 'points', label: '⭐ Points' }, { value: 'money', label: '💰 Money' }, { value: 'both', label: '⭐💰 Both' }]} />
          {newRewardType !== 'points' && (
            <FormField label={t('Money Reward (EGP)', 'المكافأة المالية')} value={newMoneyReward} onChange={setNewMoneyReward} type="number" min="0" step="0.01" />
          )}
        </div>
      </Modal>

      {/* Assign Modal */}
      <Modal open={showAssign} onClose={() => setShowAssign(false)} title={`${t('Assign', 'إسناد')}: ${assignTaskTitle}`}
        actions={<><ModalCancelBtn onClick={() => setShowAssign(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Assign', 'إسناد')} disabled={saving || !assignMemberMail} onClick={assignTask} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <SelectField label={t('Assign To', 'إسناد إلى')} value={assignMemberMail} onChange={setAssignMemberMail}
            options={members.map(m => ({ value: m.mail, label: m.username || m.mail }))} required />
          <FormField label={t('Reward Points', 'نقاط المكافأة')} value={assignPoints} onChange={setAssignPoints} type="number" min="0" />
          <FormField label={t('Penalty Points (if missed by deadline)', 'نقاط الخصم (عند تجاوز الموعد)')} value={assignPenalty} onChange={setAssignPenalty} type="number" min="0" />
          <FormField label={t('Deadline', 'الموعد النهائي')} value={assignDeadline} onChange={setAssignDeadline} type="datetime-local" />
        </div>
      </Modal>

      {/* Penalty Modal */}
      <Modal open={showPenalty} onClose={() => setShowPenalty(false)} title={t('Apply Penalty', 'تطبيق خصم')}
        actions={<><ModalCancelBtn onClick={() => setShowPenalty(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Apply', 'تطبيق')} disabled={saving} onClick={submitPenalty} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>
            {t('Deduct points for a missed or late task. This is subtracted from the member\'s points wallet.', 'خصم النقاط لمهمة متأخرة أو غير منجزة. يُخصم من محفظة نقاط الفرد.')}
          </p>
          <FormField label={t('Penalty Points', 'نقاط الخصم')} value={penaltyPoints} onChange={setPenaltyPoints} type="number" min="1" />
          <FormField label={t('Reason (optional)', 'السبب (اختياري)')} value={penaltyNotes} onChange={setPenaltyNotes} />
        </div>
      </Modal>

      {/* Reject / Redo Notes Modal */}
      <Modal open={showRejectNotes} onClose={() => setShowRejectNotes(false)} title={t('Send Back for Redo', 'إعادة للتصحيح')}
        actions={<><ModalCancelBtn onClick={() => setShowRejectNotes(false)} /><ModalPrimaryBtn label={saving ? '…' : t('Send Back', 'إعادة')} disabled={saving} onClick={rejectWithNotes} /></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>
            {t('Tell them what to fix. They can mark it complete again.', 'أخبرهم بما يجب إصلاحه. يمكنهم وضع علامة مكتمل مرة أخرى.')}
          </p>
          <FormField label={t('Note', 'ملاحظة')} value={rejectNotes} onChange={setRejectNotes} rows={3} />
        </div>
      </Modal>
    </div>
  );
}

// ── Small helpers ──────────────────────────────────────────────
function SectionTitle({ emoji, color, title, desc, count }) {
  return (
    <div style={{ marginBottom: 8 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ fontSize: 15 }}>{emoji}</span>
        <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color }}>{title}</span>
        {count > 0 && (
          <span style={{ background: '#FFEBEE', color: '#E53935', borderRadius: 10, padding: '1px 8px', fontSize: 10, fontWeight: 700 }}>{count}</span>
        )}
      </div>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)', margin: '2px 0 0 23px' }}>{desc}</p>
    </div>
  );
}

function MutedEmpty({ text }) {
  return (
    <div style={{ padding: 16, textAlign: 'center', background: 'var(--color-white)', borderRadius: 12, border: '1px dashed var(--color-border)', marginBottom: 8 }}>
      <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-hint)', margin: 0 }}>{text}</p>
    </div>
  );
}
