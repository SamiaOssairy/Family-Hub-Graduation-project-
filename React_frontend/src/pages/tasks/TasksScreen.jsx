// ═══════════════════════════════════════════════════════════════
// TasksScreen — PERSONAL task view for EVERY member (parent & child).
// Shows only the logged-in member's own tasks, grouped by status:
//   To Do · Waiting Approval · Done (rewarded) · Needs Redo.
// A celebratory banner appears when a parent approved a task since the
// member last opened this screen (the in-app "approval notification").
// Parents also get a "Manage" button → the parent task-management hub.
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckSquare, RefreshCw, Clock, Settings, PartyPopper, X } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import { useTheme } from '../../context/ThemeContext';
import * as api from '../../api/apiService';

// ── Status → display meta ──────────────────────────────────────
function rewardLabel(task) {
  if (task.rewardType === 'money') return `${(task.moneyReward || 0).toFixed(2)} EGP`;
  if (task.rewardType === 'both') return `${task.points} pts + ${(task.moneyReward || 0).toFixed(2)} EGP`;
  return `${task.points} pts`;
}
function rewardEmoji(task) {
  if (task.rewardType === 'money') return '💰';
  if (task.rewardType === 'both') return '⭐💰';
  return '⭐';
}
function formatDeadline(deadline) {
  if (!deadline) return '';
  const date = new Date(deadline);
  const now = new Date();
  const diff = date - now;
  if (diff < 0) return 'Overdue';
  const hours = Math.floor(diff / 36e5);
  if (hours < 24) return `${hours}h left`;
  const days = Math.floor(hours / 24);
  return `${days}d left`;
}

function fromJson(json) {
  return {
    id: json._id || '',
    title: json.task_id?.title || 'Unknown Task',
    description: json.task_id?.description || '',
    isMandatory: json.task_id?.is_mandatory || false,
    status: json.status || 'assigned',
    points: json.assigned_points || 0,
    penaltyPoints: json.penalty_points || 0,
    rewardType: json.task_id?.reward_type || 'points',
    moneyReward: +(json.task_id?.money_reward || 0),
    deadline: json.deadline || null,
    notes: json.notes || '',
    assignmentApproved: json.assignment_approved !== false,
  };
}

// Section buckets
const SECTIONS = [
  { key: 'todo',     title: 'To Do',            emoji: '📋', color: '#FB8C00', desc: 'Tasks you still need to finish' },
  { key: 'waiting',  title: 'Waiting Approval', emoji: '⏳', color: '#1E88E5', desc: 'Done — waiting for a parent to approve your reward' },
  { key: 'redo',     title: 'Needs Redo',       emoji: '🔁', color: '#E53935', desc: 'A parent asked you to redo these' },
  { key: 'done',     title: 'Done & Rewarded',  emoji: '✅', color: 'var(--color-primary)', desc: 'Approved — you earned the reward!' },
  { key: 'pending',  title: 'Pending Start',    emoji: '🕓', color: '#8E24AA', desc: 'Waiting for a parent to approve the assignment' },
];

function bucketOf(task) {
  if (!task.assignmentApproved) return 'pending';
  switch (task.status) {
    case 'completed': return 'waiting';
    case 'approved':  return 'done';
    case 'rejected':
    case 'late':      return 'redo';
    default:          return 'todo'; // assigned / in_progress
  }
}

