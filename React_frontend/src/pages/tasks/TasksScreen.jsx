// ═══════════════════════════════════════════════════════════════
// Tasks Screen — mirrors Flutter tasks_screen.dart exactly
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { CheckSquare, RefreshCw, Trash2, X, Plus, Clock, CheckCircle, CircleDot } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import Modal, { ModalCancelBtn, ModalPrimaryBtn } from '../../components/common/Modal';
import FormField, { SelectField } from '../../components/common/FormField';
import { useToast } from '../../components/common/Toast';
import { useAuth } from '../../context/AuthContext';
import * as api from '../../api/apiService';

// ── Helpers ───────────────────────────────────────────────────
function progressFromStatus(status) {
  if (status === 'completed' || status === 'approved') return 1.0;
  if (status === 'pending_approval') return 0.8;
  if (status === 'in_progress') return 0.5;
  return 0.0;
}

function dotColorFromStatus(status) {
  const map = {
    approved: '#00BFA5', completed: '#1E88E5', pending_approval: '#1E88E5',
    in_progress: '#1E88E5', rejected: '#FF5252', late: '#FF5252',
  };
  return map[status] || '#FB8C00';
}

function formatDeadlineShort(deadline) {
  if (!deadline) return '';
  try {
    const date = new Date(deadline);
    const now = new Date();
    const diff = date - now;
    if (diff < 0) return 'Overdue';
    const hours = Math.floor(diff / 36e5);
    if (hours < 24) return `${hours}h left`;
    return `${date.getDate()}/${date.getMonth() + 1}`;
  } catch { return ''; }
}

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

function fromJson(json) {
  const status = json.status || 'assigned';
  return {
    id: json._id || '',
    title: json.task_id?.title || json.title || 'Unknown Task',
    description: json.task_id?.description || json.description || '',
    isMandatory: json.task_id?.is_mandatory || json.is_mandatory || false,
    status,
    points: json.assigned_points || 0,
    rewardType: json.task_id?.reward_type || json.reward_type || 'points',
    moneyReward: +(json.task_id?.money_reward || json.money_reward || 0),
    deadline: json.deadline || null,
    progress: progressFromStatus(status),
    notes: json.notes || '',
    assignmentApproved: json.assignment_approved !== false,
    isSelectedToDelete: false,
  };
}

