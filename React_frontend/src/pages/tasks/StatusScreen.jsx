// ═══════════════════════════════════════════════════════════════
// Family Status Screen — mirrors status_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { RefreshCw, Users } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import StatusBadge from '../../components/common/StatusBadge';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

function progressFromStatus(status) {
  if (status === 'approved') return 1.0;
  if (status === 'completed' || status === 'pending_approval') return 0.8;
  if (status === 'in_progress') return 0.5;
  return 0.2;
}

function dotColor(status) {
  const map = { approved: '#00BFA5', completed: '#1E88E5', pending_approval: '#1E88E5', in_progress: '#1E88E5', rejected: '#FF5252', late: '#FF5252' };
  return map[status] || '#FB8C00';
}

export default function StatusScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [tasks, setTasks]     = useState([]);
  const [members, setMembers] = useState([]);
  const [filter, setFilter]   = useState('all'); // all | assigned | completed | approved | rejected

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [all, mems] = await Promise.all([
        api.getAllAssignedTasks(),
        api.getAllMembers(),
      ]);
      setTasks(all);
      setMembers(mems);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const FILTER_OPTIONS = [
    { value: 'all', label: 'All' },
    { value: 'assigned', label: 'Pending' },
    { value: 'in_progress', label: 'In Progress' },
    { value: 'completed', label: 'Waiting' },
    { value: 'approved', label: 'Done' },
    { value: 'rejected', label: 'Rejected' },
  ];

  const filtered = filter === 'all' ? tasks : tasks.filter(t => t.status === filter);

  const memberName = (mail) => {
    const m = members.find(x => x.mail === mail);
    return m?.username || mail?.split('@')[0] || '?';
  };

  const statsMap = {
    total: tasks.length,
    done: tasks.filter(t => t.status === 'approved').length,
    waiting: tasks.filter(t => t.status === 'completed' || t.status === 'pending_approval').length,
    pending: tasks.filter(t => t.status === 'assigned' || t.status === 'in_progress').length,
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={t('familyStatus')} actions={<IconBtn icon={RefreshCw} onClick={load} />} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%', padding: '12px 16px 32px' }}>
          {/* Stats row */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 20 }}>
            {[
              { label: 'Total', value: statsMap.total, color: 'var(--color-primary)' },
              { label: 'Done', value: statsMap.done, color: '#00BFA5' },
              { label: 'Waiting', value: statsMap.waiting, color: '#1E88E5' },
              { label: 'Pending', value: statsMap.pending, color: '#FB8C00' },
            ].map((s, i) => (
              <div key={i} style={{
                background: 'var(--color-white)', borderRadius: 12,
                padding: '12px 8px', textAlign: 'center',
                border: '1px solid var(--color-border)',
                boxShadow: 'var(--shadow-card)',
              }}>
                <p style={{ fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 22, color: s.color, margin: 0 }}>
                  {s.value}
                </p>
                <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-secondary)', margin: 0 }}>
                  {s.label}
                </p>
              </div>
            ))}
          </div>

          {/* Filter chips */}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
            {FILTER_OPTIONS.map(opt => (
              <button key={opt.value} onClick={() => setFilter(opt.value)} style={{
                padding: '5px 12px',
                background: filter === opt.value ? 'var(--color-primary)' : 'var(--color-white)',
                color: filter === opt.value ? '#fff' : 'var(--color-text-secondary)',
                border: filter === opt.value ? 'none' : '1px solid var(--color-border)',
                borderRadius: 20, cursor: 'pointer',
                fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600,
              }}>{opt.label}</button>
            ))}
          </div>

          {/* Task list */}
          {filtered.length === 0
            ? <EmptyState icon={Users} message="No tasks matching this filter" />
            : filtered.map(task => {
              const progress = progressFromStatus(task.status);
              const dc = dotColor(task.status);
              return (
                <div key={task._id} style={{
                  background: 'var(--color-white)', borderRadius: 16,
                  border: '1px solid var(--color-border)', padding: 14,
                  marginBottom: 10, boxShadow: 'var(--shadow-card)',
                }}>
                  <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginBottom: 10 }}>
                    <Avatar name={memberName(task.member_mail)} size={36} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                        {task.task_id?.title || 'Unknown Task'}
                      </p>
                      <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                        {memberName(task.member_mail)} · {task.assigned_points || 0} pts
                      </p>
                    </div>
                    <StatusBadge status={task.status} />
                  </div>
                  {/* Progress */}
                  <div style={{ height: 4, borderRadius: 3, background: 'var(--color-border-light)', overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: `${progress * 100}%`, background: dc, borderRadius: 3 }} />
                  </div>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: dc, fontWeight: 500, margin: '4px 0 0' }}>
                    {Math.round(progress * 100)}%
                  </p>
                </div>
              );
            })
          }
        </div>
      )}
    </div>
  );
}
