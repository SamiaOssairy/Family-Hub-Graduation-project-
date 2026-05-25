// ═══════════════════════════════════════════════════════════════
// Task Management Screen (Parent) — mirrors task_management_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, RefreshCw, ClipboardList, Clock, Users, CheckCircle, ChevronDown, ChevronUp } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn, DangerBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

const TABS = ['Templates', 'Pending Assignments', 'Waiting Approval', 'All Assigned'];

export default function TaskManagementScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const { isParent } = useAuth();

  const [activeTab, setActiveTab]       = useState(0);
  const [loading, setLoading]           = useState(true);
  const [templates, setTemplates]       = useState([]);
  const [pendingAssign, setPendingAssign] = useState([]);
  const [waitingApproval, setWaitingApproval] = useState([]);
  const [allAssigned, setAllAssigned]   = useState([]);
  const [members, setMembers]           = useState([]);
  const [categories, setCategories]     = useState([]);
  const [units, setUnits]               = useState([]);

  // Create task modal
  const [showCreate, setShowCreate]     = useState(false);
  const [newTitle, setNewTitle]         = useState('');
  const [newDesc, setNewDesc]           = useState('');
  const [newCatId, setNewCatId]         = useState('');
  const [newRewardType, setNewRewardType] = useState('points');
  const [newMoneyReward, setNewMoneyReward] = useState('');
  const [saving, setSaving]             = useState(false);

  // Assign task modal
  const [showAssign, setShowAssign]     = useState(false);
  const [assignTaskId, setAssignTaskId] = useState('');
  const [assignMemberMail, setAssignMemberMail] = useState('');
  const [assignPoints, setAssignPoints] = useState('10');
  const [assignDeadline, setAssignDeadline] = useState('');

  // Penalty modal
  const [showPenalty, setShowPenalty]   = useState(false);
  const [penaltyTaskId, setPenaltyTaskId] = useState('');
  const [penaltyPoints, setPenaltyPoints] = useState('5');
  const [penaltyNotes, setPenaltyNotes] = useState('');

  // Reject notes modal
  const [showRejectNotes, setShowRejectNotes] = useState(false);
  const [rejectTaskId, setRejectTaskId] = useState('');
  const [rejectNotes, setRejectNotes]   = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [tmpl, pend, waiting, assigned, mems, cats] = await Promise.all([
        api.getAllTasks(),
        isParent ? api.getPendingAssignments() : Promise.resolve([]),
        isParent ? api.getTasksWaitingApproval() : Promise.resolve([]),
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
      toast('Error: ' + e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [isParent]);

  useEffect(() => { load(); }, [load]);

  // ── Create task ──────────────────────────────────────────────
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
      toast('Task template created!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Delete task template ─────────────────────────────────────
  async function deleteTemplate(taskId) {
    try {
      await api.deleteTask(taskId);
      toast('Task deleted');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  // ── Assign task ──────────────────────────────────────────────
  function openAssign(templateId) {
    setAssignTaskId(templateId);
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
        penalty_points: 0,
        deadline: assignDeadline
          ? new Date(assignDeadline).toISOString()
          : new Date(Date.now() + 7 * 864e5).toISOString(),
        priority: 0,
      });
      setShowAssign(false);
      toast('Task assigned!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Approve/reject assignment ────────────────────────────────
  async function handleAssignDecision(id, approved) {
    try {
      await api.approveTaskAssignment(id, approved);
      toast(approved ? 'Assignment approved!' : 'Assignment rejected');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  // ── Approve completion ────────────────────────────────────────
  async function approveCompletion(id, approved) {
    if (!approved) {
      setRejectTaskId(id); setRejectNotes(''); setShowRejectNotes(true);
      return;
    }
    try {
      await api.approveTaskCompletion(id, true);
      toast('Completion approved!');
      load();
    } catch (e) {
      toast(e.message, 'error');
    }
  }

  async function rejectWithNotes() {
    setSaving(true);
    try {
      await api.approveTaskCompletion(rejectTaskId, false, rejectNotes);
      setShowRejectNotes(false);
      toast('Completion rejected');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Apply penalty ─────────────────────────────────────────────
  function openPenalty(id) {
    setPenaltyTaskId(id); setPenaltyPoints('5'); setPenaltyNotes('');
    setShowPenalty(true);
  }

  async function submitPenalty() {
    setSaving(true);
    try {
      await api.applyPenalty(penaltyTaskId, +(penaltyPoints || 5), penaltyNotes);
      setShowPenalty(false);
      toast('Penalty applied');
      load();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Render helpers ────────────────────────────────────────────
  const card = (children, style = {}) => (
    <div style={{
      background: 'var(--color-white)', borderRadius: 16,
      border: '1px solid var(--color-border)',
      padding: 14, marginBottom: 10,
      boxShadow: 'var(--shadow-card)',
      ...style,
    }}>{children}</div>
  );

  const actionBtn = (label, onClick, color = 'var(--color-primary)', secondary = false) => (
    <button onClick={onClick} style={{
      padding: '6px 12px', borderRadius: 8, border: 'none',
      fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
      cursor: 'pointer',
      background: secondary ? 'transparent' : color,
      color: secondary ? color : '#fff',
      border: secondary ? `1px solid ${color}` : 'none',
    }}>{label}</button>
  );

  const tabData = [templates, pendingAssign, waitingApproval, allAssigned];
  const counts  = tabData.map(d => d.length);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('taskManagement')}
        actions={
          <>
            <IconBtn icon={RefreshCw} onClick={load} />
            {isParent && <IconBtn icon={Plus} onClick={() => setShowCreate(true)} />}
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '0 0 20px' }}>
          {/* Tab bar — scrollable */}
          <div style={{
            display: 'flex', gap: 0,
            overflowX: 'auto', padding: '8px 16px 0',
            borderBottom: '1px solid var(--color-border)',
          }}>
            {TABS.map((tab, i) => (
              <button key={i} onClick={() => setActiveTab(i)} style={{
                padding: '8px 14px', flexShrink: 0,
                background: 'none', border: 'none',
                fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: activeTab === i ? 700 : 500,
                color: activeTab === i ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                cursor: 'pointer',
                borderBottom: activeTab === i ? '2px solid var(--color-primary)' : '2px solid transparent',
                position: 'relative',
              }}>
                {tab}
                {counts[i] > 0 && (
                  <span style={{
                    marginLeft: 4, padding: '1px 6px',
                    background: i === 0 ? 'var(--color-primary-surface)' : '#FFEBEE',
                    color: i === 0 ? 'var(--color-primary)' : '#E53935',
                    borderRadius: 10, fontSize: 9, fontWeight: 700,
                  }}>{counts[i]}</span>
                )}
              </button>
            ))}
          </div>

          <div style={{ padding: '12px 16px' }}>
            {/* ── Tab 0: Templates ── */}
            {activeTab === 0 && (
              templates.length === 0
                ? <EmptyState icon={ClipboardList} message={t('noTemplates')} />
                : templates.map(tmpl => card(
                  <div key={tmpl._id}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                      <div style={{ flex: 1 }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>
                          {tmpl.title}
                        </p>
                        {tmpl.description && (
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>
                            {tmpl.description}
                          </p>
                        )}
                        <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
                          <span style={{
                            background: 'var(--color-primary-surface)', color: 'var(--color-primary)',
                            padding: '2px 8px', borderRadius: 8, fontSize: 10, fontWeight: 600,
                          }}>
                            {tmpl.reward_type === 'points' ? '⭐ Points' : tmpl.reward_type === 'money' ? '💰 Money' : '⭐💰 Both'}
                          </span>
                          {tmpl.category_id?.title && (
                            <span style={{
                              background: 'var(--color-border-light)', color: 'var(--color-text-secondary)',
                              padding: '2px 8px', borderRadius: 8, fontSize: 10,
                            }}>{tmpl.category_id.title}</span>
                          )}
                        </div>
                      </div>
                      {isParent && (
                        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                          {actionBtn('Assign', () => openAssign(tmpl._id), 'var(--color-primary)')}
                          {actionBtn('Delete', () => deleteTemplate(tmpl._id), '#E53935')}
                        </div>
                      )}
                    </div>
                  </div>
                ))
            )}

            {/* ── Tab 1: Pending Assignments ── */}
            {activeTab === 1 && (
              pendingAssign.length === 0
                ? <EmptyState icon={Clock} message={t('noPendingAssignments')} />
                : pendingAssign.map(item => card(
                  <div key={item._id}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <Avatar name={item.member_mail?.split('@')[0] || '?'} size={32} />
                        <div>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                            {item.task_id?.title || 'Unknown Task'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                            {item.member_mail}
                          </p>
                        </div>
                      </div>
                      <span style={{ fontSize: 12, color: 'var(--color-text-secondary)', fontFamily: 'var(--font-family)' }}>
                        {item.assigned_points || 0} pts
                      </span>
                    </div>
                    {isParent && (
                      <div style={{ display: 'flex', gap: 8 }}>
                        {actionBtn('✓ Approve', () => handleAssignDecision(item._id, true))}
                        {actionBtn('✗ Reject', () => handleAssignDecision(item._id, false), '#E53935')}
                      </div>
                    )}
                  </div>
                ))
            )}

            {/* ── Tab 2: Waiting Approval ── */}
            {activeTab === 2 && (
              waitingApproval.length === 0
                ? <EmptyState icon={CheckCircle} message={t('noCompletions')} />
                : waitingApproval.map(item => card(
                  <div key={item._id}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <Avatar name={item.member_mail?.split('@')[0] || '?'} size={32} />
                        <div>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                            {item.task_id?.title || 'Unknown Task'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                            {item.member_mail}
                          </p>
                        </div>
                      </div>
                      <StatusBadge status={item.status} />
                    </div>
                    {isParent && (
                      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        {actionBtn('✓ Approve', () => approveCompletion(item._id, true))}
                        {actionBtn('✗ Reject', () => approveCompletion(item._id, false), '#E53935')}
                        {actionBtn('⚑ Penalty', () => openPenalty(item._id), '#FB8C00')}
                      </div>
                    )}
                  </div>
                ))
            )}

            {/* ── Tab 3: All Assigned ── */}
            {activeTab === 3 && (
              allAssigned.length === 0
                ? <EmptyState icon={Users} message="No assigned tasks" />
                : allAssigned.map(item => card(
                  <div key={item._id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flex: 1, minWidth: 0 }}>
                      <Avatar name={item.member_mail?.split('@')[0] || '?'} size={30} />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12, color: 'var(--color-text-primary)', margin: 0,
                          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {item.task_id?.title || 'Unknown Task'}
                        </p>
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)', margin: 0 }}>
                          {item.member_mail}
                        </p>
                      </div>
                    </div>
                    <StatusBadge status={item.status} />
                  </div>
                ))
            )}
          </div>
        </div>
      )}

      {/* Create Task Modal */}
      <Modal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        title={t('createTask')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowCreate(false)} />
            <ModalPrimaryBtn label={saving ? '…' : t('createTask')} disabled={saving || !newTitle.trim()} onClick={createTask} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('taskName')} value={newTitle} onChange={setNewTitle} required />
          <FormField label={t('description')} value={newDesc} onChange={setNewDesc} />
          {categories.length > 0 && (
            <SelectField
              label={t('category')}
              value={newCatId}
              onChange={setNewCatId}
              options={categories.map(c => ({ value: c._id, label: c.title || c.name }))}
              required
            />
          )}
          <SelectField
            label={t('rewardType')}
            value={newRewardType}
            onChange={setNewRewardType}
            options={[
              { value: 'points', label: '⭐ Points' },
              { value: 'money', label: '💰 Money' },
              { value: 'both', label: '⭐💰 Both' },
            ]}
          />
          {newRewardType !== 'points' && (
            <FormField label={t('moneyReward')} value={newMoneyReward} onChange={setNewMoneyReward} type="number" min="0" step="0.01" />
          )}
        </div>
      </Modal>

      {/* Assign Task Modal */}
      <Modal
        open={showAssign}
        onClose={() => setShowAssign(false)}
        title={t('assignTask')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowAssign(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Assign'} disabled={saving} onClick={assignTask} />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <SelectField
            label={t('assignTo')}
            value={assignMemberMail}
            onChange={setAssignMemberMail}
            options={members.map(m => ({ value: m.mail, label: m.username || m.mail }))}
            required
          />
          <FormField label={t('assignedPoints')} value={assignPoints} onChange={setAssignPoints} type="number" min="0" />
          <FormField label={t('deadline')} value={assignDeadline} onChange={setAssignDeadline} type="datetime-local" />
        </div>
      </Modal>

      {/* Penalty Modal */}
      <Modal
        open={showPenalty}
        onClose={() => setShowPenalty(false)}
        title={t('applyPenalty')}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowPenalty(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Apply'} disabled={saving} onClick={submitPenalty} color="#FB8C00" />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('penaltyPoints')} value={penaltyPoints} onChange={setPenaltyPoints} type="number" min="1" />
          <FormField label={t('notes')} value={penaltyNotes} onChange={setPenaltyNotes} rows={2} />
        </div>
      </Modal>

      {/* Reject Notes Modal */}
      <Modal
        open={showRejectNotes}
        onClose={() => setShowRejectNotes(false)}
        title="Reject Completion"
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowRejectNotes(false)} />
            <DangerBtn label={saving ? '…' : 'Reject'} disabled={saving} onClick={rejectWithNotes} />
          </>
        }
      >
        <FormField label="Rejection Reason (optional)" value={rejectNotes} onChange={setRejectNotes} rows={3} />
      </Modal>
    </div>
  );
}