// ═══════════════════════════════════════════════════════════════
export default function TasksScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const { memberMail, username } = useAuth();

  const [activeTab, setActiveTab] = useState(0); // 0 = Mandatory, 1 = Available
  const [isDeleteMode, setIsDeleteMode] = useState(false);
  const [loading, setLoading] = useState(true);
  const [mandatoryTasks, setMandatoryTasks] = useState([]);
  const [availableTasks, setAvailableTasks] = useState([]);
  const [memberName, setMemberName] = useState('');
  const [memberType, setMemberType] = useState('');
  const [currentMail, setCurrentMail] = useState('');
  const [categories, setCategories] = useState([]);

  // Modal state
  const [showAddModal, setShowAddModal]   = useState(false);
  const [showComplete, setShowComplete]   = useState(false);
  const [selectedTask, setSelectedTask]   = useState(null);
  const [taskName, setTaskName]           = useState('');
  const [taskDesc, setTaskDesc]           = useState('');
  const [selectedCat, setSelectedCat]     = useState('');
  const [saving, setSaving]              = useState(false);

  // ── Load tasks ───────────────────────────────────────────────
  const loadTasks = useCallback(async () => {
    setLoading(true);
    try {
      const tasks = await api.getMyTasks();
      const mandatory = [], available = [];
      let mail = '';

      if (tasks.length > 0) {
        mail = tasks[0].member_mail || '';
      }

      for (const t of tasks) {
        const item = fromJson(t);
        if (item.isMandatory) mandatory.push(item);
        else available.push(item);
      }

      if (!mail) {
        try {
          const wallet = await api.getMyWallet();
          mail = wallet.member_mail || '';
        } catch {}
      }

      if (mail) {
        try {
          const members = await api.getAllMembers();
          const match = members.find(m => m.mail === mail);
          if (match) {
            setMemberName(match.username || mail.split('@')[0]);
            setMemberType(match.member_type_id?.type || '');
          } else {
            setMemberName(mail.split('@')[0]);
          }
          setCurrentMail(mail);
        } catch {
          setCurrentMail(mail);
          setMemberName(mail.split('@')[0]);
        }
      }

      try {
        const cats = await api.getAllTaskCategories();
        setCategories(cats);
        if (cats.length > 0) setSelectedCat(cats[0]._id || '');
      } catch {}

      setMandatoryTasks(mandatory);
      setAvailableTasks(available);
    } catch (e) {
      toast('Error loading tasks: ' + e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadTasks(); }, [loadTasks]);

  // ── Delete mode ──────────────────────────────────────────────
  function toggleDeleteMode() {
    setIsDeleteMode(prev => !prev);
    setMandatoryTasks(t => t.map(x => ({ ...x, isSelectedToDelete: false })));
    setAvailableTasks(t => t.map(x => ({ ...x, isSelectedToDelete: false })));
  }

  function deleteSelected() {
    setMandatoryTasks(t => t.filter(x => !x.isSelectedToDelete));
    setAvailableTasks(t => t.filter(x => !x.isSelectedToDelete));
    setIsDeleteMode(false);
  }

  function toggleSelect(id) {
    const update = t => t.map(x => x.id === id ? { ...x, isSelectedToDelete: !x.isSelectedToDelete } : x);
    setMandatoryTasks(update);
    setAvailableTasks(update);
  }

  // ── Add new task ─────────────────────────────────────────────
  async function addNewTask() {
    if (!taskName.trim() || !selectedCat || !currentMail) return;
    setSaving(true);
    try {
      const resp = await api.createTask({
        title: taskName.trim(),
        description: taskDesc.trim(),
        category_id: selectedCat,
        is_mandatory: activeTab === 0,
        reward_type: 'points',
        money_reward: 0,
      });
      const taskId = resp?.data?.task?._id || '';
      if (!taskId) throw new Error('Task creation failed');

      await api.assignTask({
        task_id: taskId,
        member_mail: currentMail,
        assigned_points: 10,
        penalty_points: 0,
        deadline: new Date(Date.now() + 7 * 864e5).toISOString(),
        priority: 0,
      });

      setTaskName(''); setTaskDesc('');
      setShowAddModal(false);
      toast(t('taskAdded'));
      loadTasks();
    } catch (e) {
      toast('Error: ' + e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Complete task ────────────────────────────────────────────
  function openCompleteDialog(task) {
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
        const pts = reward.points_awarded || 0;
        const money = reward.money_awarded || 0;
        const type = reward.reward_type || 'points';
        let msg = '🎉 ';
        if (type === 'points' || type === 'both') msg += `+${pts} pts `;
        if (type === 'money' || type === 'both') msg += `+${money.toFixed(2)} EGP`;
        toast(msg.trim());
      }
      loadTasks();
    } catch (e) {
      toast('Error: ' + e.message, 'error');
    } finally {
      setSaving(false);
    }
  }

  // ── Render task card ─────────────────────────────────────────
  const renderTaskCard = (task) => {
    const dotColor = dotColorFromStatus(task.status);
    const isSelected = isDeleteMode && task.isSelectedToDelete;
    const isWaiting = task.assignmentApproved && task.status === 'completed';
    const isRejected = task.assignmentApproved && task.status === 'rejected';
    const canComplete = task.assignmentApproved && (task.status === 'assigned' || task.status === 'in_progress');
    const isDone = task.status === 'approved';

    const cardBorderColor = isSelected ? '#E53935' : isWaiting ? '#1E88E5' : isRejected ? '#E53935' : 'var(--color-border)';
    const cardBorderWidth = isSelected || isWaiting || isRejected ? 2 : 1;

    return (
      <div
        key={task.id}
        onClick={() => isDeleteMode && toggleSelect(task.id)}
        style={{
          marginBottom: 12,
          padding: 14,
          background: isSelected ? 'rgba(229,57,53,0.08)' : 'var(--color-white)',
          borderRadius: 18,
          border: `${cardBorderWidth}px solid ${cardBorderColor}`,
          boxShadow: 'var(--shadow-card)',
          cursor: isDeleteMode ? 'pointer' : 'default',
        }}
      >
        {/* Title row */}
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <div style={{
            width: 8, height: 8, borderRadius: '50%',
            background: dotColor, marginTop: 5, flexShrink: 0,
          }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{
              fontFamily: 'var(--font-family)', fontWeight: 600,
              fontSize: 13, color: 'var(--color-text-primary)',
              margin: 0, wordBreak: 'break-word',
            }}>{task.title}</p>
            {task.description && (
              <p style={{
                fontFamily: 'var(--font-family)', fontSize: 10,
                color: 'var(--color-text-secondary)', margin: '2px 0 0',
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>{task.description}</p>
            )}
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 5, flexWrap: 'wrap' }}>
              {task.deadline && (
                <>
                  <Clock size={10} color="var(--color-text-secondary)" />
                  <span style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)' }}>
                    {formatDeadlineShort(task.deadline)}
                  </span>
                </>
              )}
              <span style={{ fontSize: 11 }}>{rewardEmoji(task)}</span>
              <span style={{
                fontFamily: 'var(--font-family)', fontSize: 10,
                fontWeight: 600, color: 'var(--color-primary)',
              }}>{rewardLabel(task)}</span>
            </div>
          </div>
          {isDeleteMode ? (
            task.isSelectedToDelete
              ? <CheckCircle size={22} color="#E53935" />
              : <CircleDot size={22} color="var(--color-text-secondary)" />
          ) : (
            <StatusBadge status={task.status} />
          )}
        </div>

        {/* Progress bar */}
        <div style={{ marginTop: 10 }}>
          <div style={{
            height: 4, borderRadius: 3,
            background: 'var(--color-border-light)',
            overflow: 'hidden',
          }}>
            <div style={{
              height: '100%', width: `${task.progress * 100}%`,
              background: dotColor, borderRadius: 3,
              transition: 'width 0.3s ease',
            }} />
          </div>
          <p style={{
            fontFamily: 'var(--font-family)', fontSize: 9,
            color: dotColor, fontWeight: 500, marginTop: 4,
          }}>Complete: {Math.round(task.progress * 100)}%</p>
        </div>

        {/* Notes */}
        {task.notes && !isDeleteMode && (
          isRejected ? (
            <div style={{
              marginTop: 8, padding: 10,
              background: '#FFEBEE', borderRadius: 10,
              border: '1px solid #FFCDD2',
            }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, fontWeight: 600, color: '#C62828', margin: 0 }}>
                {t('rejectedByParent')}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#E53935', margin: '2px 0 0' }}>
                {task.notes}
              </p>
            </div>
          ) : (
            <div style={{
              marginTop: 8, padding: 8,
              background: '#FFFDE7', borderRadius: 8,
              border: '1px solid #FFE082',
              display: 'flex', gap: 6, alignItems: 'flex-start',
            }}>
              <span style={{ fontSize: 12 }}>📝</span>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#F57F17', margin: 0 }}>
                {task.notes}
              </p>
            </div>
          )
        )}

        {/* Waiting approval info */}
        {isWaiting && !isDeleteMode && (
          <div style={{
            marginTop: 8, padding: 9,
            background: '#E3F2FD', borderRadius: 10,
            border: '1px solid #90CAF9',
            display: 'flex', gap: 6, alignItems: 'center',
          }}>
            <span style={{ fontSize: 14 }}>⏳</span>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: '#1565C0', fontWeight: 500, margin: 0 }}>
              {t('submittedForApproval')}
            </p>
          </div>
        )}

        {/* Mark Complete button */}
        {(canComplete || isRejected) && !isDeleteMode && (
          <button
            onClick={() => openCompleteDialog(task)}
            style={{
              width: '100%', marginTop: 10, padding: '10px 0',
              background: 'linear-gradient(90deg, var(--color-primary), var(--color-primary-light))',
              border: 'none', borderRadius: 10, cursor: 'pointer',
              fontFamily: 'var(--font-family)', fontSize: 12,
              fontWeight: 700, color: '#fff',
              boxShadow: '0 2px 6px rgba(0,137,123,0.25)',
            }}
          >
            {isRejected ? t('markCompleteAgain') : t('markComplete')}
          </button>
        )}
      </div>
    );
  };

  const displayTasks = activeTab === 0 ? mandatoryTasks : availableTasks;

  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      minHeight: '100vh', background: 'var(--color-background)',
    }}>
      <AppBar
        title={t('myTasks')}
        actions={
          <>
            <IconBtn icon={RefreshCw} onClick={loadTasks} />
            <IconBtn
              icon={isDeleteMode ? X : Trash2}
              onClick={toggleDeleteMode}
              color={isDeleteMode ? '#E53935' : 'var(--color-primary)'}
            />
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '0 0 88px' }}>
          {/* Member header */}
          {memberName && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 16px 10px' }}>
              <div style={{ position: 'relative' }}>
                <Avatar name={memberName} size={42} />
                <div style={{
                  position: 'absolute', bottom: 0, right: 0,
                  width: 10, height: 10, borderRadius: '50%',
                  background: 'var(--color-primary)',
                  border: '1.5px solid var(--color-background)',
                }} />
              </div>
              <div>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
                  {memberName}
                </p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                  {memberType ? `${memberType} · ` : ''}{mandatoryTasks.length + availableTasks.length} {t('tasks')}
                </p>
              </div>
            </div>
          )}

          {/* Tab bar */}
          <div style={{
            margin: '0 16px 12px',
            padding: 3,
            background: 'var(--color-primary-surface)',
            borderRadius: 25,
            border: '1px solid var(--color-border)',
            display: 'flex', gap: 0,
          }}>
            {[t('mandatory'), t('available')].map((label, i) => {
              const count = i === 0 ? mandatoryTasks.length : availableTasks.length;
              return (
                <button
                  key={i}
                  onClick={() => setActiveTab(i)}
                  style={{
                    flex: 1, padding: '8px 0',
                    background: activeTab === i ? 'var(--color-primary)' : 'transparent',
                    border: 'none', borderRadius: 22, cursor: 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                    fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                    color: activeTab === i ? '#fff' : 'var(--color-text-secondary)',
                    transition: 'all 0.2s',
                  }}
                >
                  {label}
                  {count > 0 && (
                    <span style={{
                      width: 17, height: 17, borderRadius: '50%',
                      background: i === 0 ? '#E53935' : 'var(--color-primary-light)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 8, fontWeight: 700, color: '#fff',
                    }}>{count}</span>
                  )}
                </button>
              );
            })}
          </div>

          {/* Section header */}
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '0 16px', marginBottom: 10,
          }}>
            <span style={{ fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, color: 'var(--color-text-primary)' }}>
              {activeTab === 0 ? t('mandatoryTasks') : t('availableTasks')}
            </span>
            <span style={{
              fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)',
              fontWeight: 500,
              background: 'var(--color-primary-surface)',
              borderRadius: 10, padding: '3px 10px',
              border: '1px solid var(--color-border)',
            }}>
              {displayTasks.length} {t('tasks')}
            </span>
          </div>

          {/* Task list */}
          <div style={{ padding: '0 16px' }}>
            {displayTasks.length === 0
              ? <EmptyState icon={CheckSquare} message={t('noTasksInSection')} />
              : displayTasks.map(renderTaskCard)
            }
          </div>
        </div>
      )}

      {/* FAB / Delete buttons */}
      <div style={{
        position: 'fixed', bottom: 20, left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 200,
        width: isDeleteMode ? 'calc(100% - 40px)' : 'auto',
        maxWidth: isDeleteMode ? 560 : 'auto',
      }}>
        {isDeleteMode ? (
          <button onClick={deleteSelected} style={{
            width: '100%', padding: '14px 0',
            background: '#E53935', border: 'none', borderRadius: 12,
            fontFamily: 'var(--font-family)', fontSize: 14, fontWeight: 600, color: '#fff',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: '0 4px 16px rgba(229,57,53,0.35)',
          }}>
            <Trash2 size={18} />
            {t('deleteSelected')}
          </button>
        ) : (
          <button
            onClick={() => setShowAddModal(true)}
            style={{
              width: 56, height: 56, borderRadius: '50%',
              background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
              border: 'none', cursor: 'pointer', boxShadow: 'var(--shadow-primary)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff',
            }}
          >
            <Plus size={28} />
          </button>
        )}
      </div>

      {/* Add Task Modal */}
      <Modal
        open={showAddModal}
        onClose={() => { setShowAddModal(false); setTaskName(''); setTaskDesc(''); }}
        title={t('addNewTask')}
        actions={
          <>
            <ModalCancelBtn onClick={() => { setShowAddModal(false); setTaskName(''); setTaskDesc(''); }} />
            <ModalPrimaryBtn
              label={saving ? '…' : t('add')}
              disabled={saving || !taskName.trim() || !selectedCat || !currentMail}
              onClick={addNewTask}
            />
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <FormField label={t('taskName')} value={taskName} onChange={setTaskName} required placeholder="e.g. Clean the kitchen" />
          <FormField label={t('description')} value={taskDesc} onChange={setTaskDesc} placeholder="Optional…" />
          {categories.length > 0 && (
            <SelectField
              label={t('category')}
              value={selectedCat}
              onChange={setSelectedCat}
              options={categories.map(c => ({ value: c._id, label: c.title || c.name || 'Unknown' }))}
              required
            />
          )}
          {(categories.length === 0 || !currentMail) && (
            <div style={{
              padding: 10, background: '#FFF8E1',
              borderRadius: 8, border: '1px solid #FFE082',
            }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: '#E65100', margin: 0 }}>
                {categories.length === 0
                  ? 'No categories available. Ask a parent to create one first.'
                  : 'Could not identify your account. Please refresh.'}
              </p>
            </div>
          )}
        </div>
      </Modal>

      {/* Complete Task Confirmation Modal */}
      <Modal
        open={showComplete}
        onClose={() => setShowComplete(false)}
        title={`✅ ${t('completeTask')}`}
        actions={
          <>
            <ModalCancelBtn onClick={() => setShowComplete(false)} />
            <ModalPrimaryBtn label={saving ? '…' : 'Yes, Complete!'} disabled={saving} onClick={confirmComplete} />
          </>
        }
      >
        {selectedTask && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 13, color: 'var(--color-text-primary)' }}>
              Mark "<strong>{selectedTask.title}</strong>" as completed?
            </p>
            <div style={{
              padding: 10, background: 'var(--color-primary-surface)',
              borderRadius: 10, border: '1px solid var(--color-border)',
            }}>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600, color: 'var(--color-primary)', margin: 0 }}>
                Reward: {rewardLabel(selectedTask)}
              </p>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