export default function TasksScreen() {
  const toast = useToast();
  const navigate = useNavigate();
  const { memberMail, username, isParent } = useAuth();
  const { language } = useTheme();
  const t = (en, ar) => (language === 'ar' ? ar : en);

  const [loading, setLoading] = useState(true);
  const [tasks, setTasks] = useState([]);
  const [memberName, setMemberName] = useState(username || '');
  const [newlyApproved, setNewlyApproved] = useState([]); // celebratory banner

  // Complete confirmation modal
  const [showComplete, setShowComplete] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [saving, setSaving] = useState(false);

  const seenKey = `seenApprovedTasks_${memberMail || 'me'}`;

  const loadTasks = useCallback(async () => {
    setLoading(true);
    try {
      const raw = await api.getMyTasks();
      const items = raw.map(fromJson);
      setTasks(items);

      if (!memberName) {
        const mail = raw[0]?.member_mail || memberMail;
        if (mail) setMemberName(mail.split('@')[0]);
      }

      // ── Detect tasks approved since last visit → notification ──
      let seen = [];
      try { seen = JSON.parse(localStorage.getItem(seenKey)) || []; } catch { seen = []; }
      const approvedNow = items.filter(it => it.status === 'approved').map(it => it.id);
      const fresh = items.filter(it => it.status === 'approved' && !seen.includes(it.id));
      if (fresh.length > 0) setNewlyApproved(fresh);
      // Persist the full current approved set as "seen"
      localStorage.setItem(seenKey, JSON.stringify(approvedNow));
    } catch (e) {
      toast('Error loading tasks: ' + e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [memberMail]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { loadTasks(); }, [loadTasks]);

  function openComplete(task) {
    setSelectedTask(task);
    setShowComplete(true);
  }

  async function confirmComplete() {
    if (!selectedTask) return;
    setSaving(true);
    try {
      const resp = await api.completeTask(selectedTask.id);
      setShowComplete(false);
      const reward = resp?.data?.rewardSummary;
      if (reward) {
        // Parent completing own task → instant reward
        const pts = reward.points_awarded || 0;
        const money = reward.money_awarded || 0;
        let msg = '🎉 ';
        if (reward.reward_type === 'points' || reward.reward_type === 'both') msg += `+${pts} pts `;
        if (reward.reward_type === 'money' || reward.reward_type === 'both') msg += `+${money.toFixed(2)} EGP`;
        toast(msg.trim(), 'success');
      } else {
        toast(t('Submitted! Waiting for a parent to approve.', 'تم الإرسال! في انتظار موافقة أحد الوالدين.'), 'success');
      }
      loadTasks();
    } catch (e) {
      toast('Error: ' + (e?.response?.data?.message || e.message), 'error');
    } finally {
      setSaving(false);
    }
  }

  // Group tasks into buckets
  const buckets = {};
  SECTIONS.forEach(s => { buckets[s.key] = []; });
  tasks.forEach(task => { buckets[bucketOf(task)].push(task); });

  const totalNewPoints = newlyApproved.reduce((sum, t2) => sum + (t2.points || 0), 0);

  // ── Task card ────────────────────────────────────────────────
  const renderCard = (task, section) => {
    const canComplete = task.assignmentApproved && ['assigned', 'in_progress'].includes(task.status);
    const canRedo = task.assignmentApproved && ['rejected', 'late'].includes(task.status);
    const overdue = task.deadline && new Date(task.deadline) < new Date() && canComplete;

    return (
      <div key={task.id} style={{
        marginBottom: 10, padding: 14,
        background: 'var(--color-white)', borderRadius: 16,
        border: `1px solid ${overdue ? '#E53935' : 'var(--color-border)'}`,
        boxShadow: 'var(--shadow-card)',
      }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: section.color, marginTop: 6, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, color: 'var(--color-text-primary)', margin: 0, wordBreak: 'break-word' }}>
              {task.title}
              {task.isMandatory && (
                <span style={{ marginLeft: 6, fontSize: 9, fontWeight: 700, color: '#C62828', background: '#FFEBEE', borderRadius: 6, padding: '1px 6px', verticalAlign: 'middle' }}>
                  {t('mandatory', 'إلزامي')}
                </span>
              )}
            </p>
            {task.description && (
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)', margin: '3px 0 0' }}>{task.description}</p>
            )}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 11 }}>{rewardEmoji(task)}</span>
              <span style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: 'var(--color-primary)' }}>{rewardLabel(task)}</span>
              {task.penaltyPoints > 0 && (
                <span style={{ fontFamily: 'var(--font-family)', fontSize: 10, fontWeight: 600, color: '#E53935' }}>
                  ⚠️ −{task.penaltyPoints} pts {t('if late', 'إذا تأخرت')}
                </span>
              )}
              {task.deadline && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: 'var(--font-family)', fontSize: 10, color: overdue ? '#E53935' : 'var(--color-text-secondary)', fontWeight: overdue ? 700 : 400 }}>
                  <Clock size={11} /> {formatDeadline(task.deadline)}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Rejection / penalty note */}
        {task.notes && (section.key === 'redo') && (
          <div style={{ marginTop: 8, padding: 10, background: '#FFEBEE', borderRadius: 10, border: '1px solid #FFCDD2' }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#C62828', margin: 0, whiteSpace: 'pre-wrap' }}>{task.notes}</p>
          </div>
        )}

        {/* Action button */}
        {(canComplete || canRedo) && (
          <button onClick={() => openComplete(task)} style={{
            width: '100%', marginTop: 10, padding: '10px 0',
            background: 'linear-gradient(90deg, var(--color-primary), var(--color-primary-light))',
            border: 'none', borderRadius: 10, cursor: 'pointer',
            fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 700, color: '#fff',
            boxShadow: '0 2px 6px rgba(0,137,123,0.25)',
          }}>
            {canRedo ? t('Mark Complete Again', 'وضع علامة مكتمل مرة أخرى') : t('Mark as Complete', 'وضع علامة مكتمل')}
          </button>
        )}
      </div>
    );
  };

  const visibleSections = SECTIONS.filter(s => buckets[s.key].length > 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('My Tasks', 'مهامي')}
        actions={
          <>
            {isParent && <IconBtn icon={Settings} onClick={() => navigate('/task-management')} />}
            <IconBtn icon={RefreshCw} onClick={loadTasks} />
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '8px 16px 88px' }}>
          {/* Member header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 0 12px' }}>
            <Avatar name={memberName || 'Me'} size={42} />
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
                {memberName || username}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                {isParent ? t('Parent', 'والد/والدة') : t('Member', 'فرد')} · {tasks.length} {t('tasks', 'مهام')}
              </p>
            </div>
          </div>

          {/* Parent shortcut to management */}
          {isParent && (
            <button onClick={() => navigate('/task-management')} style={{
              width: '100%', marginBottom: 14, padding: '11px 14px',
              background: 'var(--color-primary-surface)', border: '1px solid var(--color-border)',
              borderRadius: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10,
              fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 600, color: 'var(--color-primary)',
            }}>
              <Settings size={18} />
              {t('Manage everyone\'s tasks, approvals & templates', 'إدارة مهام الجميع والموافقات والقوالب')}
              <span style={{ marginLeft: 'auto' }}>›</span>
            </button>
          )}

          {/* 🎉 Approval notification banner */}
          {newlyApproved.length > 0 && (
            <div style={{
              marginBottom: 14, padding: 14, borderRadius: 14,
              background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
              boxShadow: 'var(--shadow-primary)', position: 'relative',
            }}>
              <button onClick={() => setNewlyApproved([])} style={{
                position: 'absolute', top: 10, right: 10, background: 'rgba(255,255,255,0.25)',
                border: 'none', borderRadius: '50%', width: 24, height: 24, cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
              }}><X size={14} /></button>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
                <PartyPopper size={22} color="#fff" />
                <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: '#fff', margin: 0 }}>
                  {t('Your task was approved!', 'تمت الموافقة على مهمتك!')}
                </p>
              </div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'rgba(255,255,255,0.95)', margin: 0 }}>
                {newlyApproved.map(t2 => t2.title).join(', ')}
                {totalNewPoints > 0 && ` — +${totalNewPoints} ${t('points earned', 'نقطة مكتسبة')} 🎉`}
              </p>
            </div>
          )}

          {/* Sections */}
          {tasks.length === 0 ? (
            <EmptyState icon={CheckSquare} message={t('No tasks assigned to you yet', 'لا توجد مهام مسندة إليك بعد')} />
          ) : (
            visibleSections.map(section => (
              <div key={section.key} style={{ marginBottom: 18 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <span style={{ fontSize: 16 }}>{section.emoji}</span>
                  <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 14, color: section.color }}>
                    {section.title}
                  </span>
                  <span style={{
                    background: 'var(--color-primary-surface)', color: 'var(--color-text-secondary)',
                    borderRadius: 10, padding: '1px 8px', fontSize: 10, fontWeight: 700,
                  }}>{buckets[section.key].length}</span>
                </div>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-hint)', margin: '0 0 8px 24px' }}>
                  {section.desc}
                </p>
                {buckets[section.key].map(task => renderCard(task, section))}
              </div>
            ))
          )}
        </div>
      )}

      {/* Complete confirmation */}
      <Modal
        open={showComplete}
        onClose={() => setShowComplete(false)}
        title={`✅ ${t('Complete Task', 'إكمال المهمة')}`}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowComplete(false)} />
            <ModalPrimaryBtn label={saving ? '…' : t('Yes, I finished it', 'نعم، لقد أنهيتها')} disabled={saving} onClick={confirmComplete} />
          </>
        }
      >
        {selectedTask && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)' }}>
              {t('Mark', 'وضع علامة')} "<strong>{selectedTask.title}</strong>" {t('as complete?', 'كمكتملة؟')}
            </p>
            <div style={{ padding: 10, background: 'var(--color-primary-surface)', borderRadius: 10, border: '1px solid var(--color-border)' }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)', margin: 0 }}>
                {t('Reward', 'المكافأة')}: {rewardLabel(selectedTask)}
              </p>
              {!isParent && (
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '4px 0 0' }}>
                  {t('A parent will review it before the reward is added.', 'سيقوم أحد الوالدين بمراجعتها قبل إضافة المكافأة.')}
                </p>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
